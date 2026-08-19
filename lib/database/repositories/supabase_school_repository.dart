import 'package:mayabela/database/collection_names.dart';
import 'package:mayabela/database/models/database_models.dart';
import 'package:mayabela/database/repositories/school_repository.dart';
import 'package:mayabela/database/seed/school_seed_snapshot.dart';
import 'package:mayabela/services/cloud/document_store.dart';

/// Supabase-backed school repository (Firestore-shaped document store).
class SupabaseSchoolRepository implements SchoolRepository {
  SupabaseSchoolRepository({DocumentStore? crud})
      : _crud = crud ?? DocumentStore();

  final DocumentStore _crud;

  List<UserRecord> _users = [];
  List<ClassRecord> _classes = [];
  List<StudentRecord> _students = [];
  List<ParentRecord> _parents = [];
  List<ParentStudentLink> _parentLinks = [];
  List<TeacherRecord> _teachers = [];
  List<TeacherAssignment> _teacherAssignments = [];
  List<DriverRecord> _drivers = [];
  List<RouteRecord> _routes = [];
  List<TransportAssignment> _transportAssignments = [];
  List<AttendanceRecord> _attendance = [];
  List<GradeRecord> _grades = [];
  List<AnnouncementRecord> _announcements = [];

  @override
  Future<void> loadSnapshot(SchoolSeedSnapshot snapshot) async {
    await _writeCollection(DbCollections.users, snapshot.users, 'userId');
    await _writeCollection(DbCollections.classes, snapshot.classes, 'classId');
    await _writeCollection(
      DbCollections.students,
      snapshot.students,
      'studentId',
    );
    await _writeCollection(DbCollections.parents, snapshot.parents, 'parentId');
    await _writeCollection(
      DbCollections.parentStudentLinks,
      snapshot.parentLinks,
      'linkId',
    );
    await _writeCollection(
      DbCollections.teachers,
      snapshot.teachers,
      'teacherId',
    );
    await _writeCollection(
      DbCollections.teacherAssignments,
      snapshot.teacherAssignments,
      'assignmentId',
    );
    await _writeCollection(DbCollections.drivers, snapshot.drivers, 'driverId');
    await _writeCollection(DbCollections.routes, snapshot.routes, 'routeId');
    await _writeCollection(
      DbCollections.transportAssignments,
      snapshot.transportAssignments,
      'assignmentId',
    );
    await _writeCollection(
      DbCollections.attendance,
      snapshot.attendance,
      'attendanceId',
    );
    await _writeCollection(DbCollections.grades, snapshot.grades, 'gradeId');
    await _writeCollection(
      DbCollections.announcements,
      snapshot.announcements,
      'announcementId',
    );
    await refreshCache();
  }

  Future<void> seedIfEmpty(SchoolSeedSnapshot snapshot) async {
    final users = await _crud.readAll(DbCollections.users);
    if (users.isEmpty) {
      await loadSnapshot(snapshot);
    } else {
      await refreshCache();
    }
  }

  Future<void> refreshCache() async {
    _users = await _readAll(DbCollections.users, UserRecord.fromMap);
    _classes = await _readAll(DbCollections.classes, ClassRecord.fromMap);
    _students = await _readAll(DbCollections.students, StudentRecord.fromMap);
    _parents = await _readAll(DbCollections.parents, ParentRecord.fromMap);
    _parentLinks = await _readAll(
      DbCollections.parentStudentLinks,
      ParentStudentLink.fromMap,
    );
    _teachers = await _readAll(DbCollections.teachers, TeacherRecord.fromMap);
    _teacherAssignments = await _readAll(
      DbCollections.teacherAssignments,
      TeacherAssignment.fromMap,
    );
    _drivers = await _readAll(DbCollections.drivers, DriverRecord.fromMap);
    _routes = await _readAll(DbCollections.routes, RouteRecord.fromMap);
    _transportAssignments = await _readAll(
      DbCollections.transportAssignments,
      TransportAssignment.fromMap,
    );
    _attendance = await _readAll(
      DbCollections.attendance,
      AttendanceRecord.fromMap,
    );
    _grades = await _readAll(DbCollections.grades, GradeRecord.fromMap);
    _announcements = await _readAll(
      DbCollections.announcements,
      AnnouncementRecord.fromMap,
    );
  }

  Future<void> _writeCollection<T>(
    String collection,
    List<T> items,
    String idField,
  ) async {
    if (items.isEmpty) return;
    final maps = <Map<String, dynamic>>[];
    for (final item in items) {
      maps.add((item as dynamic).toMap() as Map<String, dynamic>);
    }
    await _crud.writeBatch(
      collection: collection,
      items: maps,
      docIdFor: (item) => item[idField] as String,
    );
  }

  Future<List<T>> _readAll<T>(
    String collection,
    T Function(Map<String, dynamic>) fromMap,
  ) async {
    final docs = await _crud.readAll(collection);
    return docs.map(fromMap).toList();
  }

  Future<void> _upsertDoc(
    String collection,
    String docId,
    Map<String, dynamic> map,
  ) async {
    await _crud.createOrUpdate(
      collection: collection,
      docId: docId,
      data: map,
    );
  }

  @override
  Future<SchoolSeedSnapshot> exportSnapshot() async {
    await refreshCache();
    return SchoolSeedSnapshot(
      users: _users,
      classes: _classes,
      students: _students,
      parents: _parents,
      parentLinks: _parentLinks,
      teachers: _teachers,
      teacherAssignments: _teacherAssignments,
      drivers: _drivers,
      routes: _routes,
      transportAssignments: _transportAssignments,
      attendance: _attendance,
      grades: _grades,
      announcements: _announcements,
    );
  }

  @override
  List<UserRecord> get users => List.unmodifiable(_users);

  @override
  List<ClassRecord> get classes => List.unmodifiable(_classes);

  @override
  List<StudentRecord> get students => List.unmodifiable(_students);

  @override
  List<ParentRecord> get parents => List.unmodifiable(_parents);

  @override
  List<ParentStudentLink> get parentLinks => List.unmodifiable(_parentLinks);

  @override
  List<TeacherRecord> get teachers => List.unmodifiable(_teachers);

  @override
  List<TeacherAssignment> get teacherAssignments =>
      List.unmodifiable(_teacherAssignments);

  @override
  List<DriverRecord> get drivers => List.unmodifiable(_drivers);

  @override
  List<RouteRecord> get routes => List.unmodifiable(_routes);

  @override
  List<TransportAssignment> get transportAssignments =>
      List.unmodifiable(_transportAssignments);

  @override
  List<AttendanceRecord> get attendance => List.unmodifiable(_attendance);

  @override
  List<GradeRecord> get grades => List.unmodifiable(_grades);

  @override
  List<AnnouncementRecord> get announcements =>
      List.unmodifiable(_announcements);

  @override
  Future<void> upsertStudent(StudentRecord record) async {
    await _upsertDoc(
      DbCollections.students,
      record.studentId,
      record.toMap(),
    );
    final idx = _students.indexWhere((s) => s.studentId == record.studentId);
    if (idx >= 0) {
      _students[idx] = record;
    } else {
      _students.add(record);
    }
  }

  @override
  Future<void> upsertClass(ClassRecord record) async {
    await _upsertDoc(DbCollections.classes, record.classId, record.toMap());
    final idx = _classes.indexWhere((c) => c.classId == record.classId);
    if (idx >= 0) {
      _classes[idx] = record;
    } else {
      _classes.add(record);
    }
  }

  @override
  Future<void> upsertUser(UserRecord record) async {
    await _upsertDoc(DbCollections.users, record.userId, record.toMap());
    final idx = _users.indexWhere((u) => u.userId == record.userId);
    if (idx >= 0) {
      _users[idx] = record;
    } else {
      _users.add(record);
    }
  }

  @override
  Future<void> upsertParent(ParentRecord record) async {
    await _upsertDoc(DbCollections.parents, record.parentId, record.toMap());
    final idx = _parents.indexWhere((p) => p.parentId == record.parentId);
    if (idx >= 0) {
      _parents[idx] = record;
    } else {
      _parents.add(record);
    }
  }

  @override
  Future<void> upsertTeacher(TeacherRecord record) async {
    await _upsertDoc(
      DbCollections.teachers,
      record.teacherId,
      record.toMap(),
    );
    final idx = _teachers.indexWhere((t) => t.teacherId == record.teacherId);
    if (idx >= 0) {
      _teachers[idx] = record;
    } else {
      _teachers.add(record);
    }
  }

  @override
  Future<void> upsertParentLink(ParentStudentLink link) async {
    await _upsertDoc(
      DbCollections.parentStudentLinks,
      link.linkId,
      link.toMap(),
    );
    final idx = _parentLinks.indexWhere((l) => l.linkId == link.linkId);
    if (idx >= 0) {
      _parentLinks[idx] = link;
    } else {
      _parentLinks.add(link);
    }
  }

  @override
  Future<void> upsertTransportAssignment(TransportAssignment assignment) async {
    await _upsertDoc(
      DbCollections.transportAssignments,
      assignment.assignmentId,
      assignment.toMap(),
    );
    await refreshCache();
  }

  @override
  Future<void> removeTransportForStudent(String studentId) async {
    final matches = await _crud.readBySchool(
      DbCollections.transportAssignments,
      equals: {'studentId': studentId},
    );
    for (final doc in matches) {
      final id = doc['_docId'] as String? ?? doc['assignmentId'] as String?;
      if (id != null) {
        await _crud.deleteDoc(
          collection: DbCollections.transportAssignments,
          docId: id,
        );
      }
    }
    await refreshCache();
  }

  @override
  Future<void> upsertTeacherAssignment(TeacherAssignment assignment) async {
    await _upsertDoc(
      DbCollections.teacherAssignments,
      assignment.assignmentId,
      assignment.toMap(),
    );
    await refreshCache();
  }

  @override
  Future<void> upsertAttendance(AttendanceRecord record) async {
    await _upsertDoc(
      DbCollections.attendance,
      record.attendanceId,
      record.toMap(),
    );
    await refreshCache();
  }

  @override
  Future<void> upsertGrade(GradeRecord record) async {
    await _upsertDoc(DbCollections.grades, record.gradeId, record.toMap());
    await refreshCache();
  }

  @override
  Future<void> upsertAnnouncement(AnnouncementRecord record) async {
    await _upsertDoc(
      DbCollections.announcements,
      record.announcementId,
      record.toMap(),
    );
    await refreshCache();
  }
}
