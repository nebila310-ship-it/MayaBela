import 'package:mayabela/database/id_utils.dart';
import 'package:mayabela/database/models/database_models.dart';
import 'package:mayabela/database/seed/school_seed_snapshot.dart';
import 'package:mayabela/database/user_roles.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

/// Builds canonical database records from existing in-app registries.
abstract final class RegistrySeedBuilder {
  static SchoolSeedSnapshot buildFromRegistries() {
    EnrollmentService.instance.ensureSeeded();
    AuthService.ensureRegistryLoginAccounts();

    final users = <UserRecord>[];
    final parents = <ParentRecord>[];
    final parentLinks = <ParentStudentLink>[];
    final parentByUsername = <String, String>{};

    var parentCounter = 1;
    var userCounter = 1;
    var linkCounter = 1;
    var assignmentCounter = 1;
    var transportCounter = 1;

    String nextUserId() {
      final n = userCounter++;
      return 'U${n.toString().padLeft(3, '0')}';
    }

    String nextParentId() {
      final n = parentCounter++;
      return 'P${n.toString().padLeft(3, '0')}';
    }

    for (final entry in AuthService.allUsers.entries) {
      final user = entry.value;
      final userId = nextUserId();
      users.add(
        UserRecord(
          userId: userId,
          role: user.roleKey,
          fullName: user.fullName ?? user.username,
          phone: user.phone,
          email: user.email,
          status: 'active',
          createdAt: DateTime.now(),
        ),
      );

      if (user.roleKey == UserRoles.parent) {
        final parentId = nextParentId();
        parentByUsername[user.username.toLowerCase()] = parentId;
        parents.add(
          ParentRecord(
            parentId: parentId,
            userId: userId,
            fatherName: user.fullName,
            phone: user.phone,
            email: user.email,
          ),
        );

        for (final link in EnrollmentService.instance.linksForParent(user.username)) {
          if (link.status != ParentLinkStatus.approved) continue;
          parentLinks.add(
            ParentStudentLink(
              linkId: 'L${linkCounter++}',
              parentId: parentId,
              studentId: link.studentId,
            ),
          );
        }

        for (final studentId in user.linkedStudentIds) {
          final exists = parentLinks.any(
            (l) => l.parentId == parentId && l.studentId == studentId,
          );
          if (!exists) {
            parentLinks.add(
              ParentStudentLink(
                linkId: 'L${linkCounter++}',
                parentId: parentId,
                studentId: studentId,
              ),
            );
          }
        }
      }
    }

    final classNames = <String>{};
    for (final student in StudentRegistryService.instance.getAllStudents()) {
      classNames.add(student.className);
    }
    for (final teacher in TeacherRegistryService.instance.getAllTeachers()) {
      for (final assignment in teacher.classAssignments) {
        classNames.add(assignment.className);
      }
    }

    final classes = classNames.map((className) {
      final parts = StudentRegistryService.parseClassNameParts(className);
      return ClassRecord(
        classId: IdUtils.classIdForName(className),
        gradeLevel: parts?.grade ?? className,
        section: parts?.section ?? '',
        className: className,
        academicYear: '2025/2026',
        active: true,
      );
    }).toList()
      ..sort((a, b) => a.className.compareTo(b.className));

    final students = StudentRegistryService.instance.getAllStudents().map((s) {
      final names = IdUtils.splitFullName(s.fullName);
      final primaryParentId = _primaryParentIdForStudent(
        s.studentId,
        parentLinks,
      );
      return StudentRecord(
        studentId: s.studentId,
        firstName: names[0],
        lastName: names[1],
        classId: IdUtils.classIdForName(s.className),
        gender: s.gender,
        birthDate: s.dateOfBirth,
        parentId: primaryParentId,
        routeId: s.transportEnabled && s.transportId != null
            ? IdUtils.routeIdForDriver(
                DriverRegistryService.instance.driverIdForTransportReference(
                      s.transportId,
                    ) ??
                    s.transportId!,
              )
            : null,
        admissionNumber: s.studentId,
        status: s.isActive ? 'active' : 'inactive',
        hasMedicalCondition: s.hasMedicalCondition,
        medicalConditionDetails: s.medicalConditionDetails,
        otherMedicalInfo: s.otherMedicalInfo,
      );
    }).toList();

    final teachers = TeacherRegistryService.instance.getAllTeachers().map((t) {
      final userId = _userIdForRoleEntity(
        users: users,
        role: UserRoles.teacher,
        phone: t.phone,
        fullName: t.fullName,
      );
      return TeacherRecord(
        teacherId: t.teacherId,
        userId: userId ?? 'U-TEA-${t.teacherId}',
        employeeNumber: t.employeeId,
        specialization: t.subject,
        status: t.isActive ? 'active' : 'inactive',
      );
    }).toList();

    final teacherAssignments = <TeacherAssignment>[];
    for (final teacher in TeacherRegistryService.instance.getAllTeachers()) {
      for (final assignment in teacher.classAssignments) {
        teacherAssignments.add(
          TeacherAssignment(
            assignmentId: 'TA-${assignmentCounter++}',
            teacherId: teacher.teacherId,
            classId: IdUtils.classIdForName(assignment.className),
            subjectName: teacher.subject,
          ),
        );
      }
    }

    final drivers = DriverRegistryService.instance.getAllDrivers().map((d) {
      final userId = _userIdForRoleEntity(
        users: users,
        role: UserRoles.driver,
        phone: d.phone,
        fullName: d.fullName,
      );
      return DriverRecord(
        driverId: d.driverId,
        userId: userId ?? 'U-DRV-${d.driverId}',
        licenseNumber: d.plateNumber,
        phone: d.phone,
        status: d.isActive ? 'active' : 'inactive',
      );
    }).toList();

    final routes = DriverRegistryService.instance.getAllDrivers().map((d) {
      return RouteRecord(
        routeId: IdUtils.routeIdForDriver(d.driverId),
        routeName: d.routeName,
        busNumber: d.busNumber,
        driverId: d.driverId,
      );
    }).toList();

    final transportAssignments = <TransportAssignment>[];
    for (final student in StudentRegistryService.instance.getAllStudents()) {
      if (!student.transportEnabled) continue;
      final driverId = DriverRegistryService.instance
          .driverIdForTransportReference(student.transportId);
      if (driverId == null || driverId.isEmpty) continue;
      transportAssignments.add(
        TransportAssignment(
          assignmentId: 'TR-${transportCounter++}',
          studentId: student.studentId,
          routeId: IdUtils.routeIdForDriver(driverId),
          pickupLocation: null,
        ),
      );
    }

    return SchoolSeedSnapshot(
      users: users,
      classes: classes,
      students: students,
      parents: parents,
      parentLinks: parentLinks,
      teachers: teachers,
      teacherAssignments: teacherAssignments,
      drivers: drivers,
      routes: routes,
      transportAssignments: transportAssignments,
    );
  }

  /// Records needed when a single student is added or updated (avoids full DB sync).
  static ({
    StudentRecord? student,
    ClassRecord? classRecord,
    TransportAssignment? transport,
  }) sliceForStudent(String studentId) {
    final snapshot = buildFromRegistries();
    final id = studentId.trim().toUpperCase();
    StudentRecord? student;
    for (final row in snapshot.students) {
      if (row.studentId.toUpperCase() == id) {
        student = row;
        break;
      }
    }
    if (student == null) {
      return (student: null, classRecord: null, transport: null);
    }
    ClassRecord? classRecord;
    for (final row in snapshot.classes) {
      if (row.classId == student.classId) {
        classRecord = row;
        break;
      }
    }
    TransportAssignment? transport;
    for (final row in snapshot.transportAssignments) {
      if (row.studentId.toUpperCase() == id) {
        transport = row;
        break;
      }
    }
    return (student: student, classRecord: classRecord, transport: transport);
  }

  /// Parent user, profile, and approved student links for one login username.
  static ({
    UserRecord? user,
    ParentRecord? parent,
    List<ParentStudentLink> links,
  }) sliceForParentUsername(String username) {
    final snapshot = buildFromRegistries();
    final authUser = AuthService.allUsers[username.trim().toLowerCase()];
    if (authUser == null || authUser.roleKey != UserRoles.parent) {
      return (user: null, parent: null, links: const []);
    }

    UserRecord? matchedUser;
    for (final user in snapshot.users) {
      if (user.role != UserRoles.parent) continue;
      if (_authMatchesUserRecord(authUser, user)) {
        matchedUser = user;
        break;
      }
    }
    if (matchedUser == null) {
      return (user: null, parent: null, links: const []);
    }

    ParentRecord? parent;
    final userRecord = matchedUser;
    for (final row in snapshot.parents) {
      if (row.userId == userRecord.userId) {
        parent = row;
        break;
      }
    }
    if (parent == null) {
      return (user: matchedUser, parent: null, links: const []);
    }

    final parentRecord = parent;
    final links = snapshot.parentLinks
        .where((link) => link.parentId == parentRecord.parentId)
        .toList();
    return (user: matchedUser, parent: parent, links: links);
  }

  static ({
    UserRecord? user,
    TeacherRecord? teacher,
    List<TeacherAssignment> assignments,
  }) sliceForTeacher(String teacherId) {
    final snapshot = buildFromRegistries();
    final id = teacherId.trim().toUpperCase();
    TeacherRecord? teacher;
    for (final row in snapshot.teachers) {
      if (row.teacherId.toUpperCase() == id) {
        teacher = row;
        break;
      }
    }
    if (teacher == null) {
      return (user: null, teacher: null, assignments: const []);
    }
    UserRecord? user;
    final teacherRecord = teacher;
    for (final row in snapshot.users) {
      if (row.userId == teacherRecord.userId) {
        user = row;
        break;
      }
    }
    final assignments = snapshot.teacherAssignments
        .where((assignment) => assignment.teacherId.toUpperCase() == id)
        .toList();
    return (user: user, teacher: teacher, assignments: assignments);
  }

  static bool _authMatchesUserRecord(
    RegisteredUser authUser,
    UserRecord userRecord,
  ) {
    if (authUser.phone != null &&
        userRecord.phone != null &&
        userRecord.phone!.replaceAll(RegExp(r'\D'), '') ==
            authUser.phone!.replaceAll(RegExp(r'\D'), '')) {
      return true;
    }
    if (authUser.fullName != null &&
        authUser.fullName!.trim().isNotEmpty &&
        userRecord.fullName.trim() == authUser.fullName!.trim()) {
      return true;
    }
    if (authUser.email != null &&
        authUser.email!.trim().isNotEmpty &&
        userRecord.email == authUser.email) {
      return true;
    }
    return false;
  }

  static String? _primaryParentIdForStudent(
    String studentId,
    List<ParentStudentLink> links,
  ) {
    try {
      return links.firstWhere((l) => l.studentId == studentId).parentId;
    } catch (_) {
      return null;
    }
  }

  static String? _userIdForRoleEntity({
    required List<UserRecord> users,
    required String role,
    String? phone,
    required String fullName,
  }) {
    for (final user in users) {
      if (user.role != role) continue;
      if (phone != null &&
          user.phone != null &&
          user.phone!.replaceAll(RegExp(r'\D'), '') ==
              phone.replaceAll(RegExp(r'\D'), '')) {
        return user.userId;
      }
      if (user.fullName == fullName) return user.userId;
    }
    return null;
  }
}
