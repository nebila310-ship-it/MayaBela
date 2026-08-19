import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/database/id_utils.dart';
import 'package:mayabela/database/models/database_models.dart';
import 'package:mayabela/database/relationship_resolver.dart';
import 'package:mayabela/database/repositories/supabase_school_repository.dart';
import 'package:mayabela/database/repositories/in_memory_school_repository.dart';
import 'package:mayabela/database/repositories/school_repository.dart';
import 'package:mayabela/database/seed/registry_seed_builder.dart';
import 'package:mayabela/database/user_roles.dart';
import 'package:mayabela/services/auth_service.dart';

/// Central database facade — seed, repository, and relationship resolver.
class SchoolDatabaseService {
  SchoolDatabaseService._();

  static final instance = SchoolDatabaseService._();

  SchoolRepository _repository = InMemorySchoolRepository();
  RelationshipResolver _resolver = const RelationshipResolver(
    students: [],
    parentLinks: [],
    teacherAssignments: [],
    transportAssignments: [],
    routes: [],
  );

  bool _initialized = false;
  bool _useFirestore = false;

  bool get isInitialized => _initialized;
  bool get useFirestore => _useFirestore;
  SchoolRepository get repository => _repository;
  RelationshipResolver get resolver => _resolver;

  /// Initialize from registries. Uses Firestore when Firebase is configured.
  Future<void> initialize({bool? useFirestore}) async {
    final firebaseReady = SupabaseBootstrap.isInitialized;
    final preferFirestore = useFirestore ?? firebaseReady;

    if (preferFirestore && firebaseReady) {
      try {
        final firestoreRepo = SupabaseSchoolRepository();
        final snapshot = RegistrySeedBuilder.buildFromRegistries();
        await firestoreRepo
            .seedIfEmpty(snapshot)
            .timeout(const Duration(seconds: 3));
        _repository = firestoreRepo;
        _useFirestore = true;
        _refreshResolver();
        _initialized = true;
        return;
      } catch (_) {
        // Firestore unavailable, slow, or rules blocked — use local seed.
      }
    }

    final repo = InMemorySchoolRepository();
    await repo.loadSnapshot(RegistrySeedBuilder.buildFromRegistries());
    _repository = repo;
    _useFirestore = false;
    _refreshResolver();
    _initialized = true;
  }

  /// Re-sync when registries or enrollment links change.
  Future<void> syncFromRegistries() async {
    if (_useFirestore && _repository is SupabaseSchoolRepository) {
      await _repository.loadSnapshot(RegistrySeedBuilder.buildFromRegistries());
    } else {
      await _repository.loadSnapshot(RegistrySeedBuilder.buildFromRegistries());
    }
    _refreshResolver();
  }

  /// Incremental sync for one enrolled student — avoids rewriting the whole database.
  Future<void> syncStudentFromRegistry(String studentId) async {
    if (!_initialized) return;
    final bundle = RegistrySeedBuilder.sliceForStudent(studentId);
    if (bundle.student == null) return;

    await _repository.upsertStudent(bundle.student!);
    if (bundle.classRecord != null) {
      await _repository.upsertClass(bundle.classRecord!);
    }
    if (bundle.transport != null) {
      await _repository.upsertTransportAssignment(bundle.transport!);
    } else {
      await _repository.removeTransportForStudent(
        studentId.trim().toUpperCase(),
      );
    }
    _refreshResolver();
  }

  /// Sync one parent's user record, profile, and approved child links.
  Future<void> syncParentEnrollmentForUser(String username) async {
    if (!_initialized) return;
    final bundle = RegistrySeedBuilder.sliceForParentUsername(username);
    if (bundle.user != null) {
      await _repository.upsertUser(bundle.user!);
    }
    if (bundle.parent != null) {
      await _repository.upsertParent(bundle.parent!);
    }
    for (final link in bundle.links) {
      await _repository.upsertParentLink(link);
      await syncStudentFromRegistry(link.studentId);
    }
    _refreshResolver();
  }

  /// Incremental sync for one teacher's assignments.
  Future<void> syncTeacherFromRegistry(String teacherId) async {
    if (!_initialized) return;
    final bundle = RegistrySeedBuilder.sliceForTeacher(teacherId);
    if (bundle.user != null) {
      await _repository.upsertUser(bundle.user!);
    }
    if (bundle.teacher != null) {
      await _repository.upsertTeacher(bundle.teacher!);
    }
    for (final assignment in bundle.assignments) {
      await _repository.upsertTeacherAssignment(assignment);
    }
    _refreshResolver();
  }

  void _refreshResolver() {
    _resolver = RelationshipResolver(
      students: _repository.students,
      parentLinks: _repository.parentLinks,
      teacherAssignments: _repository.teacherAssignments,
      transportAssignments: _repository.transportAssignments,
      routes: _repository.routes,
    );
  }

  // —— Lookups ——

  StudentRecord? studentById(String studentId) {
    final id = studentId.trim().toUpperCase();
    try {
      return _repository.students.firstWhere(
        (s) => s.studentId.toUpperCase() == id,
      );
    } catch (_) {
      return null;
    }
  }

  ClassRecord? classById(String classId) {
    try {
      return _repository.classes.firstWhere((c) => c.classId == classId);
    } catch (_) {
      return null;
    }
  }

  ClassRecord? classByName(String className) =>
      classById(IdUtils.classIdForName(className));

  String classIdForName(String className) => IdUtils.classIdForName(className);

  String? classNameForStudent(String studentId) {
    final student = studentById(studentId);
    if (student == null) return null;
    return classById(student.classId)?.className ??
        IdUtils.classNameForId(student.classId);
  }

  ParentRecord? parentById(String parentId) {
    try {
      return _repository.parents.firstWhere((p) => p.parentId == parentId);
    } catch (_) {
      return null;
    }
  }

  ParentRecord? parentForCurrentUser() {
    final user = AuthService.currentUser;
    if (user == null || user.roleKey != UserRoles.parent) return null;
    return parentForUsername(user.username);
  }

  ParentRecord? parentForUsername(String username) {
    final authUser = AuthService.allUsers[username.trim().toLowerCase()];
    if (authUser == null) return null;

    UserRecord? userRecord;
    for (final user in _repository.users) {
      if (user.role != UserRoles.parent) continue;
      if (authUser.phone != null &&
          user.phone != null &&
          user.phone!.replaceAll(RegExp(r'\D'), '') ==
              authUser.phone!.replaceAll(RegExp(r'\D'), '')) {
        userRecord = user;
        break;
      }
      if (authUser.fullName != null && user.fullName == authUser.fullName) {
        userRecord = user;
        break;
      }
      if (authUser.email != null && user.email == authUser.email) {
        userRecord = user;
        break;
      }
    }
    if (userRecord == null) return null;

    try {
      return _repository.parents.firstWhere((p) => p.userId == userRecord!.userId);
    } catch (_) {
      return null;
    }
  }

  String? parentIdForCurrentUser() => parentForCurrentUser()?.parentId;

  TeacherRecord? teacherById(String teacherId) {
    final id = teacherId.trim().toUpperCase();
    try {
      return _repository.teachers.firstWhere(
        (t) => t.teacherId.toUpperCase() == id,
      );
    } catch (_) {
      return null;
    }
  }

  RouteRecord? routeForDriver(String driverId) => _resolver.routeForDriver(driverId);

  TransportAssignment? transportForStudent(String studentId) =>
      _resolver.transportForStudent(studentId);

  String? routeIdForStudent(String studentId) =>
      transportForStudent(studentId)?.routeId;

  String? legacyRouteIdForStudent(String studentId) {
    final routeId = routeIdForStudent(studentId);
    if (routeId == null) return null;
    return IdUtils.legacyRouteIdForSchemaRoute(routeId);
  }

  String? driverIdForStudent(String studentId) {
    final assignment = transportForStudent(studentId);
    if (assignment == null) return null;
    try {
      return _repository.routes
          .firstWhere((r) => r.routeId == assignment.routeId)
          .driverId;
    } catch (_) {
      return null;
    }
  }

  // —— Access checks ——

  bool canTeacherAccessClass({
    required String teacherId,
    required String classId,
  }) {
    return RoleAccessRules.teacherCanAccessClass(
      teacherId: teacherId,
      classId: classId,
      resolver: _resolver,
    );
  }

  bool canTeacherAccessClassName({
    required String teacherId,
    required String className,
  }) {
    return canTeacherAccessClass(
      teacherId: teacherId,
      classId: classIdForName(className),
    );
  }

  bool canParentAccessStudent({
    required String parentId,
    required String studentId,
  }) {
    return RoleAccessRules.parentCanAccessStudent(
      parentId: parentId,
      studentId: studentId,
      resolver: _resolver,
    );
  }

  bool canCurrentParentAccessStudent(String studentId) {
    final parentId = parentIdForCurrentUser();
    if (parentId == null) return false;
    return canParentAccessStudent(parentId: parentId, studentId: studentId);
  }

  bool canDriverAccessStudent({
    required String driverId,
    required String studentId,
  }) {
    return RoleAccessRules.driverCanAccessStudent(
      driverId: driverId,
      studentId: studentId,
      resolver: _resolver,
    );
  }

  List<StudentRecord> studentsForCurrentParent() {
    final parentId = parentIdForCurrentUser();
    if (parentId == null) return const [];
    return _resolver.studentsForParent(parentId);
  }

  List<TeacherAssignment> teachersForParent(String parentId) =>
      _resolver.teachersForParent(parentId);

  List<TeacherAssignment> teachersForCurrentParent() {
    final parentId = parentIdForCurrentUser();
    if (parentId == null) return const [];
    return teachersForParent(parentId);
  }

  List<StudentRecord> studentsForTeacher(String teacherId) {
    final classIds = _resolver.classIdsForTeacher(teacherId);
    return _repository.students
        .where((s) => classIds.contains(s.classId))
        .toList();
  }

  List<StudentRecord> studentsOnDriverRoute(String driverId) {
    final route = _resolver.routeForDriver(driverId);
    if (route == null) return const [];
    return _resolver.studentsOnRoute(route.routeId);
  }
}
