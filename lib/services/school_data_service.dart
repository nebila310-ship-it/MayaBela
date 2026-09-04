import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mayabela/constants/school_subjects.dart';
import 'package:mayabela/database/id_utils.dart';
import 'package:mayabela/database/models/database_models.dart';
import 'package:mayabela/database/school_database_service.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/models/bus_route.dart';
import 'package:mayabela/models/calendar_event.dart';
import 'package:mayabela/models/fee_record.dart';
import 'package:mayabela/models/message.dart';
import 'package:mayabela/models/school_class.dart';
import 'package:mayabela/models/student_conduct.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/admin_registry_service.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/ethiopian_holiday_catalog.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/messaging_access_service.dart';
import 'package:mayabela/services/parent_messaging_policy.dart';
import 'package:mayabela/services/transport_service.dart';
import 'package:mayabela/services/persistence/daily_activity_persistence_service.dart';
import 'package:mayabela/services/persistence/grade_persistence_service.dart';
import 'package:mayabela/services/persistence/homework_persistence_service.dart';
import 'package:mayabela/services/persistence/learning_materials_persistence_service.dart';
import 'package:mayabela/services/persistence/message_persistence_service.dart';
import 'package:mayabela/services/persistence/school_content_persistence_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/models/grade_workflow.dart';
import 'package:mayabela/models/markbook.dart';
import 'package:mayabela/services/grade_audit_service.dart';
import 'package:mayabela/services/grade_workflow_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/school_auth_cloud_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/utils/phone_utils.dart';
/// Mock data layer — replace method bodies with API calls when backend is ready.
class SchoolDataService {
  SchoolDataService._() {
    _applyDemoGradeAttachments();
  }
  static final instance = SchoolDataService._();

  int _nextAnnouncementId = 4;
  int _nextHomeworkId = 3;
  int _nextGalleryId = 3;
  int _nextLearningMaterialId = 1;
  int _nextActivityId = 2;
  final Set<String> _busArrivalNotified = {};
  final Map<String, StudentConductRating> _studentConduct = {};

  final List<Conversation> _conversations = [
    Conversation(
      id: '1',
      name: 'Mr. Bekele',
      role: 'Parent',
      parentParticipantName: 'Mr. Bekele',
      staffParticipantId: StaffMemberOption.teacherKey('TCH-1001'),
      staffSubjectName: 'Homeroom',
      linkedStudentIds: const ['STU-1001'],
      parentParticipantUsernames: const ['parent'],
      unread: 2,
      messages: [
        ChatMessage(
          text: 'Good morning, is Sara coming to school today?',
          senderRole: AuthService.roleParent,
          senderDisplayName: 'Mr. Bekele',
          senderUsername: 'parent',
          time: DateTime.now().subtract(const Duration(hours: 3)),
          seenAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 50)),
        ),
        ChatMessage(
          text: 'Yes, she will be on time.',
          senderRole: AuthService.roleTeacher,
          senderStaffId: StaffMemberOption.teacherKey('TCH-1001'),
          senderDisplayName: 'Miss Belen',
          time: DateTime.now().subtract(const Duration(hours: 2, minutes: 45)),
        ),
        ChatMessage(
          text: 'Thank you! Also, can you share today\'s homework?',
          senderRole: AuthService.roleParent,
          senderDisplayName: 'Mr. Bekele',
          senderUsername: 'parent',
          time: DateTime.now().subtract(const Duration(minutes: 30)),
        ),
      ],
    ),
    Conversation(
      id: '2',
      name: 'Miss Belen',
      role: 'Teacher',
      staffParticipantId: StaffMemberOption.teacherKey('TCH-1001'),
      counterpartyStaffId: StaffMemberOption.adminKey('ADM-1001'),
      unread: 0,
      messages: [
        ChatMessage(
          text: 'Staff meeting tomorrow at 2 PM.',
          senderRole: AuthService.roleAdmin,
          senderStaffId: StaffMemberOption.adminKey('ADM-1001'),
          senderDisplayName: 'School Admin',
          time: DateTime.now().subtract(const Duration(days: 1)),
          seenAt: DateTime.now().subtract(const Duration(hours: 22)),
        ),
        ChatMessage(
          text: 'Noted, I will attend.',
          senderRole: AuthService.roleTeacher,
          senderStaffId: StaffMemberOption.teacherKey('TCH-1001'),
          senderDisplayName: 'Miss Belen',
          time: DateTime.now().subtract(const Duration(hours: 20)),
        ),
      ],
    ),
    Conversation(
      id: '3',
      name: 'Miss Hana',
      role: 'Teacher',
      staffParticipantId: StaffMemberOption.teacherKey('TCH-1002'),
      counterpartyStaffId: StaffMemberOption.adminKey('ADM-1001'),
      unread: 1,
      messages: [
        ChatMessage(
          text: 'Can we coordinate the Grade 4 field trip?',
          senderRole: AuthService.roleTeacher,
          senderStaffId: StaffMemberOption.teacherKey('TCH-1002'),
          senderDisplayName: 'Miss Hana',
          time: DateTime.now().subtract(const Duration(hours: 5)),
        ),
      ],
    ),
    Conversation(
      id: '4',
      name: 'Transport Team',
      role: 'Driver',
      staffParticipantId: StaffMemberOption.driverKey('DRV-1001'),
      counterpartyStaffId: StaffMemberOption.adminKey('ADM-1001'),
      unread: 0,
      messages: [
        ChatMessage(
          text: 'Route Bole starts 15 minutes earlier tomorrow.',
          senderRole: AuthService.roleAdmin,
          senderStaffId: StaffMemberOption.adminKey('ADM-1001'),
          senderDisplayName: 'School Admin',
          time: DateTime.now().subtract(const Duration(hours: 8)),
          seenAt: DateTime.now().subtract(const Duration(hours: 7)),
        ),
      ],
    ),
  ];

  final Map<String, List<StudentRef>> _classRosters = {
    'Grade 4A': [
      StudentRef(
        id: 'sara-bekele',
        registryStudentId: 'STU-1001',
        name: 'Sara Bekele',
        grade: '4A',
        parentName: 'Mr. Bekele',
      ),
      StudentRef(
        id: 'daniel-tesfaye',
        registryStudentId: 'STU-1003',
        name: 'Daniel Tesfaye',
        grade: '4A',
        parentName: 'Mrs. Tesfaye',
      ),
      StudentRef(
        id: 'hanna-girma',
        registryStudentId: 'STU-1004',
        name: 'Hanna Girma',
        grade: '4A',
        parentName: 'Mr. Girma',
      ),
      StudentRef(
        id: 'yonas-mekonnen',
        name: 'Yonas Mekonnen',
        grade: '4A',
        parentName: 'Mrs. Mekonnen',
      ),
    ],
    'Grade 5B': [
      StudentRef(
        id: 'liya-solomon',
        name: 'Liya Solomon',
        grade: '5B',
        parentName: 'Mr. Solomon',
      ),
      StudentRef(
        id: 'abel-haile',
        name: 'Abel Haile',
        grade: '5B',
        parentName: 'Mrs. Haile',
      ),
      StudentRef(
        id: 'marta-kebede',
        name: 'Marta Kebede',
        grade: '5B',
        parentName: 'Mr. Kebede',
      ),
    ],
  };

  final Map<String, String> _homeroomTeacherIds = {
    'Grade 4A': 'TCH-1001',
    'Grade 5B': 'TCH-1004',
  };

  final Map<String, String> _homeroomTeacherNames = {
    'Grade 4A': 'Miss Belen',
    'Grade 5B': 'Mr. Tadesse',
  };

  final Map<String, String> _classSchedules = {
    'Grade 4A': 'Mon–Fri, 8:00 AM – 3:00 PM',
    'Grade 5B': 'Mon–Fri, 8:00 AM – 3:00 PM',
  };

  final Map<String, String> _classRooms = {
    'Grade 4A': 'Room 12',
    'Grade 5B': 'Room 15',
  };

  /// teacherId → list of (className, role, optional subject)
  final List<Map<String, dynamic>> _teacherAssignments = [
    {
      'teacherId': 'TCH-1001',
      'className': 'Grade 4A',
      'role': ClassTeacherRole.homeroom,
    },
    {
      'teacherId': 'TCH-1001',
      'className': 'Grade 5B',
      'role': ClassTeacherRole.subject,
      'subject': 'Mathematics',
    },
    {
      'teacherId': 'TCH-1002',
      'className': 'Grade 4A',
      'role': ClassTeacherRole.subject,
      'subject': 'English',
    },
    {
      'teacherId': 'TCH-1003',
      'className': 'Grade 4A',
      'role': ClassTeacherRole.subject,
      'subject': 'Science',
    },
    {
      'teacherId': 'TCH-1004',
      'className': 'Grade 5B',
      'role': ClassTeacherRole.homeroom,
    },
    {
      'teacherId': 'TCH-1004',
      'className': 'Grade 5B',
      'role': ClassTeacherRole.subject,
      'subject': 'Amharic',
    },
  ];

  final Map<String, List<ClassSubjectTeacher>> _classSubjectTeachers = {
    'Grade 4A': [
      ClassSubjectTeacher(
        subject: 'Mathematics',
        teacherId: 'TCH-1001',
        teacherName: 'Miss Belen',
      ),
      ClassSubjectTeacher(
        subject: 'English',
        teacherId: 'TCH-1002',
        teacherName: 'Mr. Samuel',
      ),
      ClassSubjectTeacher(
        subject: 'Science',
        teacherId: 'TCH-1003',
        teacherName: 'Miss Hana',
      ),
      ClassSubjectTeacher(
        subject: 'Amharic',
        teacherId: 'TCH-1004',
        teacherName: 'Mr. Tadesse',
      ),
    ],
    'Grade 5B': [
      ClassSubjectTeacher(
        subject: 'Mathematics',
        teacherId: 'TCH-1001',
        teacherName: 'Miss Belen',
      ),
      ClassSubjectTeacher(
        subject: 'English',
        teacherId: 'TCH-1002',
        teacherName: 'Mr. Samuel',
      ),
      ClassSubjectTeacher(
        subject: 'Science',
        teacherId: 'TCH-1003',
        teacherName: 'Miss Hana',
      ),
      ClassSubjectTeacher(
        subject: 'Amharic',
        teacherId: 'TCH-1004',
        teacherName: 'Mr. Tadesse',
      ),
    ],
    'Kindergarten A': [
      ClassSubjectTeacher(
        subject: 'KG - Play & Learning',
        teacherId: 'TCH-1001',
        teacherName: 'Miss Belen',
      ),
      ClassSubjectTeacher(
        subject: 'KG - Early Literacy',
        teacherId: 'TCH-1001',
        teacherName: 'Miss Belen',
      ),
      ClassSubjectTeacher(
        subject: 'KG - Early Numeracy',
        teacherId: 'TCH-1001',
        teacherName: 'Miss Belen',
      ),
      ClassSubjectTeacher(
        subject: 'KG - Social Skills',
        teacherId: 'TCH-1001',
        teacherName: 'Miss Belen',
      ),
    ],
  };

  final List<HomeworkItem> _homework = [
    HomeworkItem(
      id: 'hw-1',
      className: 'Grade 4A',
      subject: 'Mathematics',
      description: 'Complete pages 68–69 (fractions practice)',
      teacherName: 'Miss Belen',
      teacherId: 'TCH-1001',
      postedAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    HomeworkItem(
      id: 'hw-2',
      className: 'Grade 4A',
      subject: 'Science',
      description: 'Read Chapter 4 and answer review questions 1–5',
      teacherName: 'Miss Hana',
      teacherId: 'TCH-1003',
      postedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  final List<LearningMaterialItem> _learningMaterials = [
    LearningMaterialItem(
      id: 'lm-sample-free-4a',
      className: 'Grade 4A',
      subject: 'English',
      bookName: 'Sample Free Reader',
      materialName: 'Unit 1 — Open for everyone (test)',
      filePath: 'asset:assets/branding/maya_brand.png',
      teacherId: 'TCH-1001',
      teacherName: 'Miss Belen',
      postedAt: DateTime.now().subtract(const Duration(days: 2)),
      isFree: true,
    ),
    LearningMaterialItem(
      id: 'lm-sample-paid-4a',
      className: 'Grade 4A',
      subject: 'Mathematics',
      bookName: 'Sample Paid Workbook',
      materialName: 'Fractions pack — locked until paid (test)',
      filePath: 'asset:assets/branding/maya_brand.png',
      teacherId: 'TCH-1001',
      teacherName: 'Miss Belen',
      postedAt: DateTime.now().subtract(const Duration(days: 1)),
      isFree: false,
      price: 150,
    ),
    LearningMaterialItem(
      id: 'lm-sample-paid-4a-sci',
      className: 'Grade 4A',
      subject: 'Science',
      bookName: 'Sample Paid Science Notes',
      materialName: 'Chapter 3 lab guide — locked (test)',
      filePath: 'asset:assets/branding/maya_brand.png',
      teacherId: 'TCH-1003',
      teacherName: 'Miss Hana',
      postedAt: DateTime.now().subtract(const Duration(hours: 20)),
      isFree: false,
      price: 200,
    ),
    LearningMaterialItem(
      id: 'lm-sample-free-2c',
      className: 'Grade 2C',
      subject: 'English',
      bookName: 'Sample Free Alphabet Book',
      materialName: 'Letters A–Z — open for everyone (test)',
      filePath: 'asset:assets/branding/maya_brand.png',
      teacherId: 'TCH-1002',
      teacherName: 'Mr. Samuel',
      postedAt: DateTime.now().subtract(const Duration(days: 3)),
      isFree: true,
    ),
    LearningMaterialItem(
      id: 'lm-sample-paid-2c',
      className: 'Grade 2C',
      subject: 'Science',
      bookName: 'Sample Paid Nature Book',
      materialName: 'Animals around us — locked until paid (test)',
      filePath: 'asset:assets/branding/maya_brand.png',
      teacherId: 'TCH-1002',
      teacherName: 'Mr. Samuel',
      postedAt: DateTime.now().subtract(const Duration(hours: 12)),
      isFree: false,
      price: 120,
    ),
  ];

  /// Inserts missing sample books (safe to call after local/cloud load).
  void ensureSampleLearningMaterials({bool persist = true}) {
    final existing = _learningMaterials.map((e) => e.id).toSet();
    final seeds = <LearningMaterialItem>[
      LearningMaterialItem(
        id: 'lm-sample-free-4a',
        className: 'Grade 4A',
        subject: 'English',
        bookName: 'Sample Free Reader',
        materialName: 'Unit 1 — Open for everyone (test)',
        filePath: 'asset:assets/branding/maya_brand.png',
        teacherId: 'TCH-1001',
        teacherName: 'Miss Belen',
        postedAt: DateTime.now().subtract(const Duration(days: 2)),
        isFree: true,
      ),
      LearningMaterialItem(
        id: 'lm-sample-paid-4a',
        className: 'Grade 4A',
        subject: 'Mathematics',
        bookName: 'Sample Paid Workbook',
        materialName: 'Fractions pack — locked until paid (test)',
        filePath: 'asset:assets/branding/maya_brand.png',
        teacherId: 'TCH-1001',
        teacherName: 'Miss Belen',
        postedAt: DateTime.now().subtract(const Duration(days: 1)),
        isFree: false,
        price: 150,
      ),
      LearningMaterialItem(
        id: 'lm-sample-paid-4a-sci',
        className: 'Grade 4A',
        subject: 'Science',
        bookName: 'Sample Paid Science Notes',
        materialName: 'Chapter 3 lab guide — locked (test)',
        filePath: 'asset:assets/branding/maya_brand.png',
        teacherId: 'TCH-1003',
        teacherName: 'Miss Hana',
        postedAt: DateTime.now().subtract(const Duration(hours: 20)),
        isFree: false,
        price: 200,
      ),
      LearningMaterialItem(
        id: 'lm-sample-free-2c',
        className: 'Grade 2C',
        subject: 'English',
        bookName: 'Sample Free Alphabet Book',
        materialName: 'Letters A–Z — open for everyone (test)',
        filePath: 'asset:assets/branding/maya_brand.png',
        teacherId: 'TCH-1002',
        teacherName: 'Mr. Samuel',
        postedAt: DateTime.now().subtract(const Duration(days: 3)),
        isFree: true,
      ),
      LearningMaterialItem(
        id: 'lm-sample-paid-2c',
        className: 'Grade 2C',
        subject: 'Science',
        bookName: 'Sample Paid Nature Book',
        materialName: 'Animals around us — locked until paid (test)',
        filePath: 'asset:assets/branding/maya_brand.png',
        teacherId: 'TCH-1002',
        teacherName: 'Mr. Samuel',
        postedAt: DateTime.now().subtract(const Duration(hours: 12)),
        isFree: false,
        price: 120,
      ),
    ];
    var added = false;
    for (final seed in seeds) {
      if (existing.contains(seed.id)) continue;
      _learningMaterials.add(seed);
      added = true;
    }
    if (added && persist) {
      _persistLearningMaterials();
    }
  }

  final List<GalleryPost> _galleryPosts = [
    GalleryPost(
      id: 'gal-1',
      className: 'Grade 4A',
      type: GalleryPostType.photo,
      title: 'Science Fair Prep',
      caption: 'Grade 4A students preparing their volcano models.',
      authorName: 'Miss Belen',
      postedAt: DateTime.now().subtract(const Duration(days: 1)),
      mediaLabel: 'class_photo_1.jpg',
      mediaPath: 'asset:assets/branding/maya_brand.png',
    ),
    GalleryPost(
      id: 'gal-2',
      className: 'Grade 4A',
      type: GalleryPostType.note,
      title: 'Weekly Reminder',
      caption: 'Please send sports uniforms on Thursday for PE class.',
      authorName: 'Miss Belen',
      postedAt: DateTime.now().subtract(const Duration(hours: 8)),
    ),
  ];

  final List<DailyActivityReport> _dailyActivities = [
    DailyActivityReport(
      id: 'act-1',
      studentId: 'STU-1001',
      studentName: 'Sara Bekele',
      className: 'Grade 4A',
      date: DateTime.now(),
      selectedOptionIds: ['great_day', 'did_well_test'],
      teacherComment: 'Sara participated actively in group work today.',
      teacherName: 'Miss Belen',
    ),
  ];

  final List<AttendanceSession> _attendanceSessions = [
    AttendanceSession(
      className: 'Grade 4A',
      date: DateTime.now().subtract(const Duration(days: 1)),
      conductedBy: 'Miss Belen',
      entries: [
        StudentAttendanceEntry(
          studentName: 'Sara Bekele',
          status: AttendanceStatus.present,
        ),
        StudentAttendanceEntry(
          studentName: 'Daniel Tesfaye',
          status: AttendanceStatus.present,
        ),
        StudentAttendanceEntry(
          studentName: 'Hanna Girma',
          status: AttendanceStatus.late,
        ),
      ],
    ),
    AttendanceSession(
      className: 'Grade 4A',
      date: DateTime.now(),
      conductedBy: 'Miss Belen',
      entries: [
        StudentAttendanceEntry(
          studentName: 'Sara Bekele',
          status: AttendanceStatus.present,
        ),
        StudentAttendanceEntry(
          studentName: 'Daniel Tesfaye',
          status: AttendanceStatus.absent,
        ),
        StudentAttendanceEntry(
          studentName: 'Hanna Girma',
          status: AttendanceStatus.late,
        ),
      ],
    ),
    AttendanceSession(
      className: 'Grade 5B',
      date: DateTime.now(),
      conductedBy: 'Mr. Samuel',
      entries: [
        StudentAttendanceEntry(
          studentName: 'Liya Solomon',
          status: AttendanceStatus.absent,
        ),
      ],
    ),
    AttendanceSession(
      className: 'Grade 2C',
      date: DateTime.now(),
      conductedBy: 'Mr. Samuel',
      entries: [
        StudentAttendanceEntry(
          studentName: 'Kidus Bekele',
          status: AttendanceStatus.late,
        ),
      ],
    ),
  ];

  final List<ChildProfile> _children = [
    ChildProfile(
      studentId: 'STU-1001',
      name: 'Sara Bekele',
      grade: 'Grade 4',
      className: 'Grade 4A',
      section: 'A',
      teacher: 'Miss Belen',
      attendanceRate: 0.99,
    ),
    ChildProfile(
      studentId: 'STU-1002',
      name: 'Kidus Bekele',
      grade: 'Grade 2',
      className: 'Grade 2C',
      section: 'C',
      teacher: 'Mr. Samuel',
      attendanceRate: 0.88,
    ),
  ];

  final List<Announcement> _announcements = [
    Announcement(
      id: '1',
      title: 'Parent-Teacher Meeting',
      body:
          'Our quarterly parent-teacher meeting is scheduled for Friday at 3 PM in the main hall. All parents are encouraged to attend.',
      author: 'School Admin',
      date: DateTime.now().subtract(const Duration(days: 1)),
      audienceKeys: [AnnouncementAudiences.all],
      isPinned: true,
      priority: AnnouncementPriority.important,
    ),
    Announcement(
      id: '2',
      title: 'Grade 4 Field Trip',
      body:
          'Grade 4 students will visit the Science Museum next Wednesday. Please send permission slips by Monday.',
      author: 'Miss Belen',
      date: DateTime.now().subtract(const Duration(days: 3)),
      audienceKeys: [AnnouncementAudiences.parents],
      priority: AnnouncementPriority.normal,
    ),
    Announcement(
      id: '3',
      title: 'Staff Development Day',
      body:
          'School will be closed this Saturday for staff training. Regular classes resume Monday.',
      author: 'School Admin',
      date: DateTime.now().subtract(const Duration(days: 5)),
      audienceKeys: [
        AnnouncementAudiences.teachers,
        AnnouncementAudiences.transport,
        AnnouncementAudiences.admin,
      ],
      priority: AnnouncementPriority.urgent,
    ),
  ];

  final List<StudentGradeReport> _gradeReports = [
    _grade('Sara Bekele', 'Grade 4A', [
      ('Mathematics', 88),
      ('English', 92),
      ('Science', 85),
      ('Amharic', 90),
    ], studentId: 'STU-1001'),
    _grade('Daniel Tesfaye', 'Grade 4A', [
      ('Mathematics', 76),
      ('English', 80),
      ('Science', 74),
      ('Amharic', 88),
    ], studentId: 'STU-1003'),
    _grade('Hanna Girma', 'Grade 4A', [
      ('Mathematics', 95),
      ('English', 93),
      ('Science', 97),
      ('Amharic', 91),
    ], studentId: 'STU-1004'),
    _grade('Yonas Mekonnen', 'Grade 4A', [
      ('Mathematics', 91),
      ('English', 89),
      ('Science', 90),
      ('Amharic', 88),
    ]),
    _grade('Mimi Assefa', 'Grade 4A', [
      ('Mathematics', 84),
      ('English', 86),
      ('Science', 82),
      ('Amharic', 85),
    ]),
    _grade('Abel Tadesse', 'Grade 4A', [
      ('Mathematics', 42),
      ('English', 38),
      ('Science', 45),
      ('Amharic', 48),
    ]),
    _grade('Selam Worku', 'Grade 4A', [
      ('Mathematics', 35),
      ('English', 40),
      ('Science', 32),
      ('Amharic', 44),
    ]),
    _grade('Bereket Haile', 'Grade 4A', [
      ('Mathematics', 78),
      ('English', 81),
      ('Science', 79),
      ('Amharic', 77),
    ]),
    _grade('Rahel Desta', 'Grade 4A', [
      ('Mathematics', 88),
      ('English', 90),
      ('Science', 87),
      ('Amharic', 89),
    ]),
    _grade('Samuel Fikadu', 'Grade 4A', [
      ('Mathematics', 72),
      ('English', 68),
      ('Science', 70),
      ('Amharic', 74),
    ]),
    _grade('Eden Mulatu', 'Grade 4A', [
      ('Mathematics', 93),
      ('English', 91),
      ('Science', 94),
      ('Amharic', 92),
    ]),
    _grade('Liya Kebede', 'Kindergarten A', [
      ('KG - Play & Learning', 90),
      ('KG - Early Literacy', 88),
      ('KG - Early Numeracy', 92),
      ('KG - Social Skills', 91),
    ], studentId: 'STU-KG01'),
    _grade('Natnael Alemu', 'Grade 4A', [
      ('Mathematics', 86),
      ('English', 84),
      ('Science', 88),
      ('Amharic', 83),
    ]),
    _grade('Feven Getachew', 'Grade 4B', [
      ('Mathematics', 96),
      ('English', 94),
      ('Science', 95),
      ('Amharic', 93),
    ]),
    _grade('Dawit Kebede', 'Grade 4B', [
      ('Mathematics', 90),
      ('English', 88),
      ('Science', 91),
      ('Amharic', 87),
    ]),
    _grade('Helen Berhanu', 'Grade 4B', [
      ('Mathematics', 87),
      ('English', 85),
      ('Science', 86),
      ('Amharic', 84),
    ]),
    _grade('Kaleb Solomon', 'Grade 4B', [
      ('Mathematics', 48),
      ('English', 42),
      ('Science', 46),
      ('Amharic', 39),
    ]),
    _grade('Tigist Araya', 'Grade 4B', [
      ('Mathematics', 82),
      ('English', 80),
      ('Science', 79),
      ('Amharic', 81),
    ]),
    _grade('Kidus Bekele', 'Grade 2C', [
      ('Mathematics', 78),
      ('English', 82),
      ('Art', 95),
    ], studentId: 'STU-1002'),
    _grade('Liya Solomon', 'Grade 5B', [
      ('Mathematics', 91),
      ('English', 87),
      ('Science', 89),
    ], studentId: 'STU-1005'),
    _grade('Nahom Tesfaye', 'Grade 5B', [
      ('Mathematics', 94),
      ('English', 92),
      ('Science', 93),
    ]),
    _grade('Bethel Girma', 'Grade 5B', [
      ('Mathematics', 88),
      ('English', 86),
      ('Science', 90),
    ]),
    _grade('Elias Hailu', 'Grade 5B', [
      ('Mathematics', 36),
      ('English', 41),
      ('Science', 38),
    ]),
    _grade('Meron Asfaw', 'Grade 5B', [
      ('Mathematics', 85),
      ('English', 83),
      ('Science', 84),
    ]),
    _grade('Fitsum Demeke', 'Grade 5B', [
      ('Mathematics', 79),
      ('English', 77),
      ('Science', 81),
    ]),
  ];

  static StudentGradeReport _grade(
    String studentName,
    String className,
    List<(String, double)> scores, {
    String? studentId,
  }) {
    final resolvedId = studentId ??
        StudentRegistryService.instance.lookupByName(studentName)?.studentId;
    return StudentGradeReport(
      studentName: studentName,
      studentId: resolvedId,
      className: className,
      term: 'Term 1',
      subjects: [
        for (final (subject, score) in scores)
          SubjectGrade(subject: subject, score: score, maxScore: 100),
      ],
    );
  }

  void _applyDemoGradeAttachments() {
    try {
      final sara = _gradeReports.firstWhere(
        (r) => r.studentName == 'Sara Bekele' && r.className == 'Grade 4A',
      );
      for (final subject in sara.subjects) {
        switch (subject.subject) {
          case 'Mathematics':
            subject.markPhotoPaths.add('asset:assets/branding/maya_brand.png');
            subject.comment ??=
                'Mid-term test marked sheet — see attachment below.';
            subject.enteredByTeacherId ??= 'TCH-1001';
            subject.subjectId ??= 'SUB-MATH';
          case 'English':
            subject.markPhotoPaths.add('asset:assets/branding/maya_brand.png');
            subject.enteredByTeacherId ??= 'TCH-1002';
            subject.subjectId ??= 'SUB-ENG';
          case 'Science':
            subject.comment ??= 'Lab report returned with teacher notes.';
            subject.enteredByTeacherId ??= 'TCH-1003';
            subject.subjectId ??= 'SUB-SCI';
            subject.teachingSlotId ??= 'STA-1002';
          default:
            break;
        }
      }
    } catch (_) {}
  }

  List<Conversation> getConversations() => List.unmodifiable(_conversations);

  void applyPersistedConversations(List<Conversation> persisted) {
    for (final cloud in persisted) {
      mergeConversationFromCloud(cloud);
    }
  }

  /// Merge a single conversation from the school cloud (real-time sync).
  void mergeConversationFromCloud(Conversation cloud) {
    final index = _conversations.indexWhere((c) => c.id == cloud.id);
    if (index < 0) {
      _conversations.add(cloud);
      unawaited(
        MessagePersistenceService.instance.saveFromService(pushCloud: false),
      );
      return;
    }

    final local = _conversations[index];
    final seen = <String>{
      for (final message in local.messages) _messageMergeKey(message),
    };
    var added = false;
    for (final message in cloud.messages) {
      if (seen.add(_messageMergeKey(message))) {
        local.messages.add(message);
        added = true;
      }
    }
    if (added) {
      local.messages.sort((a, b) => a.time.compareTo(b.time));
    }
    final beforeUsers = local.parentParticipantUsernames.length;
    final beforeStudents = local.linkedStudentIds.length;
    _mergeConversationParticipants(
      local,
      studentIds: cloud.linkedStudentIds,
      parentUsernames: cloud.parentParticipantUsernames,
      staffParticipantId: cloud.staffParticipantId,
      counterpartyStaffId: cloud.counterpartyStaffId,
      staffSubjectName: cloud.staffSubjectName,
    );
    if (added ||
        local.parentParticipantUsernames.length != beforeUsers ||
        local.linkedStudentIds.length != beforeStudents) {
      unawaited(
        MessagePersistenceService.instance.saveFromService(pushCloud: false),
      );
    }
  }

  String _messageMergeKey(ChatMessage message) {
    final username = message.senderUsername?.trim().toLowerCase() ?? '';
    final staff = message.senderStaffId?.trim().toLowerCase() ?? '';
    return '${message.time.millisecondsSinceEpoch}|${message.senderRole}|$username|$staff|${message.text}';
  }

  String? lastConversationPersistError;

  void _persistConversation(String conversationId) {
    final conversation = getConversation(conversationId);
    if (conversation == null) return;
    // Local only. ChatScreen / compose immediately persist to the school
    // cloud; a second unawaited cloud push races JWT refresh and can drop
    // a working teacher session (parent messages still visible, Send fails).
    unawaited(
      MessagePersistenceService.instance.saveFromService(pushCloud: false),
    );
  }

  Future<bool> persistConversationToCloud(String conversationId) async {
    AuthService.alignTeacherSessionWithRegistry();
    lastConversationPersistError = null;
    final open = getConversation(conversationId);
    if (open == null) {
      lastConversationPersistError = 'missing thread';
      return false;
    }
    _stampDirectParentThread(open);
    final conversation = _linkedParentTeacherThreadToPersist(open);
    _stampDirectParentThread(conversation);
    // Write with the current JWT first. Refreshing before Send can drop
    // school claims while parent messages are still visible.
    final schoolId = SchoolAuthCloudService.jwtSchoolId() ??
        SchoolAuthCloudService.resolvedSchoolId();
    Future<void> write() => MessagePersistenceService.instance.saveConversation(
          conversation,
          requireCloud: true,
          schoolId: schoolId,
        );
    try {
      await write();
      return true;
    } catch (e) {
      lastConversationPersistError = conversationPersistErrorText(e);
      if (kDebugMode) {
        debugPrint('persistConversationToCloud: $e');
      }
      try {
        await SchoolAuthCloudService.instance.ensureValidSchoolJwt(
          forceRefresh: true,
        );
        await write();
        lastConversationPersistError = null;
        return true;
      } catch (e2) {
        lastConversationPersistError = conversationPersistErrorText(e2);
        if (kDebugMode) {
          debugPrint('persistConversationToCloud retry: $e2');
        }
        unawaited(
          MessagePersistenceService.instance.saveConversation(
            conversation,
            schoolId: schoolId,
          ),
        );
        return false;
      }
    }
  }

  @visibleForTesting
  static String conversationPersistErrorText(Object e) {
    final s = '$e'.toLowerCase();
    if (s.contains('without schoolid') || s.contains('school id')) {
      return 'Could not save the message: school id is missing. Sign out and sign in again.';
    }
    if (s.contains('write_denied') || s.contains('not allowed')) {
      return 'Could not save the message: the school cloud blocked the write. Sign out and sign in again.';
    }
    if (s.contains('jwt') ||
        s.contains('session expired') ||
        s.contains('sign in')) {
      return 'Could not save the message: stay signed in and send again.';
    }
    if (s.contains('timeout')) {
      return 'Could not save the message: the school cloud timed out. Send again.';
    }
    return 'Could not save the message to the school cloud. Stay signed in and send again.';
  }

  void _persistSchoolContent() {
    // Best-effort: SharedPreferences / cloud push must not fail the caller
    // (calendar seed, UI, or a later unit test after this future completes).
    unawaited(_saveSchoolContentBestEffort());
  }

  Future<void> _saveSchoolContentBestEffort() async {
    try {
      await SchoolContentPersistenceService.instance.saveFromService();
    } catch (_) {}
  }

  List<Conversation> getConversationsForRole(String? roleKey) {
    return _conversations
        .where((c) => MessagingAccessService.canView(c, roleKey))
        .where((c) => !_isWeakerDuplicateParentTeacherThread(c))
        .toList(growable: false);
  }

  int totalUnreadMessagesForRole(String? roleKey) {
    final staffId = roleKey == AuthService.roleAdmin
        ? StaffMemberOption.viewerAdminStaffId(roleKey)
        : StaffMemberOption.viewerStaffId(roleKey);
    return getConversationsForRole(roleKey)
        .map((c) => c.unreadForViewer(roleKey, viewerStaffId: staffId))
        .fold(0, (sum, count) => sum + count);
  }

  String sendAdminBroadcast({
    required String body,
    required List<String> audienceKeys,
    String? subject,
  }) {
    final keys = audienceKeys.map(AnnouncementAudiences.normalizeLegacy).toSet().toList();
    if (keys.isEmpty || body.trim().isEmpty) return '';

    final senderRole = AuthService.currentUser?.roleKey ?? AuthService.roleAdmin;
    final senderName = AuthService.displayNameForRole(senderRole);
    final label = _broadcastLabelForKeys(keys);
    final id = 'broadcast-${DateTime.now().millisecondsSinceEpoch}';

    _conversations.insert(
      0,
      Conversation(
        id: id,
        name: label,
        role: 'Broadcast',
        isBroadcast: true,
        broadcastAudienceKeys: keys,
        unread: 0,
        messages: [
          ChatMessage(
            text: body.trim(),
            subject: subject?.trim().isEmpty == true ? null : subject?.trim(),
            senderRole: senderRole,
            time: DateTime.now(),
          ),
        ],
      ),
    );

    _notifyByAudiences(
      audienceKeys: keys,
      title: subject?.trim().isNotEmpty == true ? subject!.trim() : 'New message from $senderName',
      body: body.trim(),
      type: NotificationType.message,
      fromRole: senderRole,
      fromName: senderName,
    );

    return id;
  }

  List<ParentRecipientOption> getParentRecipientsForActiveSchool() {
    return MessagingAccessService.parentsForSchool(AuthService.activeSchoolId);
  }

  List<StaffMemberOption> getStaffForActiveSchool() {
    final schoolId = AuthService.activeSchoolId;
    final staff = <StaffMemberOption>[];

    for (final teacher in TeacherRegistryService.instance
        .staffTeachersForSchool(schoolId)
        .where((t) => t.isActive)) {
      final option = StaffMemberOption.fromTeacher(teacher);
      if (option != null) staff.add(option);
    }
    for (final driver
        in DriverRegistryService.instance.driversForSchool(schoolId)) {
      final option = StaffMemberOption.fromDriver(driver);
      if (option != null) staff.add(option);
    }
    for (final admin in AdminRegistryService.instance.getAllAdmins()) {
      if (schoolId != null &&
          admin.schoolId.trim().toUpperCase() != schoolId.trim().toUpperCase()) {
        continue;
      }
      final option = StaffMemberOption.fromAdmin(admin);
      if (option != null) staff.add(option);
    }

    staff.sort((a, b) => a.displayName.compareTo(b.displayName));
    return staff;
  }

  List<GroupMemberEntry> getCommunityMembers(String conversationId) {
    final conversation = getConversation(conversationId);
    if (conversation == null || !conversation.isGroup) return [];

    final members = <GroupMemberEntry>[];
    final parentOptions = {
      for (final option in getParentRecipientsForActiveSchool())
        option.parentName: option,
    };

    for (final parentName in conversation.groupParentNames) {
      final option = parentOptions[parentName];
      members.add(
        GroupMemberEntry(
          key: parentName,
          displayName: parentName,
          subtitle: option?.searchDetail ?? parentName,
          typeLabel: 'Parent',
          isParent: true,
        ),
      );
    }

    for (final staffId in conversation.groupStaffIds) {
      final staff = StaffMemberOption.resolve(staffId);
      if (staff == null) continue;
      members.add(
        GroupMemberEntry(
          key: staffId,
          displayName: staff.displayName,
          subtitle: staff.subtitle,
          typeLabel: _staffTypeLabel(staff),
          isParent: false,
        ),
      );
    }

    return members;
  }

  String _staffTypeLabel(StaffMemberOption staff) {
    return switch (staff.kind) {
      StaffKind.teacher => 'Teacher',
      StaffKind.driver => 'Driver',
      StaffKind.adminStaff => 'Admin',
    };
  }

  bool removeCommunityMember(
    String conversationId, {
    required String key,
    required bool isParent,
  }) {
    final conversation = getConversation(conversationId);
    if (conversation == null || !conversation.isGroup) return false;

    if (!canManageCommunityGroup(conversationId)) return false;

    if (isParent) {
      conversation.groupParentNames.remove(key);
    } else {
      conversation.groupStaffIds.remove(key);
    }

    if (conversation.groupParentNames.isEmpty &&
        conversation.groupStaffIds.isEmpty) {
      _conversations.removeWhere((c) => c.id == conversationId);
      return true;
    }

    if (!conversation.usesCustomGroupName) {
      conversation.name = _groupConversationName(
        conversation.groupParentNames,
        conversation.groupStaffIds
            .map(StaffMemberOption.resolve)
            .whereType<StaffMemberOption>()
            .toList(),
      );
    }
    return true;
  }

  List<ParentRecipientOption> getAvailableParentsForCommunity(
    String conversationId,
  ) {
    final conversation = getConversation(conversationId);
    if (conversation == null || !conversation.isGroup) return [];
    final existing = conversation.groupParentNames.toSet();
    return _parentRecipientsForCommunityPicker()
        .where((option) => !existing.contains(option.parentName))
        .toList();
  }

  List<StaffMemberOption> getAvailableStaffForCommunity(String conversationId) {
    final conversation = getConversation(conversationId);
    if (conversation == null || !conversation.isGroup) return [];
    final existing = conversation.groupStaffIds.toSet();
    return _staffRecipientsForCommunityPicker()
        .where((member) => !existing.contains(member.id))
        .toList();
  }

  List<ParentRecipientOption> _parentRecipientsForCommunityPicker() {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleTeacher) {
      return MessagingAccessService.parentsForTeacherClasses();
    }
    return getParentRecipientsForActiveSchool();
  }

  List<StaffMemberOption> _staffRecipientsForCommunityPicker() {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleTeacher) {
      return MessagingAccessService.adminContactsForTeacher();
    }
    return getStaffForActiveSchool();
  }

  bool teacherIsCommunityStaffMember(String conversationId) {
    final conversation = getConversation(conversationId);
    if (conversation == null || !conversation.isGroup) return false;
    final teacherStaffId =
        StaffMemberOption.viewerStaffId(AuthService.roleTeacher);
    if (teacherStaffId == null) return false;
    return conversation.groupStaffIds.any(
      (id) =>
          id.trim().toUpperCase() == teacherStaffId.trim().toUpperCase(),
    );
  }

  bool canManageCommunityGroup(String conversationId) {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleAdmin) return true;
    if (role == AuthService.roleTeacher) {
      return teacherIsCommunityStaffMember(conversationId);
    }
    return false;
  }

  bool addCommunityMembers(
    String conversationId, {
    List<String> parentNames = const [],
    List<String> staffIds = const [],
  }) {
    final conversation = getConversation(conversationId);
    if (conversation == null || !conversation.isGroup) return false;

    final senderRole = AuthService.currentUser?.roleKey;
    if (senderRole == AuthService.roleTeacher) {
      if (!canManageCommunityGroup(conversationId)) return false;
      for (final name in parentNames) {
        if (!MessagingAccessService.canTeacherDirectToParent(name)) {
          return false;
        }
      }
      for (final id in staffIds) {
        if (!MessagingAccessService.canTeacherDirectToStaff(id)) {
          return false;
        }
      }
    }

    var added = false;
    for (final name in parentNames) {
      final trimmed = name.trim();
      if (trimmed.isEmpty || conversation.groupParentNames.contains(trimmed)) {
        continue;
      }
      conversation.groupParentNames.add(trimmed);
      final recipient = MessagingAccessService.findParentRecipient(
        trimmed,
        schoolId: AuthService.activeSchoolId,
      );
      if (recipient != null) {
        _mergeConversationParticipants(
          conversation,
          studentIds: recipient.studentIds,
          parentUsernames: MessagingAccessService.usernamesOf(recipient),
        );
      }
      added = true;
    }
    for (final id in staffIds) {
      final trimmed = id.trim();
      if (trimmed.isEmpty || conversation.groupStaffIds.contains(trimmed)) {
        continue;
      }
      conversation.groupStaffIds.add(trimmed);
      added = true;
    }
    if (!added) return false;

    conversation.groupParentNames.sort(
      (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
    );
    conversation.groupStaffIds.sort(
      (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
    );
    if (!conversation.usesCustomGroupName) {
      conversation.name = _groupConversationName(
        conversation.groupParentNames,
        conversation.groupStaffIds
            .map(StaffMemberOption.resolve)
            .whereType<StaffMemberOption>()
            .toList(),
      );
    }
    return true;
  }

  List<String> sendAdminGroupMessage({
    required List<String> parentNames,
    required List<String> staffIds,
    required String body,
    required String groupName,
    String? subject,
    String? photoPath,
    List<AnnouncementAttachment> attachments = const [],
  }) {
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty && attachments.isEmpty) return [];

    final parents = parentNames
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final staff = staffIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final senderRole = AuthService.currentUser?.roleKey ?? AuthService.roleAdmin;
    if (senderRole == AuthService.roleAdmin) {
      final adminStaffId =
          StaffMemberOption.viewerAdminStaffId(AuthService.roleAdmin);
      if (adminStaffId != null && !staff.contains(adminStaffId)) {
        staff.add(adminStaffId);
        staff.sort();
      }
    }
    if (senderRole == AuthService.roleTeacher) {
      final teacherStaffId =
          StaffMemberOption.viewerStaffId(AuthService.roleTeacher);
      if (teacherStaffId != null && !staff.contains(teacherStaffId)) {
        staff.add(teacherStaffId);
        staff.sort();
      }
      for (final parentName in parents) {
        if (!MessagingAccessService.canTeacherDirectToParent(parentName)) {
          return [];
        }
      }
      for (final staffId in staff) {
        if (staffId == teacherStaffId) continue;
        if (!MessagingAccessService.canTeacherDirectToStaff(staffId)) {
          return [];
        }
      }
    }

    if (parents.isEmpty && staff.isEmpty) return [];

    final conversationId = openOrCreateGroupConversation(
      parentNames: parents,
      staffIds: staff,
      groupName: groupName.trim(),
      photoPath: photoPath,
    );
    final groupConversation = getConversation(conversationId);
    if (groupConversation != null) {
      for (final parentName in parents) {
        final recipient = MessagingAccessService.findParentRecipient(
          parentName,
          schoolId: AuthService.activeSchoolId,
        );
        if (recipient == null) continue;
        _mergeConversationParticipants(
          groupConversation,
          studentIds: recipient.studentIds,
          parentUsernames: MessagingAccessService.usernamesOf(recipient),
        );
      }
    }
    return _postAdminMessage(
      conversationId: conversationId,
      body: trimmedBody.isEmpty ? 'Voice message' : trimmedBody,
      subject: subject,
      attachments: attachments,
    );
  }

  List<String> sendAdminDirectMessage({
    required String body,
    String? subject,
    String? parentName,
    String? staffId,
    String? studentId,
    List<AnnouncementAttachment> attachments = const [],
  }) {
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty && attachments.isEmpty) return [];

    final trimmedParent = parentName?.trim();
    final trimmedStaff = staffId?.trim();
    final hasParent = trimmedParent != null && trimmedParent.isNotEmpty;
    final hasStaff = trimmedStaff != null && trimmedStaff.isNotEmpty;
    if (hasParent == hasStaff) return [];

    AuthService.alignTeacherSessionWithRegistry();
    final senderRole = AuthService.currentUser?.roleKey ?? AuthService.roleAdmin;
    if (senderRole == AuthService.roleTeacher) {
      if (hasParent &&
          !MessagingAccessService.canTeacherDirectToParent(trimmedParent)) {
        return [];
      }
      if (hasStaff &&
          !MessagingAccessService.canTeacherDirectToStaff(trimmedStaff)) {
        return [];
      }
    }

    final String conversationId;
    final parentParticipant = AuthService.currentUser?.roleKey == AuthService.roleParent
        ? AuthService.currentUser?.fullName
        : null;
    if (hasParent) {
      final recipient = MessagingAccessService.findParentRecipient(
        trimmedParent,
        schoolId: AuthService.activeSchoolId,
      );
      final senderStaffId = StaffMemberOption.viewerCompositeStaffId(senderRole);
      final lookupStudentIds = _normalizeStudentIds([
        if (studentId != null) studentId,
        ...?recipient?.studentIds,
      ]);
      conversationId = openOrCreateConversation(
        contactName: trimmedParent,
        role: 'Parent',
        parentParticipantName: trimmedParent,
        staffParticipantId: senderStaffId,
        staffSubjectName: senderStaffId == null
            ? null
            : MessagingAccessService.staffSubjectLabelFor(
                staffParticipantId: senderStaffId,
                linkedStudentIds: lookupStudentIds,
              ),
        linkedStudentIds: lookupStudentIds,
        parentParticipantUsernames: [
          ...MessagingAccessService.usernamesOf(recipient),
          ...MessagingAccessService.parentLoginKeysForStudentIds(
            lookupStudentIds,
            parentName: trimmedParent,
          ),
        ],
      );
    } else {
      final member = StaffMemberOption.resolve(trimmedStaff!);
      if (member == null) return [];
      final threadIds = _staffToStaffThreadIds(
        senderRole: senderRole,
        recipient: member,
      );
      conversationId = openOrCreateConversation(
        contactName: threadIds.contactName,
        role: threadIds.role,
        staffParticipantId: threadIds.staffId,
        counterpartyStaffId: threadIds.peerId,
        parentParticipantName: parentParticipant,
      );
    }

    return _postAdminMessage(
      conversationId: conversationId,
      body: trimmedBody.isEmpty ? 'Voice message' : trimmedBody,
      subject: subject,
      attachments: attachments,
    );
  }

  List<String> _postAdminMessage({
    required String conversationId,
    required String body,
    String? subject,
    List<AnnouncementAttachment> attachments = const [],
    String? relationshipStudentId,
  }) {
    final conversation = getConversation(conversationId);
    if (conversation == null) return [];

    final senderRole =
        AuthService.currentUser?.roleKey ?? AuthService.roleAdmin;
    final msgSubject = subject?.trim().isEmpty == true ? null : subject?.trim();
    final senderMeta = _messageSenderMeta(
      senderRole,
      relationshipStudentId: relationshipStudentId,
    );
    final senderName =
        senderMeta.senderDisplayName ?? AuthService.displayNameForRole(senderRole);
    final preview = _messagePreviewBody(body, attachments);

    conversation.messages.add(
      ChatMessage(
        text: body,
        subject: msgSubject,
        senderRole: senderRole,
        time: DateTime.now(),
        senderStaffId: senderMeta.senderStaffId,
        senderDisplayName: senderMeta.senderDisplayName,
        senderUsername: senderMeta.senderUsername,
        senderRelationshipLabel: senderMeta.senderRelationshipLabel,
        attachments: List.unmodifiable(attachments),
      ),
    );

    if (conversation.isGroup) {
      _notifyGroupParticipants(
        conversation: conversation,
        senderRole: senderRole,
        senderName: senderName,
        title: msgSubject ?? 'New message from $senderName',
        body: preview,
      );
    } else {
      final recipientRole =
          _recipientRoleForConversation(conversation, senderRole);
      final targeting =
          _directMessageNotificationTargets(conversation, recipientRole);
      NotificationService.instance.push(
        title: msgSubject ?? 'New message from $senderName',
        body: preview,
        type: NotificationType.message,
        fromRole: senderRole,
        fromName: senderName,
        recipientRole: recipientRole,
        recipientStaffId: targeting.recipientStaffId,
        recipientUsernames: targeting.recipientUsernames,
        targetStudentId: targeting.targetStudentId,
      );
    }

    _stampDirectParentThread(conversation);
    _persistConversation(conversationId);
    return [conversationId];
  }

  String _messagePreviewBody(
    String text,
    List<AnnouncementAttachment> attachments,
  ) {
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) return trimmed;
    if (attachments.isEmpty) return '';
    if (attachments.every((a) {
      final lower = a.fileName.toLowerCase();
      return lower.endsWith('.m4a') ||
          lower.endsWith('.aac') ||
          lower.endsWith('.wav') ||
          lower.startsWith('voice_');
    })) {
      return 'Voice message';
    }
    if (attachments.length == 1) {
      return attachments.first.fileName;
    }
    return '${attachments.length} attachments';
  }

  ({String? senderStaffId, String? senderDisplayName, String? senderUsername, String? senderRelationshipLabel}) _messageSenderMeta(
    String senderRole, {
    String? relationshipStudentId,
  }) {
    final user = AuthService.currentUser;
    final username = user?.username.trim();
    final senderUsername =
        username == null || username.isEmpty ? null : username;

    if (senderRole == AuthService.roleTeacher) {
      final record = TeacherRegistryService.instance.resolveForAuthUser(
        linkedTeacherId: user?.linkedTeacherId,
        username: user?.username,
        phone: user?.phone,
        schoolId: AuthService.activeSchoolId ?? user?.schoolId,
      );
      final teacherId = record?.teacherId.trim().isNotEmpty == true
          ? record!.teacherId
          : user?.linkedTeacherId;
      final teacherName = record?.fullName.trim().isNotEmpty == true
          ? record!.fullName.trim()
          : (user?.fullName?.trim() ?? 'Teacher');
      return (
        senderStaffId: teacherId == null || teacherId.trim().isEmpty
            ? null
            : StaffMemberOption.teacherKey(teacherId),
        senderDisplayName: teacherName,
        senderUsername: senderUsername,
        senderRelationshipLabel: null,
      );
    }
    if (senderRole == AuthService.roleDriver) {
      final record = DriverRegistryService.instance.resolveForAuthUser(
        linkedDriverId: user?.linkedDriverId,
        username: user?.username,
        phone: user?.phone,
        schoolId: AuthService.activeSchoolId ?? user?.schoolId,
      );
      final driverId = record?.driverId.trim().isNotEmpty == true
          ? record!.driverId
          : user?.linkedDriverId;
      final driverName = record?.fullName.trim().isNotEmpty == true
          ? record!.fullName.trim()
          : (user?.fullName?.trim() ?? 'Driver');
      return (
        senderStaffId: driverId == null || driverId.trim().isEmpty
            ? null
            : StaffMemberOption.driverKey(driverId),
        senderDisplayName: driverName,
        senderUsername: senderUsername,
        senderRelationshipLabel: null,
      );
    }
    if (senderRole == AuthService.roleAdmin) {
      final adminId = user?.linkedAdminId?.trim();
      AdminStaffRecord? adminRecord;
      if (adminId != null && adminId.isNotEmpty) {
        adminRecord = AdminRegistryService.instance.lookupById(adminId);
      } else {
        final schoolId = AuthService.activeSchoolId ?? user?.schoolId;
        for (final admin in AdminRegistryService.instance.getAllAdmins()) {
          if (schoolId != null &&
              admin.schoolId.trim().toUpperCase() !=
                  schoolId.trim().toUpperCase()) {
            continue;
          }
          final phone = user?.phone?.trim();
          if (phone != null &&
              phone.isNotEmpty &&
              admin.phone?.trim() == phone) {
            adminRecord = admin;
            break;
          }
        }
      }
      if (adminRecord != null) {
        return (
          senderStaffId: StaffMemberOption.adminKey(adminRecord.adminId),
          senderDisplayName: adminRecord.fullName.trim(),
          senderUsername: senderUsername,
          senderRelationshipLabel: null,
        );
      }
    }
    if (senderRole == AuthService.roleParent) {
      final studentId = relationshipStudentId ??
          (AuthService.activeLinkedStudentIds().isNotEmpty
              ? AuthService.activeLinkedStudentIds().first
              : null);
      final relationship = studentId != null
          ? MessagingAccessService.relationshipLabelForStudent(studentId)
          : MessagingAccessService.relationshipLabelForCurrentParent();
      return (
        senderStaffId: null,
        senderDisplayName: user?.fullName ?? 'Parent',
        senderUsername: senderUsername,
        senderRelationshipLabel: relationship,
      );
    }
    return (
      senderStaffId: null,
      senderDisplayName: AuthService.displayNameForRole(senderRole),
      senderUsername: senderUsername,
      senderRelationshipLabel: null,
    );
  }

  void _notifyGroupParticipants({
    required Conversation conversation,
    required String senderRole,
    required String senderName,
    required String title,
    required String body,
  }) {
    final roles = <String>{AuthService.roleAdmin};
    if (conversation.groupParentNames.isNotEmpty) {
      roles.add(AuthService.roleParent);
    }
    for (final staffId in conversation.groupStaffIds) {
      final member = StaffMemberOption.resolve(staffId);
      if (member != null) roles.add(member.roleKey);
    }
    roles.remove(senderRole);
    for (final role in roles) {
      NotificationService.instance.push(
        title: title,
        body: body,
        type: NotificationType.message,
        fromRole: senderRole,
        fromName: senderName,
        recipientRole: role,
      );
    }
  }

  String openOrCreateGroupConversation({
    required List<String> parentNames,
    required List<String> staffIds,
    String? groupName,
    String? photoPath,
  }) {
    final sortedParents = [...parentNames]
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final sortedStaffIds = [...staffIds]
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    try {
      return _conversations
          .firstWhere(
            (c) =>
                c.isGroup &&
                _sameIdList(c.groupParentNames, sortedParents) &&
                _sameIdList(c.groupStaffIds, sortedStaffIds),
          )
          .id;
    } catch (_) {
      final staffMembers = sortedStaffIds
          .map(StaffMemberOption.resolve)
          .whereType<StaffMemberOption>()
          .toList();
      final trimmedName = groupName?.trim() ?? '';
      final customName = trimmedName.isNotEmpty;
      final id = 'group-${DateTime.now().millisecondsSinceEpoch}';
      _conversations.insert(
        0,
        Conversation(
          id: id,
          name: customName
              ? trimmedName
              : _groupConversationName(sortedParents, staffMembers),
          role: 'Group',
          isGroup: true,
          groupParentNames: sortedParents,
          groupStaffIds: sortedStaffIds,
          messages: [],
          photoPath: photoPath,
          usesCustomGroupName: customName,
        ),
      );
      return id;
    }
  }

  bool _sameIdList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].trim().toUpperCase() != b[i].trim().toUpperCase()) {
        return false;
      }
    }
    return true;
  }

  String _groupConversationName(
    List<String> parentNames,
    List<StaffMemberOption> staffMembers,
  ) {
    final parts = <String>[];
    if (parentNames.length == 1) {
      parts.add(parentNames.first);
    } else if (parentNames.isNotEmpty) {
      parts.add('${parentNames.length} parents');
    }
    if (staffMembers.length == 1) {
      parts.add(staffMembers.first.displayName);
    } else if (staffMembers.isNotEmpty) {
      parts.add('${staffMembers.length} staff');
    }
    if (parts.isEmpty) return 'Group chat';
    if (parts.length == 1) return parts.first;
    return parts.join(' · ');
  }

  String _broadcastLabelForKeys(List<String> keys) {
    if (keys.length == 1) {
      return switch (keys.first) {
        AnnouncementAudiences.parents => 'All Parents',
        AnnouncementAudiences.teachers => 'All Teachers',
        AnnouncementAudiences.transport => 'All Drivers',
        _ => 'Broadcast',
      };
    }
    final parts = keys.map((k) => switch (k) {
          AnnouncementAudiences.parents => 'Parents',
          AnnouncementAudiences.teachers => 'Teachers',
          AnnouncementAudiences.transport => 'Drivers',
          _ => k,
        });
    return 'Broadcast · ${parts.join(' & ')}';
  }

  Conversation? getConversation(String id) {
    try {
      return _conversations.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  void markConversationRead(String conversationId) {
    markMessagesSeenByViewer(conversationId);
  }

  /// Marks incoming messages as read and flags outgoing messages as seen by the viewer.
  void markMessagesSeenByViewer(String conversationId) {
    final conversation = getConversation(conversationId);
    final viewerRole = AuthService.currentUser?.roleKey;
    if (conversation == null || viewerRole == null) return;

    final now = DateTime.now();
    for (final message in conversation.messages) {
      if (message.senderRole != viewerRole && message.seenAt == null) {
        message.seenAt = now;
      }
    }
    conversation.unread = 0;
    NotificationService.instance.refreshBadges();
  }

  bool deleteMessage(String conversationId, int messageIndex) {
    final conversation = getConversation(conversationId);
    if (conversation == null) return false;
    if (messageIndex < 0 || messageIndex >= conversation.messages.length) {
      return false;
    }

    final viewerRole = AuthService.currentUser?.roleKey;
    final viewerStaffId = viewerRole == AuthService.roleAdmin
        ? StaffMemberOption.viewerAdminStaffId(viewerRole)
        : StaffMemberOption.viewerStaffId(viewerRole);
    final viewerUsername = AuthService.currentUser?.username;
    final message = conversation.messages[messageIndex];
    if (!message.isOutgoingFor(
      viewerRole,
      viewerStaffId: viewerStaffId,
      viewerUsername: viewerUsername,
    )) {
      return false;
    }

    conversation.messages.removeAt(messageIndex);
    return true;
  }

  void sendMessage(
    String conversationId,
    String text, {
    List<AnnouncementAttachment> attachments = const [],
    MessageReplyQuote? replyTo,
  }) {
    final existing = getConversation(conversationId);
    final trimmed = text.trim();
    if (existing == null ||
        (trimmed.isEmpty && attachments.isEmpty)) {
      return;
    }
    final conversation = existing;

    final senderRole =
        AuthService.currentUser?.roleKey ?? AuthService.roleTeacher;
    AuthService.alignTeacherSessionWithRegistry();
    if (!MessagingAccessService.canView(conversation, senderRole)) {
      return;
    }
    _stampDirectParentThread(conversation);
    final persistTarget = _linkedParentTeacherThreadToPersist(conversation);
    final senderMeta = _messageSenderMeta(
      senderRole,
      relationshipStudentId: conversation.linkedStudentIds.isNotEmpty
          ? conversation.linkedStudentIds.first
          : persistTarget.linkedStudentIds.isNotEmpty
              ? persistTarget.linkedStudentIds.first
              : null,
    );
    final preview = _messagePreviewBody(trimmed, attachments);
    final senderName =
        senderMeta.senderDisplayName ?? AuthService.displayNameForRole(senderRole);

    final message = ChatMessage(
      text: trimmed,
      senderRole: senderRole,
      time: DateTime.now(),
      senderStaffId: senderMeta.senderStaffId,
      senderDisplayName: senderMeta.senderDisplayName,
      senderUsername: senderMeta.senderUsername,
      senderRelationshipLabel: senderMeta.senderRelationshipLabel,
      attachments: List.unmodifiable(attachments),
      replyTo: replyTo,
    );
    conversation.messages.add(message);
    if (persistTarget.id != conversation.id) {
      _copyMessageIfMissing(persistTarget, message);
    }

    if (conversation.isGroup) {
      _notifyGroupParticipants(
        conversation: conversation,
        senderRole: senderRole,
        senderName: senderName,
        title: 'New message from $senderName',
        body: preview,
      );
      _persistConversation(persistTarget.id);
      return;
    }

    final recipientRole =
        _recipientRoleForConversation(conversation, senderRole);
    final targeting =
        _directMessageNotificationTargets(conversation, recipientRole);

    NotificationService.instance.push(
      title: 'New message from $senderName',
      body: preview,
      type: NotificationType.message,
      fromRole: senderRole,
      fromName: senderName,
      recipientRole: recipientRole,
      recipientStaffId: targeting.recipientStaffId,
      recipientUsernames: targeting.recipientUsernames,
      targetStudentId: targeting.targetStudentId,
    );
    _persistConversation(persistTarget.id);
  }

  void _copyMessageIfMissing(Conversation? target, ChatMessage message) {
    if (target == null) return;
    final key = _messageMergeKey(message);
    if (target.messages.any((existing) => _messageMergeKey(existing) == key)) {
      return;
    }
    target.messages.add(message);
  }

  void _stampDirectParentThread(Conversation conversation) {
    if (conversation.isGroup || conversation.isBroadcast) return;
    if (conversation.isStaffOnlyDirectThread) return;

    final role = AuthService.currentUser?.roleKey;
    if ((conversation.staffParticipantId == null ||
            conversation.staffParticipantId!.trim().isEmpty) &&
        (role == AuthService.roleTeacher ||
            role == AuthService.roleAdmin ||
            role == AuthService.roleDriver)) {
      final viewer = StaffMemberOption.viewerCompositeStaffId(role);
      if (viewer != null && viewer.trim().isNotEmpty) {
        conversation.staffParticipantId = viewer;
      }
    }

    final threadStudents = _conversationStudentIds(conversation);
    if (threadStudents.isEmpty) {
      final parentName = conversation.parentParticipantName?.trim();
      if (parentName != null && parentName.isNotEmpty) {
        final recipient = MessagingAccessService.findParentRecipient(
          parentName,
          schoolId: AuthService.activeSchoolId,
        );
        threadStudents.addAll(
          _normalizeStudentIds(recipient?.studentIds ?? const []),
        );
      }
    }

    final parentName = conversation.parentParticipantName?.trim();
    final usernames = <String>[
      ...conversation.parentParticipantUsernames,
    ];
    if (role == AuthService.roleParent) {
      final username = AuthService.currentUser?.username.trim();
      if (username != null && username.isNotEmpty) {
        usernames.add(username);
      }
    }
    if (parentName != null && parentName.isNotEmpty) {
      final recipient = MessagingAccessService.findParentRecipient(
        parentName,
        schoolId: AuthService.activeSchoolId,
      );
      usernames.addAll(MessagingAccessService.usernamesOf(recipient));
    }
    usernames.addAll(
      MessagingAccessService.parentLoginKeysForStudentIds(
        threadStudents,
        parentName: parentName,
      ),
    );

    _mergeConversationParticipants(
      conversation,
      studentIds: threadStudents,
      parentUsernames: usernames,
    );
  }

  ({
    String? recipientStaffId,
    List<String>? recipientUsernames,
    String? targetStudentId,
  }) _directMessageNotificationTargets(
    Conversation conversation,
    String recipientRole,
  ) {
    if (recipientRole == AuthService.roleTeacher) {
      final staffId = conversation.staffParticipantId?.trim();
      return (
        recipientStaffId: staffId == null || staffId.isEmpty ? null : staffId,
        recipientUsernames: null,
        targetStudentId: null,
      );
    }
    if (recipientRole == AuthService.roleParent) {
      final usernames = conversation.parentParticipantUsernames
          .map((u) => u.trim())
          .where((u) => u.isNotEmpty)
          .toList();
      final studentId = conversation.linkedStudentIds.isNotEmpty
          ? conversation.linkedStudentIds.first
          : null;
      return (
        recipientStaffId: null,
        recipientUsernames: usernames.isEmpty ? null : usernames,
        targetStudentId: studentId,
      );
    }
    return (
      recipientStaffId: null,
      recipientUsernames: null,
      targetStudentId: null,
    );
  }

  String _recipientRoleForConversation(
    Conversation conversation,
    String senderRole,
  ) {
    final contactRole = conversation.role.toLowerCase();
    if (senderRole == AuthService.roleTeacher) {
      return switch (contactRole) {
        'parent' => AuthService.roleParent,
        'admin' => AuthService.roleAdmin,
        'driver' => AuthService.roleDriver,
        _ => AuthService.roleParent,
      };
    }
    if (senderRole == AuthService.roleParent) {
      return switch (contactRole) {
        'teacher' => AuthService.roleTeacher,
        'admin' => AuthService.roleAdmin,
        'driver' => AuthService.roleDriver,
        _ => AuthService.roleTeacher,
      };
    }
    if (senderRole == AuthService.roleAdmin) {
      return switch (contactRole) {
        'teacher' => AuthService.roleTeacher,
        'parent' => AuthService.roleParent,
        'driver' => AuthService.roleDriver,
        _ => AuthService.roleTeacher,
      };
    }
    return switch (contactRole) {
      'admin' => AuthService.roleAdmin,
      'parent' => AuthService.roleParent,
      'teacher' => AuthService.roleTeacher,
      _ => AuthService.roleAdmin,
    };
  }

  void _notifyParentsInClass({
    required String className,
    required String title,
    required String body,
    required NotificationType type,
    required String fromRole,
    required String fromName,
  }) {
    NotificationService.instance.push(
      title: title,
      body: body,
      type: type,
      fromRole: fromRole,
      fromName: fromName,
      recipientRole: AuthService.roleParent,
      targetClassName: className,
    );
  }

  void _notifyByAudiences({
    required List<String> audienceKeys,
    required String title,
    required String body,
    required NotificationType type,
    required String fromRole,
    required String fromName,
  }) {
    final roles = <String>{};
    for (final key in audienceKeys) {
      roles.addAll(_rolesForAudienceKey(key));
    }
    for (final role in roles) {
      NotificationService.instance.push(
        title: title,
        body: body,
        type: type,
        fromRole: fromRole,
        fromName: fromName,
        recipientRole: role,
        showOnMessagesBadge: role == AuthService.roleParent ||
            role == AuthService.roleTeacher,
      );
    }
  }

  Set<String> _rolesForAudienceKey(String key) {
    switch (AnnouncementAudiences.normalizeLegacy(key)) {
      case AnnouncementAudiences.parents:
        return {AuthService.roleParent};
      case AnnouncementAudiences.teachers:
        return {AuthService.roleTeacher};
      case AnnouncementAudiences.transport:
        return {AuthService.roleDriver};
      case AnnouncementAudiences.admin:
        return {AuthService.roleAdmin};
      case AnnouncementAudiences.all:
      default:
        return {
          AuthService.roleParent,
          AuthService.roleTeacher,
          AuthService.roleAdmin,
          AuthService.roleDriver,
        };
    }
  }

  String? homeroomTeacherIdForClass(String className) {
    final cached = _homeroomTeacherIds[className];
    if (cached != null && cached.trim().isNotEmpty) return cached;

    for (final teacher in TeacherRegistryService.instance.getAllTeachers()) {
      for (final assignment in teacher.classAssignments) {
        if (_classNamesMatch(assignment.className, className) &&
            assignment.role == TeacherStaffRole.homeroomTeacher) {
          return teacher.teacherId;
        }
      }
    }
    return null;
  }

  String? homeroomTeacherNameForClass(String className) {
    final id = homeroomTeacherIdForClass(className);
    if (id != null) {
      final teacher = TeacherRegistryService.instance.lookupById(id);
      if (teacher != null) return teacher.fullName;
    }
    return _homeroomTeacherNames[className];
  }

  /// Classes where this teacher is the assigned homeroom teacher.
  List<String> homeroomClassNamesForTeacher(String teacherId) {
    final id = teacherId.trim().toUpperCase();
    return _homeroomTeacherIds.entries
        .where((entry) => entry.value.toUpperCase() == id)
        .map((entry) => entry.key)
        .toList();
  }

  String? _senderCounterpartyStaffId(String senderRole) {
    return StaffMemberOption.viewerCompositeStaffId(senderRole);
  }

  bool _staffPeerPairMatches(
    Conversation conversation,
    String staffId,
    String peerStaffId,
  ) {
    final existingStaff = conversation.staffParticipantId?.trim();
    final existingPeer = conversation.counterpartyStaffId?.trim();
    if (existingStaff == null ||
        existingStaff.isEmpty ||
        existingPeer == null ||
        existingPeer.isEmpty) {
      return existingStaff == staffId.trim() && existingPeer == peerStaffId.trim();
    }
    final pair = {existingStaff, existingPeer};
    return pair.contains(staffId.trim()) && pair.contains(peerStaffId.trim());
  }

  void _canonicalizeStaffToStaffThread(Conversation conversation) {
    final staffId = conversation.staffParticipantId?.trim();
    final peerId = conversation.counterpartyStaffId?.trim();
    if (staffId == null || peerId == null) return;

    final staffMember = StaffMemberOption.resolve(staffId);
    final peerMember = StaffMemberOption.resolve(peerId);
    if (staffMember?.roleKey == AuthService.roleAdmin &&
        peerMember != null &&
        peerMember.roleKey != AuthService.roleAdmin) {
      conversation.staffParticipantId = peerId;
      conversation.counterpartyStaffId = staffId;
      conversation.name = peerMember.displayName;
    }
  }

  ({String staffId, String peerId, String contactName, String role})
      _staffToStaffThreadIds({
    required String senderRole,
    required StaffMemberOption recipient,
  }) {
    final senderStaffId = _senderCounterpartyStaffId(senderRole);
    if (senderStaffId == null || senderStaffId.isEmpty) {
      return (
        staffId: recipient.id,
        peerId: recipient.id,
        contactName: recipient.displayName,
        role: recipient.conversationRole,
      );
    }

    if (senderRole == AuthService.roleAdmin) {
      return (
        staffId: recipient.id,
        peerId: senderStaffId,
        contactName: recipient.displayName,
        role: recipient.conversationRole,
      );
    }

    if (recipient.roleKey == AuthService.roleAdmin) {
      return (
        staffId: senderStaffId,
        peerId: recipient.id,
        contactName: recipient.displayName,
        role: recipient.conversationRole,
      );
    }

    return (
      staffId: senderStaffId,
      peerId: recipient.id,
      contactName: recipient.displayName,
      role: recipient.conversationRole,
    );
  }

  String _deterministicDirectConversationId({
    required String contactName,
    String? staffParticipantId,
    String? counterpartyStaffId,
    List<String> studentIds = const [],
    List<String> parentUsernames = const [],
    String? parentParticipantName,
  }) {
    final staffId = staffParticipantId?.trim().toUpperCase();
    final peerStaffId = counterpartyStaffId?.trim().toUpperCase();
    final hasStaff = staffId != null && staffId.isNotEmpty;
    final isStaffToStaff = hasStaff &&
        peerStaffId != null &&
        peerStaffId.isNotEmpty &&
        (parentParticipantName == null || parentParticipantName.trim().isEmpty) &&
        studentIds.isEmpty &&
        parentUsernames.isEmpty;

    if (isStaffToStaff) {
      final pair = [staffId, peerStaffId]..sort();
      return 'direct-staff-${pair[0]}-${pair[1]}';
    }

    final primaryStudent = _primaryStudentId(studentIds);
    if (hasStaff && primaryStudent != null) {
      return _canonicalDirectParentTeacherConversationId(
        staffParticipantId: staffId,
        studentId: primaryStudent,
      );
    }

    // Last-resort fallback when a parent/teacher thread has no student id yet.
    if (hasStaff) {
      final parentKey = _fallbackParentThreadKey(
        parentUsernames: parentUsernames,
        parentParticipantName: parentParticipantName,
        contactName: contactName,
      );
      return 'direct-$staffId-$parentKey';
    }

    final parentKey = _fallbackParentThreadKey(
      parentUsernames: parentUsernames,
      parentParticipantName: parentParticipantName,
      contactName: contactName,
    );
    final roleSlug = contactName.trim().toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]+'),
          '-',
        );
    return 'direct-$roleSlug-$parentKey';
  }

  String _canonicalDirectParentTeacherConversationId({
    required String staffParticipantId,
    required String studentId,
  }) {
    return 'direct-${staffParticipantId.trim().toUpperCase()}'
        '-stu-${studentId.trim().toUpperCase()}';
  }

  String? _studentIdFromParentTeacherConversationId(String id) {
    final upper = id.trim().toUpperCase();
    if (!upper.startsWith('DIRECT-') || upper.startsWith('DIRECT-STAFF-')) {
      return null;
    }
    const marker = '-STU-';
    final index = upper.lastIndexOf(marker);
    if (index < 0) return null;
    final student = upper.substring(index + marker.length).trim();
    return student.isEmpty ? null : student;
  }

  List<String> _normalizeStudentIds(Iterable<String> raw) {
    final seen = <String>{};
    final ids = <String>[];
    for (final value in raw) {
      final id = value.trim().toUpperCase();
      if (id.isEmpty || !seen.add(id)) continue;
      ids.add(id);
    }
    return ids;
  }

  String? _primaryStudentId(Iterable<String> studentIds) {
    final ids = _normalizeStudentIds(studentIds);
    return ids.isEmpty ? null : ids.first;
  }

  List<String> _conversationStudentIds(Conversation conversation) {
    final fromId = _studentIdFromParentTeacherConversationId(conversation.id);
    return _normalizeStudentIds([
      ...conversation.linkedStudentIds,
      if (fromId != null) fromId,
    ]);
  }

  String _fallbackParentThreadKey({
    required List<String> parentUsernames,
    String? parentParticipantName,
    required String contactName,
  }) {
    final named = parentParticipantName?.trim();
    if (named != null && named.isNotEmpty) {
      return 'name-${named.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';
    }
    if (parentUsernames.isNotEmpty) {
      return 'user-${parentUsernames.first.trim().toLowerCase()}';
    }
    return 'name-${contactName.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';
  }

  bool _sameStaffParticipant(String? left, String? right) {
    return StaffMemberOption.idsEqual(left, right);
  }

  bool _parentUsernamesOverlap(
    Iterable<String> left,
    Iterable<String> right,
  ) {
    final existing = left
        .map((u) => u.trim().toLowerCase())
        .where((u) => u.isNotEmpty)
        .toList();
    final incoming = right
        .map((u) => u.trim().toLowerCase())
        .where((u) => u.isNotEmpty)
        .toList();
    if (existing.isEmpty || incoming.isEmpty) return false;
    for (final a in incoming) {
      for (final b in existing) {
        if (a == b || PhoneUtils.matches(a, b)) return true;
      }
    }
    return false;
  }

  List<Conversation> _findParentTeacherThreads({
    required String staffParticipantId,
    required List<String> studentIds,
    List<String> parentUsernames = const [],
  }) {
    final wantedStudents = _normalizeStudentIds(studentIds).toSet();
    final candidates = <Conversation>[];
    for (final conversation in _conversations) {
      if (conversation.isGroup ||
          conversation.isBroadcast ||
          conversation.isStaffOnlyDirectThread) {
        continue;
      }
      if (!_sameStaffParticipant(
        conversation.staffParticipantId,
        staffParticipantId,
      )) {
        continue;
      }
      final existingStudents = _conversationStudentIds(conversation).toSet();
      final studentHit = wantedStudents.isNotEmpty &&
          existingStudents.any(wantedStudents.contains);
      if (studentHit) {
        candidates.add(conversation);
        continue;
      }
      if (existingStudents.isEmpty &&
          _parentUsernamesOverlap(
            conversation.parentParticipantUsernames,
            parentUsernames,
          )) {
        candidates.add(conversation);
      }
    }
    candidates.sort((a, b) {
      final aHasParent = a.messages.any(
            (m) => m.senderRole == AuthService.roleParent,
          )
          ? 0
          : 1;
      final bHasParent = b.messages.any(
            (m) => m.senderRole == AuthService.roleParent,
          )
          ? 0
          : 1;
      if (aHasParent != bHasParent) {
        return aHasParent.compareTo(bHasParent);
      }
      if (b.messages.length != a.messages.length) {
        return b.messages.length.compareTo(a.messages.length);
      }
      final aTime = a.messages.isEmpty
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : a.messages.first.time;
      final bTime = b.messages.isEmpty
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : b.messages.first.time;
      return aTime.compareTo(bTime);
    });
    return candidates;
  }

  Conversation _linkedParentTeacherThreadToPersist(Conversation open) {
    if (open.isGroup || open.isBroadcast || open.isStaffOnlyDirectThread) {
      return open;
    }
    final staffId = open.staffParticipantId?.trim();
    if (staffId == null || staffId.isEmpty) return open;
    final matches = _findParentTeacherThreads(
      staffParticipantId: staffId,
      studentIds: _conversationStudentIds(open),
      parentUsernames: open.parentParticipantUsernames,
    );
    if (matches.isEmpty) return open;
    final best = matches.first;
    if (best.id == open.id) return open;
    for (final message in open.messages) {
      _copyMessageIfMissing(best, message);
    }
    _mergeConversationParticipants(
      best,
      studentIds: open.linkedStudentIds,
      parentUsernames: open.parentParticipantUsernames,
      staffParticipantId: staffId,
      staffSubjectName: open.staffSubjectName,
    );
    return best;
  }

  bool _isWeakerDuplicateParentTeacherThread(Conversation conversation) {
    if (conversation.isGroup ||
        conversation.isBroadcast ||
        conversation.isStaffOnlyDirectThread) {
      return false;
    }
    final staffId = conversation.staffParticipantId?.trim();
    if (staffId == null || staffId.isEmpty) return false;
    final matches = _findParentTeacherThreads(
      staffParticipantId: staffId,
      studentIds: _conversationStudentIds(conversation),
      parentUsernames: conversation.parentParticipantUsernames,
    );
    if (matches.length < 2) return false;
    return matches.first.id != conversation.id;
  }

  String openOrCreateConversation({
    required String contactName,
    required String role,
    String? parentParticipantName,
    String? staffParticipantId,
    String? counterpartyStaffId,
    String? staffSubjectName,
    List<String>? linkedStudentIds,
    List<String>? parentParticipantUsernames,
  }) {
    final normalizedRole = role.trim().toLowerCase();
    final staffId = staffParticipantId?.trim();
    final peerStaffId = counterpartyStaffId?.trim();
    final hasStaffThread = staffId != null && staffId.isNotEmpty;
    final studentIds = _normalizeStudentIds(linkedStudentIds ?? const []);
    final parentUsernames = parentParticipantUsernames
            ?.map((u) => u.trim().toLowerCase())
            .where((u) => u.isNotEmpty)
            .toList() ??
        const <String>[];
    final isStaffToStaff = hasStaffThread &&
        peerStaffId != null &&
        peerStaffId.isNotEmpty &&
        (parentParticipantName == null || parentParticipantName.trim().isEmpty) &&
        studentIds.isEmpty &&
        parentUsernames.isEmpty;

    if (hasStaffThread && !isStaffToStaff) {
      return _openOrCreateParentTeacherConversation(
        contactName: contactName,
        role: role,
        staffId: staffId,
        parentParticipantName: parentParticipantName,
        staffSubjectName: staffSubjectName,
        studentIds: studentIds,
        parentUsernames: parentUsernames,
      );
    }

    for (final conversation in _conversations) {
      if (conversation.isGroup || conversation.isBroadcast) continue;

      if (isStaffToStaff) {
        if (!_staffPeerPairMatches(conversation, staffId, peerStaffId)) {
          continue;
        }
        _mergeConversationParticipants(
          conversation,
          staffParticipantId: staffId,
          counterpartyStaffId: peerStaffId,
          staffSubjectName: staffSubjectName,
        );
        _canonicalizeStaffToStaffThread(conversation);
        return conversation.id;
      }

      if (parentParticipantName != null &&
          conversation.parentParticipantName?.trim().toLowerCase() ==
              parentParticipantName.trim().toLowerCase() &&
          conversation.role.trim().toLowerCase() == normalizedRole &&
          !hasStaffThread) {
        _mergeConversationParticipants(
          conversation,
          studentIds: studentIds,
          parentUsernames: parentUsernames,
          staffSubjectName: staffSubjectName,
        );
        return conversation.id;
      }

      if (conversation.name == contactName &&
          conversation.role.trim().toLowerCase() == normalizedRole &&
          !hasStaffThread) {
        _mergeConversationParticipants(
          conversation,
          studentIds: studentIds,
          parentUsernames: parentUsernames,
          staffSubjectName: staffSubjectName,
        );
        return conversation.id;
      }
    }

    final id = _deterministicDirectConversationId(
      contactName: contactName,
      staffParticipantId: staffId,
      counterpartyStaffId: peerStaffId,
      studentIds: studentIds,
      parentUsernames: parentUsernames,
      parentParticipantName: parentParticipantName,
    );
    final existingById = _conversations.indexWhere((c) => c.id == id);
    if (existingById >= 0) {
      _mergeConversationParticipants(
        _conversations[existingById],
        studentIds: studentIds,
        parentUsernames: parentUsernames,
        staffParticipantId: staffId,
        counterpartyStaffId: peerStaffId,
        staffSubjectName: staffSubjectName,
      );
      return id;
    }

    _conversations.insert(
      0,
      Conversation(
        id: id,
        name: contactName,
        role: role,
        messages: [],
        parentParticipantName: parentParticipantName?.trim(),
        staffParticipantId: staffId,
        counterpartyStaffId: peerStaffId,
        staffSubjectName: staffSubjectName?.trim(),
        linkedStudentIds: studentIds,
        parentParticipantUsernames: List.from(parentUsernames),
      ),
    );
    return id;
  }

  String _openOrCreateParentTeacherConversation({
    required String contactName,
    required String role,
    required String staffId,
    String? parentParticipantName,
    String? staffSubjectName,
    required List<String> studentIds,
    required List<String> parentUsernames,
  }) {
    var lookupStudents = List<String>.from(studentIds);
    if (lookupStudents.isEmpty &&
        parentParticipantName != null &&
        parentParticipantName.trim().isNotEmpty) {
      final recipient = MessagingAccessService.findParentRecipient(
        parentParticipantName,
        schoolId: AuthService.activeSchoolId,
      );
      lookupStudents = _normalizeStudentIds(recipient?.studentIds ?? const []);
    }

    final matches = _findParentTeacherThreads(
      staffParticipantId: staffId,
      studentIds: lookupStudents,
      parentUsernames: parentUsernames,
    );

    if (matches.isNotEmpty) {
      final match = matches.first;
      _mergeConversationParticipants(
        match,
        studentIds: lookupStudents,
        parentUsernames: parentUsernames,
        staffParticipantId: staffId,
        staffSubjectName: staffSubjectName,
      );
      for (final other in matches.skip(1)) {
        for (final message in other.messages) {
          _copyMessageIfMissing(match, message);
        }
        _mergeConversationParticipants(
          match,
          studentIds: other.linkedStudentIds,
          parentUsernames: other.parentParticipantUsernames,
        );
      }
      return match.id;
    }

    final threadStudent = _primaryStudentId(lookupStudents);
    final id = _deterministicDirectConversationId(
      contactName: contactName,
      staffParticipantId: staffId,
      studentIds: threadStudent == null ? const [] : [threadStudent],
      parentUsernames: parentUsernames,
      parentParticipantName: parentParticipantName,
    );
    final existingById = _conversations.indexWhere((c) => c.id == id);
    if (existingById >= 0) {
      _mergeConversationParticipants(
        _conversations[existingById],
        studentIds: lookupStudents,
        parentUsernames: parentUsernames,
        staffParticipantId: staffId,
        staffSubjectName: staffSubjectName,
      );
      return id;
    }

    final created = Conversation(
      id: id,
      name: contactName,
      role: role,
      messages: [],
      parentParticipantName: parentParticipantName?.trim(),
      staffParticipantId: staffId,
      staffSubjectName: staffSubjectName?.trim(),
      linkedStudentIds: lookupStudents,
      parentParticipantUsernames: List.from(parentUsernames),
    );
    _conversations.insert(0, created);
    return created.id;
  }

  void _mergeConversationParticipants(
    Conversation conversation, {
    List<String> studentIds = const [],
    List<String> parentUsernames = const [],
    String? staffParticipantId,
    String? counterpartyStaffId,
    String? staffSubjectName,
  }) {
    final mergedStudents = {
      ...conversation.linkedStudentIds,
      ...studentIds,
    }.toList();
    conversation.linkedStudentIds
      ..clear()
      ..addAll(mergedStudents);

    final mergedUsernames = {
      ...conversation.parentParticipantUsernames.map((u) => u.toLowerCase()),
      ...parentUsernames,
    }.toList();
    conversation.parentParticipantUsernames
      ..clear()
      ..addAll(mergedUsernames);

    final staffId = staffParticipantId?.trim();
    if (staffId != null &&
        staffId.isNotEmpty &&
        (conversation.staffParticipantId == null ||
            conversation.staffParticipantId!.trim().isEmpty)) {
      conversation.staffParticipantId = staffId;
    }

    final peerId = counterpartyStaffId?.trim();
    if (peerId != null &&
        peerId.isNotEmpty &&
        (conversation.counterpartyStaffId == null ||
            conversation.counterpartyStaffId!.trim().isEmpty)) {
      conversation.counterpartyStaffId = peerId;
    }

    final subject = staffSubjectName?.trim();
    if (subject != null &&
        subject.isNotEmpty &&
        (conversation.staffSubjectName == null ||
            conversation.staffSubjectName!.trim().isEmpty)) {
      conversation.staffSubjectName = subject;
    }
  }

  List<SchoolClass> getTeacherClasses([String? teacherId]) {
    final id = teacherId ??
        AuthService.currentUser?.linkedTeacherId ??
        'TCH-1001';
    return getClassAssignmentsForTeacher(id)
        .map(
          (assignment) => SchoolClass(
            name: assignment.className,
            subject: assignment.subject?.trim().isNotEmpty == true
                ? assignment.subject!
                : (assignment.isHomeroom ? 'Homeroom' : 'Subject'),
            schedule: assignment.schedule,
            room: assignment.room,
            students: assignment.students
                .map(
                  (student) => Student(
                    name: student.name,
                    grade: student.grade,
                    parentName: student.parentName,
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }

  List<ClassAssignment> getClassAssignmentsForTeacher(String teacherId) {
    final id = teacherId.trim().toUpperCase();
    final teacher = TeacherRegistryService.instance.lookupById(id);
    if (teacher != null) {
      if (teacher.classAssignments.isNotEmpty) {
        return teacher.classAssignments
            .map((assignment) => _classAssignmentForTeacher(teacher, assignment))
            .toList();
      }
      final parsed = _parseAssignedClasses(teacher.assignedClass);
      if (parsed.isNotEmpty) {
        final hasHomeroom =
            teacher.roles.contains(TeacherStaffRole.homeroomTeacher);
        final hasSubject =
            teacher.roles.contains(TeacherStaffRole.subjectTeacher);
        return [
          for (var i = 0; i < parsed.length; i++)
            _classAssignmentForTeacher(
              teacher,
              TeacherClassAssignment(
                className: parsed[i],
                role: (i == 0 && hasHomeroom)
                    ? TeacherStaffRole.homeroomTeacher
                    : TeacherStaffRole.subjectTeacher,
              ),
              subjectOverride: hasSubject ? teacher.subject : null,
            ),
        ];
      }
    }

    final links = _teacherAssignments
        .where((link) => (link['teacherId'] as String).toUpperCase() == id)
        .toList();

    return links.map((link) {
      final className = link['className'] as String;
      final role = link['role'] as ClassTeacherRole;
      return ClassAssignment(
        className: className,
        role: role,
        subject: link['subject'] as String?,
        room: _classRooms[className] ?? '',
        schedule: _classSchedules[className] ?? '',
        students: getStudentsForClass(className),
        homeroomTeacherName: _homeroomTeacherNames[className],
      );
    }).toList();
  }

  ClassAssignment _classAssignmentForTeacher(
    AdminTeacherRecord teacher,
    TeacherClassAssignment assignment, {
    String? subjectOverride,
  }) {
    final className = assignment.className;
    _ensureClassShell(className);
    final isHomeroom = assignment.role == TeacherStaffRole.homeroomTeacher;
    if (isHomeroom) {
      _homeroomTeacherIds[className] = teacher.teacherId;
      _homeroomTeacherNames[className] = teacher.fullName;
    }
    return ClassAssignment(
      className: className,
      role: isHomeroom ? ClassTeacherRole.homeroom : ClassTeacherRole.subject,
      // Homeroom/ST is authority; subjects taught are independent.
      subject: _subjectLabelForAssignment(teacher, assignment, subjectOverride),
      room: _classRooms[className] ?? '',
      schedule: _classSchedules[className] ?? '',
      students: getStudentsForClass(className, schoolId: teacher.schoolId),
      homeroomTeacherName: _homeroomTeacherNames[className],
    );
  }

  String? _subjectLabelForAssignment(
    AdminTeacherRecord teacher,
    TeacherClassAssignment assignment,
    String? subjectOverride,
  ) {
    final slots = _subjectSlotsForAssignment(teacher, assignment);
    if (slots.isNotEmpty) {
      return slots.map((slot) => slot.subjectName).join(', ');
    }
    final fallback = subjectOverride ?? teacher.subject;
    return fallback.trim().isEmpty ? null : fallback;
  }

  List<ClassSubjectTeacher> getSubjectsForClass(String className) {
    final merged = <ClassSubjectTeacher>[];
    final seen = <String>{};
    for (final entry in _classSubjectTeachers.entries) {
      if (!_classNamesMatch(entry.key, className)) continue;
      for (final item in entry.value) {
        final key = '${item.teacherId}|${item.subject}';
        if (seen.add(key)) merged.add(item);
      }
    }
    return List.unmodifiable(merged);
  }

  List<StudentRef> getStudentsForClass(String className, {String? schoolId}) {
    final normalized = className.trim();
    final registryStudents = StudentRegistryService.instance.studentsForClass(
      normalized,
      schoolId: schoolId ?? AuthService.activeSchoolId,
    );
    final rosterCache = <StudentRef>[
      for (final entry in _classRosters.entries)
        if (_classNamesMatch(entry.key, normalized)) ...entry.value,
    ];

    if (registryStudents.isNotEmpty) {
      return registryStudents.map((record) {
        final ref = _studentRefFromRecord(record);
        for (final cached in rosterCache) {
          if (cached.registryStudentId?.toUpperCase() ==
                  record.studentId.toUpperCase() ||
              cached.name == record.fullName) {
            ref.photoPath ??= cached.photoPath ?? record.photoPath;
            break;
          }
        }
        ref.photoPath ??= record.photoPath;
        return ref;
      }).toList();
    }

    return List.unmodifiable(rosterCache);
  }

  List<String> getTeacherClassNames([String? teacherId]) {
    final id = teacherId ??
        AuthService.currentUser?.linkedTeacherId ??
        'TCH-1001';
    return getClassAssignmentsForTeacher(id).map((a) => a.className).toList();
  }

  StudentRef? getStudentById(String studentId) {
    final id = studentId.trim();
    for (final roster in _classRosters.values) {
      for (final student in roster) {
        if (student.id == id ||
            student.registryStudentId?.toUpperCase() == id.toUpperCase()) {
          return student;
        }
      }
    }
    return null;
  }

  String? classNameForStudent(String studentId) {
    final db = SchoolDatabaseService.instance;
    if (db.isInitialized) {
      final fromDb = db.classNameForStudent(studentId);
      if (fromDb != null) return fromDb;
    }

    final normalized = studentId.trim().toUpperCase();
    for (final entry in _classRosters.entries) {
      if (entry.value.any(
        (student) =>
            student.id == studentId ||
            student.registryStudentId?.toUpperCase() == normalized,
      )) {
        return entry.key;
      }
    }
    final record = StudentRegistryService.instance.lookupById(studentId);
    return record?.className;
  }

  List<DailyActivityOption> getDailyActivityOptions() => [
        DailyActivityOption(
          id: 'great_day',
          label: 'He/She had a great day',
        ),
        DailyActivityOption(
          id: 'fell_down',
          label: 'He/She fell down during play time today',
        ),
        DailyActivityOption(
          id: 'no_lunch',
          label: 'He/She did not finish snack/lunch',
        ),
        DailyActivityOption(
          id: 'was_sick',
          label: 'He/She was ill/sick at school today',
        ),
        DailyActivityOption(
          id: 'came_late',
          label: 'He/She came late to school today',
        ),
        DailyActivityOption(
          id: 'no_materials',
          label: 'He/She did not bring full school materials',
        ),
        DailyActivityOption(
          id: 'did_well_test',
          label: 'He/She did well on the test/exam',
        ),
        DailyActivityOption(
          id: 'no_homework',
          label: 'He/She did not finish homework yesterday',
        ),
        DailyActivityOption(
          id: 'extra_help',
          label: 'Please give extra help at home',
        ),
        DailyActivityOption(
          id: 'positive_behavior',
          label: 'Showed excellent behavior and teamwork',
        ),
        DailyActivityOption(
          id: 'needs_rest',
          label: 'Seemed tired — may need more rest at home',
        ),
      ];

  DailyActivityReport? getDailyActivityForStudent(
    String studentId,
    DateTime date, {
    String? studentName,
  }) {
    try {
      return _dailyActivities.firstWhere(
        (report) =>
            _dailyActivityMatchesStudent(
              report,
              studentId,
              studentName: studentName,
            ) &&
            report.date.year == date.year &&
            report.date.month == date.month &&
            report.date.day == date.day,
      );
    } catch (_) {
      return null;
    }
  }

  /// Canonical registry id (or roster slug) used to link teacher + parent views.
  String resolveDailyActivityStudentKey({
    required String studentId,
    String? studentName,
  }) {
    final trimmed = studentId.trim();
    if (trimmed.isEmpty && studentName != null) {
      return _canonicalStudentId(studentName: studentName) ?? studentName;
    }

    final byRegistry = StudentRegistryService.instance.lookupById(trimmed);
    if (byRegistry != null) return byRegistry.studentId;

    for (final roster in _classRosters.values) {
      for (final student in roster) {
        if (student.id == trimmed ||
            student.registryStudentId?.toUpperCase() == trimmed.toUpperCase() ||
            (studentName != null && student.name == studentName)) {
          return student.registryStudentId ?? student.id;
        }
      }
    }

    if (studentName != null) {
      final byName = StudentRegistryService.instance.lookupByName(studentName);
      if (byName != null) return byName.studentId;
      for (final roster in _classRosters.values) {
        for (final student in roster) {
          if (student.name == studentName) {
            return student.registryStudentId ?? student.id;
          }
        }
      }
    }

    try {
      final profile = _studentQrProfiles.firstWhere(
        (p) =>
            p.id == trimmed ||
            p.qrCode.toLowerCase() == trimmed.toLowerCase() ||
            (studentName != null && p.name == studentName),
      );
      final record = StudentRegistryService.instance.lookupByName(profile.name);
      return record?.studentId ?? profile.id;
    } catch (_) {}

    return trimmed;
  }

  bool parentCanAccessDailyActivity(String studentId, {String? studentName}) {
    if (AuthService.currentUser?.roleKey != AuthService.roleParent) return true;
    final key = resolveDailyActivityStudentKey(
      studentId: studentId,
      studentName: studentName,
    );
    final linked = AuthService.activeLinkedStudentIds()
        .map((id) => id.trim().toUpperCase())
        .toSet();
    return linked.contains(key.toUpperCase());
  }

  List<DailyActivityReport> dailyActivitiesSnapshot() =>
      List.unmodifiable(_dailyActivities);

  void applyPersistedDailyActivities(List<DailyActivityReport> reports) {
    for (final persisted in reports) {
      final canonicalId = resolveDailyActivityStudentKey(
        studentId: persisted.studentId,
        studentName: persisted.studentName,
      );
      final normalized = DailyActivityReport(
        id: persisted.id,
        studentId: canonicalId,
        studentName: persisted.studentName,
        className: persisted.className,
        date: persisted.date,
        selectedOptionIds: List<String>.from(persisted.selectedOptionIds),
        teacherComment: persisted.teacherComment,
        teacherName: persisted.teacherName,
        parentComment: persisted.parentComment,
        parentSeenAt: persisted.parentSeenAt,
        parentSeenBy: persisted.parentSeenBy,
      );

      final index = _dailyActivities.indexWhere(
        (item) =>
            _dailyActivityMatchesStudent(
              item,
              normalized.studentId,
              studentName: normalized.studentName,
            ) &&
            item.date.year == normalized.date.year &&
            item.date.month == normalized.date.month &&
            item.date.day == normalized.date.day,
      );
      if (index >= 0) {
        _dailyActivities[index] = normalized;
      } else {
        _dailyActivities.add(normalized);
      }

      final numeric = RegExp(r'act-(\d+)').firstMatch(normalized.id);
      if (numeric != null) {
        final value = int.tryParse(numeric.group(1)!);
        if (value != null && value >= _nextActivityId) {
          _nextActivityId = value + 1;
        }
      }
    }
  }

  bool _dailyActivityMatchesStudent(
    DailyActivityReport report,
    String studentId, {
    String? studentName,
  }) {
    final queryKey = resolveDailyActivityStudentKey(
      studentId: studentId,
      studentName: studentName ?? report.studentName,
    );
    final reportKey = resolveDailyActivityStudentKey(
      studentId: report.studentId,
      studentName: report.studentName,
    );
    if (queryKey.toUpperCase() == reportKey.toUpperCase()) return true;
    if (studentName != null && report.studentName == studentName) return true;
    return report.studentId.toUpperCase() == studentId.trim().toUpperCase();
  }

  String? _canonicalStudentId({String? studentId, String? studentName}) {
    if (studentId != null && studentId.trim().isNotEmpty) {
      return resolveDailyActivityStudentKey(
        studentId: studentId,
        studentName: studentName,
      );
    }
    if (studentName != null) {
      return resolveDailyActivityStudentKey(
        studentId: '',
        studentName: studentName,
      );
    }
    return null;
  }

  List<DailyActivityReport> getDailyActivitiesForClass(String className) {
    return _dailyActivities
        .where((report) => _classNamesMatch(report.className, className))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  void saveDailyActivity({
    required String studentId,
    required String studentName,
    required String className,
    required DateTime date,
    required List<String> selectedOptionIds,
    required String teacherComment,
    required String teacherName,
  }) {
    final canonicalId = resolveDailyActivityStudentKey(
      studentId: studentId,
      studentName: studentName,
    );
    final existing = getDailyActivityForStudent(
      canonicalId,
      date,
      studentName: studentName,
    );
    if (existing != null) {
      existing.selectedOptionIds.clear();
      existing.selectedOptionIds.addAll(selectedOptionIds);
      existing.teacherComment = teacherComment;
    } else {
      _dailyActivities.insert(
        0,
        DailyActivityReport(
          id: 'act-${_nextActivityId++}',
          studentId: canonicalId,
          studentName: studentName,
          className: className,
          date: date,
          selectedOptionIds: List<String>.from(selectedOptionIds),
          teacherComment: teacherComment,
          teacherName: teacherName,
        ),
      );
    }

    _notifyParentForDailyActivity(
      studentId: canonicalId,
      studentName: studentName,
      teacherName: teacherName,
    );
    _persistDailyActivities();
  }

  void markDailyActivitySeen({
    required String reportId,
    required String parentName,
    String? parentComment,
  }) {
    final report = _dailyActivities.cast<DailyActivityReport?>().firstWhere(
          (item) => item!.id == reportId,
          orElse: () => null,
        );
    if (report == null) return;
    if (!parentCanAccessDailyActivity(
      report.studentId,
      studentName: report.studentName,
    )) {
      return;
    }

    report.parentSeenAt = DateTime.now();
    report.parentSeenBy = parentName;
    if (parentComment != null && parentComment.trim().isNotEmpty) {
      report.parentComment = parentComment.trim();
    }

    NotificationService.instance.push(
      title: 'Parent viewed daily report',
      body: '$parentName viewed the daily activity report for ${report.studentName}.',
      type: NotificationType.dailyActivitySeen,
      fromRole: AuthService.roleParent,
      fromName: parentName,
      recipientRole: AuthService.roleTeacher,
      targetStudentId: report.studentId,
    );
    _persistDailyActivities();
  }

  void _notifyParentForDailyActivity({
    required String studentId,
    required String studentName,
    required String teacherName,
  }) {
    NotificationService.instance.push(
      title: 'Daily activity report',
      body: '$teacherName posted today\'s activities for $studentName.',
      type: NotificationType.dailyActivity,
      fromRole: AuthService.roleTeacher,
      fromName: teacherName,
      recipientRole: AuthService.roleParent,
      targetStudentId: studentId,
    );
  }

  void _persistDailyActivities() {
    DailyActivityPersistenceService.instance.saveFromService();
  }

  List<HomeworkItem> getHomeworkForParent() {
    final classes = getChildren().map((child) => child.className).toSet();
    return _homework
        .where((item) => classes.any((c) => _classNamesMatch(c, item.className)))
        .toList()
      ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
  }

  List<HomeworkItem> getHomeworkForClass(String className) {
    return _homework
        .where((item) => _classNamesMatch(className, item.className))
        .toList()
      ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
  }

  List<HomeworkItem> getHomeworkForTeacher(String teacherId) {
    final classNames = getTeacherClassNames(teacherId);
    return _homework
        .where(
          (item) => classNames.any((c) => _classNamesMatch(c, item.className)),
        )
        .toList()
      ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
  }

  List<HomeworkItem> homeworkSnapshot() => List.unmodifiable(_homework);

  void applyPersistedHomework(List<HomeworkItem> items) {
    for (final persisted in items) {
      final normalized = HomeworkItem(
        id: persisted.id,
        className: _canonicalClassName(persisted.className),
        subject: persisted.subject,
        description: persisted.description,
        teacherName: persisted.teacherName,
        teacherId: persisted.teacherId,
        postedAt: persisted.postedAt,
        subjectId: persisted.subjectId,
        teachingSlotId: persisted.teachingSlotId,
        attachmentPaths: List<String>.from(persisted.attachmentPaths),
        studentWorksheetPaths: persisted.studentWorksheetPaths.map(
          (key, value) => MapEntry(key, List<String>.from(value)),
        ),
      );

      final index = _homework.indexWhere((item) => item.id == normalized.id);
      if (index >= 0) {
        _homework[index] = normalized;
      } else {
        _homework.add(normalized);
      }

      final numeric = RegExp(r'hw-(\d+)').firstMatch(normalized.id);
      if (numeric != null) {
        final value = int.tryParse(numeric.group(1)!);
        if (value != null && value >= _nextHomeworkId) {
          _nextHomeworkId = value + 1;
        }
      }
    }
  }

  void addHomework({
    required String className,
    required String subject,
    required String description,
    required String teacherName,
    required String teacherId,
    String? subjectId,
    String? teachingSlotId,
    List<String> attachmentPaths = const [],
  }) {
    final canonicalClass = _canonicalClassName(className);
    _homework.insert(
      0,
      HomeworkItem(
        id: 'hw-${_nextHomeworkId++}',
        className: canonicalClass,
        subject: subject,
        description: description.trim(),
        teacherName: teacherName,
        teacherId: teacherId,
        postedAt: DateTime.now(),
        subjectId: subjectId,
        teachingSlotId: teachingSlotId,
        attachmentPaths: List.from(attachmentPaths),
      ),
    );

    _notifyParentsInClass(
      className: canonicalClass,
      title: 'New homework — $subject',
      body: '$teacherName: $description',
      type: NotificationType.homework,
      fromRole: AuthService.roleTeacher,
      fromName: teacherName,
    );
    _persistHomework();
  }

  bool updateHomework({
    required String id,
    required String description,
    List<String>? attachmentPaths,
  }) {
    try {
      final item = _homework.firstWhere((hw) => hw.id == id);
      item.description = description.trim();
      if (attachmentPaths != null) {
        item.attachmentPaths
          ..clear()
          ..addAll(attachmentPaths);
      }
      _persistHomework();
      return true;
    } catch (_) {
      return false;
    }
  }

  List<String> studentWorksheetsFor({
    required String homeworkId,
    required String studentId,
  }) {
    try {
      final item = _homework.firstWhere((hw) => hw.id == homeworkId);
      return item.worksheetsForStudent(studentId);
    } catch (_) {
      return const [];
    }
  }

  bool addStudentWorksheets({
    required String homeworkId,
    required String studentId,
    required List<String> paths,
  }) {
    if (paths.isEmpty) return false;
    try {
      final item = _homework.firstWhere((hw) => hw.id == homeworkId);
      final key = studentId.trim().toUpperCase();
      final existing = item.studentWorksheetPaths[key] ?? <String>[];
      item.studentWorksheetPaths[key] = [...existing, ...paths];
      _persistHomework();
      return true;
    } catch (_) {
      return false;
    }
  }

  bool removeStudentWorksheet({
    required String homeworkId,
    required String studentId,
    required String path,
  }) {
    try {
      final item = _homework.firstWhere((hw) => hw.id == homeworkId);
      final key = studentId.trim().toUpperCase();
      final existing = List<String>.from(item.studentWorksheetPaths[key] ?? []);
      existing.remove(path);
      if (existing.isEmpty) {
        item.studentWorksheetPaths.remove(key);
      } else {
        item.studentWorksheetPaths[key] = existing;
      }
      _persistHomework();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _persistHomework() {
    HomeworkPersistenceService.instance.saveFromService();
  }

  List<LearningMaterialItem> getLearningMaterialsForClass(String className) {
    return _learningMaterials
        .where((item) => _classNamesMatch(item.className, className))
        .toList()
      ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
  }

  List<LearningMaterialItem> getLearningMaterialsForParent() {
    final classNames = getChildren().map((child) => child.className).toSet();
    return _learningMaterials
        .where(
          (item) => classNames.any((c) => _classNamesMatch(c, item.className)),
        )
        .toList()
      ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
  }

  List<LearningMaterialItem> learningMaterialsSnapshot() =>
      List.unmodifiable(_learningMaterials);

  void applyPersistedLearningMaterials(List<LearningMaterialItem> items) {
    for (final persisted in items) {
      final normalized = LearningMaterialItem(
        id: persisted.id,
        className: _canonicalClassName(persisted.className),
        subject: persisted.subject,
        bookName: persisted.bookName,
        materialName: persisted.materialName,
        filePath: persisted.filePath,
        teacherId: persisted.teacherId,
        teacherName: persisted.teacherName,
        postedAt: persisted.postedAt,
        subjectId: persisted.subjectId,
        teachingSlotId: persisted.teachingSlotId,
        isFree: persisted.isFree,
        price: persisted.price,
      );

      final index =
          _learningMaterials.indexWhere((item) => item.id == normalized.id);
      if (index >= 0) {
        _learningMaterials[index] = normalized;
      } else {
        _learningMaterials.add(normalized);
      }

      final numeric = RegExp(r'lm-(\d+)').firstMatch(normalized.id);
      if (numeric != null) {
        final value = int.tryParse(numeric.group(1)!);
        if (value != null && value >= _nextLearningMaterialId) {
          _nextLearningMaterialId = value + 1;
        }
      }
    }
  }

  void addLearningMaterial({
    required String className,
    required String subject,
    required String bookName,
    required String materialName,
    required String filePath,
    required String teacherName,
    required String teacherId,
    String? subjectId,
    String? teachingSlotId,
    bool isFree = true,
    double? price,
  }) {
    _learningMaterials.insert(
      0,
      LearningMaterialItem(
        id: 'lm-${_nextLearningMaterialId++}',
        className: _canonicalClassName(className),
        subject: subject.trim(),
        bookName: bookName.trim(),
        materialName: materialName.trim(),
        filePath: filePath,
        teacherName: teacherName,
        teacherId: teacherId,
        postedAt: DateTime.now(),
        subjectId: subjectId,
        teachingSlotId: teachingSlotId,
        isFree: isFree,
        price: isFree ? null : price,
      ),
    );
    _persistLearningMaterials();
  }

  bool updateLearningMaterial({
    required String id,
    required String bookName,
    required String materialName,
    String? filePath,
    bool? isFree,
    double? price,
  }) {
    try {
      final item = _learningMaterials.firstWhere((entry) => entry.id == id);
      item.bookName = bookName.trim();
      item.materialName = materialName.trim();
      if (filePath != null && filePath.trim().isNotEmpty) {
        item.filePath = filePath.trim();
      }
      if (isFree != null) {
        item.isFree = isFree;
        item.price = isFree ? null : price;
      }
      _persistLearningMaterials();
      return true;
    } catch (_) {
      return false;
    }
  }

  bool deleteLearningMaterial(String id) {
    final index = _learningMaterials.indexWhere((item) => item.id == id);
    if (index < 0) return false;
    _learningMaterials.removeAt(index);
    _persistLearningMaterials();
    unawaited(LearningMaterialsPersistenceService.instance.deleteFromCloud(id));
    return true;
  }

  void _persistLearningMaterials() {
    LearningMaterialsPersistenceService.instance.saveFromService();
  }

  String _canonicalClassName(String className) {
    final parts = StudentRegistryService.parseClassNameParts(className);
    if (parts != null) {
      return StudentRegistryService.buildClassName(parts.grade, parts.section);
    }
    return className.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _classNamesMatch(String a, String b) {
    return StudentRegistryService.classNamesMatch(a, b);
  }

  bool _gradeReportMatches(
    StudentGradeReport report,
    String studentName,
    String className,
  ) {
    return report.studentName == studentName &&
        _classNamesMatch(report.className, className);
  }

  StudentGradeReport? _findGradeReport({
    required String studentName,
    required String className,
  }) {
    try {
      return _gradeReports.firstWhere(
        (item) => _gradeReportMatches(item, studentName, className),
      );
    } catch (_) {
      return null;
    }
  }

  SubjectGrade? _findSubjectGrade({
    required String studentName,
    required String className,
    required String subject,
  }) {
    final report = _findGradeReport(
      studentName: studentName,
      className: className,
    );
    if (report == null) return null;
    try {
      return report.subjects.firstWhere((item) => item.subject == subject);
    } catch (_) {
      return null;
    }
  }

  List<GalleryPost> getGalleryForClass(String className) {
    return _galleryPosts
        .where((post) => _classNamesMatch(post.className, className))
        .toList()
      ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
  }

  List<GalleryPost> getGalleryForParent() {
    final classNames = getChildren().map((child) => child.className).toSet();
    return _galleryPosts
        .where(
          (post) => classNames.any((name) => _classNamesMatch(name, post.className)),
        )
        .toList()
      ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
  }

  void addGalleryPost({
    required String className,
    required GalleryPostType type,
    required String title,
    required String caption,
    required String authorName,
    String? mediaLabel,
    String? mediaPath,
  }) {
    _galleryPosts.insert(
      0,
      GalleryPost(
        id: 'gal-${_nextGalleryId++}',
        className: className,
        type: type,
        title: title.trim(),
        caption: caption.trim(),
        authorName: authorName,
        postedAt: DateTime.now(),
        mediaLabel: mediaLabel,
        mediaPath: mediaPath,
      ),
    );

    _notifyParentsInClass(
      className: className,
      title: 'New gallery post',
      body: '$authorName shared "$title" with $className.',
      type: NotificationType.gallery,
      fromRole: AuthService.roleTeacher,
      fromName: authorName,
    );
    _persistSchoolContent();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  AttendanceSession? getAttendanceSession(String className, DateTime date) {
    try {
      return _attendanceSessions.firstWhere(
        (session) =>
            _classNamesMatch(session.className, className) &&
            _isSameDay(session.date, date),
      );
    } catch (_) {
      return null;
    }
  }

  List<AttendanceSession> getAttendanceSessionsForDate(DateTime date) {
    return _attendanceSessions
        .where((session) => _isSameDay(session.date, date))
        .toList()
      ..sort((a, b) => a.className.compareTo(b.className));
  }

  String _gradeForStudent(String studentName, String className) {
    final student = StudentRegistryService.instance.lookupByName(studentName);
    if (student != null && student.grade.trim().isNotEmpty) {
      return student.grade.trim();
    }
    for (final grade in ['Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6', 'Grade 7', 'Grade 8']) {
      if (className.startsWith(grade)) return grade;
    }
    return className.trim();
  }

  DailyAttendanceReport buildDailyAttendanceReport(DateTime date) {
    final sessions = getAttendanceSessionsForDate(date);
    final records = <StudentAttendanceRecord>[];
    final summaries = <AttendanceSessionSummary>[];

    var present = 0;
    var late = 0;
    var absent = 0;

    for (final session in sessions) {
      var sessionPresent = 0;
      var sessionLate = 0;
      var sessionAbsent = 0;

      for (final entry in session.entries) {
        switch (entry.status) {
          case AttendanceStatus.present:
            sessionPresent++;
            present++;
          case AttendanceStatus.late:
            sessionLate++;
            late++;
          case AttendanceStatus.absent:
            sessionAbsent++;
            absent++;
        }
        records.add(
          StudentAttendanceRecord(
            studentName: entry.studentName,
            grade: _gradeForStudent(entry.studentName, session.className),
            className: session.className,
            status: entry.status,
            conductedBy: session.conductedBy,
            date: DateTime(date.year, date.month, date.day),
          ),
        );
      }

      summaries.add(
        AttendanceSessionSummary(
          className: session.className,
          conductedBy: session.conductedBy,
          presentCount: sessionPresent,
          lateCount: sessionLate,
          absentCount: sessionAbsent,
        ),
      );
    }

    return DailyAttendanceReport(
      date: DateTime(date.year, date.month, date.day),
      presentCount: present,
      lateCount: late,
      absentCount: absent,
      sessions: summaries,
      records: records,
    );
  }

  AttendanceDateRangeReport buildAttendanceReportForRange({
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    final from = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final to = DateTime(toDate.year, toDate.month, toDate.day);
    final start = from.isBefore(to) ? from : to;
    final end = from.isBefore(to) ? to : from;

    final dailyReports = <DailyAttendanceReport>[];
    final records = <StudentAttendanceRecord>[];
    var present = 0;
    var late = 0;
    var absent = 0;

    for (var day = start;
        !day.isAfter(end);
        day = day.add(const Duration(days: 1))) {
      final daily = buildDailyAttendanceReport(day);
      dailyReports.add(daily);
      present += daily.presentCount;
      late += daily.lateCount;
      absent += daily.absentCount;
      records.addAll(daily.records);
    }

    return AttendanceDateRangeReport(
      fromDate: start,
      toDate: end,
      presentCount: present,
      lateCount: late,
      absentCount: absent,
      dailyReports: dailyReports,
      records: records,
    );
  }

  List<AttendanceSession> getAttendanceHistory(String className) {
    return _attendanceSessions
        .where((session) => _classNamesMatch(session.className, className))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  void saveAttendanceSession({
    required String className,
    required DateTime date,
    required String conductedBy,
    required List<StudentAttendanceEntry> entries,
    bool notifyParents = true,
  }) {
    final existing = getAttendanceSession(className, date);
    if (existing != null) {
      _attendanceSessions.remove(existing);
    }

    _attendanceSessions.add(
      AttendanceSession(
        className: className,
        date: date,
        conductedBy: conductedBy,
        entries: entries
            .map(
              (entry) => StudentAttendanceEntry(
                studentName: entry.studentName,
                status: entry.status,
              ),
            )
            .toList(),
      ),
    );

    if (notifyParents) {
      _notifyParentsInClass(
        className: className,
        title: 'Attendance recorded',
        body: '$conductedBy saved attendance for $className.',
        type: NotificationType.attendance,
        fromRole: AuthService.roleTeacher,
        fromName: conductedBy,
      );
    }
    _persistSchoolContent();
  }

  bool updateSubjectGrade({
    required String studentName,
    required String className,
    required double score,
    required String subject,
    String? comment,
    List<String>? markPhotoPaths,
    List<String>? attachmentPaths,
    String? enteredByTeacherId,
    String? subjectId,
    String? teachingSlotId,
    List<AssessmentMark>? assessments,
  }) {
    final subjectGrade = _findSubjectGrade(
      studentName: studentName,
      className: className,
      subject: subject,
    );
    final report = _findGradeReport(
      studentName: studentName,
      className: className,
    );
    if (subjectGrade == null || report == null) return false;
    _normalizeSubjectWorkflow(subjectGrade);
    if (!subjectGrade.canTeacherEdit) return false;
    if (subjectGrade.status == SubjectGradeStatus.rejected ||
        subjectGrade.status == SubjectGradeStatus.changesRequested) {
      subjectGrade.status = SubjectGradeStatus.draft;
    }
    subjectGrade.score = score;
    if (assessments != null) {
      subjectGrade.assessments
        ..clear()
        ..addAll(assessments.map((m) => m.copy()));
      if (subjectGrade.assessments.any((m) => m.isEntered)) {
        subjectGrade.applyWeightedScore(
          missingCountsAsZero: _markbookMissingCountsAsZero(),
        );
      }
    }
    if (comment != null) subjectGrade.comment = comment;
    if (markPhotoPaths != null) {
      subjectGrade.markPhotoPaths
        ..clear()
        ..addAll(markPhotoPaths);
    }
    if (attachmentPaths != null) {
      subjectGrade.attachmentPaths
        ..clear()
        ..addAll(attachmentPaths);
    }
    if (enteredByTeacherId != null && enteredByTeacherId.isNotEmpty) {
      subjectGrade.enteredByTeacherId = enteredByTeacherId;
    }
    if (subjectId != null && subjectId.isNotEmpty) {
      subjectGrade.subjectId = subjectId;
    }
    if (teachingSlotId != null && teachingSlotId.isNotEmpty) {
      subjectGrade.teachingSlotId = teachingSlotId;
    }

    if (subjectGrade.isVisibleToParent) {
      _notifyLinkedParentsForGrade(
        report: report,
        subject: subject,
        score: score,
        maxScore: subjectGrade.maxScore,
        updated: true,
        teacherId: enteredByTeacherId ?? subjectGrade.enteredByTeacherId,
      );
    }
    _persistGradeReports();
    return true;
  }

  bool publishSubjectGrade({
    required String studentName,
    required String className,
    required String subject,
    String? teacherId,
  }) {
    final schoolId = AuthService.activeSchoolId;
    if (GradeWorkflowService.requireApproval(schoolId)) {
      return submitSubjectGradeForApproval(
        studentName: studentName,
        className: className,
        subject: subject,
        teacherId: teacherId,
      );
    }
    return _publishSubjectGradeDirect(
      studentName: studentName,
      className: className,
      subject: subject,
      teacherId: teacherId,
    );
  }

  bool submitSubjectGradeForApproval({
    required String studentName,
    required String className,
    required String subject,
    String? teacherId,
  }) {
    final subjectGrade = _findSubjectGrade(
      studentName: studentName,
      className: className,
      subject: subject,
    );
    if (subjectGrade == null) return false;
    _normalizeSubjectWorkflow(subjectGrade);
    if (!subjectGrade.canTeacherEdit) return false;

    final report = _findGradeReport(studentName: studentName, className: className);
    if (report == null) return false;

    final schoolId = AuthService.activeSchoolId ?? '';
    final settings = GradeWorkflowService.settingsForSchool(schoolId);
    final before = subjectGrade.status;

    if (!settings.requireApproval) {
      return _finalizeGradeApproval(
        report: report,
        subjectGrade: subjectGrade,
        subject: subject,
        reviewerId: teacherId,
        reviewerName: _actorName(teacherId),
        reviewerRole: AuthService.roleTeacher,
      );
    }

    subjectGrade.status = SubjectGradeStatus.pendingApproval;
    subjectGrade.approvalLevelIndex = 0;
    subjectGrade.submittedAt = DateTime.now();
    subjectGrade.submittedByTeacherId = teacherId;
    subjectGrade.reviewComment = null;
    subjectGrade.publishedToParents = false;
    subjectGrade.publishedAt = null;

    unawaited(
      GradeAuditService.instance.log(
        action: GradeAuditAction.submitted,
        schoolId: schoolId,
        className: className,
        subject: subject,
        studentName: studentName,
        studentId: report.studentId,
        actorId: teacherId,
        actorName: _actorName(teacherId),
        actorRole: AuthService.roleTeacher,
        statusBefore: before,
        statusAfter: subjectGrade.status,
      ),
    );

    if (settings.notifyApproversOnSubmit) {
      _notifyGradeApprovers(
        report: report,
        subject: subject,
        subjectGrade: subjectGrade,
      );
    }

    _persistGradeReports();
    return true;
  }

  bool approveSubjectGrade({
    required String studentName,
    required String className,
    required String subject,
    String? reviewerId,
    String? reviewerName,
    String? reviewerRole,
    String? comment,
  }) {
    final subjectGrade = _findSubjectGrade(
      studentName: studentName,
      className: className,
      subject: subject,
    );
    final report = _findGradeReport(studentName: studentName, className: className);
    if (subjectGrade == null || report == null) return false;
    if (subjectGrade.status != SubjectGradeStatus.pendingApproval) return false;

    if (!GradeWorkflowService.canUserApprove(
      grade: subjectGrade,
      className: className,
      schoolId: AuthService.activeSchoolId,
      roleKey: reviewerRole ?? AuthService.currentUser?.roleKey,
    )) {
      return false;
    }

    final schoolId = AuthService.activeSchoolId ?? '';
    final settings = GradeWorkflowService.settingsForSchool(schoolId);
    final chain = settings.approvalChain;
    final before = subjectGrade.status;

    subjectGrade.lastReviewedAt = DateTime.now();
    subjectGrade.lastReviewedBy = reviewerName ?? _actorName(reviewerId);
    if (comment != null && comment.trim().isNotEmpty) {
      subjectGrade.reviewComment = comment.trim();
    }

    final isFinal =
        chain.isEmpty || subjectGrade.approvalLevelIndex >= chain.length - 1;

    if (isFinal) {
      _finalizeGradeApproval(
        report: report,
        subjectGrade: subjectGrade,
        subject: subject,
        reviewerId: reviewerId,
        reviewerName: reviewerName,
        reviewerRole: reviewerRole,
      );
      if (settings.notifyTeacherOnDecision) {
        _notifyGradeTeacherDecision(
          report: report,
          subject: subject,
          decision: GradeTeacherDecision.approved,
          comment: comment,
        );
      }
    } else {
      subjectGrade.approvalLevelIndex++;
      unawaited(
        GradeAuditService.instance.log(
          action: GradeAuditAction.approved,
          schoolId: schoolId,
          className: className,
          subject: subject,
          studentName: studentName,
          studentId: report.studentId,
          actorId: reviewerId,
          actorName: reviewerName,
          actorRole: reviewerRole,
          detail: 'Advanced to ${GradeWorkflowService.pendingApproverRole(subjectGrade, schoolId)?.label ?? 'next level'}',
          statusBefore: before,
          statusAfter: subjectGrade.status,
        ),
      );
      if (settings.notifyApproversOnSubmit) {
        _notifyGradeApprovers(
          report: report,
          subject: subject,
          subjectGrade: subjectGrade,
        );
      }
      _persistGradeReports();
    }

    return true;
  }

  bool rejectSubjectGrade({
    required String studentName,
    required String className,
    required String subject,
    required String reason,
    String? reviewerId,
    String? reviewerName,
    String? reviewerRole,
  }) {
    return _reviewSubjectGradeDecision(
      studentName: studentName,
      className: className,
      subject: subject,
      nextStatus: SubjectGradeStatus.rejected,
      action: GradeAuditAction.rejected,
      reason: reason,
      reviewerId: reviewerId,
      reviewerName: reviewerName,
      reviewerRole: reviewerRole,
    );
  }

  bool requestSubjectGradeChanges({
    required String studentName,
    required String className,
    required String subject,
    required String comment,
    String? reviewerId,
    String? reviewerName,
    String? reviewerRole,
  }) {
    return _reviewSubjectGradeDecision(
      studentName: studentName,
      className: className,
      subject: subject,
      nextStatus: SubjectGradeStatus.changesRequested,
      action: GradeAuditAction.changesRequested,
      reason: comment,
      reviewerId: reviewerId,
      reviewerName: reviewerName,
      reviewerRole: reviewerRole,
    );
  }

  bool adminUnlockSubjectGrade({
    required String studentName,
    required String className,
    required String subject,
    String? adminId,
    String? adminName,
  }) {
    final subjectGrade = _findSubjectGrade(
      studentName: studentName,
      className: className,
      subject: subject,
    );
    final report = _findGradeReport(studentName: studentName, className: className);
    if (subjectGrade == null || report == null) return false;

    final before = subjectGrade.status;
    subjectGrade.status = SubjectGradeStatus.draft;
    subjectGrade.approvalLevelIndex = 0;
    subjectGrade.publishedToParents = false;
    subjectGrade.publishedAt = null;

    unawaited(
      GradeAuditService.instance.log(
        action: GradeAuditAction.unlocked,
        schoolId: AuthService.activeSchoolId ?? '',
        className: className,
        subject: subject,
        studentName: studentName,
        studentId: report.studentId,
        actorId: adminId,
        actorName: adminName,
        actorRole: AuthService.roleAdmin,
        statusBefore: before,
        statusAfter: subjectGrade.status,
      ),
    );
    _persistGradeReports();
    return true;
  }

  List<SubjectGradePendingItem> pendingGradeApprovals({String? schoolId}) {
    return adminGradeReviewItems(schoolId: schoolId)
        .where(
          (item) =>
              item.subjectGrade.status == SubjectGradeStatus.pendingApproval,
        )
        .toList();
  }

  /// All grade submissions that entered the admin review workflow (any status).
  List<SubjectGradePendingItem> adminGradeReviewItems({String? schoolId}) {
    final normalizedSchool = schoolId?.trim().toUpperCase();
    final items = <SubjectGradePendingItem>[];
    for (final report in _gradeReports) {
      if (normalizedSchool != null && normalizedSchool.isNotEmpty) {
        final student = StudentRegistryService.instance.lookupByName(
          report.studentName,
        );
        if (student != null && student.schoolId.toUpperCase() != normalizedSchool) {
          continue;
        }
      }
      for (final subject in report.subjects) {
        final inWorkflow = subject.status != SubjectGradeStatus.draft ||
            subject.submittedAt != null ||
            subject.lastReviewedAt != null;
        if (!inWorkflow) continue;
        items.add(
          SubjectGradePendingItem(
            report: report,
            subjectGrade: subject,
          ),
        );
      }
    }
    items.sort((a, b) {
      DateTime activityAt(SubjectGrade grade) =>
          grade.lastReviewedAt ??
          grade.submittedAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return activityAt(b.subjectGrade).compareTo(activityAt(a.subjectGrade));
    });
    return items;
  }

  bool _publishSubjectGradeDirect({
    required String studentName,
    required String className,
    required String subject,
    String? teacherId,
  }) {
    final report = _findGradeReport(
      studentName: studentName,
      className: className,
    );
    final subjectGrade = _findSubjectGrade(
      studentName: studentName,
      className: className,
      subject: subject,
    );
    if (report == null || subjectGrade == null) return false;
    return _finalizeGradeApproval(
      report: report,
      subjectGrade: subjectGrade,
      subject: subject,
      reviewerId: teacherId,
      reviewerName: _actorName(teacherId),
      reviewerRole: AuthService.roleTeacher,
    );
  }

  bool _finalizeGradeApproval({
    required StudentGradeReport report,
    required SubjectGrade subjectGrade,
    required String subject,
    String? reviewerId,
    String? reviewerName,
    String? reviewerRole,
  }) {
    final before = subjectGrade.status;
    subjectGrade.status = SubjectGradeStatus.approved;
    subjectGrade.publishedToParents = true;
    subjectGrade.publishedAt = DateTime.now();
    if (reviewerId != null && reviewerId.isNotEmpty && reviewerRole == AuthService.roleTeacher) {
      subjectGrade.enteredByTeacherId ??= reviewerId;
    }

    unawaited(
      GradeAuditService.instance.log(
        action: GradeAuditAction.approved,
        schoolId: AuthService.activeSchoolId ?? '',
        className: report.className,
        subject: subject,
        studentName: report.studentName,
        studentId: report.studentId,
        actorId: reviewerId,
        actorName: reviewerName,
        actorRole: reviewerRole,
        statusBefore: before,
        statusAfter: subjectGrade.status,
      ),
    );

    final settings = GradeWorkflowService.settingsForSchool(AuthService.activeSchoolId);
    if (settings.notifyParentsOnPublish) {
      _notifyLinkedParentsForGrade(
        report: report,
        subject: subject,
        score: subjectGrade.score,
        maxScore: subjectGrade.maxScore,
        updated: false,
        teacherId: subjectGrade.enteredByTeacherId,
      );
      _notifyStudentGradePublished(report: report, subject: subject);
    }

    _persistGradeReports();
    return true;
  }

  bool _reviewSubjectGradeDecision({
    required String studentName,
    required String className,
    required String subject,
    required SubjectGradeStatus nextStatus,
    required GradeAuditAction action,
    required String reason,
    String? reviewerId,
    String? reviewerName,
    String? reviewerRole,
  }) {
    final subjectGrade = _findSubjectGrade(
      studentName: studentName,
      className: className,
      subject: subject,
    );
    final report = _findGradeReport(studentName: studentName, className: className);
    if (subjectGrade == null || report == null) return false;
    if (subjectGrade.status != SubjectGradeStatus.pendingApproval) return false;

    if (!GradeWorkflowService.canUserApprove(
      grade: subjectGrade,
      className: className,
      schoolId: AuthService.activeSchoolId,
      roleKey: reviewerRole ?? AuthService.currentUser?.roleKey,
    )) {
      return false;
    }

    final before = subjectGrade.status;
    subjectGrade.status = nextStatus;
    subjectGrade.reviewComment = reason.trim();
    subjectGrade.lastReviewedAt = DateTime.now();
    subjectGrade.lastReviewedBy = reviewerName ?? _actorName(reviewerId);
    subjectGrade.approvalLevelIndex = 0;
    subjectGrade.publishedToParents = false;
    subjectGrade.publishedAt = null;

    unawaited(
      GradeAuditService.instance.log(
        action: action,
        schoolId: AuthService.activeSchoolId ?? '',
        className: className,
        subject: subject,
        studentName: studentName,
        studentId: report.studentId,
        actorId: reviewerId,
        actorName: reviewerName,
        actorRole: reviewerRole,
        detail: reason.trim(),
        statusBefore: before,
        statusAfter: nextStatus,
      ),
    );

    final settings = GradeWorkflowService.settingsForSchool(AuthService.activeSchoolId);
    if (settings.notifyTeacherOnDecision) {
      final decision = nextStatus == SubjectGradeStatus.rejected
          ? GradeTeacherDecision.rejected
          : GradeTeacherDecision.changesRequested;
      _notifyGradeTeacherDecision(
        report: report,
        subject: subject,
        decision: decision,
        comment: reason,
      );
    }

    _persistGradeReports();
    return true;
  }

  int pendingGradeApprovalCount({String? schoolId, String? roleKey}) {
    final role = roleKey ?? AuthService.currentUser?.roleKey;
    return pendingGradeApprovals(schoolId: schoolId)
        .where(
          (item) => GradeWorkflowService.canUserApprove(
            grade: item.subjectGrade,
            className: item.report.className,
            schoolId: schoolId,
            roleKey: role,
          ),
        )
        .length;
  }

  String _actorName(String? id) {
    if (id != null && id.isNotEmpty) {
      final teacher = TeacherRegistryService.instance.lookupById(id);
      if (teacher != null && teacher.fullName.isNotEmpty) return teacher.fullName;
    }
    return AuthService.displayNameForRole(AuthService.currentUser?.roleKey ?? '');
  }

  void _notifyGradeApprovers({
    required StudentGradeReport report,
    required String subject,
    required SubjectGrade subjectGrade,
  }) {
    final role = GradeWorkflowService.pendingApproverRole(
      subjectGrade,
      AuthService.activeSchoolId,
    );
    NotificationService.instance.push(
      title: 'Grade submission awaiting approval',
      body: '${report.studentName} · $subject (${report.className})',
      type: NotificationType.grade,
      fromRole: AuthService.roleTeacher,
      fromName: _actorName(subjectGrade.submittedByTeacherId),
      recipientRole: role == GradeApprovalRole.admin
          ? AuthService.roleAdmin
          : AuthService.roleTeacher,
      showOnMessagesBadge: false,
      targetStudentId: report.studentId,
    );
  }

  void _notifyGradeTeacherDecision({
    required StudentGradeReport report,
    required String subject,
    required GradeTeacherDecision decision,
    String? comment,
  }) {
    final subjectGrade = report.subjects
        .firstWhere((item) => item.subject == subject);
    final teacherId = subjectGrade.submittedByTeacherId ??
        subjectGrade.enteredByTeacherId;

    final title = switch (decision) {
      GradeTeacherDecision.approved => 'Grades approved and published',
      GradeTeacherDecision.rejected => 'Grades rejected',
      GradeTeacherDecision.changesRequested => 'Grade adjustment requested',
    };
    final defaultBody = switch (decision) {
      GradeTeacherDecision.approved =>
        '${report.studentName} · $subject is now visible to parents and students.',
      GradeTeacherDecision.rejected =>
        '${report.studentName} · $subject was rejected. Please review and resubmit.',
      GradeTeacherDecision.changesRequested =>
        '${report.studentName} · $subject needs changes before approval.',
    };

    NotificationService.instance.push(
      title: title,
      body: comment?.trim().isNotEmpty == true ? comment!.trim() : defaultBody,
      type: NotificationType.grade,
      fromRole: AuthService.roleAdmin,
      fromName: AuthService.displayNameForRole(AuthService.roleAdmin),
      recipientRole: AuthService.roleTeacher,
      recipientStaffId: teacherId != null && teacherId.isNotEmpty
          ? StaffMemberOption.teacherKey(teacherId)
          : null,
      showOnMessagesBadge: false,
      targetStudentId: report.studentId,
    );
  }

  void _notifyStudentGradePublished({
    required StudentGradeReport report,
    required String subject,
  }) {
    final studentId = report.studentId ??
        StudentRegistryService.instance.lookupByName(report.studentName)?.studentId;
    if (studentId == null) return;
    NotificationService.instance.push(
      title: 'Report card published',
      body: '$subject grades are now available.',
      type: NotificationType.grade,
      fromRole: AuthService.roleAdmin,
      fromName: AuthService.displayNameForRole(AuthService.roleAdmin),
      recipientRole: AuthService.roleStudent,
      showOnMessagesBadge: false,
      targetStudentId: studentId,
    );
  }

  /// Saves scores for every student in [scoresByStudentName] and optionally publishes.
  SubjectGradesClassEntryResult enterSubjectGradesForClass({
    required String className,
    required String subject,
    required String teacherId,
    required Map<String, double> scoresByStudentName,
    String? subjectId,
    String? teachingSlotId,
    bool publishToParents = false,
    Map<String, String>? commentsByStudentName,
    Map<String, List<String>>? markPhotoPathsByStudentName,
    Map<String, List<String>>? attachmentPathsByStudentName,
    Map<String, List<AssessmentMark>>? assessmentsByStudentName,
  }) {
    final canonicalClass = _canonicalClassName(className);
    var saved = 0;
    var skippedLocked = 0;
    for (final entry in scoresByStudentName.entries) {
      final studentName = entry.key.trim();
      if (studentName.isEmpty) continue;

      addSubjectToGradeReport(
        studentName: studentName,
        className: canonicalClass,
        subject: subject,
        teacherId: teacherId,
        subjectId: subjectId,
        teachingSlotId: teachingSlotId,
      );

      final comment = commentsByStudentName?[studentName]?.trim();
      final updated = updateSubjectGrade(
        studentName: studentName,
        className: canonicalClass,
        subject: subject,
        score: entry.value,
        comment: comment != null && comment.isNotEmpty ? comment : null,
        markPhotoPaths: markPhotoPathsByStudentName?[studentName],
        attachmentPaths: attachmentPathsByStudentName?[studentName],
        enteredByTeacherId: teacherId,
        subjectId: subjectId,
        teachingSlotId: teachingSlotId,
        assessments: assessmentsByStudentName?[studentName],
      );
      if (!updated) {
        final existing = _findSubjectGrade(
          studentName: studentName,
          className: canonicalClass,
          subject: subject,
        );
        if (existing != null && !existing.canTeacherEdit) {
          skippedLocked++;
        }
        continue;
      }

      if (publishToParents) {
        final submitted = publishSubjectGrade(
          studentName: studentName,
          className: canonicalClass,
          subject: subject,
          teacherId: teacherId,
        );
        if (!submitted) {
          skippedLocked++;
          continue;
        }
      }
      saved++;
    }
    return SubjectGradesClassEntryResult(
      saved: saved,
      skippedLocked: skippedLocked,
    );
  }

  void _notifyLinkedParentsForGrade({
    required StudentGradeReport report,
    required String subject,
    required double score,
    required double maxScore,
    required bool updated,
    String? teacherId,
  }) {
    final studentId = report.studentId ??
        StudentRegistryService.instance.lookupByName(report.studentName)?.studentId;
    if (studentId == null || studentId.trim().isEmpty) return;

    final teacherRecord = teacherId != null && teacherId.isNotEmpty
        ? TeacherRegistryService.instance.lookupById(teacherId)
        : null;
    final teacherName = teacherRecord?.fullName.isNotEmpty == true
        ? teacherRecord!.fullName
        : AuthService.displayNameForRole(AuthService.roleTeacher);

    final grade = SubjectGrade(subject: subject, score: score, maxScore: maxScore);
    final letter = grade.letterGrade;
    final scoreInt = score.round();
    final s = AppLocale.instance.strings;

    NotificationService.instance.push(
      title: updated
          ? s.gradeUpdatedNotificationTitle(subject, report.studentName)
          : s.gradePublishedNotificationTitle(subject, report.studentName),
      body: updated
          ? s.gradeUpdatedNotificationBody(
              teacherName,
              report.studentName,
              subject,
              scoreInt,
              letter,
            )
          : s.gradePublishedNotificationBody(
              teacherName,
              report.studentName,
              subject,
              scoreInt,
              letter,
            ),
      type: NotificationType.grade,
      fromRole: AuthService.roleTeacher,
      fromName: teacherName,
      recipientRole: AuthService.roleParent,
      showOnMessagesBadge: false,
      targetStudentId: studentId,
    );
  }

  void _persistGradeReports() {
    GradePersistenceService.instance.saveFromService();
  }

  bool _markbookMissingCountsAsZero() {
    final schoolId = AuthService.activeSchoolId;
    if (schoolId == null || schoolId.isEmpty) return false;
    return SchoolRegistryService.instance
            .lookup(schoolId)
            ?.markbookSettings
            .missingCountsAsZero ??
        false;
  }

  StudentAttendanceSnapshot attendanceSnapshotForStudent({
    required String studentName,
    required String className,
  }) {
    var present = 0;
    var late = 0;
    var absent = 0;
    for (final session in getAttendanceHistory(className)) {
      for (final entry in session.entries) {
        if (entry.studentName != studentName) continue;
        switch (entry.status) {
          case AttendanceStatus.present:
            present++;
          case AttendanceStatus.late:
            late++;
          case AttendanceStatus.absent:
            absent++;
        }
      }
    }
    return StudentAttendanceSnapshot(
      present: present,
      late: late,
      absent: absent,
    );
  }

  bool updateTermReportCard({
    required String studentName,
    required String className,
    String? term,
    String? academicYear,
    String? homeroomComment,
    String? principalComment,
    bool? publish,
    bool refreshAttendance = true,
  }) {
    final report = _findGradeReport(
      studentName: studentName,
      className: className,
    );
    if (report == null) return false;
    if (term != null && term.trim().isNotEmpty) {
      report.term = term.trim();
    }
    if (academicYear != null) {
      report.academicYear = academicYear.trim().isEmpty ? null : academicYear.trim();
    }
    if (homeroomComment != null) {
      report.homeroomComment =
          homeroomComment.trim().isEmpty ? null : homeroomComment.trim();
    }
    if (principalComment != null) {
      report.principalComment =
          principalComment.trim().isEmpty ? null : principalComment.trim();
    }
    if (refreshAttendance) {
      final snap = attendanceSnapshotForStudent(
        studentName: studentName,
        className: className,
      );
      report.attendancePresent = snap.present;
      report.attendanceLate = snap.late;
      report.attendanceAbsent = snap.absent;
    }
    if (publish != null) {
      report.reportCardPublished = publish;
      report.reportCardPublishedAt = publish ? DateTime.now() : null;
    }
    _persistGradeReports();
    return true;
  }

  int unpublishedReportCardCount({String? className}) {
    final reports = className == null || className.isEmpty
        ? _gradeReports
        : getGradeReportsForClass(className);
    return reports
        .where(
          (r) =>
              !r.reportCardPublished &&
              r.subjects.any((s) => s.status == SubjectGradeStatus.approved),
        )
        .length;
  }

  void applyPersistedGradeReports(List<StudentGradeReport> reports) {
    for (final persisted in reports) {
      final normalized = persisted.copyWith(
        className: _canonicalClassName(persisted.className),
        subjects: persisted.subjects.map(_normalizeSubjectWorkflow).toList(),
      );
      final index = _gradeReports.indexWhere(
        (item) => _gradeReportMatches(
          item,
          normalized.studentName,
          normalized.className,
        ),
      );
      if (index >= 0) {
        _gradeReports[index] = _mergeGradeReports(
          _gradeReports[index],
          normalized,
        );
      } else {
        _gradeReports.add(normalized);
      }
    }
  }

  SubjectGrade _normalizeSubjectWorkflow(SubjectGrade grade) {
    if (grade.status == SubjectGradeStatus.approved &&
        !grade.publishedToParents) {
      grade.status = SubjectGradeStatus.draft;
    }
    return grade;
  }

  StudentGradeReport _mergeGradeReports(
    StudentGradeReport local,
    StudentGradeReport incoming,
  ) {
    final mergedBySubject = <String, SubjectGrade>{
      for (final subject in local.subjects) subject.subject: subject,
    };

    for (final incomingSubject in incoming.subjects) {
      final normalizedIncoming = _normalizeSubjectWorkflow(incomingSubject);
      final existing = mergedBySubject[normalizedIncoming.subject];
      if (existing == null) {
        mergedBySubject[normalizedIncoming.subject] = normalizedIncoming;
        continue;
      }
      mergedBySubject[normalizedIncoming.subject] = _pickPreferredSubjectGrade(
        _normalizeSubjectWorkflow(existing),
        normalizedIncoming,
      );
    }

    return local.copyWith(
      studentName: incoming.studentName,
      className: incoming.className,
      term: incoming.term,
      studentId: incoming.studentId ?? local.studentId,
      academicYear: incoming.academicYear ?? local.academicYear,
      homeroomComment: incoming.homeroomComment ?? local.homeroomComment,
      principalComment: incoming.principalComment ?? local.principalComment,
      reportCardPublished:
          incoming.reportCardPublished || local.reportCardPublished,
      reportCardPublishedAt:
          incoming.reportCardPublishedAt ?? local.reportCardPublishedAt,
      attendancePresent: incoming.attendancePresent ?? local.attendancePresent,
      attendanceLate: incoming.attendanceLate ?? local.attendanceLate,
      attendanceAbsent: incoming.attendanceAbsent ?? local.attendanceAbsent,
      subjects: mergedBySubject.values.toList(),
    );
  }

  SubjectGrade _pickPreferredSubjectGrade(
    SubjectGrade local,
    SubjectGrade incoming,
  ) {
    int rank(SubjectGradeStatus status) {
      return switch (status) {
        SubjectGradeStatus.pendingApproval => 5,
        SubjectGradeStatus.changesRequested => 4,
        SubjectGradeStatus.rejected => 4,
        SubjectGradeStatus.approved => 3,
        SubjectGradeStatus.draft => 2,
      };
    }

    final localRank = rank(local.status);
    final incomingRank = rank(incoming.status);
    if (localRank != incomingRank) {
      return localRank > incomingRank ? local : incoming;
    }

    DateTime? activityAt(SubjectGrade grade) {
      return grade.submittedAt ??
          grade.lastReviewedAt ??
          grade.publishedAt;
    }

    final localAt = activityAt(local);
    final incomingAt = activityAt(incoming);
    if (localAt != null && incomingAt != null) {
      return localAt.isAfter(incomingAt) ? local : incoming;
    }
    if (localAt != null) return local;
    if (incomingAt != null) return incoming;

    final localFiles =
        local.markPhotoPaths.length + local.attachmentPaths.length;
    final incomingFiles =
        incoming.markPhotoPaths.length + incoming.attachmentPaths.length;
    if (localFiles != incomingFiles) {
      return localFiles > incomingFiles ? local : incoming;
    }

    return incoming;
  }

  List<StudentGradeReport> gradeReportsSnapshot() {
    return _gradeReports
        .where((report) => report.subjects.isNotEmpty)
        .map(
          (report) => report.copyWith(
            subjects: report.subjects.map((subject) => subject.clone()).toList(),
          ),
        )
        .toList();
  }

  SchoolClass? getClassByName(String name) {
    try {
      return getTeacherClasses().firstWhere((c) => c.name == name);
    } catch (_) {
      return null;
    }
  }

  List<ChildProfile> getChildren() {
    final user = AuthService.currentUser;
    if (user?.roleKey == AuthService.roleStudent) {
      final studentId = user!.linkedStudentId?.trim().toUpperCase();
      if (studentId == null || studentId.isEmpty) return const [];
      return _children
          .where((child) => child.studentId?.toUpperCase() == studentId)
          .toList();
    }
    if (user?.roleKey == AuthService.roleParent) {
      EnrollmentService.instance.ensureSeeded();
      final ids = AuthService.activeLinkedStudentIds()
          .map((id) => id.toUpperCase())
          .toSet();
      if (ids.isNotEmpty) {
        return _children
            .where(
              (child) =>
                  child.studentId != null &&
                  ids.contains(child.studentId!.toUpperCase()),
            )
            .toList();
      }
      return const [];
    }
    return List.unmodifiable(_children);
  }

  /// Class rank by average grade (1 = highest). Returns null if no report exists.
  int? rankForStudentId(String studentId, String className) {
    final normalized = studentId.trim().toUpperCase();
    final reports = List<StudentGradeReport>.from(
      getGradeReportsForClass(className),
    )..sort((a, b) => b.average.compareTo(a.average));
    for (var i = 0; i < reports.length; i++) {
      final report = reports[i];
      if (report.studentId?.toUpperCase() == normalized) return i + 1;
      if (report.studentName == studentId) return i + 1;
    }
    return null;
  }

  /// Class rank by average grade (1 = highest). Returns null if no report exists.
  int? rankForStudent(String studentName, String className) {
    final record = StudentRegistryService.instance.lookupByName(studentName);
    if (record != null) {
      final byId = rankForStudentId(record.studentId, className);
      if (byId != null) return byId;
    }
    final reports = List<StudentGradeReport>.from(
      getGradeReportsForClass(className),
    )..sort((a, b) => b.average.compareTo(a.average));
    for (var i = 0; i < reports.length; i++) {
      if (reports[i].studentName == studentName) return i + 1;
    }
    return null;
  }

  /// Teachers assigned to a class (homeroom + subject), as messaging contacts.
  List<StaffMemberOption> getTeachersForClass(String className) {
    final db = SchoolDatabaseService.instance;
    if (db.isInitialized) {
      final classId = db.classIdForName(className);
      final assignments = db.resolver.assignmentsForClass(classId);
      final seen = <String>{};
      final contacts = <StaffMemberOption>[];
      for (final assignment in assignments) {
        final teacher =
            TeacherRegistryService.instance.lookupById(assignment.teacherId);
        if (teacher == null || !teacher.isActive) continue;
        final option = StaffMemberOption.fromTeacher(teacher);
        if (option == null || seen.contains(option.id)) continue;
        seen.add(option.id);
        contacts.add(option);
      }
      contacts.sort((a, b) => a.displayName.compareTo(b.displayName));
      if (contacts.isNotEmpty) return contacts;
    }

    final classKey = className.trim();
    final seen = <String>{};
    final contacts = <StaffMemberOption>[];

    for (final teacher in TeacherRegistryService.instance.getAllTeachers()) {
      if (!teacher.isActive) continue;
      final assigned = teacher.classAssignments.any(
        (a) => _classNamesMatch(a.className, classKey),
      );
      if (!assigned) continue;
      final option = StaffMemberOption.fromTeacher(teacher);
      if (option == null || seen.contains(option.id)) continue;
      seen.add(option.id);
      contacts.add(option);
    }
    contacts.sort((a, b) => a.displayName.compareTo(b.displayName));
    return contacts;
  }

  /// School admin contacts parents can message.
  List<StaffMemberOption> getAdminContactsForParent() {
    return MessagingAccessService.adminContactsForParent();
  }

  /// Parent → staff direct message (homeroom teacher or admin only).
  List<String> sendParentDirectMessage({
    required String body,
    required String staffId,
    String? subject,
    String? studentId,
    List<AnnouncementAttachment> attachments = const [],
  }) {
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty && attachments.isEmpty) return [];

    final member = StaffMemberOption.resolve(staffId.trim());
    if (member == null) return [];

    if (!ParentMessagingPolicy.canMessageStaff(
      staffId: member.id,
      studentId: studentId,
    )) {
      return [];
    }

    final parentName = AuthService.currentUser?.fullName ?? 'Parent';
    final username = AuthService.currentUser?.username;
    final studentIds = _normalizeStudentIds(
      studentId != null
          ? [studentId]
          : AuthService.activeLinkedStudentIds(),
    );
    final conversationId = openOrCreateConversation(
      contactName: member.displayName,
      role: member.conversationRole,
      staffParticipantId: member.id,
      staffSubjectName: MessagingAccessService.staffSubjectLabelFor(
        staffParticipantId: member.id,
        linkedStudentIds: studentIds,
      ),
      parentParticipantName: parentName,
      linkedStudentIds: studentIds,
      parentParticipantUsernames: [
        if (username != null && username.trim().isNotEmpty) username.toLowerCase(),
        ...MessagingAccessService.parentLoginKeysForStudentIds(
          studentIds,
          parentName: parentName,
        ),
      ],
    );

    return _postAdminMessage(
      conversationId: conversationId,
      body: trimmedBody.isEmpty ? 'Voice message' : trimmedBody,
      subject: subject,
      attachments: attachments,
      relationshipStudentId: studentIds.isNotEmpty ? studentIds.first : null,
    );
  }

  /// Driver transport issue → school admin (messages) and route parents (messages + alerts).
  void deliverTransportIssueReport({
    required String reporterName,
    required String category,
    required String description,
  }) {
    final driverId = AuthService.resolvedLinkedDriverId;
    if (driverId == null || driverId.trim().isEmpty) return;

    final driver = DriverRegistryService.instance.lookupById(driverId);
    final subject = 'Transport alert: $category';
    final busLabel = driver != null
        ? '${driver.busNumber} · ${driver.routeName}'
        : 'School bus';
    final body = '$description\n\nReported by $reporterName · $busLabel';
    final schoolId = AuthService.activeSchoolId;

    for (final admin in ParentMessagingPolicy.adminContactsForSchool(schoolId)) {
      final thread = _staffToStaffThreadIds(
        senderRole: AuthService.roleDriver,
        recipient: admin,
      );
      final conversationId = openOrCreateConversation(
        contactName: thread.contactName,
        role: thread.role,
        staffParticipantId: thread.staffId,
        counterpartyStaffId: thread.peerId,
      );
      _postAdminMessage(
        conversationId: conversationId,
        body: body,
        subject: subject,
      );
    }

    final routeStudentIds = TransportService.instance
        .passengersForDriver(driverId)
        .map((p) => p.studentId.trim().toUpperCase())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (routeStudentIds.isEmpty) return;

    final parentNames = <String>{};
    for (final option in MessagingAccessService.parentsForSchool(schoolId)) {
      final onRoute = option.studentIds.any(
        (id) => routeStudentIds.contains(id.trim().toUpperCase()),
      );
      if (!onRoute) continue;
      parentNames.add(option.parentName);
    }

    if (parentNames.isEmpty) return;

    final driverStaffId =
        StaffMemberOption.viewerCompositeStaffId(AuthService.roleDriver);
    if (driverStaffId == null) return;

    final groupName = driver != null
        ? 'Transport · ${driver.busNumber}'
        : 'Transport alert';
    final conversationId = openOrCreateGroupConversation(
      parentNames: parentNames.toList(),
      staffIds: [driverStaffId],
      groupName: groupName,
    );
    _postAdminMessage(
      conversationId: conversationId,
      body: body,
      subject: subject,
    );
  }

  void syncChildFromRegistry(String studentId) {
    final record = StudentRegistryService.instance.lookupById(studentId);
    if (record == null) return;

    _relocateStudentOnRosters(record);

    if (record.homeroomTeacherId != null &&
        record.homeroomTeacherId!.trim().isNotEmpty) {
      assignHomeroomTeacherForClass(
        className: record.className,
        teacherId: record.homeroomTeacherId!,
        schoolId: record.schoolId,
      );
    }

    _ensureClassShell(record.className);
    _upsertStudentOnRoster(record);

    final existing = _children.indexWhere(
      (c) => c.studentId?.toUpperCase() == record.studentId.toUpperCase(),
    );
    final profile = ChildProfile(
      studentId: record.studentId,
      name: record.fullName,
      grade: record.grade,
      className: record.className,
      section: ChildProfile.sectionFromClassName(record.className),
      teacher: _homeroomTeacherNames[record.className] ?? 'Staff',
      attendanceRate: 0.9,
    );
    if (existing >= 0) {
      _children[existing] = profile;
    } else {
      _children.add(profile);
    }

    syncStudentTransport(studentId);
    upsertStudentQrProfile(
      StudentQrProfile(
        id: record.studentId.toLowerCase(),
        name: record.fullName,
        className: record.className,
        qrCode: 'STUDENT:${record.studentId.toUpperCase()}',
      ),
    );
    if (SchoolDatabaseService.instance.isInitialized) {
      unawaited(
        SchoolDatabaseService.instance.syncStudentFromRegistry(studentId),
      );
    }
  }

  /// Links a transport-enabled student to the bus route for their transport ID.
  void syncStudentTransport(String studentId) {
    final record = StudentRegistryService.instance.lookupById(studentId);
    if (record == null) return;

    _childBusAssignments.removeWhere(
      (a) =>
          a.studentId?.toUpperCase() == record.studentId.toUpperCase() ||
          a.childName == record.fullName,
    );

    if (!record.transportEnabled) {
      SchoolDatabaseService.instance.repository.removeTransportForStudent(
        record.studentId,
      );
      return;
    }

    final driverId = DriverRegistryService.instance
        .driverIdForTransportReference(record.transportId);
    if (driverId != null) {
      final route = routeForDriverId(driverId);
      if (route != null) {
        final stopName = route.stops.isNotEmpty
            ? route.stops.first.name
            : route.routeName;
        _childBusAssignments.add(
          ChildBusAssignment(
            childName: record.fullName,
            studentId: record.studentId,
            routeId: route.id,
            stopName: stopName,
          ),
        );
      }
    }

    final db = SchoolDatabaseService.instance;
    final routeId = db.isInitialized && driverId != null
        ? IdUtils.routeIdForDriver(driverId)
        : db.routeIdForStudent(record.studentId);
    final legacyRouteId = routeId != null
        ? IdUtils.legacyRouteIdForSchemaRoute(routeId)
        : null;

    if (legacyRouteId != null &&
        !_childBusAssignments.any(
          (a) => a.studentId?.toUpperCase() == record.studentId.toUpperCase(),
        )) {
      final matchedRoute = _busRoutes[legacyRouteId];
      if (matchedRoute != null) {
        final stopName = matchedRoute.stops.isNotEmpty
            ? matchedRoute.stops.first.name
            : matchedRoute.routeName;
        _childBusAssignments.add(
          ChildBusAssignment(
            childName: record.fullName,
            studentId: record.studentId,
            routeId: matchedRoute.id,
            stopName: stopName,
          ),
        );
      }
    }

    final transportId = record.transportId?.trim();
    if (transportId != null &&
        transportId.isNotEmpty &&
        db.isInitialized &&
        routeId != null) {
      db.repository.upsertTransportAssignment(
        TransportAssignment(
          assignmentId: 'TR-${record.studentId}',
          studentId: record.studentId,
          routeId: routeId,
        ),
      );
    }
  }

  void removeStudentFromSchool(String studentId) {
    final normalized = studentId.trim().toUpperCase();
    for (final roster in _classRosters.values) {
      roster.removeWhere(
        (student) => student.registryStudentId?.toUpperCase() == normalized,
      );
    }
    _children.removeWhere((c) => c.studentId?.toUpperCase() == normalized);
  }

  /// Deactivates a teacher after homeroom classes are reassigned.
  bool deactivateTeacherWithReplacement({
    required String teacherId,
    required Map<String, String> homeroomReplacementsByClass,
  }) {
    final teacher = TeacherRegistryService.instance.lookupById(teacherId);
    if (teacher == null) return false;

    final homeroomClasses = TeacherRegistryService.instance.homeroomClassesFor(
      teacherId,
    );
    for (final className in homeroomClasses) {
      final replacementId = homeroomReplacementsByClass[className];
      if (replacementId == null || replacementId.trim().isEmpty) return false;
      assignHomeroomTeacherForClass(
        className: className,
        teacherId: replacementId.trim(),
        schoolId: teacher.schoolId,
      );
      TeacherRegistryService.instance.assignHomeroomClass(
        replacementId.trim(),
        className,
      );
      SchoolDataService.instance.syncTeacherFromRegistry(
        TeacherRegistryService.instance.lookupById(replacementId.trim())!,
      );
      for (final student in StudentRegistryService.instance.studentsForClass(
        className,
        schoolId: teacher.schoolId,
      )) {
        StudentRegistryService.instance.updateStudentPlacement(
          studentId: student.studentId,
          grade: student.grade,
          className: student.className,
          homeroomTeacherId: replacementId.trim(),
        );
        syncChildFromRegistry(student.studentId);
      }
    }

    _teacherAssignments.removeWhere((link) => link['teacherId'] == teacherId);
    return TeacherRegistryService.instance.deactivateTeacher(teacherId);
  }

  void removeTeacherAssignments(String teacherId) {
    _teacherAssignments.removeWhere((link) => link['teacherId'] == teacherId);
  }

  /// Replaces all runtime class links for a teacher from registry assignments.
  void setTeacherAssignmentsFromRegistry(AdminTeacherRecord teacher) {
    final teacherId = teacher.teacherId.trim().toUpperCase();

    for (final entry in _homeroomTeacherIds.entries.toList()) {
      if (entry.value.trim().toUpperCase() != teacherId) continue;
      final stillHomeroom = teacher.classAssignments.any(
        (assignment) =>
            _classNamesMatch(assignment.className, entry.key) &&
            assignment.role == TeacherStaffRole.homeroomTeacher,
      );
      if (!stillHomeroom) {
        _homeroomTeacherIds.remove(entry.key);
        _homeroomTeacherNames.remove(entry.key);
      }
    }

    _teacherAssignments.removeWhere(
      (link) => (link['teacherId'] as String).trim().toUpperCase() == teacherId,
    );

    for (final assignment in teacher.classAssignments) {
      _ensureClassShell(assignment.className);
      if (assignment.role == TeacherStaffRole.homeroomTeacher) {
        assignHomeroomTeacherForClass(
          className: assignment.className,
          teacherId: teacher.teacherId,
          schoolId: teacher.schoolId,
        );
      }
      // Subjects apply for both homeroom and subject-teacher authority.
      final slots = _subjectSlotsForAssignment(teacher, assignment);
      for (final slot in slots) {
        _addTeacherAssignmentIfMissing(
          teacherId: teacher.teacherId,
          className: assignment.className,
          role: ClassTeacherRole.subject,
          subject: slot.subjectName,
        );
        _upsertClassSubjectTeacher(
          className: assignment.className,
          teacherId: teacher.teacherId,
          teacherName: teacher.fullName,
          subject: slot.subjectName,
        );
      }
    }

    _removeStaleSubjectTeachers(teacher);
    if (SchoolDatabaseService.instance.isInitialized) {
      unawaited(
        SchoolDatabaseService.instance.syncTeacherFromRegistry(teacher.teacherId),
      );
    }
  }

  void _upsertClassSubjectTeacher({
    required String className,
    required String teacherId,
    required String teacherName,
    required String subject,
  }) {
    final list = _classSubjectTeachers.putIfAbsent(className, () => []);
    final index = list.indexWhere((entry) => entry.subject == subject);
    final entry = ClassSubjectTeacher(
      subject: subject,
      teacherId: teacherId,
      teacherName: teacherName,
    );
    if (index >= 0) {
      list[index] = entry;
    } else {
      list.add(entry);
    }
  }

  List<SubjectTeachingSlot> _subjectSlotsForAssignment(
    AdminTeacherRecord teacher,
    TeacherClassAssignment assignment,
  ) {
    if (assignment.teachingSlots.isNotEmpty) {
      return assignment.teachingSlots;
    }
    // Legacy fallback only for subject-teacher rows with empty slots.
    if (assignment.role != TeacherStaffRole.subjectTeacher) {
      return const [];
    }
    return teacher.subjects
        .map(
          (name) => SubjectTeachingSlot(
            slotId: 'STA-LEG-${teacher.teacherId}-$name',
            subjectId: SchoolSubjects.resolveSubjectId(name),
            subjectName: name,
          ),
        )
        .toList();
  }

  void _removeStaleSubjectTeachers(AdminTeacherRecord teacher) {
    final classNames =
        teacher.classAssignments.map((a) => a.className).toSet();
    for (final className in classNames) {
      final list = _classSubjectTeachers[className];
      if (list == null) continue;
      final allowedSubjects = teacher.classAssignments
          .where((assignment) => _classNamesMatch(assignment.className, className))
          .expand((assignment) => _subjectSlotsForAssignment(teacher, assignment))
          .map((slot) => slot.subjectName)
          .toSet();
      list.removeWhere(
        (entry) =>
            entry.teacherId == teacher.teacherId &&
            !allowedSubjects.contains(entry.subject),
      );
    }
  }

  /// Assigns homeroom teacher to a class and links them in My Classes.
  void assignHomeroomTeacherForClass({
    required String className,
    required String teacherId,
    String? schoolId,
  }) {
    final teacher = TeacherRegistryService.instance.lookupById(teacherId);
    if (teacher == null) return;
    if (schoolId != null &&
        teacher.schoolId.toUpperCase() != schoolId.trim().toUpperCase()) {
      return;
    }

    _teacherAssignments.removeWhere(
      (link) =>
          link['className'] == className &&
          link['role'] == ClassTeacherRole.homeroom,
    );

    _homeroomTeacherIds[className] = teacher.teacherId;
    _homeroomTeacherNames[className] = teacher.fullName;
    _ensureClassShell(className);
    _addTeacherAssignmentIfMissing(
      teacherId: teacher.teacherId,
      className: className,
      role: ClassTeacherRole.homeroom,
    );
  }

  void _relocateStudentOnRosters(AdminStudentRecord record) {
    for (final entry in _classRosters.entries) {
      if (entry.key == record.className) continue;
      entry.value.removeWhere(
        (student) =>
            student.registryStudentId?.toUpperCase() ==
            record.studentId.toUpperCase(),
      );
    }
  }

  /// Keeps homeroom class rosters and teacher assignments aligned with registries.
  void syncEnrollmentFromRegistry({String? schoolId}) {
    syncAllStudentsFromRegistry(schoolId: schoolId);
    for (final teacher in TeacherRegistryService.instance.getAllTeachers()) {
      if (schoolId != null &&
          teacher.schoolId.toUpperCase() != schoolId.trim().toUpperCase()) {
        continue;
      }
      syncTeacherFromRegistry(teacher);
    }
  }

  void syncAllStudentsFromRegistry({String? schoolId}) {
    final students = schoolId != null
        ? StudentRegistryService.instance.studentsForSchool(schoolId)
        : StudentRegistryService.instance.getAllStudents();
    for (final student in students) {
      syncChildFromRegistry(student.studentId);
    }
  }

  void syncTeacherFromRegistry(AdminTeacherRecord teacher) {
    setTeacherAssignmentsFromRegistry(teacher);
  }

  void _ensureClassShell(String className) {
    _classRosters.putIfAbsent(className, () => []);
    _classSchedules.putIfAbsent(className, () => 'Mon–Fri, 8:00 AM – 3:00 PM');
    _classRooms.putIfAbsent(className, () => 'Room TBD');
  }

  void ensureClassExists(String className) => _ensureClassShell(className);

  List<String> _parseAssignedClasses(String assignedClass) {
    return assignedClass
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  StudentRef _studentRefFromRecord(AdminStudentRecord record) {
    final roster = _classRosters[record.className] ?? const <StudentRef>[];
    final slug = _slugFromName(record.fullName);
    final shortGrade = _shortGradeLabel(record.className);
    StudentRef? cached;
    for (final student in roster) {
      if (student.registryStudentId?.toUpperCase() ==
              record.studentId.toUpperCase() ||
          student.id == slug ||
          student.name == record.fullName) {
        cached = student;
        break;
      }
    }

    final ref = StudentRef(
      id: slug,
      registryStudentId: record.studentId,
      name: record.fullName,
      grade: shortGrade,
      parentName: record.primaryParentName ?? cached?.parentName,
      parentPhone: record.primaryContactPhone,
    );
    ref.photoPath = record.photoPath ?? cached?.photoPath;
    return ref;
  }

  void _upsertStudentOnRoster(AdminStudentRecord record) {
    final roster = _classRosters[record.className]!;
    final updated = _studentRefFromRecord(record);
    final existingIndex = roster.indexWhere(
      (student) =>
          student.registryStudentId?.toUpperCase() ==
              record.studentId.toUpperCase() ||
          student.id == updated.id ||
          student.name == record.fullName,
    );

    if (existingIndex >= 0) {
      roster[existingIndex] = updated;
    } else {
      roster.add(updated);
    }
  }

  String _slugFromName(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');

  String _shortGradeLabel(String className) {
    final match = RegExp(r'Grade\s*(\S+)', caseSensitive: false).firstMatch(className);
    return match?.group(1) ?? className;
  }

  void _addTeacherAssignmentIfMissing({
    required String teacherId,
    required String className,
    required ClassTeacherRole role,
    String? subject,
  }) {
    final exists = _teacherAssignments.any(
      (link) =>
          link['teacherId'] == teacherId &&
          link['className'] == className &&
          link['role'] == role,
    );
    if (exists) return;

    final entry = <String, dynamic>{
      'teacherId': teacherId,
      'className': className,
      'role': role,
    };
    if (subject != null && subject.isNotEmpty) {
      entry['subject'] = subject;
    }
    _teacherAssignments.add(entry);
  }

  List<String> getAllClassNames() {
    final names = _classRosters.keys.toList();
    names.sort();
    return names;
  }

  ChildProfile? getChildById(String studentId) {
    final normalized = studentId.trim().toUpperCase();
    try {
      return _children.firstWhere(
        (c) => c.studentId?.toUpperCase() == normalized,
      );
    } catch (_) {
      return null;
    }
  }

  ChildProfile? getChildByName(String name) {
    for (final child in _children) {
      if (child.name == name) return child;
    }
    final record = StudentRegistryService.instance.lookupByName(name);
    if (record != null) return getChildById(record.studentId);
    return null;
  }

  List<Announcement> getAnnouncements() {
    final sorted = List<Announcement>.from(_announcements);
    sorted.sort((a, b) {
      // Newest posts always on top; pinned stays above unpinned of same age.
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return _priorityRank(a.priority).compareTo(_priorityRank(b.priority));
    });
    return List.unmodifiable(sorted);
  }

  List<Announcement> getAnnouncementsForRole(String? roleKey) {
    return getAnnouncements()
        .where((a) => a.isVisibleToRole(roleKey))
        .toList(growable: false);
  }

  int _priorityRank(AnnouncementPriority priority) {
    return switch (priority) {
      AnnouncementPriority.urgent => 0,
      AnnouncementPriority.important => 1,
      AnnouncementPriority.normal => 2,
    };
  }

  Announcement? getAnnouncement(String id) {
    try {
      return _announcements.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  void addAnnouncement({
    required String title,
    required String body,
    required String author,
    String? audience,
    List<String>? audienceKeys,
    AnnouncementPriority priority = AnnouncementPriority.normal,
    List<AnnouncementAttachment> attachments = const [],
    bool isPinned = false,
  }) {
    final keys = audienceKeys ??
        [AnnouncementAudiences.normalizeLegacy(audience ?? 'All')];
    final fromRole =
        AuthService.currentUser?.roleKey ?? AuthService.roleAdmin;
    _announcements.insert(
      0,
      Announcement(
        id: '${_nextAnnouncementId++}',
        title: title.trim(),
        body: body.trim(),
        author: author,
        date: DateTime.now(),
        audienceKeys: keys,
        priority: priority,
        attachments: attachments,
        isPinned: isPinned,
        createdByRole: fromRole,
        createdByAuthor: author,
      ),
    );

    _notifyByAudiences(
      audienceKeys: keys,
      title: 'New announcement',
      body: '$author: $title',
      type: NotificationType.announcement,
      fromRole: fromRole,
      fromName: author,
    );
    _persistSchoolContent();
  }

  List<StudentGradeReport> getAllGradeReports() =>
      List.unmodifiable(_gradeReports);

  StudentGradeReport? getGradeReportForStudentId(String studentId) {
    final normalized = studentId.trim().toUpperCase();
    try {
      return _gradeReports.firstWhere(
        (r) => r.studentId?.toUpperCase() == normalized,
      );
    } catch (_) {
      final record = StudentRegistryService.instance.lookupById(studentId);
      if (record != null) {
        return getGradeReportForStudent(record.fullName);
      }
      return null;
    }
  }

  StudentGradeReport? getGradeReportForStudent(String studentName) {
    try {
      return _gradeReports.firstWhere((r) => r.studentName == studentName);
    } catch (_) {
      return null;
    }
  }

  List<StudentGradeReport> getGradeReportsForClass(String className) {
    final roster = getStudentsForClass(className);
    final existing = {
      for (final report in _gradeReports.where(
        (r) => _classNamesMatch(r.className, className),
      ))
        report.studentName: report,
    };

    if (roster.isEmpty) {
      return existing.values.toList();
    }

    return roster.map((student) {
      final report = existing[student.name];
      if (report != null) return report;
      return StudentGradeReport(
        studentName: student.name,
        className: className,
        term: 'Term 1',
        studentId: student.registryStudentId,
        subjects: const [],
      );
    }).toList();
  }

  List<StudentGradeReport> getGradeReportsForParent() {
    final childIds = getChildren()
        .map((c) => c.studentId?.toUpperCase())
        .whereType<String>()
        .toSet();
    final childNames = getChildren().map((c) => c.name).toSet();
    return _gradeReports
        .where(
          (r) =>
              (r.studentId != null &&
                  childIds.contains(r.studentId!.toUpperCase())) ||
              childNames.contains(r.studentName),
        )
        .map(_parentVisibleGradeReport)
        .where((report) => report.subjects.isNotEmpty)
        .toList();
  }

  StudentGradeReport _parentVisibleGradeReport(StudentGradeReport report) {
    final published = report.subjects
        .where((subject) => subject.isVisibleToParent)
        .toList();
    if (!report.reportCardPublished) {
      return report.copyWith(
        subjects: published,
        clearHomeroomComment: true,
        clearPrincipalComment: true,
        reportCardPublished: false,
      );
    }
    return report.copyWith(subjects: published);
  }

  final List<ChildBusAssignment> _childBusAssignments = [
    ChildBusAssignment(
      childName: 'Sara Bekele',
      studentId: 'STU-1001',
      routeId: 'route-bole',
      stopName: 'Bole Medhanialem',
    ),
    ChildBusAssignment(
      childName: 'Kidus Bekele',
      studentId: 'STU-1002',
      routeId: 'route-piassa',
      stopName: 'Piassa Square',
    ),
  ];

  final Map<String, BusRoute> _busRoutes = {
    'route-bole': BusRoute(
      id: 'route-bole',
      busNumber: 'Bus 12',
      driverName: 'Alemayehu T.',
      plateNumber: 'AA-3-45678',
      routeName: 'Bole → School',
      currentStopIndex: 1,
      tripStatus: TripStatus.inProgress,
      progressToNextStop: 0.45,
      stops: [
        BusStop(
          name: 'Bole Airport Area',
          scheduledTime: '7:00 AM',
          students: ['Marta Kebede'],
          latitude: 8.9779,
          longitude: 38.7993,
          status: StopStatus.completed,
        ),
        BusStop(
          name: 'Bole Medhanialem',
          scheduledTime: '7:15 AM',
          students: ['Sara Bekele', 'Daniel Tesfaye'],
          latitude: 8.9932,
          longitude: 38.7894,
          status: StopStatus.current,
          etaMinutes: 6,
        ),
        BusStop(
          name: 'CMC Michael',
          scheduledTime: '7:30 AM',
          students: ['Hanna Girma'],
          latitude: 9.0120,
          longitude: 38.7610,
          status: StopStatus.pending,
        ),
        BusStop(
          name: 'Maya School',
          scheduledTime: '7:50 AM',
          students: [],
          latitude: 9.0200,
          longitude: 38.7500,
          status: StopStatus.pending,
        ),
      ],
    ),
    'route-piassa': BusRoute(
      id: 'route-piassa',
      busNumber: 'Bus 07',
      driverName: 'Tadesse M.',
      plateNumber: 'AA-2-11223',
      routeName: 'Piassa → School',
      currentStopIndex: 0,
      tripStatus: TripStatus.inProgress,
      progressToNextStop: 0.7,
      stops: [
        BusStop(
          name: 'Piassa Square',
          scheduledTime: '7:10 AM',
          students: ['Kidus Bekele'],
          latitude: 9.0310,
          longitude: 38.7500,
          status: StopStatus.current,
          etaMinutes: 3,
        ),
        BusStop(
          name: 'Arat Kilo',
          scheduledTime: '7:25 AM',
          students: ['Abel Haile'],
          latitude: 9.0325,
          longitude: 38.7610,
          status: StopStatus.pending,
        ),
        BusStop(
          name: 'Maya School',
          scheduledTime: '7:45 AM',
          students: [],
          latitude: 9.0200,
          longitude: 38.7500,
          status: StopStatus.pending,
        ),
      ],
    ),
  };

  List<ChildBusAssignment> getChildBusAssignments() =>
      List.unmodifiable(_childBusAssignments);

  ChildBusAssignment? getBusAssignmentForStudent(String studentId) {
    final normalized = studentId.trim().toUpperCase();
    try {
      return _childBusAssignments.firstWhere(
        (a) => a.studentId?.toUpperCase() == normalized,
      );
    } catch (_) {
      final child = getChildById(studentId);
      if (child != null) return getBusAssignmentForChild(child.name);
      return null;
    }
  }

  ChildBusAssignment? getBusAssignmentForChild(String childName) {
    try {
      return _childBusAssignments.firstWhere((a) => a.childName == childName);
    } catch (_) {
      return null;
    }
  }

  BusRoute? getBusRoute(String routeId) => _busRoutes[routeId];

  List<BusRoute> getAllBusRoutes() => _busRoutes.values.toList();

  /// Resolves a map route for a driver — matches seeded routes or builds one
  /// from the driver registry (e.g. after admin registration or parent bus link).
  BusRoute? routeForDriverId(String driverId) {
    final id = driverId.trim().toUpperCase();
    final driver = DriverRegistryService.instance.lookupById(id);
    if (driver == null) return null;

    for (final route in _busRoutes.values) {
      if (route.driverName == driver.fullName ||
          route.plateNumber == driver.plateNumber ||
          route.busNumber == driver.busNumber) {
        return route;
      }
    }

    final syntheticKey = 'route-${id.toLowerCase()}';
    return _busRoutes.putIfAbsent(
      syntheticKey,
      () => _syntheticRouteForDriver(driver, syntheticKey),
    );
  }

  BusRoute _syntheticRouteForDriver(
    AdminDriverRecord driver,
    String routeKey,
  ) {
    final parts = DriverRegistryService.parseRoute(driver.routeName);
    final startName =
        parts.from.isNotEmpty ? parts.from : driver.routeName.split('→').first.trim();
    final throughName = parts.through.trim();
    final endName = parts.to.isNotEmpty ? parts.to : 'Maya School';

    final stops = <BusStop>[
      BusStop(
        name: startName.isEmpty ? 'Route start' : startName,
        scheduledTime: '7:00 AM',
        students: const [],
        latitude: 8.9932,
        longitude: 38.7894,
        status: StopStatus.current,
        etaMinutes: 8,
      ),
      if (throughName.isNotEmpty)
        BusStop(
          name: throughName,
          scheduledTime: '7:25 AM',
          students: const [],
          latitude: 9.0120,
          longitude: 38.7610,
          status: StopStatus.pending,
        ),
      BusStop(
        name: endName,
        scheduledTime: '7:50 AM',
        students: const [],
        latitude: 9.0200,
        longitude: 38.7500,
        status: StopStatus.pending,
      ),
    ];

    return BusRoute(
      id: routeKey,
      busNumber: driver.busNumber,
      driverName: driver.fullName,
      plateNumber: driver.plateNumber,
      routeName: driver.routeName,
      tripStatus: TripStatus.inProgress,
      currentStopIndex: 0,
      progressToNextStop: 0.35,
      stops: stops,
    );
  }

  BusRoute getDriverRoute() {
    final linkedId = AuthService.resolvedLinkedDriverId;
    if (linkedId != null) {
      final route = routeForDriverId(linkedId);
      if (route != null) return route;
    }
    return _busRoutes['route-bole']!;
  }

  void _refreshStopStatuses(BusRoute route) {
    for (var i = 0; i < route.stops.length; i++) {
      if (route.tripStatus == TripStatus.completed) {
        route.stops[i].status = StopStatus.completed;
      } else if (i < route.currentStopIndex) {
        route.stops[i].status = StopStatus.completed;
      } else if (i == route.currentStopIndex) {
        route.stops[i].status = StopStatus.current;
      } else {
        route.stops[i].status = StopStatus.pending;
      }
    }
  }

  void simulateBusMovement() {
    for (final route in _busRoutes.values) {
      if (route.tripStatus != TripStatus.inProgress) continue;

      final previousIndex = route.currentStopIndex;
      route.progressToNextStop += 0.15;
      if (route.progressToNextStop >= 1) {
        route.progressToNextStop = 0;
        route.currentStopIndex++;
        if (route.currentStopIndex >= route.stops.length - 1) {
          route.currentStopIndex = route.stops.length - 1;
          route.tripStatus = TripStatus.completed;
          route.progressToNextStop = 1;
        }
      }

      final current = route.currentStop;
      if (current != null && route.tripStatus == TripStatus.inProgress) {
        current.etaMinutes = ((1 - route.progressToNextStop) * 8).round().clamp(1, 12);
      }
      _refreshStopStatuses(route);

      if (route.currentStopIndex != previousIndex) {
        _maybeNotifySchoolArrival(route);
      }
      if (route.tripStatus == TripStatus.completed &&
          previousIndex < route.stops.length - 1) {
        _maybeNotifySchoolArrival(route);
      }
    }
  }

  void startDriverRoute() {
    final route = getDriverRoute();
    _busArrivalNotified.remove(route.id);
    route.tripStatus = TripStatus.inProgress;
    route.currentStopIndex = 0;
    route.progressToNextStop = 0;
    _refreshStopStatuses(route);
  }

  void markStopComplete() {
    final route = getDriverRoute();
    if (route.tripStatus == TripStatus.notStarted) return;

    route.progressToNextStop = 0;
    route.currentStopIndex++;
    if (route.currentStopIndex >= route.stops.length - 1) {
      route.currentStopIndex = route.stops.length - 1;
      route.tripStatus = TripStatus.completed;
      route.progressToNextStop = 1;
    }
    _refreshStopStatuses(route);
    _maybeNotifySchoolArrival(route);
  }

  void _maybeNotifySchoolArrival(BusRoute route) {
    if (route.tripStatus != TripStatus.completed) return;
    if (_busArrivalNotified.contains(route.id)) return;
    _busArrivalNotified.add(route.id);

    final schoolStop = route.stops.isNotEmpty ? route.stops.last : null;
    if (schoolStop == null) return;

    final childrenOnRoute = _childBusAssignments
        .where((a) => a.routeId == route.id)
        .map((a) => a.childName)
        .toSet();

    for (final childName in childrenOnRoute) {
      NotificationService.instance.push(
        title: 'Arrived at school',
        body:
            '$childName reached ${schoolStop.name} on ${route.busNumber} (${route.routeName}).',
        type: NotificationType.bus,
        fromRole: AuthService.roleDriver,
        fromName: route.driverName,
        recipientRole: AuthService.roleParent,
        showOnMessagesBadge: false,
      );
    }
    _persistSchoolContent();
  }

  void endDriverRoute() {
    final route = getDriverRoute();
    route.tripStatus = TripStatus.completed;
    route.currentStopIndex = route.stops.length - 1;
    route.progressToNextStop = 1;
    _refreshStopStatuses(route);
  }

  final List<FeeRecord> _fees = [
    FeeRecord(
      id: 'fee-1',
      studentName: 'Sara Bekele',
      studentId: 'STU-1001',
      title: 'Tuition - Term 1',
      amount: 12500,
      dueDate: DateTime.now().add(const Duration(days: 14)),
      term: 'Term 1',
    ),
    FeeRecord(
      id: 'fee-2',
      studentName: 'Sara Bekele',
      studentId: 'STU-1001',
      title: 'Transport Fee',
      amount: 1800,
      dueDate: DateTime.now().subtract(const Duration(days: 3)),
      term: 'Term 1',
      status: FeeStatus.overdue,
    ),
    FeeRecord(
      id: 'fee-3',
      studentName: 'Kidus Bekele',
      studentId: 'STU-1002',
      title: 'Tuition - Term 1',
      amount: 9800,
      dueDate: DateTime.now().add(const Duration(days: 21)),
      term: 'Term 1',
    ),
    FeeRecord(
      id: 'fee-4',
      studentName: 'Kidus Bekele',
      studentId: 'STU-1002',
      title: 'Activity Fee',
      amount: 450,
      dueDate: DateTime.now().subtract(const Duration(days: 30)),
      term: 'Term 1',
      status: FeeStatus.paid,
      paidVia: 'Telebirr',
      paidDate: DateTime.now().subtract(const Duration(days: 10)),
    ),
    FeeRecord(
      id: 'fee-5',
      studentName: 'Daniel Tesfaye',
      studentId: 'STU-1003',
      title: 'Tuition - Term 1',
      amount: 12500,
      dueDate: DateTime.now().add(const Duration(days: 7)),
      term: 'Term 1',
    ),
  ];

  List<FeeRecord> getAllFees() => List.unmodifiable(_fees);

  List<FeeRecord> getFeesForParent() {
    final children = getChildren();
    final childIds = children
        .map((c) => c.studentId?.trim().toUpperCase())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    final childNames = children.map((c) => c.name.trim()).toSet();
    return _fees.where((f) {
      final sid = f.studentId?.trim().toUpperCase();
      if (sid != null && sid.isNotEmpty) {
        return childIds.contains(sid);
      }
      return childNames.contains(f.studentName.trim());
    }).toList();
  }

  PaymentSummary getPaymentSummary({bool parentOnly = true}) {
    final fees = parentOnly ? getFeesForParent() : getAllFees();
    final due = fees
        .where((f) => f.status != FeeStatus.paid)
        .fold<double>(0, (sum, f) => sum + f.amount);
    final paid = fees
        .where((f) => f.status == FeeStatus.paid)
        .fold<double>(0, (sum, f) => sum + f.amount);
    final overdue = fees.where((f) => f.status == FeeStatus.overdue).length;
    return PaymentSummary(
      totalDue: due,
      totalPaid: paid,
      overdueCount: overdue,
    );
  }

  bool payFee(String feeId, String method) {
    try {
      final fee = _fees.firstWhere((f) => f.id == feeId);
      if (fee.isPaid) return false;

      fee.status = FeeStatus.paid;
      fee.paidVia = method;
      fee.paidDate = DateTime.now();

      final parentName =
          AuthService.displayNameForRole(AuthService.roleParent);
      NotificationService.instance.push(
        title: 'Fee payment received',
        body: '$parentName paid ${fee.title} for ${fee.studentName} via $method.',
        type: NotificationType.fee,
        fromRole: AuthService.roleParent,
        fromName: parentName,
        recipientRole: AuthService.roleAdmin,
        showOnMessagesBadge: false,
      );
      _persistSchoolContent();
      return true;
    } catch (_) {
      return false;
    }
  }

  final List<CalendarEvent> _calendarEvents = [
    CalendarEvent(
      id: 'cal-1',
      title: 'Mid-Term Exams Begin',
      description: 'Grade 4 and 5 mid-term examinations start today.',
      date: DateTime(2026, 6, 20),
      type: CalendarEventType.exam,
      time: '8:00 AM',
      audience: 'Students',
    ),
    CalendarEvent(
      id: 'cal-2',
      title: 'Parent-Teacher Meeting',
      description: 'Quarterly meeting in the main hall.',
      date: DateTime(2026, 6, 20),
      type: CalendarEventType.meeting,
      time: '3:00 PM',
      audience: 'Parents',
      autoAnnounce: true,
    ),
    CalendarEvent(
      id: 'cal-3',
      title: 'Sports Day',
      description: 'Inter-class football and athletics competition.',
      date: DateTime(2026, 6, 25),
      type: CalendarEventType.sports,
      time: '9:00 AM',
    ),
    CalendarEvent(
      id: 'cal-4',
      title: 'Science Fair',
      description: 'Grade 4A project presentations in Room 12.',
      date: DateTime(2026, 6, 18),
      type: CalendarEventType.classEvent,
      time: '10:00 AM',
      audience: 'Grade 4A',
    ),
    CalendarEvent(
      id: 'cal-5',
      title: 'Public Holiday',
      description: 'School closed — national holiday.',
      date: DateTime(2026, 6, 28),
      type: CalendarEventType.holiday,
    ),
    CalendarEvent(
      id: 'cal-6',
      title: 'Staff Planning Day',
      description: 'No classes for students. Staff curriculum planning.',
      date: DateTime(2026, 6, 30),
      type: CalendarEventType.meeting,
      audience: 'Teachers',
    ),
    CalendarEvent(
      id: 'cal-7',
      title: 'Math Quiz - Grade 5B',
      description: 'Weekly mathematics assessment.',
      date: DateTime(2026, 6, 22),
      type: CalendarEventType.exam,
      time: '11:00 AM',
      audience: 'Grade 5B',
      autoAnnounce: true,
    ),
  ];

  int _nextCalendarId = 100;
  bool _ethiopianHolidaysSynced = false;

  final List<StudentQrProfile> _studentQrProfiles = [
    StudentQrProfile(
      id: 'sara-bekele',
      name: 'Sara Bekele',
      className: 'Grade 4A',
      qrCode: 'STUDENT:sara-bekele',
    ),
    StudentQrProfile(
      id: 'kidus-bekele',
      name: 'Kidus Bekele',
      className: 'Grade 2C',
      qrCode: 'STUDENT:kidus-bekele',
    ),
    StudentQrProfile(
      id: 'daniel-tesfaye',
      name: 'Daniel Tesfaye',
      className: 'Grade 4A',
      qrCode: 'STUDENT:daniel-tesfaye',
    ),
    StudentQrProfile(
      id: 'hanna-girma',
      name: 'Hanna Girma',
      className: 'Grade 4A',
      qrCode: 'STUDENT:hanna-girma',
    ),
    StudentQrProfile(
      id: 'liya-solomon',
      name: 'Liya Solomon',
      className: 'Grade 5B',
      qrCode: 'STUDENT:liya-solomon',
    ),
  ];

  final List<QrScanRecord> _qrScanHistory = [
    QrScanRecord(
      studentId: 'sara-bekele',
      studentName: 'Sara Bekele',
      className: 'Grade 4A',
      action: QrScanAction.entry,
      time: DateTime(2026, 6, 20, 7, 45),
      scannedBy: 'Gate Staff',
    ),
    QrScanRecord(
      studentId: 'daniel-tesfaye',
      studentName: 'Daniel Tesfaye',
      className: 'Grade 4A',
      action: QrScanAction.entry,
      time: DateTime(2026, 6, 20, 7, 52),
      scannedBy: 'Miss Belen',
    ),
  ];

  List<CalendarEvent> getCalendarEvents() {
    ensureEthiopianHolidaysSynced();
    return List.unmodifiable(_calendarEvents);
  }

  List<CalendarEvent> getEventsForDay(DateTime day) {
    ensureEthiopianHolidaysSynced();
    return _calendarEvents.where((event) {
      return event.date.year == day.year &&
          event.date.month == day.month &&
          event.date.day == day.day;
    }).toList();
  }

  List<CalendarEvent> getEventsForMonth(DateTime month) {
    return _calendarEvents.where((event) {
      return event.date.year == month.year && event.date.month == month.month;
    }).toList();
  }

  List<StudentQrProfile> getAllStudentQrProfiles() =>
      List.unmodifiable(_studentQrProfiles);

  void upsertStudentQrProfile(StudentQrProfile profile) {
    final idx = _studentQrProfiles.indexWhere(
      (p) =>
          p.id == profile.id ||
          p.qrCode.toLowerCase() == profile.qrCode.toLowerCase(),
    );
    if (idx >= 0) {
      _studentQrProfiles[idx] = profile;
    } else {
      _studentQrProfiles.add(profile);
    }
  }

  List<StudentQrProfile> getStudentQrProfilesForClass(String className) {
    return _studentQrProfiles
        .where((profile) => _classNamesMatch(profile.className, className))
        .toList();
  }

  List<StudentQrProfile> getStudentQrProfilesForParent() {
    final children = getChildren();
    final childIds = children
        .map((c) => c.studentId?.trim().toUpperCase())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    final childNames = children.map((c) => c.name.trim()).toSet();
    return _studentQrProfiles.where((s) {
      final sid = s.id.trim().toUpperCase();
      if (sid.isNotEmpty && childIds.contains(sid)) return true;
      return childNames.contains(s.name.trim());
    }).toList();
  }

  StudentQrProfile? findStudentByQrCode(String code) {
    final normalized = code.trim();
    if (normalized.isEmpty) return null;
    try {
      return _studentQrProfiles.firstWhere(
        (s) => s.qrCode.toLowerCase() == normalized.toLowerCase(),
      );
    } catch (_) {
      final upper = normalized.toUpperCase();
      if (upper.startsWith('STUDENT:')) {
        final id = normalized.substring('STUDENT:'.length).trim().toUpperCase();
        final record = StudentRegistryService.instance.lookupById(id);
        if (record != null) {
          return StudentQrProfile(
            id: record.studentId.toLowerCase(),
            name: record.fullName,
            className: record.className,
            qrCode: 'STUDENT:${record.studentId.toUpperCase()}',
          );
        }
      }
      return null;
    }
  }

  List<QrScanRecord> getQrScanHistory() =>
      List.unmodifiable(_qrScanHistory.reversed);

  String? recordQrScan({
    required String qrCode,
    required QrScanAction action,
    required String scannedBy,
    String? allowedClassName,
    bool syncAttendance = false,
  }) {
    final student = findStudentByQrCode(qrCode);
    if (student == null) return 'Invalid QR code';

    if (allowedClassName != null &&
        allowedClassName.trim().isNotEmpty &&
        student.className != allowedClassName) {
      return 'wrong_class:$allowedClassName';
    }

    if (syncAttendance) {
      final attendanceError = _syncAttendanceFromQrScan(
        studentName: student.name,
        className: student.className,
        action: action,
        scannedBy: scannedBy,
      );
      if (attendanceError != null) return attendanceError;
    }

    _qrScanHistory.add(
      QrScanRecord(
        studentId: student.id,
        studentName: student.name,
        className: student.className,
        action: action,
        time: DateTime.now(),
        scannedBy: scannedBy,
      ),
    );

    final scannerRole =
        AuthService.currentUser?.roleKey ?? AuthService.roleTeacher;
    NotificationService.instance.push(
      title: 'QR ${_qrScanActionLabel(action)} recorded',
      body: '$scannedBy scanned ${student.name} (${student.className}).',
      type: NotificationType.qrScan,
      fromRole: scannerRole,
      fromName: scannedBy,
      recipientRole: AuthService.roleParent,
    );
    _persistSchoolContent();
    return null;
  }

  String? _syncAttendanceFromQrScan({
    required String studentName,
    required String className,
    required QrScanAction action,
    required String scannedBy,
  }) {
    final today = DateTime.now();
    final session = getAttendanceSession(className, today);
    final roster = getStudentsForClass(className);
    final targetStatus = switch (action) {
      QrScanAction.present || QrScanAction.entry => AttendanceStatus.present,
      QrScanAction.late => AttendanceStatus.late,
      QrScanAction.absent || QrScanAction.exit => AttendanceStatus.absent,
    };

    final entries = session?.entries
            .map(
              (entry) => StudentAttendanceEntry(
                studentName: entry.studentName,
                status: entry.status,
              ),
            )
            .toList() ??
        roster
            .map(
              (student) => StudentAttendanceEntry(
                studentName: student.name,
                status: AttendanceStatus.absent,
              ),
            )
            .toList();

    final normalized = studentName.trim().toLowerCase();
    final index = entries.indexWhere(
      (entry) => entry.studentName.trim().toLowerCase() == normalized,
    );
    if (index >= 0) {
      entries[index].status = targetStatus;
    } else {
      entries.add(
        StudentAttendanceEntry(
          studentName: studentName,
          status: targetStatus,
        ),
      );
    }

    saveAttendanceSession(
      className: className,
      date: today,
      conductedBy: scannedBy,
      entries: entries,
      notifyParents: false,
    );
    return null;
  }

  String _qrScanActionLabel(QrScanAction action) {
    switch (action) {
      case QrScanAction.present:
        return 'Present';
      case QrScanAction.late:
        return 'Late';
      case QrScanAction.absent:
        return 'Absent';
      case QrScanAction.entry:
        return 'Entry';
      case QrScanAction.exit:
        return 'Exit';
    }
  }

  void updateStudentPhoto(String studentId, String? photoPath) {
    for (final roster in _classRosters.values) {
      for (final student in roster) {
        if (student.id == studentId) {
          student.photoPath = photoPath;
          return;
        }
      }
    }
  }

  StudentRef? getStudentRef(String studentId) => getStudentById(studentId);

  bool addSubjectToGradeReport({
    required String studentName,
    required String className,
    required String subject,
    required String teacherId,
    String? subjectId,
    String? teachingSlotId,
  }) {
    final canonicalClass = _canonicalClassName(className);
    StudentGradeReport? report = _findGradeReport(
      studentName: studentName,
      className: canonicalClass,
    );
    if (report == null) {
      report = StudentGradeReport(
        studentName: studentName,
        className: canonicalClass,
        term: 'Term 1',
        subjects: [],
        studentId: StudentRegistryService.instance
            .lookupByName(studentName)
            ?.studentId,
      );
      _gradeReports.add(report);
    }

    if (report.subjects.any((item) => item.subject == subject)) {
      return false;
    }

    report.subjects.add(
      SubjectGrade(
        subject: subject,
        score: 0,
        maxScore: 100,
        enteredByTeacherId: teacherId,
        subjectId: subjectId,
        teachingSlotId: teachingSlotId,
        publishedToParents: false,
      ),
    );
    _persistGradeReports();
    return true;
  }

  /// Upserts Ethiopian national holidays for last year → +2 years.
  /// Replaces legacy single-year seed ids (`eth-1` … `eth-6`).
  void ensureEthiopianHolidaysSynced({
    bool force = false,
    bool persist = true,
  }) {
    if (_ethiopianHolidaysSynced && !force) return;
    final year = DateTime.now().year;
    final catalog =
        EthiopianHolidayCatalog.forYearRange(year - 1, year + 2);
    var changed = false;

    final before = _calendarEvents.length;
    _calendarEvents.removeWhere((e) => RegExp(r'^eth-\d+$').hasMatch(e.id));
    if (_calendarEvents.length != before) changed = true;

    for (final holiday in catalog) {
      final index = _calendarEvents.indexWhere((e) => e.id == holiday.id);
      if (index < 0) {
        _calendarEvents.add(holiday);
        changed = true;
        continue;
      }
      final existing = _calendarEvents[index];
      if (existing.date.year != holiday.date.year ||
          existing.date.month != holiday.date.month ||
          existing.date.day != holiday.date.day ||
          existing.title != holiday.title ||
          !existing.isEthiopianHoliday) {
        _calendarEvents[index] = holiday.copyWith(
          announcementPublished: existing.announcementPublished,
          announcementReminderPublished:
              existing.announcementReminderPublished,
        );
        changed = true;
      }
    }

    _ethiopianHolidaysSynced = true;
    if (changed && persist) _persistSchoolContent();
  }

  CalendarEvent scheduleCalendarEvent({
    required String title,
    required String description,
    required DateTime date,
    required CalendarEventType type,
    required String audience,
    required bool autoAnnounce,
    String? time,
  }) {
    final event = CalendarEvent(
      id: 'cal-${_nextCalendarId++}',
      title: title.trim(),
      description: description.trim(),
      date: DateTime(date.year, date.month, date.day),
      type: type,
      time: (time == null || time.trim().isEmpty) ? null : time.trim(),
      audience: audience,
      autoAnnounce: autoAnnounce,
    );
    _calendarEvents.add(event);
    _persistSchoolContent();
    return event;
  }

  bool updateCalendarEvent(CalendarEvent updated) {
    final index = _calendarEvents.indexWhere((e) => e.id == updated.id);
    if (index < 0) return false;
    if (_calendarEvents[index].isEthiopianHoliday) return false;
    _calendarEvents[index] = updated.copyWith(
      date: DateTime(
        updated.date.year,
        updated.date.month,
        updated.date.day,
      ),
    );
    _persistSchoolContent();
    return true;
  }

  bool deleteCalendarEvent(String id) {
    final index = _calendarEvents.indexWhere((e) => e.id == id);
    if (index < 0) return false;
    if (_calendarEvents[index].isEthiopianHoliday) return false;
    _calendarEvents.removeAt(index);
    _persistSchoolContent();
    unawaited(CloudAppStore.instance.deleteCalendarEvent(id));
    return true;
  }

  List<CalendarEvent> getVisibleCalendarEvents({bool includeEthiopian = true}) {
    ensureEthiopianHolidaysSynced();
    if (includeEthiopian) return List.unmodifiable(_calendarEvents);
    return _calendarEvents.where((event) => !event.isEthiopianHoliday).toList();
  }

  List<CalendarEvent> getVisibleCalendarEventsForRole(
    String? roleKey, {
    bool includeEthiopian = true,
  }) {
    final events = getVisibleCalendarEvents(includeEthiopian: includeEthiopian);
    if (roleKey == AuthService.roleAdmin) return events;
    return events
        .where((event) => calendarEventVisibleToRole(event, roleKey))
        .toList(growable: false);
  }

  bool calendarEventVisibleToRole(CalendarEvent event, String? roleKey) {
    if (roleKey == AuthService.roleAdmin) return true;
    final audience = event.audience.trim().toLowerCase();
    if (audience.isEmpty || audience == 'all') return true;

    final classNames = getChildren()
        .map((child) => child.className.trim())
        .where((name) => name.isNotEmpty)
        .toSet();

    bool matchesClass() => classNames.any(
          (className) =>
              _classNamesMatch(className, event.audience) ||
              audience.contains(className.toLowerCase()),
        );

    return switch (roleKey) {
      AuthService.roleStudent =>
        audience == 'students' || matchesClass(),
      AuthService.roleParent =>
        audience == 'parents' ||
            audience == 'students' ||
            matchesClass(),
      AuthService.roleTeacher =>
        audience == 'teachers' ||
            audience == 'staff' ||
            matchesClass(),
      AuthService.roleDriver => audience == 'transport' || audience == 'staff',
      _ => true,
    };
  }

  List<CalendarEvent> getUpcomingEvents({int days = 30}) {
    ensureEthiopianHolidaysSynced();
    final now = DateTime.now();
    final end = now.add(Duration(days: days));
    return _calendarEvents
        .where(
          (event) =>
              !event.date.isBefore(DateTime(now.year, now.month, now.day)) &&
              !event.date.isAfter(end),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  void publishDueCalendarAnnouncements() {
    ensureEthiopianHolidaysSynced();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final event in _calendarEvents) {
      if (!event.autoAnnounce) continue;

      final eventDay = DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
      );
      final dayBefore = eventDay.subtract(const Duration(days: 1));

      if (!event.announcementReminderPublished && today == dayBefore) {
        addAnnouncement(
          title: event.isEthiopianHoliday
              ? 'Holiday Tomorrow: ${event.title}'
              : 'Tomorrow: ${event.title}',
          body: '${event.description}\n\nScheduled for tomorrow.'
              '${event.time != null ? '\nTime: ${event.time}' : ''}',
          author: 'School Calendar',
          audience: event.audience,
        );
        event.announcementReminderPublished = true;
      }

      if (!event.announcementPublished && today == eventDay) {
        addAnnouncement(
          title: event.isEthiopianHoliday
              ? 'Holiday Today: ${event.title}'
              : 'Today: ${event.title}',
          body: event.description,
          author: 'School Calendar',
          audience: event.audience,
        );
        event.announcementPublished = true;
      }
    }
  }

  String _conductKey(String className, String studentId) =>
      '${className.trim()}|${studentId.trim()}';

  StudentConductRating? getStudentConduct({
    required String className,
    required String studentId,
  }) {
    return _studentConduct[_conductKey(className, studentId)];
  }

  void setStudentConduct({
    required String className,
    required String studentId,
    required StudentConductRating rating,
  }) {
    _studentConduct[_conductKey(className, studentId)] = rating;
  }

  StudentRef? findStudentInClass({
    required String className,
    required String studentName,
  }) {
    try {
      return getStudentsForClass(className)
          .firstWhere((student) => student.name == studentName);
    } catch (_) {
      return null;
    }
  }

  // —— Firestore snapshots & apply ——

  List<FeeRecord> feesSnapshot() => List.unmodifiable(_fees);

  void applyPersistedFees(List<FeeRecord> fees) {
    for (final fee in fees) {
      final index = _fees.indexWhere((f) => f.id == fee.id);
      if (index >= 0) {
        _fees[index] = fee;
      } else {
        _fees.add(fee);
      }
    }
  }

  List<CalendarEvent> calendarSnapshot() => List.unmodifiable(_calendarEvents);

  int calendarNextIdSnapshot() => _nextCalendarId;

  void applyPersistedCalendar(List<CalendarEvent> events, {int? nextId}) {
    for (final event in events) {
      final index = _calendarEvents.indexWhere((e) => e.id == event.id);
      if (index >= 0) {
        _calendarEvents[index] = event;
      } else {
        _calendarEvents.add(event);
      }
    }
    if (nextId != null && nextId > _nextCalendarId) {
      _nextCalendarId = nextId;
    }
    ensureEthiopianHolidaysSynced(force: true, persist: false);
  }

  List<GalleryPost> gallerySnapshot() => List.unmodifiable(_galleryPosts);

  void applyPersistedGallery(List<GalleryPost> posts) {
    for (final post in posts) {
      final index = _galleryPosts.indexWhere((p) => p.id == post.id);
      if (index >= 0) {
        _galleryPosts[index] = post;
      } else {
        _galleryPosts.add(post);
      }
    }
  }

  List<QrScanRecord> qrScanSnapshot() => List.unmodifiable(_qrScanHistory);

  void applyPersistedQrScans(List<QrScanRecord> scans) {
    for (final scan in scans) {
      final exists = _qrScanHistory.any(
        (s) =>
            s.studentId == scan.studentId &&
            s.time.millisecondsSinceEpoch == scan.time.millisecondsSinceEpoch,
      );
      if (!exists) _qrScanHistory.add(scan);
    }
  }

  List<Announcement> announcementsSnapshot() =>
      List.unmodifiable(_announcements);

  int announcementNextIdSnapshot() => _nextAnnouncementId;

  void applyPersistedAnnouncements(List<Announcement> items, {int? nextId}) {
    for (final item in items) {
      final index = _announcements.indexWhere((a) => a.id == item.id);
      if (index >= 0) {
        _announcements[index] = item;
      } else {
        _announcements.add(item);
      }
    }
    if (nextId != null && nextId > _nextAnnouncementId) {
      _nextAnnouncementId = nextId;
    }
  }

  List<AttendanceSession> attendanceSnapshot() =>
      List.unmodifiable(_attendanceSessions);

  void applyPersistedAttendance(List<AttendanceSession> sessions) {
    for (final session in sessions) {
      final existing = getAttendanceSession(session.className, session.date);
      if (existing != null) {
        _attendanceSessions.remove(existing);
      }
      _attendanceSessions.add(session);
    }
  }
}

class SubjectGradePendingItem {
  const SubjectGradePendingItem({
    required this.report,
    required this.subjectGrade,
  });

  final StudentGradeReport report;
  final SubjectGrade subjectGrade;

  String get subject => subjectGrade.subject;
}

class SubjectGradesClassEntryResult {
  const SubjectGradesClassEntryResult({
    required this.saved,
    required this.skippedLocked,
  });

  final int saved;
  final int skippedLocked;
}
