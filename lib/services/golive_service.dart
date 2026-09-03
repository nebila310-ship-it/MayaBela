import 'package:flutter/foundation.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/database/supabase/supabase_storage_bootstrap.dart';
import 'package:mayabela/models/golive_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/persistence/golive_persistence_service.dart';
import 'package:mayabela/services/persistence/student_persistence_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/student_excel_import.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/services/totp.dart';
import 'package:mayabela/utils/short_registry_id.dart';

/// Phase J go-live desk: opt-in MFA, privacy rights, school backups, Excel import.
/// Never writes grades, exams, or G–I collections. Never force-enrolls Admin.
class GoliveService extends ChangeNotifier {
  GoliveService._();
  static final instance = GoliveService._();

  final List<MfaEnrollment> _mfa = [];
  final List<PrivacyConsent> _consents = [];
  final List<DataRightsRequest> _rights = [];
  final List<SchoolBackupRecord> _backups = [];
  bool _loaded = false;

  @visibleForTesting
  static void resetForTests() {
    instance._mfa.clear();
    instance._consents.clear();
    instance._rights.clear();
    instance._backups.clear();
    instance._loaded = true;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    await GolivePersistenceService.instance.loadIntoService();
  }

  String get _schoolId =>
      (AuthService.activeSchoolId ?? AuthService.currentUser?.schoolId ?? '')
          .trim()
          .toUpperCase();

  String get _username => AuthService.currentUser?.username ?? '';

  bool get _isStudent =>
      AuthService.currentUser?.roleKey == AuthService.roleStudent;
  bool get _isParent =>
      AuthService.currentUser?.roleKey == AuthService.roleParent;
  bool get _isPublicReader => _isStudent || _isParent;

  bool get canManageDesk => ModuleAccess.canManage('go_live');
  bool get canViewDesk => ModuleAccess.canView('go_live');

  bool get canImportStudents =>
      canManageDesk || ModuleAccess.canManage('students');

  List<String> get _linkedIds => AuthService.activeLinkedStudentIds()
      .map((id) => id.trim().toUpperCase())
      .where((id) => id.isNotEmpty)
      .toList();

  bool _ownsStudent(String studentId) {
    final id = studentId.trim().toUpperCase();
    if (id.isEmpty) return false;
    if (_isStudent) {
      final self = (AuthService.currentUser?.linkedStudentId ?? _username)
          .trim()
          .toUpperCase();
      return id == self;
    }
    if (_isParent) return _linkedIds.contains(id);
    return canViewDesk;
  }

  List<MfaEnrollment> enrollmentsForSchool([String? schoolId]) {
    var list = _schoolFilter(_mfa, schoolId);
    final uname = _username.trim().toLowerCase();
    if (!canViewDesk) {
      list = list
          .where((row) => row.username.trim().toLowerCase() == uname)
          .toList();
    }
    return list
        .map(
          (row) => row.username.trim().toLowerCase() == uname
              ? row
              : row.copyWith(clearSecret: true),
        )
        .toList()
      ..sort((a, b) => b.enrolledAt.compareTo(a.enrolledAt));
  }

  MfaEnrollment? enrollmentForUsername(String username, {String? schoolId}) {
    final key = username.trim().toLowerCase();
    if (key.isEmpty) return null;
    for (final row in _schoolFilter(_mfa, schoolId)) {
      if (row.username.trim().toLowerCase() == key && row.enabled) {
        return row;
      }
    }
    return null;
  }

  bool isEnabledFor(String username, {String? schoolId}) =>
      enrollmentForUsername(username, schoolId: schoolId) != null;

  int mfaEnrolledCount([String? schoolId]) =>
      _schoolFilter(_mfa, schoolId).where((row) => row.enabled).length;

  List<PrivacyConsent> consentsForSchool([String? schoolId]) {
    var list = _schoolFilter(_consents, schoolId);
    if (_isPublicReader) {
      final uname = _username.trim().toLowerCase();
      list = list.where((row) {
        if (row.authorUsername.trim().toLowerCase() == uname) return true;
        return row.studentId.isNotEmpty && _ownsStudent(row.studentId);
      }).toList();
    }
    return list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<DataRightsRequest> rightsForSchool([String? schoolId]) {
    var list = _schoolFilter(_rights, schoolId);
    if (_isPublicReader) {
      final uname = _username.trim().toLowerCase();
      list = list.where((row) {
        if (row.authorUsername.trim().toLowerCase() == uname) return true;
        return row.studentId.isNotEmpty && _ownsStudent(row.studentId);
      }).toList();
    }
    return list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<SchoolBackupRecord> backupsForSchool([String? schoolId]) {
    if (_isPublicReader || !canViewDesk) return const [];
    return _schoolFilter(_backups, schoolId)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  DateTime? lastBackupAt([String? schoolId]) {
    final rows = backupsForSchool(schoolId);
    return rows.isEmpty ? null : rows.first.createdAt;
  }

  int openDataRightsCount([String? schoolId]) => rightsForSchool(schoolId)
      .where(
        (row) =>
            row.status == DataRightsStatus.open ||
            row.status == DataRightsStatus.reviewing,
      )
      .length;

  GoLiveCapacitySnapshot capacitySnapshot() {
    return GoLiveCapacitySnapshot(
      cloudReady: SupabaseBootstrap.isInitialized,
      storageReady: SupabaseStorageBootstrap.lastError == null &&
          !SupabaseStorageBootstrap.deferred &&
          SupabaseBootstrap.isInitialized,
      lastBackupAt: lastBackupAt(),
      mfaEnrolled: mfaEnrolledCount(),
      openDataRights: openDataRightsCount(),
    );
  }

  /// Starts opt-in MFA. Returns the secret and recovery codes once.
  /// Does not enable until [confirmEnrollment] sees a valid TOTP.
  Future<({MfaEnrollment enrollment, List<String> recoveryCodes})>
      startEnrollment({String? username, String? schoolId}) async {
    final uname = (username ?? _username).trim();
    if (uname.isEmpty) {
      throw StateError('Sign in before enrolling an authenticator.');
    }
    if (_username.isNotEmpty &&
        uname.toLowerCase() != _username.trim().toLowerCase() &&
        !canManageDesk) {
      throw StateError('You can only enroll your own authenticator.');
    }
    final existing = _findMfa(uname, schoolId);
    if (existing != null && existing.enabled) {
      throw StateError('Authenticator is already enabled for this username.');
    }
    final now = DateTime.now().toUtc();
    final codes = Totp.generateRecoveryCodes();
    final row = MfaEnrollment(
      id: existing?.id ?? _id('MFA', _mfa.map((item) => item.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      username: uname,
      secret: Totp.generateSecret(),
      enabled: false,
      recoveryCodeHashes: codes.map(Totp.hashRecovery).toList(),
      enrolledAt: now,
      enrolledBy: _username,
    );
    _upsertMfa(row);
    await _persist();
    return (enrollment: row, recoveryCodes: codes);
  }

  Future<MfaEnrollment> confirmEnrollment(String username, String code) async {
    final row = _findMfa(username);
    if (row == null || row.secret.isEmpty) {
      throw StateError('Start authenticator enrollment first.');
    }
    if (!Totp.verify(row.secret, code)) {
      throw StateError('That authenticator code is not valid.');
    }
    final enabled = row.copyWith(enabled: true);
    _upsertMfa(enabled);
    await _persist();
    return enabled;
  }

  Future<void> disableEnrollment(
    String username, {
    String? code,
    String? recoveryCode,
  }) async {
    final row = _findMfa(username);
    if (row == null) return;
    final self = username.trim().toLowerCase() == _username.trim().toLowerCase();
    if (!self && !canManageDesk) {
      throw StateError('You can only disable your own authenticator.');
    }
    if (self && row.enabled) {
      final totpOk = code != null &&
          code.trim().isNotEmpty &&
          row.secret.isNotEmpty &&
          Totp.verify(row.secret, code);
      final recoveryOk = recoveryCode != null &&
          _matchRecovery(row, recoveryCode) != null;
      if (!totpOk && !recoveryOk && !canManageDesk) {
        throw StateError('Enter an authenticator or recovery code to disable.');
      }
    }
    _mfa.removeWhere((item) => item.id == row.id);
    await _persist();
  }

  bool verifyLogin(String username, String code) {
    final row = enrollmentForUsername(username);
    if (row == null) return true;
    if (row.secret.isNotEmpty && Totp.verify(row.secret, code)) {
      return true;
    }
    final hash = _matchRecovery(row, code);
    if (hash == null) return false;
    final remaining = [...row.recoveryCodeHashes]..remove(hash);
    _upsertMfa(row.copyWith(recoveryCodeHashes: remaining));
    unawaitedPersist();
    return true;
  }

  void unawaitedPersist() {
    _persist();
  }

  Future<PrivacyConsent> recordConsent({
    required ConsentPurpose purpose,
    required ConsentState state,
    String subjectName = '',
    String subjectRole = '',
    String studentId = '',
    String? schoolId,
  }) async {
    if (_isPublicReader &&
        studentId.trim().isNotEmpty &&
        !_ownsStudent(studentId)) {
      throw StateError('You can only record consent for a linked student.');
    }
    if (!_isPublicReader && !canViewDesk) {
      throw StateError('You cannot record school consent.');
    }
    final now = DateTime.now();
    final sid = studentId.trim().toUpperCase();
    final name = subjectName.trim().isNotEmpty
        ? subjectName.trim()
        : (sid.isEmpty
            ? (AuthService.currentUser?.fullName ?? _username)
            : _studentName(sid));
    final row = PrivacyConsent(
      id: _id('CON', _consents.map((item) => item.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      subjectName: name,
      subjectRole: subjectRole.trim().isEmpty
          ? (AuthService.currentUser?.roleKey ?? '')
          : subjectRole.trim(),
      studentId: sid,
      purpose: purpose,
      state: state,
      authorUsername: _username,
      createdAt: now,
      updatedAt: now,
    );
    _consents.add(row);
    await _persist();
    return row;
  }

  Future<PrivacyConsent> revokeConsent(String id) async {
    final idx = _consents.indexWhere((item) => item.id == id);
    if (idx < 0) throw StateError('Consent not found.');
    final row = _consents[idx];
    if (_isPublicReader &&
        row.authorUsername.trim().toLowerCase() !=
            _username.trim().toLowerCase()) {
      throw StateError('You can only revoke your own consent.');
    }
    final updated = row.copyWith(
      state: ConsentState.revoked,
      updatedAt: DateTime.now(),
    );
    _consents[idx] = updated;
    await _persist();
    return updated;
  }

  Future<DataRightsRequest> fileDataRightsRequest({
    required DataRightsKind kind,
    String studentId = '',
    String details = '',
    String? schoolId,
  }) async {
    if (!_isPublicReader && !canViewDesk) {
      throw StateError('You cannot file a data-rights request.');
    }
    if (_isPublicReader &&
        studentId.trim().isNotEmpty &&
        !_ownsStudent(studentId)) {
      throw StateError(
        'You can only file a request for your linked student.',
      );
    }
    final now = DateTime.now();
    final sid = studentId.trim().toUpperCase();
    final row = DataRightsRequest(
      id: _id('DRR', _rights.map((item) => item.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      studentId: sid,
      studentName: sid.isEmpty
          ? (AuthService.currentUser?.fullName ?? _username)
          : _studentName(sid),
      kind: kind,
      status: DataRightsStatus.open,
      authorUsername: _username,
      authorRole: AuthService.currentUser?.roleKey,
      details: details.trim(),
      createdAt: now,
      updatedAt: now,
    );
    _rights.add(row);
    await _persist();
    return row;
  }

  Future<DataRightsRequest> reviewDataRights(
    String id,
    DataRightsStatus status, {
    String staffNote = '',
  }) async {
    _requireStaffDesk();
    final idx = _rights.indexWhere((item) => item.id == id);
    if (idx < 0) throw StateError('Request not found.');
    var row = _rights[idx].copyWith(
      status: status,
      staffNote: staffNote,
      updatedAt: DateTime.now(),
    );
    if (status == DataRightsStatus.redacted &&
        row.kind == DataRightsKind.erasure) {
      if (row.studentId.isEmpty) {
        throw StateError('Erasure needs a student id.');
      }
      redactStudentPersonalFields(row.studentId);
    }
    _rights[idx] = row;
    await _persist();
    return row;
  }

  /// Redacts personal fields. Keeps student id, grade, class, and the grade store.
  AdminStudentRecord redactStudentPersonalFields(String studentId) {
    _requireStaffDesk();
    final existing = StudentRegistryService.instance.lookupAnyById(studentId);
    if (existing == null) {
      throw StateError('Student not found.');
    }
    final redacted = AdminStudentRecord(
      studentId: existing.studentId,
      fullName: 'Redacted ${existing.studentId}',
      grade: existing.grade,
      className: existing.className,
      schoolId: existing.schoolId,
      campus: existing.campus,
      dateOfBirth: DateTime.utc(2000, 1, 1),
      gender: null,
      emergencyContact: null,
      transportEnabled: existing.transportEnabled,
      transportId: existing.transportId,
      isActive: existing.isActive,
      lifecycleStatus: existing.lifecycleStatus,
      photoPath: null,
      fatherName: null,
      fatherPhone: null,
      motherName: null,
      motherPhone: null,
      guardianName: null,
      guardianPhone: null,
      emergencyPhone1: null,
      emergencyContact1Name: null,
      emergencyPhone2: null,
      emergencyContact2Name: null,
      homeroomTeacherId: existing.homeroomTeacherId,
      academicYear: existing.academicYear,
      hasMedicalCondition: false,
      medicalConditionDetails: null,
      otherMedicalInfo: null,
      loginUsername: existing.loginUsername,
      initialPassword: null,
      mustChangePassword: existing.mustChangePassword,
      portalAccountStatus: existing.portalAccountStatus,
      portalAccountCreatedAt: existing.portalAccountCreatedAt,
      portalAccountCreatedBy: existing.portalAccountCreatedBy,
      firstLoginCompleted: existing.firstLoginCompleted,
    );
    StudentRegistryService.instance.updateStudent(redacted);
    return redacted;
  }

  Map<String, dynamic> subjectAccessExport(String studentId) {
    if (_isPublicReader && !_ownsStudent(studentId)) {
      throw StateError('You can only export a linked student.');
    }
    if (!_isPublicReader && !canViewDesk) {
      throw StateError('You cannot export student data.');
    }
    final student = StudentRegistryService.instance.lookupAnyById(studentId);
    if (student == null) throw StateError('Student not found.');
    final consents = consentsForSchool()
        .where((row) => row.studentId == student.studentId)
        .map((row) => row.toMap())
        .toList();
    return {
      'studentId': student.studentId,
      'fullName': student.fullName,
      'grade': student.grade,
      'className': student.className,
      'dateOfBirth': student.dateOfBirth.toIso8601String(),
      'gender': student.gender,
      'fatherName': student.fatherName,
      'motherName': student.motherName,
      'guardianName': student.guardianName,
      'consents': consents,
      'excluded': [
        'counseling staff notes',
        'safeguarding / child-protection files',
        'passwords',
        'authenticator secrets',
      ],
    };
  }

  Future<SchoolBackupRecord> recordSchoolBackup({String notes = ''}) async {
    _requireStaffDesk();
    final now = DateTime.now();
    final students =
        StudentRegistryService.instance.studentsForSchool(_schoolId);
    final staff = TeacherRegistryService.instance
        .getAllTeachers()
        .where(
          (t) =>
              _schoolId.isEmpty ||
              t.schoolId.trim().toUpperCase() == _schoolId,
        )
        .length;
    final row = SchoolBackupRecord(
      id: _id('BAK', _backups.map((item) => item.id)),
      schoolId: _schoolId,
      createdAt: now,
      createdBy: _username,
      studentCount: students.length,
      staffCount: staff,
      mfaCount: mfaEnrolledCount(),
      notes: notes.trim(),
    );
    _backups.add(row);
    await _persist();
    return row;
  }

  Map<String, dynamic> schoolSnapshotExport() {
    if (!canViewDesk) {
      throw StateError('You cannot export a school snapshot.');
    }
    final students =
        StudentRegistryService.instance.studentsForSchool(_schoolId);
    return {
      'schoolId': _schoolId,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'students': students.length,
      'staff': TeacherRegistryService.instance.getAllTeachers().length,
      'mfaEnrolled': mfaEnrolledCount(),
      'openDataRights': openDataRightsCount(),
      'studentDirectory': [
        for (final row in students)
          {
            'studentId': row.studentId,
            'fullName': row.fullName,
            'grade': row.grade,
            'className': row.className,
          },
      ],
    };
  }

  List<StudentImportRow> previewStudentImport({
    required List<int> bytes,
    required String filename,
  }) {
    _requireImport();
    return StudentExcelImport.parseBytes(bytes: bytes, filename: filename);
  }

  Future<StudentImportResult> importStudentRows(
    List<StudentImportRow> rows, {
    String? schoolId,
  }) async {
    _requireImport();
    final sid = (schoolId ?? _schoolId).toUpperCase();
    final created = <String>[];
    final skipped = <String>[];
    final registry = StudentRegistryService.instance;
    for (final row in rows) {
      if (row.existingId != null &&
          registry.lookupAnyById(row.existingId!) != null) {
        skipped.add('${row.fullName} (existing id)');
        continue;
      }
      final duplicate = registry.studentsForSchool(sid).any(
            (student) =>
                student.fullName.trim().toLowerCase() ==
                    row.fullName.trim().toLowerCase() &&
                student.className.trim().toLowerCase() ==
                    row.className.trim().toLowerCase(),
          );
      if (duplicate) {
        skipped.add('${row.fullName} (same name + class)');
        continue;
      }
      final record = registry.addStudent(
        schoolId: sid,
        fullName: row.fullName,
        grade: row.grade,
        className: row.className,
        dateOfBirth: row.dateOfBirth,
        gender: row.gender,
        fatherName: row.fatherName,
        fatherPhone: row.fatherPhone,
        motherName: row.motherName,
        motherPhone: row.motherPhone,
      );
      created.add(record.studentId);
    }
    if (created.isNotEmpty) {
      await StudentPersistenceService.instance.saveRegistryFromService(
        syncStudentId: created.last,
      );
    }
    return StudentImportResult(createdIds: created, skipped: skipped);
  }

  void applyPersistedData({
    List<MfaEnrollment>? enrollments,
    List<PrivacyConsent>? consents,
    List<DataRightsRequest>? rights,
    List<SchoolBackupRecord>? backups,
    bool merge = false,
  }) {
    void mergeList<T>(
      List<T> local,
      List<T> incoming,
      String Function(T) idOf,
    ) {
      if (!merge) {
        local
          ..clear()
          ..addAll(incoming);
        return;
      }
      final byId = {for (final item in local) idOf(item): item};
      for (final item in incoming) {
        byId[idOf(item)] = item;
      }
      local
        ..clear()
        ..addAll(byId.values);
    }

    if (enrollments != null) {
      final uname = _username.trim().toLowerCase();
      final safe = enrollments.map((row) {
        if (row.username.trim().toLowerCase() == uname) return row;
        return row.copyWith(clearSecret: true);
      }).toList();
      mergeList(_mfa, safe, (row) => row.id);
    }
    if (consents != null) mergeList(_consents, consents, (row) => row.id);
    if (rights != null) mergeList(_rights, rights, (row) => row.id);
    if (backups != null) {
      mergeList(
        _backups,
        _isPublicReader ? const [] : backups,
        (row) => row.id,
      );
    }
    _loaded = true;
    notifyListeners();
  }

  List<Map<String, dynamic>> mfaMaps({bool cloud = false}) {
    final rows = cloud
        ? _mfa.where((row) => row.secret.isNotEmpty)
        : _mfa;
    return rows.map((row) => row.toMap(includeSecret: row.secret.isNotEmpty)).toList();
  }

  List<Map<String, dynamic>> consentMaps() =>
      _consents.map((row) => row.toMap()).toList();

  List<Map<String, dynamic>> rightsMaps() => _rights
      .map(
        (row) => row.toMap(includeStaffNote: !_isPublicReader),
      )
      .toList();

  List<Map<String, dynamic>> backupMaps() =>
      _backups.map((row) => row.toMap()).toList();

  MfaEnrollment? _findMfa(String username, [String? schoolId]) {
    final key = username.trim().toLowerCase();
    for (final row in _schoolFilter(_mfa, schoolId)) {
      if (row.username.trim().toLowerCase() == key) return row;
    }
    return null;
  }

  void _upsertMfa(MfaEnrollment row) {
    final idx = _mfa.indexWhere((item) => item.id == row.id);
    if (idx >= 0) {
      _mfa[idx] = row;
    } else {
      _mfa.add(row);
    }
  }

  String? _matchRecovery(MfaEnrollment row, String code) {
    final hash = Totp.hashRecovery(code);
    for (final stored in row.recoveryCodeHashes) {
      if (Totp.constantTimeEquals(stored, hash)) return stored;
    }
    return null;
  }

  String _studentName(String studentId) {
    return StudentRegistryService.instance.lookupAnyById(studentId)?.fullName ??
        studentId;
  }

  List<T> _schoolFilter<T>(List<T> rows, String? schoolId) {
    final sid = (schoolId ?? _schoolId).toUpperCase();
    if (sid.isEmpty) return List<T>.from(rows);
    return rows.where((row) {
      final rowSchool = switch (row) {
        MfaEnrollment r => r.schoolId,
        PrivacyConsent r => r.schoolId,
        DataRightsRequest r => r.schoolId,
        SchoolBackupRecord r => r.schoolId,
        _ => '',
      };
      return rowSchool == sid;
    }).toList();
  }

  void _requireStaffDesk() {
    if (!canManageDesk) {
      throw StateError('Only the go-live desk can complete this action.');
    }
  }

  void _requireImport() {
    if (!canImportStudents) {
      throw StateError('Only registrars and owners can import students.');
    }
  }

  Future<void> _persist() async {
    notifyListeners();
    await GolivePersistenceService.instance.saveFromService();
  }

  String _id(String prefix, Iterable<String> existing) {
    return ShortRegistryId.allocate(
      prefix: prefix,
      existingIds: existing,
      isTaken: (id) => existing.contains(id),
    );
  }
}
