import 'package:mayabela/constants/school_subjects.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

import 'package:mayabela/utils/phone_utils.dart';
import 'package:mayabela/utils/short_registry_id.dart';

class AdminTeacherRecord {
  AdminTeacherRecord({
    required this.teacherId,
    required this.fullName,
    String? subject,
    List<String>? subjects,
    required this.assignedClass,
    required this.schoolId,
    this.campus = 'Main Campus',
    this.email,
    this.phone,
    this.employeeId,
    this.roles = const [TeacherStaffRole.subjectTeacher],
    this.loginUsername,
    this.mustChangePassword = false,
    this.isActive = true,
    this.photoPath,
    this.initialPassword,
    this.classAssignments = const [],
    this.staffRoles = const [],
  }) : subjects = subjects != null
            ? List<String>.from(subjects)
            : (subject != null && subject.trim().isNotEmpty
                ? [subject.trim()]
                : const []);

  final String teacherId;
  final String fullName;
  final List<String> subjects;
  final String assignedClass;
  final String schoolId;
  final String campus;
  final String? email;
  final String? phone;
  final String? employeeId;
  final List<TeacherStaffRole> roles;
  final String? loginUsername;
  final bool mustChangePassword;
  final bool isActive;
  final String? photoPath;
  final String? initialPassword;
  final List<TeacherClassAssignment> classAssignments;

  /// RBAC staff role keys (StaffRoles.*) mirrored from the auth account for
  /// display in staff lists. The auth account is the source of truth.
  final List<String> staffRoles;

  String get subject => subjects.isEmpty ? '' : subjects.join(', ');

  List<String> get assignedClassNames {
    final names = <String>{};
    for (final part in assignedClass.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty) names.add(trimmed);
    }
    for (final assignment in classAssignments) {
      final trimmed = assignment.className.trim();
      if (trimmed.isNotEmpty) names.add(trimmed);
    }
    return names.toList();
  }

  Map<String, dynamic> toMap() => {
        'teacherId': teacherId,
        'fullName': fullName,
        'subjects': subjects,
        'assignedClass': assignedClass,
        'assignedClassNames': assignedClassNames,
        'schoolId': schoolId,
        'campus': campus,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (employeeId != null) 'employeeId': employeeId,
        'roles': roles.map((role) => role.name).toList(),
        if (loginUsername != null) 'loginUsername': loginUsername,
        'mustChangePassword': mustChangePassword,
        'isActive': isActive,
        if (photoPath != null) 'photoPath': photoPath,
        if (initialPassword != null) 'initialPassword': initialPassword,
        'classAssignments':
            classAssignments.map((assignment) => assignment.toMap()).toList(),
        if (staffRoles.isNotEmpty) 'staffRoles': staffRoles,
      };

  factory AdminTeacherRecord.fromMap(Map<String, dynamic> map) {
    final rawRoles = map['roles'] as List?;
    final roles = rawRoles == null
        ? const [TeacherStaffRole.subjectTeacher]
        : rawRoles
            .map((role) => role.toString())
            .map(
              (name) => TeacherStaffRole.values.firstWhere(
                (role) => role.name == name,
                orElse: () => TeacherStaffRole.subjectTeacher,
              ),
            )
            .toList();
    final rawSubjects = map['subjects'] as List?;
    final subjects = rawSubjects == null
        ? const <String>[]
        : rawSubjects.map((item) => item.toString()).toList();
    final rawAssignments = map['classAssignments'] as List?;
    final classAssignments = rawAssignments == null
        ? const <TeacherClassAssignment>[]
        : rawAssignments
            .whereType<Map>()
            .map(
              (item) => TeacherClassAssignment.fromMap(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();

    return AdminTeacherRecord(
      teacherId: (map['teacherId'] as String? ?? '').trim().toUpperCase(),
      fullName: map['fullName'] as String? ?? '',
      subjects: subjects,
      assignedClass: map['assignedClass'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      campus: map['campus'] as String? ?? 'Main Campus',
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      employeeId: map['employeeId'] as String?,
      roles: roles,
      loginUsername: map['loginUsername'] as String?,
      mustChangePassword: map['mustChangePassword'] as bool? ?? false,
      isActive: map['isActive'] as bool? ?? true,
      photoPath: map['photoPath'] as String?,
      initialPassword: map['initialPassword'] as String?,
      classAssignments: classAssignments,
      staffRoles: (map['staffRoles'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  AdminTeacherRecord copyWith({
    String? fullName,
    String? subject,
    List<String>? subjects,
    String? assignedClass,
    String? email,
    String? phone,
    String? employeeId,
    String? photoPath,
    String? initialPassword,
    String? loginUsername,
    List<TeacherStaffRole>? roles,
    List<TeacherClassAssignment>? classAssignments,
    bool? isActive,
    String? campus,
    List<String>? staffRoles,
  }) {
    return AdminTeacherRecord(
      teacherId: teacherId,
      fullName: fullName ?? this.fullName,
      subjects: subjects ??
          (subject != null ? [subject.trim()] : List<String>.from(this.subjects)),
      assignedClass: assignedClass ?? this.assignedClass,
      schoolId: schoolId,
      campus: campus ?? this.campus,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      employeeId: employeeId ?? this.employeeId,
      roles: roles ?? this.roles,
      loginUsername: loginUsername ?? this.loginUsername,
      mustChangePassword: mustChangePassword,
      isActive: isActive ?? this.isActive,
      photoPath: photoPath ?? this.photoPath,
      initialPassword: initialPassword ?? this.initialPassword,
      classAssignments: classAssignments ?? this.classAssignments,
      staffRoles: staffRoles ?? List<String>.from(this.staffRoles),
    );
  }
}

class TeacherRegistryService {
  TeacherRegistryService._();
  static final instance = TeacherRegistryService._();

  int _nextId = 1005;
  int _nextSlotId = 1004;

  String generateTeachingSlotId() {
    final existing = [
      for (final t in _teachers)
        for (final a in t.classAssignments)
          for (final slot in a.teachingSlots) slot.slotId,
    ];
    final id = ShortRegistryId.allocate(
      prefix: 'STA',
      existingIds: existing,
      isTaken: existing.contains,
      persistedNext: _nextSlotId,
    );
    _nextSlotId = (ShortRegistryId.parseNumber(id) ?? _nextSlotId) + 1;
    return id;
  }

  /// Builds teaching slots with stable subject ids for a class row.
  List<SubjectTeachingSlot> buildTeachingSlots(
    Iterable<String> subjectNames, {
    List<SubjectTeachingSlot>? existing,
  }) {
    final preserved = <String, SubjectTeachingSlot>{
      for (final slot in existing ?? const <SubjectTeachingSlot>[])
        slot.subjectName.toLowerCase(): slot,
    };
    final slots = <SubjectTeachingSlot>[];
    for (final rawName in subjectNames) {
      final name = rawName.trim();
      if (name.isEmpty) continue;
      final kept = preserved[name.toLowerCase()];
      if (kept != null) {
        slots.add(kept);
        continue;
      }
      slots.add(
        SubjectTeachingSlot(
          slotId: generateTeachingSlotId(),
          subjectId: SchoolSubjects.resolveSubjectId(name),
          subjectName: name,
        ),
      );
    }
    return slots;
  }

  static List<String> subjectsFromAssignments(
    List<TeacherClassAssignment> assignments,
  ) {
    final names = <String>{};
    for (final assignment in assignments) {
      names.addAll(assignment.subjectNames);
    }
    return names.toList()..sort();
  }

  final List<AdminTeacherRecord> _teachers = [
    AdminTeacherRecord(
      teacherId: 'TCH-1001',
      fullName: 'Miss Belen',
      subject: 'Mathematics',
      assignedClass: 'Grade 4A, Grade 5B',
      schoolId: 'TB-001',
      email: 'belen@mayaschool.et',
      phone: '0911223344',
      employeeId: 'EMP-001',
      roles: [TeacherStaffRole.homeroomTeacher, TeacherStaffRole.subjectTeacher],
      loginUsername: 'teacher',
      classAssignments: const [
        TeacherClassAssignment(
          className: 'Grade 4A',
          role: TeacherStaffRole.homeroomTeacher,
        ),
        TeacherClassAssignment(
          className: 'Grade 5B',
          role: TeacherStaffRole.subjectTeacher,
          teachingSlots: [
            SubjectTeachingSlot(
              slotId: 'STA-1001',
              subjectId: 'SUB-MATH',
              subjectName: 'Mathematics',
            ),
          ],
        ),
      ],
    ),
    AdminTeacherRecord(
      teacherId: 'TCH-1002',
      fullName: 'Mr. Samuel',
      subject: 'English',
      assignedClass: 'Grade 2C',
      schoolId: 'TB-001',
      email: 'samuel@mayaschool.et',
      phone: '0911334455',
      employeeId: 'EMP-002',
      roles: [TeacherStaffRole.homeroomTeacher],
      loginUsername: 'samuel',
      classAssignments: const [
        TeacherClassAssignment(
          className: 'Grade 2C',
          role: TeacherStaffRole.homeroomTeacher,
        ),
      ],
    ),
    AdminTeacherRecord(
      teacherId: 'TCH-1003',
      fullName: 'Miss Hana',
      subject: 'Science',
      assignedClass: 'Grade 4A',
      schoolId: 'TB-001',
      email: 'hana@mayaschool.et',
      phone: '0911445566',
      employeeId: 'EMP-003',
      roles: [TeacherStaffRole.subjectTeacher],
      classAssignments: const [
        TeacherClassAssignment(
          className: 'Grade 4A',
          role: TeacherStaffRole.subjectTeacher,
          teachingSlots: [
            SubjectTeachingSlot(
              slotId: 'STA-1002',
              subjectId: 'SUB-SCI',
              subjectName: 'Science',
            ),
          ],
        ),
      ],
    ),
    AdminTeacherRecord(
      teacherId: 'TCH-1004',
      fullName: 'Mr. Tadesse',
      subject: 'Amharic',
      assignedClass: 'Grade 5B',
      schoolId: 'TB-001',
      employeeId: 'EMP-004',
      roles: [TeacherStaffRole.subjectTeacher],
      classAssignments: const [
        TeacherClassAssignment(
          className: 'Grade 5B',
          role: TeacherStaffRole.subjectTeacher,
          teachingSlots: [
            SubjectTeachingSlot(
              slotId: 'STA-1003',
              subjectId: 'SUB-AMH',
              subjectName: 'Amharic',
            ),
          ],
        ),
      ],
    ),
  ];

  AdminTeacherRecord? lookupByPhone(String phone, {String? schoolId}) {
    for (final teacher in _teachers.where((t) => t.isActive)) {
      if (!PhoneUtils.matches(teacher.phone, phone)) continue;
      if (schoolId != null &&
          teacher.schoolId.toUpperCase() != schoolId.trim().toUpperCase()) {
        continue;
      }
      return teacher;
    }
    return null;
  }

  /// Resolves the staff record for a logged-in teacher account.
  AdminTeacherRecord? resolveForAuthUser({
    String? linkedTeacherId,
    String? username,
    String? phone,
    String? schoolId,
  }) {
    if (linkedTeacherId != null && linkedTeacherId.trim().isNotEmpty) {
      final byId = lookupById(linkedTeacherId);
      if (byId != null) return byId;
    }
    if (username != null && username.trim().isNotEmpty) {
      final byLogin = lookupByLoginUsername(username);
      if (byLogin != null) {
        if (schoolId == null ||
            byLogin.schoolId.toUpperCase() == schoolId.trim().toUpperCase()) {
          return byLogin;
        }
      }
    }
    if (phone != null && phone.trim().isNotEmpty) {
      return lookupByPhone(phone, schoolId: schoolId);
    }
    return null;
  }

  AdminTeacherRecord? lookupById(String teacherId) {
    final id = teacherId.trim().toUpperCase();
    try {
      return _teachers.firstWhere((t) => t.teacherId == id && t.isActive);
    } catch (_) {
      return null;
    }
  }

  /// Active or inactive — used when freeing a deleted staff phone.
  AdminTeacherRecord? lookupAnyById(String teacherId) {
    final id = teacherId.trim().toUpperCase();
    try {
      return _teachers.firstWhere((t) => t.teacherId == id);
    } catch (_) {
      return null;
    }
  }

  AdminTeacherRecord? lookupByLoginUsername(String username) {
    final lower = username.trim().toLowerCase();
    try {
      return _teachers.firstWhere(
        (t) => t.loginUsername?.toLowerCase() == lower && t.isActive,
      );
    } catch (_) {
      return null;
    }
  }

  List<AdminTeacherRecord> getAllTeachers() =>
      List.unmodifiable(_teachers.where((t) => t.isActive));

  /// Active and inactive — used when freeing phones / auditing deletions.
  List<AdminTeacherRecord> allTeachersIncludingInactive() =>
      List.unmodifiable(_teachers);

  List<AdminTeacherRecord> teachersForSchool(
    String schoolId, {
    bool includeInactive = false,
  }) {
    final id = schoolId.trim().toUpperCase();
    return _teachers
        .where(
          (t) =>
              t.schoolId.toUpperCase() == id &&
              (includeInactive || t.isActive),
        )
        .toList();
  }

  void _replace(AdminTeacherRecord updated) {
    final idx = _teachers.indexWhere((t) => t.teacherId == updated.teacherId);
    if (idx >= 0) _teachers[idx] = updated;
  }

  void updatePhoto(String teacherId, String photoPath) {
    final existing = lookupById(teacherId);
    if (existing == null) return;
    _replace(existing.copyWith(photoPath: photoPath));
  }

  void saveCredentials({
    required String teacherId,
    required String initialPassword,
    String? loginUsername,
  }) {
    final existing = lookupById(teacherId);
    if (existing == null) return;
    final pass = initialPassword.trim();
    final safePass = (pass.length >= AuthService.minPasswordLength &&
            pass != AuthService.demoPassword)
        ? pass
        : AuthService.tempPassword;
    _replace(
      existing.copyWith(
        initialPassword: safePass,
        loginUsername: loginUsername ?? existing.loginUsername,
      ),
    );
  }

  void updateTeacher(AdminTeacherRecord updated) {
    _replace(updated);
  }

  void transferTeacherClass({
    required String teacherId,
    required String fromClassName,
    required String toClassName,
  }) {
    final teacher = lookupById(teacherId);
    if (teacher == null) return;
    final from = fromClassName.trim();
    final to = toClassName.trim();
    if (from.isEmpty || to.isEmpty || from == to) return;

    final assignments = teacher.classAssignments
        .map(
          (a) => a.className == from
              ? TeacherClassAssignment(className: to, role: a.role)
              : a,
        )
        .toList();

    final classNames = teacher.assignedClass
        .split(',')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .map((c) => c == from ? to : c)
        .toSet()
        .toList();

    _replace(
      teacher.copyWith(
        assignedClass: classNames.join(', '),
        classAssignments: assignments,
      ),
    );
  }

  void transferTeacherCampus({
    required String teacherId,
    required String toCampus,
  }) {
    final teacher = lookupById(teacherId);
    if (teacher == null) return;
    _replace(teacher.copyWith(campus: toCampus.trim()));
  }

  /// Bulk campus rename for a school. Caller persists the registry.
  int reassignCampusForSchool(
    String schoolId, {
    required String from,
    required String to,
  }) {
    final sid = schoolId.trim().toUpperCase();
    var count = 0;
    for (var i = 0; i < _teachers.length; i++) {
      final teacher = _teachers[i];
      if (teacher.schoolId.toUpperCase() == sid && teacher.campus == from) {
        _teachers[i] = teacher.copyWith(campus: to);
        count++;
      }
    }
    return count;
  }

  List<String> homeroomClassesFor(String teacherId) {
    final id = teacherId.trim().toUpperCase();
    final classes = <String>{};
    final teacher = lookupById(id);
    if (teacher != null) {
      for (final assignment in teacher.classAssignments) {
        if (assignment.role == TeacherStaffRole.homeroomTeacher) {
          classes.add(assignment.className);
        }
      }
    }
    classes.addAll(
      SchoolDataService.instance.homeroomClassNamesForTeacher(id),
    );
    final list = classes.toList()..sort();
    return list;
  }

  /// Same teacher list as Staff → Teachers tab.
  List<AdminTeacherRecord> staffTeachersForSchool(String? schoolId) {
    if (schoolId == null || schoolId.trim().isEmpty) {
      return getAllTeachers();
    }
    return teachersForSchool(schoolId);
  }

  void assignHomeroomClass(String teacherId, String className) {
    final teacher = lookupById(teacherId);
    if (teacher == null) return;
    final assignments = List<TeacherClassAssignment>.from(
      teacher.classAssignments,
    );
    assignments.removeWhere(
      (a) =>
          StudentRegistryService.classNamesMatch(a.className, className) &&
          a.role == TeacherStaffRole.homeroomTeacher,
    );
    assignments.add(
      TeacherClassAssignment(
        className: className,
        role: TeacherStaffRole.homeroomTeacher,
      ),
    );
    _replace(teacher.copyWith(classAssignments: assignments));
  }

  bool deactivateTeacher(String teacherId) {
    final existing = lookupAnyById(teacherId);
    if (existing == null) return false;
    _replace(existing.copyWith(isActive: false));
    return true;
  }

  void removeTeacher(String teacherId) {
    final id = teacherId.trim().toUpperCase();
    _teachers.removeWhere((t) => t.teacherId == id);
  }

  AdminTeacherRecord addTeacher({
    required String schoolId,
    required String fullName,
    required String email,
    required String phone,
    String? employeeId,
    String? subject,
    List<String>? subjects,
    required String assignedClass,
    required List<TeacherStaffRole> roles,
    required String loginUsername,
    String? initialPassword,
    String? photoPath,
    List<TeacherClassAssignment> classAssignments = const [],
    String? campus,
    List<String> staffRoles = const [],
  }) {
    final record = AdminTeacherRecord(
      teacherId: _allocateTeacherId(staffRoles: staffRoles),
      fullName: fullName.trim(),
      subject: subject?.trim(),
      subjects: subjects,
      assignedClass: assignedClass.trim(),
      schoolId: schoolId.trim().toUpperCase(),
      email: email.trim().isEmpty ? null : email.trim(),
      phone: phone.trim(),
      employeeId: employeeId?.trim().isEmpty ?? true ? null : employeeId!.trim(),
      roles: roles,
      loginUsername: loginUsername.trim().toLowerCase(),
      mustChangePassword: true,
      initialPassword: initialPassword,
      photoPath: photoPath,
      classAssignments: classAssignments,
      campus: campus == null || campus.trim().isEmpty
          ? 'Main Campus'
          : campus.trim(),
      staffRoles: staffRoles,
    );
    _teachers.add(record);
    return record;
  }

  List<AdminTeacherRecord> registrySnapshot() =>
      List.unmodifiable(_teachers);

  int get nextTeacherIdCounter => _nextId;

  /// Role-based ids: `TCH-0001` (classroom) or `QA-0001` / `HR-0001` …
  /// (administration staff). Always four digits.
  String _allocateTeacherId({List<String> staffRoles = const []}) {
    final prefix = staffRoles.isEmpty
        ? 'TCH'
        : StaffRoles.idPrefixFor(staffRoles.first);
    final id = ShortRegistryId.allocate(
      prefix: prefix,
      existingIds: _teachers.map((t) => t.teacherId),
      isTaken: (id) => lookupAnyById(id) != null,
    );
    _nextId = (ShortRegistryId.parseNumber(id) ?? 0) + 1;
    return id;
  }

  void applyPersistedTeachers(
    List<AdminTeacherRecord> teachers, {
    int? nextId,
  }) {
    for (final teacher in teachers) {
      final index =
          _teachers.indexWhere((item) => item.teacherId == teacher.teacherId);
      if (index >= 0) {
        _teachers[index] = teacher;
      } else {
        _teachers.add(teacher);
      }
    }
    final clamped = ShortRegistryId.clampCounter(nextId, fallback: _nextId);
    if (clamped > _nextId) {
      _nextId = clamped;
    }
  }
}
