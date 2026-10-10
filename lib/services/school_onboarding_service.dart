import 'package:mayabela/models/lesson_plan_models.dart';
import 'package:mayabela/models/message.dart';
import 'package:mayabela/models/school_onboarding_checklist.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/golive_service.dart';
import 'package:mayabela/services/lesson_plan_service.dart';
import 'package:mayabela/services/school_admin_credentials_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/services/transport_service.dart';

/// Live score from creating a school through daily use and go-live.
class SchoolOnboardingService {
  SchoolOnboardingService._();
  static final instance = SchoolOnboardingService._();

  SchoolOnboardingChecklist forSchool(SchoolRecord school) {
    EnrollmentService.instance.ensureSeeded();
    final creds = SchoolAdminCredentialsService.instance;
    final schoolId = school.id.trim().toUpperCase();
    final classes = _classNamesFor(schoolId);
    final data = SchoolDataService.instance;
    final golive = GoliveService.instance;

    final hasLogo =
        (school.displayLogoPath?.isNotEmpty == true) ||
        (school.displayLogoUrl?.isNotEmpty == true);
    final hasAdminPhone =
        creds.adminPhoneForSchool(school)?.trim().isNotEmpty == true;
    final hasPassword = creds.schoolHasPassword(school);
    final adminEmail = creds.adminEmailForSchool(school)?.trim() ?? '';
    final adminName = creds.adminNameForSchool(school)?.trim() ?? '';
    final students = StudentRegistryService.instance.studentsForSchool(schoolId);
    final teachers = TeacherRegistryService.instance.teachersForSchool(schoolId);
    final parentCount = EnrollmentService.instance
        .approvedForSchool(schoolId)
        .length;
    final teacherAssigned = teachers.any((t) => t.classAssignments.isNotEmpty);
    final buses = TransportService.instance.busesForSchool(schoolId);

    final attendanceDone = data.attendanceSnapshot().any(
      (s) => _classMatches(s.className, classes),
    );
    final homeworkDone = data.homeworkSnapshot().any(
      (h) => _classMatches(h.className, classes),
    );
    final galleryDone = data.gallerySnapshot().any(
      (p) => _classMatches(p.className, classes),
    );
    final activityDone = data.dailyActivitiesSnapshot().any(
      (a) =>
          _classMatches(a.className, classes) ||
          students.any(
            (s) =>
                s.studentId.trim().toUpperCase() ==
                a.studentId.trim().toUpperCase(),
          ),
    );
    final gradeEntered = data.gradeReportsSnapshot().any(
      (r) =>
          r.subjects.isNotEmpty &&
          (_classMatches(r.className, classes) ||
              students.any(
                (s) =>
                    (r.studentId ?? '').trim().toUpperCase() ==
                    s.studentId.trim().toUpperCase(),
              )),
    );
    final reportPublished = data.gradeReportsSnapshot().any(
      (r) =>
          r.reportCardPublished &&
          (_classMatches(r.className, classes) ||
              students.any(
                (s) =>
                    (r.studentId ?? '').trim().toUpperCase() ==
                    s.studentId.trim().toUpperCase(),
              )),
    );
    final lessonPublished = LessonPlanService.instance
        .forSchool(schoolId)
        .any((p) => p.status == LessonPlanStatus.published);
    final calendarDone = data
        .getVisibleCalendarEvents(includeEthiopian: false)
        .isNotEmpty;
    final announcementDone = data.getAnnouncements().isNotEmpty;
    final messagesDone = _hasSchoolMessage(
      schoolId: schoolId,
      teachers: teachers,
    );
    final mfaDone = golive.mfaEnrolledCount(schoolId) > 0;
    final backupDone = golive.lastBackupAt(schoolId) != null;
    final dryRunDone = golive.signOffForSchool(schoolId).dryRunComplete;

    final phases = <SchoolScorePhase>[
      SchoolScorePhase(
        key: 'create',
        title: '1. Create school',
        summary: 'Identity, year, grades, and an active subscription.',
        steps: [
          _step(
            'school_named',
            'School name saved',
            school.name.trim().isNotEmpty,
            'School record has a display name',
            'create',
          ),
          _step(
            'logo',
            'School logo uploaded',
            hasLogo,
            'Logo file or cloud URL on the school profile',
            'create',
          ),
          _step(
            'academic_year',
            'Academic year set',
            (school.academicYear ?? '').trim().isNotEmpty,
            'Academic year field on the school record',
            'create',
          ),
          _step(
            'grade_levels',
            'Grade levels defined',
            school.gradeLevels.isNotEmpty,
            'At least one grade in the school catalog',
            'create',
          ),
          _step(
            'campus',
            'City or campus recorded',
            (school.city ?? '').trim().isNotEmpty || school.campuses.isNotEmpty,
            'City and/or campus list on the school record',
            'create',
          ),
          _step(
            'live',
            'School is active',
            school.isAccessible,
            'Not inactive, suspended, or past subscription expiry',
            'create',
          ),
        ],
      ),
      SchoolScorePhase(
        key: 'admin',
        title: '2. Admin access',
        summary: 'The first school administrator can sign in.',
        steps: [
          _step(
            'admin',
            'Admin password saved',
            hasPassword,
            'Temporary or saved admin password on file',
            'admin',
          ),
          _step(
            'admin_phone',
            'Admin phone on file',
            hasAdminPhone,
            'Admin contact phone for login and reset',
            'admin',
          ),
          _step(
            'admin_email',
            'Admin email on file',
            adminEmail.isNotEmpty,
            'Admin email used for credentials and resets',
            'admin',
          ),
          _step(
            'admin_name',
            'Admin name saved',
            adminName.isNotEmpty,
            'Named school administrator, not a blank role',
            'admin',
          ),
        ],
      ),
      SchoolScorePhase(
        key: 'people',
        title: '3. People and classes',
        summary: 'Teachers, students, parents, and class structure.',
        steps: [
          _step(
            'teachers',
            'First teacher registered',
            teachers.isNotEmpty,
            'Active teacher in the school registry',
            'people',
          ),
          _step(
            'teacher_assigned',
            'Teacher assigned to a class',
            teacherAssigned,
            'At least one class assignment on a teacher',
            'people',
          ),
          _step(
            'students',
            'First student enrolled',
            students.isNotEmpty,
            'Active student billed to this school',
            'people',
          ),
          _step(
            'parents',
            'First parent linked',
            parentCount > 0,
            'Approved parent–student link for this school',
            'people',
          ),
          _step(
            'terms',
            'Academic terms defined',
            school.academicTerms.isNotEmpty,
            'At least one term on the school calendar',
            'people',
          ),
          _step(
            'sections',
            'Class section created',
            school.sections.isNotEmpty || classes.isNotEmpty,
            'Section labels or a class name from roster/assignments',
            'people',
          ),
        ],
      ),
      SchoolScorePhase(
        key: 'daily',
        title: '4. Daily loop',
        summary: 'Attendance, homework, messages, and notices in use.',
        steps: [
          _step(
            'attendance',
            'Attendance taken',
            attendanceDone,
            'A saved register for a class of this school',
            'daily',
          ),
          _step(
            'homework',
            'Homework assigned',
            homeworkDone,
            'A homework item posted to a school class',
            'daily',
          ),
          _step(
            'messages',
            'Messages used',
            messagesDone,
            'A parent or teacher thread that belongs to this school',
            'daily',
          ),
          _step(
            'announcements',
            'Announcement published',
            announcementDone,
            'At least one school announcement on the desk',
            'daily',
          ),
          _step(
            'calendar',
            'Calendar event added',
            calendarDone,
            'A non-holiday calendar event (school or class)',
            'daily',
          ),
        ],
      ),
      SchoolScorePhase(
        key: 'academics',
        title: '5. Academics',
        summary: 'Plans, daily activity, grades, and report cards.',
        steps: [
          _step(
            'lesson_plan',
            'Lesson plan published',
            lessonPublished,
            'A published lesson plan with this school id',
            'academics',
          ),
          _step(
            'daily_activity',
            'Daily activity saved',
            activityDone,
            'A daily activity for a student or class of this school',
            'academics',
          ),
          _step(
            'grades',
            'Grades entered',
            gradeEntered,
            'A grade report with subjects for a school student/class',
            'academics',
          ),
          _step(
            'report_card',
            'Report card published',
            reportPublished,
            'A report card marked published for a school student',
            'academics',
          ),
        ],
      ),
      SchoolScorePhase(
        key: 'campus',
        title: '6. Campus operations',
        summary: 'Gallery, transport, and parent-facing media.',
        steps: [
          _step(
            'gallery',
            'Gallery post published',
            galleryDone,
            'A gallery item on a class of this school',
            'campus',
          ),
          _step(
            'transport',
            'Bus or driver registered',
            buses.isNotEmpty,
            'A bus assigned to this school (or a school driver)',
            'campus',
          ),
        ],
      ),
      SchoolScorePhase(
        key: 'golive',
        title: '7. Go-live',
        summary: 'Security, backup, and signed dry-run.',
        steps: [
          _step(
            'mfa',
            'Authenticator enrolled',
            mfaDone,
            'At least one MFA enrollment for this school',
            'golive',
          ),
          _step(
            'backup',
            'School snapshot taken',
            backupDone,
            'A go-live backup record for this school',
            'golive',
          ),
          _step(
            'dry_run',
            'Live dry-run signed off',
            dryRunDone,
            'Every go-live dry-run item marked pass',
            'golive',
          ),
        ],
      ),
    ];

    return SchoolOnboardingChecklist(
      schoolId: school.id,
      phases: phases,
      steps: [for (final phase in phases) ...phase.steps],
    );
  }

  SchoolOnboardingStep _step(
    String key,
    String label,
    bool done,
    String parameter,
    String phaseKey,
  ) {
    return SchoolOnboardingStep(
      key: key,
      label: label,
      done: done,
      parameter: parameter,
      phaseKey: phaseKey,
    );
  }

  Set<String> _classNamesFor(String schoolId) {
    final names = <String>{};
    for (final student in StudentRegistryService.instance.studentsForSchool(
      schoolId,
    )) {
      final className = student.className.trim();
      if (className.isNotEmpty) names.add(className);
    }
    for (final teacher in TeacherRegistryService.instance.teachersForSchool(
      schoolId,
    )) {
      for (final assignment in teacher.classAssignments) {
        final className = assignment.className.trim();
        if (className.isNotEmpty) names.add(className);
      }
    }
    return names;
  }

  bool _classMatches(String className, Set<String> schoolClasses) {
    final value = className.trim();
    if (value.isEmpty || schoolClasses.isEmpty) return false;
    for (final name in schoolClasses) {
      if (StudentRegistryService.classNamesMatch(name, value)) return true;
    }
    return false;
  }

  bool _hasSchoolMessage({
    required String schoolId,
    required List<AdminTeacherRecord> teachers,
  }) {
    final parentUsernames = EnrollmentService.instance
        .approvedForSchool(schoolId)
        .map((link) => link.parentUsername.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet();
    final staffIds = {
      for (final teacher in teachers)
        StaffMemberOption.teacherKey(teacher.teacherId).toLowerCase(),
    };
    for (final chat in SchoolDataService.instance.getConversations()) {
      for (final username in chat.parentParticipantUsernames) {
        if (parentUsernames.contains(username.trim().toLowerCase())) {
          return true;
        }
      }
      final staff = chat.staffParticipantId?.trim().toLowerCase() ?? '';
      final peer = chat.counterpartyStaffId?.trim().toLowerCase() ?? '';
      if (staffIds.contains(staff) || staffIds.contains(peer)) return true;
    }
    return false;
  }
}
