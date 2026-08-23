import 'dart:async';

import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/models/student_portal.dart';
import 'package:mayabela/models/transfer_models.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/persistence/student_persistence_service.dart';
import 'package:mayabela/utils/phone_utils.dart';
import 'package:mayabela/utils/short_registry_id.dart';

class AdminStudentRecord {
  AdminStudentRecord({
    required this.studentId,
    required this.fullName,
    required this.grade,
    required this.className,
    required this.schoolId,
    this.campus = 'Main Campus',
    required this.dateOfBirth,
    this.gender,
    this.emergencyContact,
    this.transportEnabled = false,
    this.transportId,
    this.isActive = true,
    this.lifecycleStatus = StudentLifecycleStatus.active,
    this.photoPath,
    this.fatherName,
    this.fatherPhone,
    this.motherName,
    this.motherPhone,
    this.guardianName,
    this.guardianPhone,
    this.emergencyPhone1,
    this.emergencyContact1Name,
    this.emergencyPhone2,
    this.emergencyContact2Name,
    this.homeroomTeacherId,
    this.academicYear,
    this.hasMedicalCondition = false,
    this.medicalConditionDetails,
    this.otherMedicalInfo,
    this.loginUsername,
    this.initialPassword,
    this.mustChangePassword = false,
    this.portalAccountStatus = StudentAccountStatus.inactive,
    this.portalAccountCreatedAt,
    this.portalAccountCreatedBy,
    this.firstLoginCompleted = false,
  });

  final String studentId;
  final String fullName;
  final String grade;
  final String className;
  final String schoolId;
  final String campus;
  final DateTime dateOfBirth;
  final String? gender;
  final String? emergencyContact;
  final bool transportEnabled;
  final String? transportId;
  final bool isActive;

  /// Enrollment lifecycle (active / transferred / left / graduated).
  /// Kept in sync with [isActive] so legacy filters keep working.
  final StudentLifecycleStatus lifecycleStatus;
  final String? photoPath;
  final String? fatherName;
  final String? fatherPhone;
  final String? motherName;
  final String? motherPhone;
  final String? guardianName;
  final String? guardianPhone;
  final String? emergencyPhone1;
  final String? emergencyContact1Name;
  final String? emergencyPhone2;
  final String? emergencyContact2Name;
  final String? homeroomTeacherId;
  final String? academicYear;
  final bool hasMedicalCondition;
  final String? medicalConditionDetails;
  final String? otherMedicalInfo;
  final String? loginUsername;
  final String? initialPassword;
  final bool mustChangePassword;
  final StudentAccountStatus portalAccountStatus;
  final DateTime? portalAccountCreatedAt;
  final String? portalAccountCreatedBy;
  final bool firstLoginCompleted;

  String? get primaryContactPhone {
    for (final phone in [
      fatherPhone,
      motherPhone,
      guardianPhone,
      emergencyPhone1,
      emergencyPhone2,
    ]) {
      if (phone != null && phone.trim().isNotEmpty) return phone.trim();
    }
    return emergencyContact?.trim();
  }

  String? get primaryParentName {
    for (final name in [fatherName, motherName, guardianName]) {
      if (name != null && name.trim().isNotEmpty) return name.trim();
    }
    return null;
  }

  String? phoneForRelationship(ParentRelationship relationship) {
    final phone = switch (relationship) {
      ParentRelationship.father => fatherPhone,
      ParentRelationship.mother => motherPhone,
      ParentRelationship.guardian => guardianPhone,
    };
    return PhoneUtils.normalizeStoredPhone(phone);
  }

  String? nameForRelationship(ParentRelationship relationship) {
    final name = switch (relationship) {
      ParentRelationship.father => fatherName,
      ParentRelationship.mother => motherName,
      ParentRelationship.guardian => guardianName,
    };
    final trimmed = name?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  bool hasParentContactPhone(String phone) {
    final key = PhoneUtils.loginKey(phone);
    for (final contact in [fatherPhone, motherPhone, guardianPhone]) {
      if (contact != null && PhoneUtils.loginKey(contact) == key) {
        return true;
      }
    }
    return false;
  }

  List<String> get allContactPhones {
    final phones = <String>[];
    for (final phone in [
      fatherPhone,
      motherPhone,
      guardianPhone,
      emergencyPhone1,
      emergencyPhone2,
    ]) {
      if (phone == null) continue;
      final trimmed = phone.trim();
      if (trimmed.isEmpty) continue;
      if (!phones.contains(trimmed)) phones.add(trimmed);
    }
    return phones;
  }

  AdminStudentRecord copyWith({
    String? fullName,
    String? photoPath,
    String? className,
    String? grade,
    DateTime? dateOfBirth,
    String? homeroomTeacherId,
    String? academicYear,
    String? campus,
    String? gender,
    String? fatherName,
    String? fatherPhone,
    String? motherName,
    String? motherPhone,
    String? guardianName,
    String? guardianPhone,
    String? emergencyPhone1,
    String? emergencyContact1Name,
    String? emergencyPhone2,
    String? emergencyContact2Name,
    bool? transportEnabled,
    String? transportId,
    bool? isActive,
    StudentLifecycleStatus? lifecycleStatus,
    bool clearTransportId = false,
    bool? hasMedicalCondition,
    String? medicalConditionDetails,
    String? otherMedicalInfo,
    String? loginUsername,
    String? initialPassword,
    bool? mustChangePassword,
    StudentAccountStatus? portalAccountStatus,
    DateTime? portalAccountCreatedAt,
    String? portalAccountCreatedBy,
    bool? firstLoginCompleted,
  }) {
    return AdminStudentRecord(
      studentId: studentId,
      fullName: fullName ?? this.fullName,
      grade: grade ?? this.grade,
      className: className ?? this.className,
      schoolId: schoolId,
      campus: campus ?? this.campus,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      emergencyContact: emergencyContact,
      transportEnabled: transportEnabled ?? this.transportEnabled,
      transportId: clearTransportId ? null : (transportId ?? this.transportId),
      isActive: isActive ?? this.isActive,
      lifecycleStatus: lifecycleStatus ?? this.lifecycleStatus,
      photoPath: photoPath ?? this.photoPath,
      fatherName: fatherName ?? this.fatherName,
      fatherPhone: fatherPhone ?? this.fatherPhone,
      motherName: motherName ?? this.motherName,
      motherPhone: motherPhone ?? this.motherPhone,
      guardianName: guardianName ?? this.guardianName,
      guardianPhone: guardianPhone ?? this.guardianPhone,
      emergencyPhone1: emergencyPhone1 ?? this.emergencyPhone1,
      emergencyContact1Name: emergencyContact1Name ?? this.emergencyContact1Name,
      emergencyPhone2: emergencyPhone2 ?? this.emergencyPhone2,
      emergencyContact2Name: emergencyContact2Name ?? this.emergencyContact2Name,
      homeroomTeacherId: homeroomTeacherId ?? this.homeroomTeacherId,
      academicYear: academicYear ?? this.academicYear,
      hasMedicalCondition: hasMedicalCondition ?? this.hasMedicalCondition,
      medicalConditionDetails:
          medicalConditionDetails ?? this.medicalConditionDetails,
      otherMedicalInfo: otherMedicalInfo ?? this.otherMedicalInfo,
      loginUsername: loginUsername ?? this.loginUsername,
      initialPassword: initialPassword ?? this.initialPassword,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      portalAccountStatus: portalAccountStatus ?? this.portalAccountStatus,
      portalAccountCreatedAt:
          portalAccountCreatedAt ?? this.portalAccountCreatedAt,
      portalAccountCreatedBy:
          portalAccountCreatedBy ?? this.portalAccountCreatedBy,
      firstLoginCompleted: firstLoginCompleted ?? this.firstLoginCompleted,
    );
  }

  Map<String, dynamic> toMap() => {
        'studentId': studentId,
        'fullName': fullName,
        'grade': grade,
        'className': className,
        'schoolId': schoolId,
        'campus': campus,
        'dateOfBirth': dateOfBirth.toIso8601String(),
        if (gender != null) 'gender': gender,
        if (emergencyContact != null) 'emergencyContact': emergencyContact,
        'transportEnabled': transportEnabled,
        if (transportId != null) 'transportId': transportId,
        'isActive': isActive,
        'lifecycleStatus': lifecycleStatus.name,
        if (photoPath != null) 'photoPath': photoPath,
        if (fatherName != null) 'fatherName': fatherName,
        if (fatherPhone != null) 'fatherPhone': fatherPhone,
        if (motherName != null) 'motherName': motherName,
        if (motherPhone != null) 'motherPhone': motherPhone,
        if (guardianName != null) 'guardianName': guardianName,
        if (guardianPhone != null) 'guardianPhone': guardianPhone,
        if (emergencyPhone1 != null) 'emergencyPhone1': emergencyPhone1,
        if (emergencyContact1Name != null)
          'emergencyContact1Name': emergencyContact1Name,
        if (emergencyPhone2 != null) 'emergencyPhone2': emergencyPhone2,
        if (emergencyContact2Name != null)
          'emergencyContact2Name': emergencyContact2Name,
        if (homeroomTeacherId != null) 'homeroomTeacherId': homeroomTeacherId,
        if (academicYear != null) 'academicYear': academicYear,
        'hasMedicalCondition': hasMedicalCondition,
        if (medicalConditionDetails != null)
          'medicalConditionDetails': medicalConditionDetails,
        if (otherMedicalInfo != null) 'otherMedicalInfo': otherMedicalInfo,
        if (loginUsername != null) 'loginUsername': loginUsername,
        if (initialPassword != null) 'initialPassword': initialPassword,
        'mustChangePassword': mustChangePassword,
        'portalAccountStatus': portalAccountStatus.name,
        if (portalAccountCreatedAt != null)
          'portalAccountCreatedAt': portalAccountCreatedAt!.toIso8601String(),
        if (portalAccountCreatedBy != null)
          'portalAccountCreatedBy': portalAccountCreatedBy,
        'firstLoginCompleted': firstLoginCompleted,
      };

  factory AdminStudentRecord.fromMap(Map<String, dynamic> map) {
    return AdminStudentRecord(
      studentId: (map['studentId'] as String).trim().toUpperCase(),
      fullName: map['fullName'] as String,
      grade: map['grade'] as String,
      className: map['className'] as String,
      schoolId: (map['schoolId'] as String).trim().toUpperCase(),
      campus: map['campus'] as String? ?? 'Main Campus',
      dateOfBirth: DateTime.parse(map['dateOfBirth'] as String),
      gender: map['gender'] as String?,
      emergencyContact: map['emergencyContact'] as String?,
      transportEnabled: map['transportEnabled'] as bool? ?? false,
      transportId: map['transportId'] as String?,
      lifecycleStatus: StudentLifecycleStatusX.parse(
        map['lifecycleStatus'] as String?,
        isActiveFallback: map['isActive'] as bool?,
      ),
      isActive: StudentLifecycleStatusX.parse(
        map['lifecycleStatus'] as String?,
        isActiveFallback: map['isActive'] as bool?,
      ).countsAsEnrolled,
      photoPath: map['photoPath'] as String?,
      fatherName: map['fatherName'] as String?,
      fatherPhone: map['fatherPhone'] as String?,
      motherName: map['motherName'] as String?,
      motherPhone: map['motherPhone'] as String?,
      guardianName: map['guardianName'] as String?,
      guardianPhone: map['guardianPhone'] as String?,
      emergencyPhone1: map['emergencyPhone1'] as String?,
      emergencyContact1Name: map['emergencyContact1Name'] as String?,
      emergencyPhone2: map['emergencyPhone2'] as String?,
      emergencyContact2Name: map['emergencyContact2Name'] as String?,
      homeroomTeacherId: map['homeroomTeacherId'] as String?,
      academicYear: map['academicYear'] as String?,
      hasMedicalCondition: map['hasMedicalCondition'] as bool? ?? false,
      medicalConditionDetails: map['medicalConditionDetails'] as String?,
      otherMedicalInfo: map['otherMedicalInfo'] as String?,
      loginUsername: map['loginUsername'] as String?,
      initialPassword: map['initialPassword'] as String?,
      mustChangePassword: map['mustChangePassword'] as bool? ?? false,
      portalAccountStatus: StudentAccountStatus.parse(
        map['portalAccountStatus'] as String?,
      ),
      portalAccountCreatedAt: map['portalAccountCreatedAt'] != null
          ? DateTime.tryParse(map['portalAccountCreatedAt'] as String)
          : null,
      portalAccountCreatedBy: map['portalAccountCreatedBy'] as String?,
      firstLoginCompleted: map['firstLoginCompleted'] as bool? ?? false,
    );
  }
}

class StudentRegistryService {
  StudentRegistryService._();
  static final instance = StudentRegistryService._();

  int _nextId = 1006;

  final List<AdminStudentRecord> _students = [
    AdminStudentRecord(
      studentId: 'STU-1001',
      fullName: 'Sara Bekele',
      grade: 'Grade 4',
      className: 'Grade 4A',
      schoolId: 'TB-001',
      dateOfBirth: DateTime(2016, 3, 15),
      gender: 'Female',
      emergencyContact: '0911000002',
      fatherName: 'Bekele Tadesse',
      fatherPhone: '0911000002',
      motherName: 'Almaz Bekele',
      motherPhone: '0911000099',
      homeroomTeacherId: 'TCH-1001',
      transportEnabled: true,
      transportId: 'BUS-1001',
    ),
    AdminStudentRecord(
      studentId: 'STU-1002',
      fullName: 'Kidus Bekele',
      grade: 'Grade 2',
      className: 'Grade 2C',
      schoolId: 'TB-001',
      dateOfBirth: DateTime(2018, 7, 22),
      gender: 'Male',
      emergencyContact: '0911000002',
      fatherName: 'Bekele Tadesse',
      fatherPhone: '0911000002',
      motherName: 'Almaz Bekele',
      homeroomTeacherId: 'TCH-1002',
    ),
    AdminStudentRecord(
      studentId: 'STU-1003',
      fullName: 'Daniel Tesfaye',
      grade: 'Grade 4',
      className: 'Grade 4A',
      schoolId: 'TB-001',
      dateOfBirth: DateTime(2016, 1, 8),
      gender: 'Male',
      emergencyContact: '0911555666',
      fatherName: 'Tesfaye Alemu',
      fatherPhone: '0911555666',
      homeroomTeacherId: 'TCH-1001',
    ),
    AdminStudentRecord(
      studentId: 'STU-1004',
      fullName: 'Hanna Girma',
      grade: 'Grade 4',
      className: 'Grade 4A',
      schoolId: 'TB-001',
      dateOfBirth: DateTime(2016, 11, 30),
      gender: 'Female',
      emergencyContact: '0911666777',
      motherName: 'Girma Worku',
      motherPhone: '0911666777',
      homeroomTeacherId: 'TCH-1001',
    ),
    AdminStudentRecord(
      studentId: 'STU-1005',
      fullName: 'Liya Solomon',
      grade: 'Grade 5',
      className: 'Grade 5B',
      schoolId: 'TB-001',
      dateOfBirth: DateTime(2015, 5, 12),
      gender: 'Female',
      emergencyContact: '0911777888',
      guardianName: 'Solomon Hailu',
      guardianPhone: '0911777888',
      homeroomTeacherId: 'TCH-1004',
    ),
  ];

  /// Builds roster class name from grade + section, e.g. Grade 4 + A → Grade 4A.
  static String buildClassName(String grade, String section) {
    final g = grade.trim();
    final sec = section.trim();
    if (g.isEmpty) return sec;
    if (sec.isEmpty) return g;
    if (RegExp(r'^[A-Za-z0-9]{1,3}$').hasMatch(sec) && !sec.contains(' ')) {
      return '$g$sec';
    }
    return '$g $sec';
  }

  /// Splits a roster class name into grade + section when possible.
  static ({String grade, String section})? parseClassNameParts(String className) {
    final trimmed = className.trim();
    if (trimmed.isEmpty) return null;

    final compact = RegExp(
      r'^(Grade\s*\d+)([A-Za-z0-9]{1,3})$',
      caseSensitive: false,
    ).firstMatch(trimmed.replaceAll(RegExp(r'\s+'), ' '));
    if (compact != null) {
      return (
        grade: compact.group(1)!.trim(),
        section: compact.group(2)!.trim(),
      );
    }

    final spaced = RegExp(r'^(Grade\s*\d+)\s+(.+)$', caseSensitive: false)
        .firstMatch(trimmed);
    if (spaced != null) {
      return (
        grade: spaced.group(1)!.trim(),
        section: spaced.group(2)!.trim(),
      );
    }

    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (
        grade: parts.sublist(0, parts.length - 1).join(' '),
        section: parts.last,
      );
    }

    return (grade: trimmed, section: '');
  }

  static String canonicalClassName(String className) {
    final parts = parseClassNameParts(className);
    if (parts != null) {
      return buildClassName(parts.grade, parts.section);
    }
    return className.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool classNamesMatch(String a, String b) {
    if (canonicalClassName(a) == canonicalClassName(b)) return true;
    return a.trim().toLowerCase() == b.trim().toLowerCase();
  }

  AdminStudentRecord? lookupById(String studentId) {
    final id = studentId.trim().toUpperCase();
    try {
      return _students.firstWhere((s) => s.studentId == id && s.isActive);
    } catch (_) {
      return null;
    }
  }

  AdminStudentRecord? lookupAnyById(String studentId) {
    final id = studentId.trim().toUpperCase();
    try {
      return _students.firstWhere((s) => s.studentId == id);
    } catch (_) {
      return null;
    }
  }

  AdminStudentRecord? lookupByLoginUsername(String username) {
    final key = username.trim().toLowerCase();
    if (key.isEmpty) return null;
    try {
      return _students.firstWhere(
        (s) => (s.loginUsername?.trim().toLowerCase() ?? '') == key,
      );
    } catch (_) {
      return null;
    }
  }

  void replaceStudent(AdminStudentRecord updated) => updateStudent(updated);

  AdminStudentRecord? lookupByName(String fullName) {
    final name = fullName.trim();
    if (name.isEmpty) return null;
    try {
      return _students.firstWhere((s) => s.fullName == name && s.isActive);
    } catch (_) {
      return null;
    }
  }

  bool verifyStudent({
    required String schoolId,
    required String studentId,
    required DateTime dateOfBirth,
  }) {
    final student = lookupById(studentId);
    if (student == null) return false;
    if (student.schoolId.toUpperCase() != schoolId.trim().toUpperCase()) {
      return false;
    }
    return _sameDay(student.dateOfBirth, dateOfBirth);
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<AdminStudentRecord> getAllStudents() =>
      List.unmodifiable(_students.where((s) => s.isActive));

  List<AdminStudentRecord> registrySnapshot() =>
      List.unmodifiable(_students);

  int get nextStudentIdCounter => _nextId;

  /// Short sequential id (`STU-0001` … `STU-9999`).
  ///
  /// The next number is the highest existing 4-digit STU id in the
  /// cloud-merged registry + 1. Timestamp leftovers are ignored.
  String _allocateStudentId() {
    final id = ShortRegistryId.allocate(
      prefix: 'STU',
      existingIds: _students.map((s) => s.studentId),
      isTaken: (id) => lookupAnyById(id) != null,
      persistedNext: _nextId,
    );
    _nextId = (ShortRegistryId.parseNumber(id) ?? 0) + 1;
    return id;
  }

  /// Merge saved students over in-memory seed (new students, edits, deactivations).
  void applyPersistedStudents(
    List<AdminStudentRecord> students, {
    int? nextId,
    bool replace = false,
  }) {
    if (replace) {
      _students
        ..clear()
        ..addAll(students);
    } else {
      for (final record in students) {
        final idx = _students.indexWhere((s) => s.studentId == record.studentId);
        if (idx >= 0) {
          _students[idx] = record;
        } else {
          _students.add(record);
        }
      }
    }
    final clamped = ShortRegistryId.clampCounter(nextId, fallback: _nextId);
    if (clamped > _nextId) {
      _nextId = clamped;
    }
  }

  List<AdminStudentRecord> studentsForSchool(String schoolId) {
    final id = schoolId.trim().toUpperCase();
    return _students
        .where((s) => s.isActive && s.schoolId.toUpperCase() == id)
        .toList();
  }

  List<AdminStudentRecord> inactiveStudentsForSchool(String schoolId) {
    final id = schoolId.trim().toUpperCase();
    return _students
        .where((s) => !s.isActive && s.schoolId.toUpperCase() == id)
        .toList();
  }

  int billableCountForSchool(String? schoolId) {
    if (schoolId == null || schoolId.trim().isEmpty) return 0;
    return studentsForSchool(schoolId).length;
  }

  List<AdminStudentRecord> studentsForClass(
    String className, {
    String? schoolId,
  }) {
    final normalizedClass = className.trim();
    return _students.where((student) {
      if (!student.isActive || student.className != normalizedClass) {
        return false;
      }
      if (schoolId == null) return true;
      return student.schoolId.toUpperCase() == schoolId.trim().toUpperCase();
    }).toList();
  }

  List<AdminStudentRecord> studentsForHomeroomTeacher(String teacherId) {
    final id = teacherId.trim().toUpperCase();
    return _students
        .where((s) => s.isActive && s.homeroomTeacherId?.toUpperCase() == id)
        .toList();
  }

  void updatePhoto(String studentId, String photoPath, {bool persist = true}) {
    final existing = lookupById(studentId);
    if (existing == null) return;
    final idx = _students.indexWhere((s) => s.studentId == existing.studentId);
    if (idx >= 0) _students[idx] = existing.copyWith(photoPath: photoPath);
    if (persist) _persistRegistry(syncStudentId: studentId);
  }

  void updateStudentPlacement({
    required String studentId,
    required String grade,
    required String className,
    String? homeroomTeacherId,
  }) {
    final existing = lookupById(studentId);
    if (existing == null) return;
    final idx = _students.indexWhere((s) => s.studentId == existing.studentId);
    if (idx >= 0) {
      _students[idx] = existing.copyWith(
        grade: grade,
        className: className,
        homeroomTeacherId: homeroomTeacherId ?? existing.homeroomTeacherId,
      );
    }
    _persistRegistry(syncStudentId: studentId);
  }

  void updateStudent(AdminStudentRecord updated) {
    final idx = _students.indexWhere((s) => s.studentId == updated.studentId);
    if (idx >= 0) {
      _students[idx] = updated;
      _persistRegistry(syncStudentId: updated.studentId);
    }
  }

  void _persistRegistry({String? syncStudentId}) {
    unawaited(
      StudentPersistenceService.instance.saveRegistryFromService(
        syncStudentId: syncStudentId,
      ),
    );
  }

  bool deactivateStudent(String studentId) {
    return setLifecycleStatus(studentId, StudentLifecycleStatus.left);
  }

  /// Updates enrollment lifecycle and keeps [isActive] in sync.
  bool setLifecycleStatus(String studentId, StudentLifecycleStatus status) {
    final existing = lookupAnyById(studentId);
    if (existing == null) return false;
    final idx = _students.indexWhere((s) => s.studentId == existing.studentId);
    if (idx < 0) return false;
    _students[idx] = existing.copyWith(
      lifecycleStatus: status,
      isActive: status.countsAsEnrolled,
    );
    _persistRegistry(syncStudentId: studentId);
    return true;
  }

  void transferStudentTransport({
    required String studentId,
    required String toDriverId,
  }) {
    final existing = lookupById(studentId);
    if (existing == null) return;
    final idx = _students.indexWhere((s) => s.studentId == existing.studentId);
    if (idx < 0) return;
    _students[idx] = existing.copyWith(
      transportEnabled: true,
      transportId: DriverRegistryService.instance
          .transportLinkIdForDriver(toDriverId.trim()),
    );
    _persistRegistry();
  }

  void transferStudentCampus({
    required String studentId,
    required String toCampus,
  }) {
    final existing = lookupById(studentId);
    if (existing == null) return;
    final idx = _students.indexWhere((s) => s.studentId == existing.studentId);
    if (idx < 0) return;
    _students[idx] = existing.copyWith(campus: toCampus.trim());
    _persistRegistry();
  }

  /// Bulk campus rename for a school (single persist).
  int reassignCampusForSchool(
    String schoolId, {
    required String from,
    required String to,
  }) {
    final sid = schoolId.trim().toUpperCase();
    var count = 0;
    for (var i = 0; i < _students.length; i++) {
      final student = _students[i];
      if (student.schoolId.toUpperCase() == sid && student.campus == from) {
        _students[i] = student.copyWith(campus: to);
        count++;
      }
    }
    if (count > 0) _persistRegistry();
    return count;
  }

  void transferStudent({
    required String studentId,
    required String grade,
    required String section,
    String? homeroomTeacherId,
  }) {
    final className = buildClassName(grade, section);
    updateStudentPlacement(
      studentId: studentId,
      grade: grade.trim(),
      className: className,
      homeroomTeacherId: homeroomTeacherId,
    );
  }

  AdminStudentRecord addStudent({
    required String schoolId,
    required String fullName,
    required String grade,
    required String className,
    required DateTime dateOfBirth,
    String? gender,
    String? emergencyContact,
    bool transportEnabled = false,
    String? transportId,
    String? photoPath,
    String? fatherName,
    String? fatherPhone,
    String? motherName,
    String? motherPhone,
    String? guardianName,
    String? guardianPhone,
    String? emergencyPhone1,
    String? emergencyContact1Name,
    String? emergencyPhone2,
    String? emergencyContact2Name,
    String? homeroomTeacherId,
    String? academicYear,
    String? campus,
  }) {
    final contact = _trimOrNull(emergencyContact) ??
        _phoneOrNull(fatherPhone) ??
        _phoneOrNull(motherPhone) ??
        _phoneOrNull(guardianPhone) ??
        _phoneOrNull(emergencyPhone1) ??
        _phoneOrNull(emergencyPhone2);

    final record = AdminStudentRecord(
      studentId: _allocateStudentId(),
      fullName: fullName.trim(),
      grade: grade.trim(),
      className: className.trim(),
      schoolId: schoolId.trim().toUpperCase(),
      dateOfBirth: dateOfBirth,
      gender: gender?.trim(),
      emergencyContact: contact,
      transportEnabled: transportEnabled,
      transportId: _normalizeTransportId(transportId),
      photoPath: photoPath,
      fatherName: _trimOrNull(fatherName),
      fatherPhone: _phoneOrNull(fatherPhone),
      motherName: _trimOrNull(motherName),
      motherPhone: _phoneOrNull(motherPhone),
      guardianName: _trimOrNull(guardianName),
      guardianPhone: _phoneOrNull(guardianPhone),
      emergencyPhone1: _phoneOrNull(emergencyPhone1),
      emergencyContact1Name: _trimOrNull(emergencyContact1Name),
      emergencyPhone2: _phoneOrNull(emergencyPhone2),
      emergencyContact2Name: _trimOrNull(emergencyContact2Name),
      homeroomTeacherId: _trimOrNull(homeroomTeacherId)?.toUpperCase(),
      academicYear: _trimOrNull(academicYear),
      campus: _trimOrNull(campus) ?? 'Main Campus',
    );
    _students.add(record);
    return record;
  }

  void removeStudent(String studentId) {
    final id = studentId.trim().toUpperCase();
    _students.removeWhere((s) => s.studentId == id);
  }

  String? _trimOrNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _phoneOrNull(String? value) => PhoneUtils.normalizeStoredPhone(value);

  String? _normalizeTransportId(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final driver =
        DriverRegistryService.instance.resolveTransportReference(trimmed);
    if (driver != null) return driver.busId;
    return trimmed.toUpperCase();
  }
}
