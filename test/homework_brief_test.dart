import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/web_erp/pages/web_homework_page.dart';
import 'package:mayabela/widgets/homework_brief_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = RegisteredUser(
      username: 'teacher.brief',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'HW-BRIEF',
      fullName: 'Brief Teacher',
      linkedTeacherId: 'TCH-BRIEF',
    );
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  test('an international brief round-trips and applies to the class', () {
    SchoolDataService.instance.addHomework(
      className: 'Grade 6A',
      subject: 'Science',
      description: 'Draw and label the water cycle.',
      teacherName: 'Brief Teacher',
      teacherId: 'TCH-BRIEF',
      title: 'Water cycle diagram',
      taskType: HomeworkTaskTypes.inquiry,
      learningObjective: 'Explain how water moves through the cycle.',
      successCriteria: 'Four stages are labelled in the right order.',
      estimatedMinutes: 30,
      submissionMethod: HomeworkSubmissionMethods.online,
      resources: 'Textbook pages 40–42',
      supportNote: 'Use the word bank on the board.',
      extensionNote: 'Add one human impact on the cycle.',
      maxScore: 20,
      dueDate: DateTime(2026, 10, 20, 16, 0),
    );

    final posted = SchoolDataService.instance
        .homeworkForSchool('HW-BRIEF')
        .firstWhere((item) => item.title == 'Water cycle diagram');
    expect(posted.displayTitle, 'Water cycle diagram');
    expect(posted.taskType, HomeworkTaskTypes.inquiry);
    expect(posted.estimatedMinutes, 30);
    expect(posted.scoreCap, 20);
    expect(posted.learningObjective, contains('water moves'));

    final again = HomeworkItemPersistence.fromMap(posted.toMap());
    expect(again.title, posted.title);
    expect(again.successCriteria, posted.successCriteria);
    expect(again.supportNote, posted.supportNote);
    expect(again.extensionNote, posted.extensionNote);
    expect(again.resources, posted.resources);
    expect(again.submissionMethod, HomeworkSubmissionMethods.online);
    expect(again.maxScore, 20);
    expect(again.dueDate?.hour, 16);

    SchoolDataService.instance.recordHomeworkScore(
      homeworkId: posted.id,
      studentId: 'STU-1',
      score: 40,
    );
    expect(posted.studentScores['STU-1'], 20);
  });

  testWidgets('the homework card shows the objective and the time', (tester) async {
    final item = HomeworkItem(
      id: 'hw-card',
      className: 'Year 7',
      subject: 'English',
      description: 'Write the opening paragraph.',
      teacherName: 'Ms Abebe',
      teacherId: 'TCH-1',
      postedAt: DateTime(2026, 10, 14, 9),
      title: 'Opening paragraph',
      taskType: HomeworkTaskTypes.practice,
      learningObjective: 'Hook the reader in the first three sentences.',
      estimatedMinutes: 20,
      submissionMethod: HomeworkSubmissionMethods.inClass,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeworkBriefSections(item: item),
        ),
      ),
    );

    expect(find.text('Opening paragraph'), findsOneWidget);
    expect(find.text('Hook the reader in the first three sentences.'), findsOneWidget);
    expect(
      find.text(AppLocale.instance.strings.homeworkMinutes(20)),
      findsOneWidget,
    );
    expect(find.text('Practice'), findsOneWidget);
    expect(find.text('Bring to class'), findsOneWidget);
  });

  testWidgets('the homework desk filters and opens a task', (tester) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    AuthService.currentUser = RegisteredUser(
      username: 'admin.brief',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'HW-DESK',
      fullName: 'Desk Admin',
    );
    final soon = DateTime.now().add(const Duration(days: 1));
    final late = DateTime.now().subtract(const Duration(days: 1));
    SchoolDataService.instance.addHomework(
      className: 'Year 8',
      subject: 'History',
      description: 'Read the source and write three points.',
      teacherName: 'Desk Admin',
      teacherId: 'admin.brief',
      title: 'Source reading',
      learningObjective: 'Identify the writer’s purpose.',
      dueDate: soon,
    );
    SchoolDataService.instance.addHomework(
      className: 'Year 8',
      subject: 'History',
      description: 'Finish the timeline.',
      teacherName: 'Desk Admin',
      teacherId: 'admin.brief',
      title: 'Late timeline',
      dueDate: late,
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WebHomeworkPage())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Homework desk'), findsOneWidget);
    expect(find.text('Source reading'), findsOneWidget);
    expect(find.text('Late timeline'), findsOneWidget);
    expect(find.text('Identify the writer’s purpose.'), findsOneWidget);

    await tester.tap(find.text('Due soon'));
    await tester.pumpAndSettle();
    expect(find.text('Source reading'), findsOneWidget);
    expect(find.text('Late timeline'), findsNothing);

    await tester.tap(find.text('Overdue'));
    await tester.pumpAndSettle();
    expect(find.text('Late timeline'), findsOneWidget);
    expect(find.text('Source reading'), findsNothing);
  });
}
