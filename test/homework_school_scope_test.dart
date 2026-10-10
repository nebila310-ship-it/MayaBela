import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_content_sync_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
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

  test('new school hides leftover posts from teachers it does not have', () {
    SchoolRegistryService.instance.upsertSchool(
      SchoolRecord(
        id: 'SCH-NEW',
        name: 'Majestic Smart Academy',
        registeredAt: DateTime(2026, 10, 10),
        sections: const ['Grade 1A', 'Grade 2A'],
      ),
    );
    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: 'STU-NEW-1',
        fullName: 'Kid New',
        grade: 'Grade 1',
        className: 'Grade 1A',
        schoolId: 'SCH-NEW',
        dateOfBirth: DateTime(2018, 1, 1),
      ),
    ]);
    SchoolDataService.instance.applyPersistedHomework([
      HomeworkItem(
        id: 'hw-ghost-yared',
        className: 'Grade 1A',
        subject: 'Civics',
        description: 'please do this worksheet',
        teacherName: 'Yared',
        teacherId: 'TCH-YARED',
        postedAt: DateTime(2026, 7, 30, 15, 13),
      ),
      HomeworkItem(
        id: 'hw-ghost-kaleb',
        className: 'Grade 1A',
        subject: 'English',
        description: 'Old English homework',
        teacherName: 'Mr Kaleb',
        teacherId: 'TCH-KALEB',
        postedAt: DateTime(2026, 6, 28, 16, 45),
      ),
      HomeworkItem(
        id: 'hw-ghost-stamped',
        className: 'Grade 1A',
        subject: 'Civics',
        description: 'Leftover stamped with this school id',
        teacherName: 'Josiah Yared',
        teacherId: 'TCH-YARED',
        schoolId: 'SCH-NEW',
        postedAt: DateTime(2026, 7, 30, 15, 13),
      ),
      HomeworkItem(
        id: 'hw-ghost-today',
        className: 'Grade 1A',
        subject: 'English',
        description: 'Same-day leftover from another campus',
        teacherName: 'Yared H/michael',
        teacherId: 'TCH-YARED',
        postedAt: DateTime(2026, 10, 10, 6, 7),
      ),
    ]);

    signIn('SCH-NEW');
    final items = SchoolDataService.instance.getHomeworkForClass('Grade 1A');
    expect(items.any((h) => h.teacherName.contains('Yared')), isFalse);
    expect(items.any((h) => h.teacherName.contains('Kaleb')), isFalse);
    expect(items.any((h) => h.description.contains('worksheet')), isFalse);
    expect(items.any((h) => h.id.startsWith('hw-ghost-')), isFalse);

    SchoolDataService.instance.addHomework(
      className: 'Grade 1A',
      subject: 'Mathematics',
      description: 'Posted today by this school',
      teacherName: 'Teacher SCH-NEW',
      teacherId: 'TCH-SCH-NEW',
    );
    expect(
      SchoolDataService.instance
          .getHomeworkForClass('Grade 1A')
          .any((h) => h.description == 'Posted today by this school'),
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
