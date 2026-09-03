import 'package:flutter/foundation.dart';

import 'package:mayabela/models/student_support_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/messaging_access_service.dart';
import 'package:mayabela/services/persistence/student_support_persistence_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/utils/short_registry_id.dart';

/// Phase G student-support desk. Clinic, counseling, IEP, and college sit on
/// the care collections. [SafeguardingCase] files never leave the
/// care-leadership desk — not parents, students, classroom teachers, or QA.
class StudentSupportService extends ChangeNotifier {
  StudentSupportService._();
  static final instance = StudentSupportService._();

  final List<HealthRecord> _health = [];
  final List<CounselingRecord> _counseling = [];
  final List<IepPlan> _iep = [];
  final List<CollegeGuidancePlan> _college = [];
  final List<SupportRequest> _requests = [];
  final List<SafeguardingCase> _safeguarding = [];
  bool _loaded = false;

  @visibleForTesting
  static void resetForTests() {
    instance._health.clear();
    instance._counseling.clear();
    instance._iep.clear();
    instance._college.clear();
    instance._requests.clear();
    instance._safeguarding.clear();
    instance._loaded = true;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    await StudentSupportPersistenceService.instance.loadIntoService();
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

  bool get canManageDesk => ModuleAccess.canManage('student_affairs');
  bool get canViewDesk => ModuleAccess.canView('student_affairs');
  bool get canViewSafeguarding => ModuleAccess.canView('safeguarding');
  bool get canManageSafeguarding => ModuleAccess.canManage('safeguarding');

  List<HealthRecord> healthForSchool([String? schoolId]) {
    var list = _schoolFilter(_health, schoolId);
    if (_isStudent) return const [];
    if (_isParent) {
      list = list
          .where((row) => _ownsStudent(row.studentId))
          .map(_publicHealth)
          .toList();
    }
    return list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<CounselingRecord> counselingForSchool([String? schoolId]) {
    var list = _schoolFilter(_counseling, schoolId);
    if (_isStudent) return const [];
    if (_isParent) {
      list = list
          .where((row) => _ownsStudent(row.studentId))
          .map(_publicCounseling)
          .toList();
    }
    return list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<IepPlan> iepForSchool([String? schoolId]) {
    var list = _schoolFilter(_iep, schoolId);
    if (_isStudent) return const [];
    if (_isParent) {
      list = list
          .where((row) => _ownsStudent(row.studentId))
          .map(_publicIep)
          .toList();
    }
    return list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<CollegeGuidancePlan> collegeForSchool([String? schoolId]) {
    var list = _schoolFilter(_college, schoolId);
    if (_isPublicReader) {
      list = list
          .where((row) => _ownsStudent(row.studentId))
          .map(_publicCollege)
          .toList();
    }
    return list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<SupportRequest> requestsForSchool([String? schoolId]) {
    var list = _schoolFilter(_requests, schoolId);
    if (_isPublicReader) {
      final uname = _username.trim().toLowerCase();
      list = list
          .where(
            (row) =>
                _ownsStudent(row.studentId) ||
                (uname.isNotEmpty &&
                    row.authorUsername.trim().toLowerCase() == uname),
          )
          .toList();
    }
    return list..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<SafeguardingCase> safeguardingForSchool([String? schoolId]) {
    if (!canViewSafeguarding) return const [];
    return _schoolFilter(_safeguarding, schoolId)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<HealthRecord> healthForStudent(String studentId) =>
      healthForSchool().where((row) => row.studentId == studentId).toList();

  List<CounselingRecord> counselingForStudent(String studentId) =>
      counselingForSchool().where((row) => row.studentId == studentId).toList();

  List<IepPlan> iepForStudent(String studentId) =>
      iepForSchool().where((row) => row.studentId == studentId).toList();

  CollegeGuidancePlan? collegeForStudent(String studentId) {
    for (final row in collegeForSchool()) {
      if (row.studentId == studentId) return row;
    }
    return null;
  }

  List<SupportRequest> requestsForStudent(String studentId) =>
      requestsForSchool().where((row) => row.studentId == studentId).toList();

  List<SafeguardingCase> safeguardingForStudent(String studentId) =>
      safeguardingForSchool()
          .where((row) => row.studentId == studentId)
          .toList();

  List<SupportRequest> pendingRequests([String? schoolId]) =>
      requestsForSchool(schoolId)
          .where((row) => row.status != SupportRequestStatus.completed)
          .toList();

  int pendingRequestCount([String? schoolId]) => pendingRequests(schoolId).length;

  List<IepPlan> unsignedIeps([String? schoolId]) => iepForSchool(schoolId)
      .where(
        (row) =>
            row.stage == IepStage.intake ||
            row.stage == IepStage.draftPlan ||
            !row.parentAgreed,
      )
      .toList();

  int unsignedIepCount([String? schoolId]) => unsignedIeps(schoolId).length;

  List<SafeguardingCase> openSafeguarding([String? schoolId]) =>
      safeguardingForSchool(schoolId).where((row) => row.isOpen).toList();

  int openSafeguardingCount([String? schoolId]) =>
      openSafeguarding(schoolId).length;

  Future<HealthRecord> addHealthRecord({
    required String studentId,
    required HealthRecordType type,
    String title = '',
    String details = '',
    String staffNotes = '',
    DateTime? occurredAt,
    String? schoolId,
  }) async {
    _requireStaffDesk();
    final now = DateTime.now();
    final meta = _studentMeta(studentId);
    final record = HealthRecord(
      id: _id('HR', _health.map((row) => row.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      studentId: studentId.trim().toUpperCase(),
      studentName: meta.name,
      className: meta.className,
      type: type,
      title: title.trim(),
      details: details.trim(),
      staffNotes: staffNotes.trim(),
      occurredAt: occurredAt,
      createdBy: _username,
      createdAt: now,
      updatedAt: now,
    );
    _health.add(record);
    await _persist();
    return record;
  }

  Future<CounselingRecord> addCounselingRecord({
    required String studentId,
    required CounselingKind kind,
    String title = '',
    String parentSummary = '',
    String staffNotes = '',
    String? referralTo,
    DateTime? startsAt,
    String? schoolId,
  }) async {
    _requireStaffDesk();
    final now = DateTime.now();
    final meta = _studentMeta(studentId);
    final record = CounselingRecord(
      id: _id('CN', _counseling.map((row) => row.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      studentId: studentId.trim().toUpperCase(),
      studentName: meta.name,
      className: meta.className,
      kind: kind,
      title: title.trim(),
      parentSummary: parentSummary.trim(),
      staffNotes: staffNotes.trim(),
      referralTo: referralTo?.trim(),
      startsAt: startsAt,
      createdBy: _username,
      createdAt: now,
      updatedAt: now,
    );
    _counseling.add(record);
    await _persist();
    return record;
  }

  Future<IepPlan> addIepPlan({
    required String studentId,
    String goals = '',
    String accommodations = '',
    String staffNotes = '',
    String parentAgreementText = '',
    IepStage stage = IepStage.intake,
    DateTime? nextReviewAt,
    String? schoolId,
  }) async {
    _requireStaffDesk();
    final now = DateTime.now();
    final meta = _studentMeta(studentId);
    final plan = IepPlan(
      id: _id('IP', _iep.map((row) => row.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      studentId: studentId.trim().toUpperCase(),
      studentName: meta.name,
      className: meta.className,
      stage: stage,
      goals: goals.trim(),
      accommodations: accommodations.trim(),
      staffNotes: staffNotes.trim(),
      parentAgreementText: parentAgreementText.trim(),
      nextReviewAt: nextReviewAt,
      createdBy: _username,
      createdAt: now,
      updatedAt: now,
    );
    _iep.add(plan);
    await _persist();
    return plan;
  }

  Future<IepPlan> updateIepStage(String id, IepStage stage) async {
    _requireStaffDesk();
    final plan = _iep.cast<IepPlan?>().firstWhere(
          (row) => row?.id == id,
          orElse: () => null,
        );
    if (plan == null) {
      throw StateError('IEP plan not found.');
    }
    plan.stage = stage;
    plan.updatedAt = DateTime.now();
    await _persist();
    return plan;
  }

  /// Parent agreement. Does not write grades. Cloud write of the IEP itself
  /// stays on the care desk; the parent also files a [SupportRequest].
  Future<IepPlan> signIepPlan(String id, {String note = ''}) async {
    if (!_isParent) {
      throw StateError('Only a parent can sign an IEP agreement.');
    }
    final plan = _iep.cast<IepPlan?>().firstWhere(
          (row) => row?.id == id,
          orElse: () => null,
        );
    if (plan == null) {
      throw StateError('IEP plan not found.');
    }
    if (!_ownsStudent(plan.studentId)) {
      throw StateError('You can only sign your child\'s IEP.');
    }
    plan.stage = IepStage.parentAgreement;
    plan.parentSignedAt = DateTime.now();
    plan.parentSignedBy = _username;
    plan.updatedAt = DateTime.now();
    final hasOpen = _requests.any(
      (row) =>
          row.relatedPlanId == id &&
          row.kind == SupportRequestKind.iepAgreement &&
          row.status != SupportRequestStatus.completed,
    );
    if (!hasOpen) {
      await submitSupportRequest(
        studentId: plan.studentId,
        kind: SupportRequestKind.iepAgreement,
        body: note.trim().isEmpty
            ? 'Parent signed the IEP agreement.'
            : note.trim(),
        relatedPlanId: id,
      );
      return plan;
    }
    await _persist();
    return plan;
  }

  Future<CollegeGuidancePlan> upsertCollegePlan({
    required String studentId,
    CollegeStage stage = CollegeStage.exploring,
    String targets = '',
    String portfolio = '',
    String notes = '',
    DateTime? nextAppointmentAt,
    String? schoolId,
  }) async {
    _requireStaffDesk();
    final now = DateTime.now();
    final meta = _studentMeta(studentId);
    final existing = _college.cast<CollegeGuidancePlan?>().firstWhere(
          (row) => row?.studentId == studentId.trim().toUpperCase(),
          orElse: () => null,
        );
    if (existing != null) {
      existing.studentName = meta.name;
      existing.className = meta.className;
      existing.stage = stage;
      existing.targets = targets.trim();
      existing.portfolio = portfolio.trim();
      existing.notes = notes.trim();
      existing.nextAppointmentAt = nextAppointmentAt;
      existing.updatedAt = now;
      await _persist();
      return existing;
    }
    final plan = CollegeGuidancePlan(
      id: _id('CG', _college.map((row) => row.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      studentId: studentId.trim().toUpperCase(),
      studentName: meta.name,
      className: meta.className,
      stage: stage,
      targets: targets.trim(),
      portfolio: portfolio.trim(),
      notes: notes.trim(),
      nextAppointmentAt: nextAppointmentAt,
      createdBy: _username,
      createdAt: now,
      updatedAt: now,
    );
    _college.add(plan);
    await _persist();
    return plan;
  }

  Future<SupportRequest> submitSupportRequest({
    required String studentId,
    required SupportRequestKind kind,
    String body = '',
    String? relatedPlanId,
    String? schoolId,
  }) async {
    if (!_isParent && !_isStudent && !canManageDesk) {
      throw StateError('You cannot submit a student-support request.');
    }
    if (_isParent && !_ownsStudent(studentId)) {
      throw StateError('You can only request support for your linked child.');
    }
    if (_isStudent) {
      final self = (AuthService.currentUser?.linkedStudentId ?? '')
          .trim()
          .toUpperCase();
      if (self.isEmpty || self != studentId.trim().toUpperCase()) {
        throw StateError('You can only request support for yourself.');
      }
    }
    final now = DateTime.now();
    final meta = _studentMeta(studentId);
    final request = SupportRequest(
      id: _id('SR', _requests.map((row) => row.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      studentId: studentId.trim().toUpperCase(),
      studentName: meta.name,
      className: meta.className,
      kind: kind,
      body: body.trim(),
      authorUsername: _username,
      authorRole: AuthService.currentUser?.roleKey,
      relatedPlanId: relatedPlanId,
      createdAt: now,
      updatedAt: now,
    );
    _requests.add(request);
    await _persist();
    return request;
  }

  Future<SupportRequest> acknowledgeSupportRequest(String id) async {
    _requireStaffDesk();
    return _setRequestStatus(id, SupportRequestStatus.acknowledged);
  }

  Future<SupportRequest> completeSupportRequest(String id) async {
    _requireStaffDesk();
    final request = await _setRequestStatus(id, SupportRequestStatus.completed);
    if (request.kind == SupportRequestKind.iepAgreement &&
        (request.relatedPlanId ?? '').isNotEmpty) {
      final plan = _iep.cast<IepPlan?>().firstWhere(
            (row) => row?.id == request.relatedPlanId,
            orElse: () => null,
          );
      if (plan != null) {
        plan.stage = IepStage.parentAgreement;
        plan.parentSignedAt ??= DateTime.now();
        plan.parentSignedBy ??= request.authorUsername;
        plan.updatedAt = DateTime.now();
        await _persist();
      }
    }
    return request;
  }

  Future<SafeguardingCase> openSafeguardingCase({
    required String studentId,
    String title = '',
    String details = '',
    String severity = 'standard',
    String? schoolId,
  }) async {
    _requireSafeguarding();
    final now = DateTime.now();
    final meta = _studentMeta(studentId);
    final file = SafeguardingCase(
      id: _id('SG', _safeguarding.map((row) => row.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      studentId: studentId.trim().toUpperCase(),
      studentName: meta.name,
      className: meta.className,
      title: title.trim(),
      details: details.trim(),
      severity: severity.trim().isEmpty ? 'standard' : severity.trim(),
      reporterUsername: _username,
      assignedRole: 'student_affairs',
      createdAt: now,
      updatedAt: now,
    );
    _safeguarding.add(file);
    await _persist();
    return file;
  }

  Future<SafeguardingCase> updateSafeguardingStatus(
    String id,
    SafeguardingStatus status,
  ) async {
    _requireSafeguarding();
    final file = _safeguarding.cast<SafeguardingCase?>().firstWhere(
          (row) => row?.id == id,
          orElse: () => null,
        );
    if (file == null) {
      throw StateError('Safeguarding case not found.');
    }
    file.status = status;
    file.updatedAt = DateTime.now();
    await _persist();
    return file;
  }

  /// Reuses the existing parent-messaging thread. Never put child-protection
  /// case narrative in [body].
  Future<bool> openParentChannel({
    required String studentId,
    required String body,
  }) async {
    if (body.trim().isEmpty) {
      throw StateError('Write a parent message first.');
    }
    _requireStaffDesk();
    final student = StudentRegistryService.instance.lookupById(studentId);
    final parentName = student?.primaryParentName?.trim() ?? '';
    if (parentName.isEmpty) {
      throw StateError('No parent name is listed for this student.');
    }
    final recipient = MessagingAccessService.findParentRecipient(parentName);
    if (recipient == null) {
      throw StateError('No parent account is linked to this student.');
    }
    final sent = SchoolDataService.instance.sendAdminDirectMessage(
      parentName: recipient.parentName,
      body: body.trim(),
      studentId: studentId,
    );
    if (sent.isEmpty) {
      throw StateError('Could not open the parent message thread.');
    }
    return true;
  }

  void applyPersistedData({
    List<HealthRecord>? health,
    List<CounselingRecord>? counseling,
    List<IepPlan>? iep,
    List<CollegeGuidancePlan>? college,
    List<SupportRequest>? requests,
    List<SafeguardingCase>? safeguarding,
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

    if (health != null) mergeList(_health, health, (row) => row.id);
    if (counseling != null) {
      mergeList(_counseling, counseling, (row) => row.id);
    }
    if (iep != null) mergeList(_iep, iep, (row) => row.id);
    if (college != null) mergeList(_college, college, (row) => row.id);
    if (requests != null) mergeList(_requests, requests, (row) => row.id);
    if (safeguarding != null) {
      if (_isPublicReader || !canViewSafeguarding) {
        _safeguarding.clear();
      } else {
        mergeList(_safeguarding, safeguarding, (row) => row.id);
      }
    }
    _loaded = true;
    notifyListeners();
  }

  List<Map<String, dynamic>> healthMaps() =>
      _health.map((row) => row.toMap()).toList();
  List<Map<String, dynamic>> counselingMaps() =>
      _counseling.map((row) => row.toMap()).toList();
  List<Map<String, dynamic>> iepMaps() =>
      _iep.map((row) => row.toMap()).toList();
  List<Map<String, dynamic>> collegeMaps() =>
      _college.map((row) => row.toMap()).toList();
  List<Map<String, dynamic>> requestMaps() =>
      _requests.map((row) => row.toMap()).toList();
  List<Map<String, dynamic>> safeguardingMaps() =>
      _safeguarding.map((row) => row.toMap()).toList();

  Future<SupportRequest> _setRequestStatus(
    String id,
    SupportRequestStatus status,
  ) async {
    final request = _requests.cast<SupportRequest?>().firstWhere(
          (row) => row?.id == id,
          orElse: () => null,
        );
    if (request == null) {
      throw StateError('Support request not found.');
    }
    request.status = status;
    request.updatedAt = DateTime.now();
    await _persist();
    return request;
  }

  List<T> _schoolFilter<T>(List<T> rows, String? schoolId) {
    final sid = (schoolId ?? _schoolId).toUpperCase();
    if (sid.isEmpty) return List<T>.from(rows);
    return rows.where((row) {
      final rowSchool = switch (row) {
        HealthRecord r => r.schoolId,
        CounselingRecord r => r.schoolId,
        IepPlan r => r.schoolId,
        CollegeGuidancePlan r => r.schoolId,
        SupportRequest r => r.schoolId,
        SafeguardingCase r => r.schoolId,
        _ => '',
      };
      return rowSchool == sid;
    }).toList();
  }

  HealthRecord _publicHealth(HealthRecord row) => HealthRecord(
        id: row.id,
        schoolId: row.schoolId,
        studentId: row.studentId,
        studentName: row.studentName,
        type: row.type,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        className: row.className,
        title: row.title,
        details: row.details,
        staffNotes: '',
        occurredAt: row.occurredAt,
        createdBy: row.createdBy,
      );

  CounselingRecord _publicCounseling(CounselingRecord row) => CounselingRecord(
        id: row.id,
        schoolId: row.schoolId,
        studentId: row.studentId,
        studentName: row.studentName,
        kind: row.kind,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        className: row.className,
        title: row.title,
        parentSummary: row.parentSummary,
        staffNotes: '',
        referralTo: row.referralTo,
        startsAt: row.startsAt,
        createdBy: row.createdBy,
      );

  IepPlan _publicIep(IepPlan row) => IepPlan(
        id: row.id,
        schoolId: row.schoolId,
        studentId: row.studentId,
        studentName: row.studentName,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        className: row.className,
        stage: row.stage,
        goals: row.goals,
        accommodations: row.accommodations,
        staffNotes: '',
        parentAgreementText: row.parentAgreementText,
        parentSignedAt: row.parentSignedAt,
        parentSignedBy: row.parentSignedBy,
        nextReviewAt: row.nextReviewAt,
        createdBy: row.createdBy,
      );

  CollegeGuidancePlan _publicCollege(CollegeGuidancePlan row) =>
      CollegeGuidancePlan(
        id: row.id,
        schoolId: row.schoolId,
        studentId: row.studentId,
        studentName: row.studentName,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        className: row.className,
        stage: row.stage,
        targets: row.targets,
        portfolio: row.portfolio,
        notes: '',
        nextAppointmentAt: row.nextAppointmentAt,
        createdBy: row.createdBy,
      );

  ({String name, String? className}) _studentMeta(String studentId) {
    final student = StudentRegistryService.instance.lookupById(studentId);
    return (
      name: student?.fullName ?? studentId.trim().toUpperCase(),
      className: student?.className,
    );
  }

  bool _ownsStudent(String studentId) {
    final id = studentId.trim().toUpperCase();
    if (id.isEmpty) return false;
    if (_isStudent) {
      final self = (AuthService.currentUser?.linkedStudentId ?? '')
          .trim()
          .toUpperCase();
      return self.isNotEmpty && self == id;
    }
    return AuthService.activeLinkedStudentIds()
        .map((value) => value.trim().toUpperCase())
        .contains(id);
  }

  void _requireStaffDesk() {
    if (!canManageDesk) {
      throw StateError(
        'Student-support files can only be written by the care desk.',
      );
    }
  }

  void _requireSafeguarding() {
    if (!canManageSafeguarding) {
      throw StateError('Safeguarding files stay on the care-leadership desk.');
    }
  }

  Future<void> _persist() async {
    notifyListeners();
    await StudentSupportPersistenceService.instance.saveFromService();
  }

  String _id(String prefix, Iterable<String> existing) {
    return ShortRegistryId.allocate(
      prefix: prefix,
      existingIds: existing,
      isTaken: (id) => existing.contains(id),
    );
  }
}
