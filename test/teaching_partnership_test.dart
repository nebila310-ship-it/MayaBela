import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/class_timetable.dart';
import 'package:mayabela/models/cloud/app_data_maps.dart';
import 'package:mayabela/models/conference_models.dart';
import 'package:mayabela/models/curriculum_models.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/conference_service.dart';
import 'package:mayabela/services/curriculum_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/timetable_service.dart';
import 'package:mayabela/widgets/announcements_ui.dart';
import 'package:mayabela/widgets/parent_unit_pack.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schoolId = 'TP-001';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = RegisteredUser(
      username: 'homeroom.tp',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: schoolId,
      fullName: 'Ms Homeroom',
      linkedTeacherId: 'TCH-TP',
    );
    ConferenceService.instance.resetForTests();
    CurriculumService.resetForTests();
    TimetableService.instance.resetForTests();
    NotificationService.instance.resetForTests();
  });

  tearDown(() {
    AuthService.currentUser = null;
    ConferenceService.instance.resetForTests();
    CurriculumService.resetForTests();
    TimetableService.instance.resetForTests();
  });

  test('phase 1 conference pack books a slot and writes home actions', () async {
    final svc = ConferenceService.instance;
    final window = await svc.createWindow(
      className: 'Grade 4A',
      heldOn: '2026-11-27',
      venue: 'Homeroom',
      startTime: '16:00',
      slotMinutes: 15,
      slotCount: 3,
      schoolId: schoolId,
    );
    expect(window.openCount, 3);
    expect(window.slots.first.startsAt, '16:00');
    expect(window.slots[1].startsAt, '16:15');

    final booked = await svc.bookSlot(
      windowId: window.id,
      slotId: window.slots.first.id,
      studentId: 'STU-41',
      studentName: 'Ada',
      parentName: 'Parent Ada',
    );
    expect(booked?.status, ConferenceSlotStatus.booked);
    expect(svc.slotsForStudent('STU-41').length, 1);

    SchoolDataService.instance.addHomework(
      className: 'Grade 4A',
      subject: 'Math',
      description: 'Times tables',
      teacherName: 'Ms Homeroom',
      teacherId: 'TCH-TP',
      dueDate: DateTime(2020, 1, 1),
    );
    final homework = SchoolDataService.instance.homeworkSnapshot().firstWhere(
      (item) => item.description == 'Times tables',
    );
    SchoolDataService.instance.setHomeworkCompletion(
      homeworkId: homework.id,
      studentId: 'STU-41',
      status: HomeworkCompletion.missing,
    );

    final closed = await svc.completeSlot(
      windowId: window.id,
      slotId: window.slots.first.id,
      teacherNotes: 'Practise number bonds.',
      homeActions: 'Ten minutes of cards each evening.',
    );
    expect(closed?.status, ConferenceSlotStatus.completed);
    expect(closed?.homeActions, contains('Ten minutes'));
    expect(closed?.packSummary, contains('homework gap'));
  });

  test('phase 2 homework completion round-trips and parent help notes persist', () {
    SchoolDataService.instance.addHomework(
      className: 'Grade 4A',
      subject: 'Science',
      description: 'Leaf rubbing',
      teacherName: 'Ms Homeroom',
      teacherId: 'TCH-TP',
    );
    final item = SchoolDataService.instance.homeworkSnapshot().firstWhere(
      (hw) => hw.description == 'Leaf rubbing',
    );
    expect(item.completionFor('STU-41'), HomeworkCompletion.notStarted);

    SchoolDataService.instance.setHomeworkCompletion(
      homeworkId: item.id,
      studentId: 'stu-41',
      status: HomeworkCompletion.late,
    );
    expect(item.completionFor('STU-41'), HomeworkCompletion.late);

    SchoolDataService.instance.setParentHelpNote(
      homeworkId: item.id,
      studentId: 'STU-41',
      note: 'We collected leaves in the garden.',
    );
    expect(item.helpNoteFor('STU-41'), contains('garden'));

    final again = HomeworkItemPersistence.fromMap(item.toMap());
    expect(again.completionFor('STU-41'), HomeworkCompletion.late);
    expect(again.helpNoteFor('STU-41'), contains('garden'));
  });

  test('phase 3 weekly class letter stays a letter after persist', () {
    final letter = SchoolDataService.instance.postClassLetter(
      className: 'Grade 4A',
      author: 'Ms Homeroom',
      title: 'Week of 23 Nov',
      body: 'We finished the water cycle.',
      weekOf: '2026-11-23',
      nextWeekFocus: 'States of matter',
      whatToBring: 'A clear bottle',
    );
    expect(letter.isClassLetter, isTrue);
    expect(letter.audienceKeys, contains(AnnouncementAudiences.parents));
    expect(
      SchoolDataService.instance.classLettersFor('Grade 4A').first.title,
      'Week of 23 Nov',
    );

    final map = AppDataMaps.announcementToMap(letter);
    final again = AppDataMaps.announcementFromMap(map);
    expect(again.isClassLetter, isTrue);
    expect(again.nextWeekFocus, 'States of matter');
    expect(again.whatToBring, 'A clear bottle');
    expect(again.className, 'Grade 4A');
  });

  test('phase 4 parent-facing unit publishes goals and help at home', () async {
    final unit = await CurriculumService.instance.upsertParentPack(
      className: 'Grade 4A',
      subject: 'Science',
      title: 'Water cycle',
      objectives: 'Name the four stages.',
      assessmentSummary: 'Oral quiz Friday',
      helpAtHome: 'Ask what happens to puddles on a sunny day.',
      homeLearning: 'Draw the cycle once.',
    );
    expect(unit.isPublished, isTrue);
    expect(unit.helpAtHome, contains('puddles'));
    expect(
      CurriculumService.instance.publishedForClass('Grade 4A').first.title,
      'Water cycle',
    );

    final again = CurriculumUnit.fromMap(unit.toMap());
    expect(again.assessmentSummary, 'Oral quiz Friday');
    expect(again.homeLearning, contains('Draw'));
  });

  test('phase 5 cover notes persist and notify the class', () {
    final original = ClassTimetable(
      className: 'Grade 4A',
      homeroomTeacherId: 'TCH-TP',
      homeroomTeacherName: 'Ms Homeroom',
      updatedAt: DateTime.utc(2026, 11, 1),
      days: {
        'monday': DayTimetable(
          dayKey: 'monday',
          slots: [
            TimetableSlot(
              id: 'slot-math',
              kind: TimetableSlotKind.lesson,
              subject: 'Mathematics',
              teacherName: 'Ms Homeroom',
            ),
          ],
        ),
      },
    );
    TimetableService.instance.saveTimetable(original);

    final covered = original.copyWith(
      days: {
        'monday': DayTimetable(
          dayKey: 'monday',
          slots: [
            original.day('monday').slots.first.copyWith(
                  substituteTeacherId: 'TCH-COVER',
                  substituteTeacherName: 'Mr Cover',
                  homeworkStands: true,
                  coverNote: 'Bring the workbook as usual.',
                ),
          ],
        ),
      },
    );
    TimetableService.instance.saveTimetable(covered);

    final stored = TimetableService.instance.getOrCreateForClass('Grade 4A');
    final slot = stored.day('monday').slots.first;
    expect(slot.hasCover, isTrue);
    expect(slot.homeworkStands, isTrue);
    expect(slot.coverNote, contains('workbook'));

    final map = AppDataMaps.classTimetableToMap(stored);
    final again = AppDataMaps.classTimetableFromMap(map);
    expect(again.day('monday').slots.first.coverNote, contains('workbook'));

    final notes = NotificationService.instance.itemsForTests();
    expect(
      notes.any((n) => n.title.contains('Timetable change')),
      isTrue,
    );
  });

  testWidgets('class letter chip and parent unit pack render on the desks', (
    tester,
  ) async {
    final letter = Announcement(
      id: 'a1',
      title: 'Week of 23 Nov',
      body: 'We finished the water cycle.',
      author: 'Ms Homeroom',
      date: DateTime(2026, 11, 23),
      audienceKeys: const [AnnouncementAudiences.parents],
      kind: 'letter',
      className: 'Grade 4A',
      weekOf: '2026-11-23',
    );
    final unit = CurriculumUnit(
      id: 'cu1',
      schoolId: schoolId,
      title: 'Water cycle',
      subject: 'Science',
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
      objectives: 'Name the four stages.',
      assessmentSummary: 'Oral quiz Friday',
      helpAtHome: 'Talk about rain.',
      status: CurriculumUnitStatus.published,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              AnnouncementCard(
                announcement: letter,
                onTap: () {},
                audienceLabelBuilder: (key) => key,
                dateLabel: '23/11/2026',
              ),
              ParentUnitPackCard(
                unit: unit,
                accent: const Color(0xFF5D4037),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.textContaining('Class letter'), findsOneWidget);
    expect(find.text('How you can help'), findsOneWidget);
    expect(find.text('Coming assessment'), findsOneWidget);
  });
}
