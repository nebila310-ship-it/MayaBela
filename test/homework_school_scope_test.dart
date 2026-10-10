import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_content_sync_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void signIn(String schoolId) {
    AuthService.currentUser = RegisteredUser(
      username: 'teacher.$schoolId',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: schoolId,
      fullName: 'Teacher $schoolId',
      linkedTeacherId: 'TCH-$schoolId',
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = null;
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  test('homework posted at one school stays hidden from the other', () {
    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: 'STU-HW-A',
        fullName: 'Ada School A',
        grade: 'Grade 4',
        className: 'Grade 4A',
        schoolId: 'SCH-A',
        dateOfBirth: DateTime(2016, 1, 1),
      ),
      AdminStudentRecord(
        studentId: 'STU-HW-B',
        fullName: 'Bini School B',
        grade: 'Grade 4',
        className: 'Grade 4A',
        schoolId: 'SCH-B',
        dateOfBirth: DateTime(2016, 2, 2),
      ),
    ]);

    signIn('SCH-A');
    SchoolDataService.instance.addHomework(
      className: 'Grade 4A',
      subject: 'Mathematics',
      description: 'School A only — fractions',
      teacherName: 'Teacher A',
      teacherId: 'TCH-SCH-A',
    );

    final schoolA = SchoolDataService.instance.getHomeworkForClass('Grade 4A');
    expect(
      schoolA.any((h) => h.description.contains('School A only')),
      isTrue,
    );
    expect(schoolA.first.schoolId, 'SCH-A');

    signIn('SCH-B');
    final schoolB = SchoolDataService.instance.getHomeworkForClass('Grade 4A');
    expect(
      schoolB.any((h) => h.description.contains('School A only')),
      isFalse,
    );
    expect(
      SchoolDataService.instance.homeworkForSchool('SCH-B').any(
        (h) => h.description.contains('School A only'),
      ),
      isFalse,
    );
  });

  test('posted homework is in the school list without a page reload', () {
    signIn('SCH-LIVE');
    var notified = false;
    void onSync() => notified = true;
    SchoolContentSyncService.instance.addListener(onSync);
    addTearDown(() {
      SchoolContentSyncService.instance.removeListener(onSync);
    });

    SchoolDataService.instance.addHomework(
      className: 'Grade 2B',
      subject: 'English',
      description: 'Visible immediately',
      teacherName: 'Teacher Live',
      teacherId: 'TCH-SCH-LIVE',
    );

    expect(notified, isTrue);
    expect(
      SchoolDataService.instance
          .getHomeworkForClass('Grade 2B')
          .any((h) => h.description == 'Visible immediately'),
      isTrue,
    );
  });

  test('homework maps keep the school id for cloud writes', () {
    final item = HomeworkItem(
      id: 'hw-scope',
      className: 'Grade 4A',
      subject: 'Math',
      description: 'Scoped',
      teacherName: 'A',
      teacherId: 'T1',
      schoolId: 'SCH-A',
      postedAt: DateTime.utc(2026, 10, 10),
    );
    expect(item.toMap()['schoolId'], 'SCH-A');
    expect(HomeworkItemPersistence.fromMap(item.toMap()).schoolId, 'SCH-A');
  });
}
