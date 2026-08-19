import 'package:mayabela/database/seed/registry_seed_builder.dart';
import 'package:mayabela/database/school_database_service.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    AuthService.ensureRegistryLoginAccounts();
    await SchoolDatabaseService.instance.initialize();
  });

  test('seed builds students, classes, and parent links', () {
    final snapshot = RegistrySeedBuilder.buildFromRegistries();
    expect(snapshot.students.any((s) => s.studentId == 'STU-1001'), isTrue);
    expect(snapshot.classes.any((c) => c.classId == 'C001'), isTrue);
    expect(
      snapshot.parentLinks.any(
        (l) => l.studentId == 'STU-1001' && l.parentId.startsWith('P'),
      ),
      isTrue,
    );
  });

  test('parent can reach child class teachers via resolver', () {
    final db = SchoolDatabaseService.instance;
    final parent = db.parentForUsername('parent');
    expect(parent, isNotNull);

    final children = db.resolver.studentsForParent(parent!.parentId);
    expect(children.map((s) => s.studentId), contains('STU-1001'));

    final teachers = db.resolver.teachersForParent(parent.parentId);
    expect(teachers.any((a) => a.classId == 'C001'), isTrue);
  });

  test('role access rules enforce teacher and driver boundaries', () {
    final db = SchoolDatabaseService.instance;
    expect(
      db.canTeacherAccessClass(teacherId: 'TCH-1001', classId: 'C001'),
      isTrue,
    );
    expect(
      db.canTeacherAccessClass(teacherId: 'TCH-1002', classId: 'C001'),
      isFalse,
    );
    expect(
      db.canDriverAccessStudent(
        driverId: 'DRV-1001',
        studentId: 'STU-1001',
      ),
      isTrue,
    );
    expect(
      db.canDriverAccessStudent(
        driverId: 'DRV-1002',
        studentId: 'STU-1001',
      ),
      isFalse,
    );
  });
}
