import 'package:mayabela/utils/phone_utils.dart';

/// Built-in Maya School fixtures. They stay on TB-001 and never on a real school.
class DemoContent {
  DemoContent._();

  static const schoolId = 'TB-001';

  static bool isRealSchool(String? raw) {
    final sid = (raw ?? '').trim().toUpperCase();
    return sid.isNotEmpty && sid != schoolId;
  }

  static const sampleStudentNames = {
    'sara bekele',
    'kidus bekele',
    'daniel tesfaye',
    'hanna girma',
    'liya solomon',
  };

  static const sampleStaffNames = {
    'miss belen',
    'mr. samuel',
    'miss hana',
    'mr. tadesse',
    'mr. bekele',
    'mrs. selam',
    'mr. getachew',
    'alemayehu t.',
  };

  static const sampleLogins = {
    'teacher',
    'samuel',
    'parent',
    'admin',
    'driver',
    'transport',
    'student',
  };

  static const sampleTeacherIds = {
    'TCH-1001',
    'TCH-1002',
    'TCH-1003',
    'TCH-1004',
  };

  static const sampleStudentIds = {
    'STU-1001',
    'STU-1002',
    'STU-1003',
    'STU-1004',
    'STU-1005',
  };

  static const _samplePhones = {
    '0911223344',
    '0911334455',
    '0911445566',
    '0911000001',
    '0911000002',
    '0911000003',
    '0911556677',
    '0911667788',
    '0911778899',
    '0911889900',
  };

  static bool isSampleTeacher({
    required String teacherId,
    required String fullName,
    required String schoolId,
    String? email,
    String? phone,
    String? loginUsername,
  }) {
    final id = teacherId.trim().toUpperCase();
    final school = schoolId.trim().toUpperCase();
    final name = fullName.trim().toLowerCase();
    if (sampleTeacherIds.contains(id)) {
      if (school.isEmpty || school == DemoContent.schoolId) return true;
      const expected = {
        'TCH-1001': 'miss belen',
        'TCH-1002': 'mr. samuel',
        'TCH-1003': 'miss hana',
        'TCH-1004': 'mr. tadesse',
      };
      if (expected[id] == name) return true;
    }
    final mail = (email ?? '').trim().toLowerCase();
    if (mail.endsWith('@mayaschool.et')) return true;
    final login = (loginUsername ?? '').trim().toLowerCase();
    if (sampleLogins.contains(login)) return true;
    final normalized = PhoneUtils.normalizeLocal(phone ?? '') ?? '';
    if (normalized.isNotEmpty &&
        _samplePhones.contains(normalized) &&
        sampleStaffNames.contains(name)) {
      return true;
    }
    return false;
  }

  static bool isSampleStudent({
    required String studentId,
    required String fullName,
    required String schoolId,
  }) {
    final id = studentId.trim().toUpperCase();
    if (!sampleStudentIds.contains(id)) return false;
    final school = schoolId.trim().toUpperCase();
    if (school.isEmpty || school == DemoContent.schoolId) return true;
    const expected = {
      'STU-1001': 'sara bekele',
      'STU-1002': 'kidus bekele',
      'STU-1003': 'daniel tesfaye',
      'STU-1004': 'hanna girma',
      'STU-1005': 'liya solomon',
    };
    return expected[id] == fullName.trim().toLowerCase();
  }

  static bool isSampleNotification({
    required String id,
    required String fromName,
    required String title,
    required String body,
  }) {
    if (id.trim().toLowerCase().startsWith('seed-')) return true;
    final from = fromName.trim().toLowerCase();
    if (sampleStaffNames.contains(from)) return true;
    final text = '${title.trim()} ${body.trim()}'.toLowerCase();
    for (final name in sampleStudentNames) {
      if (text.contains(name)) return true;
    }
    for (final name in sampleStaffNames) {
      if (name.length > 4 && text.contains(name)) return true;
    }
    return false;
  }

  static bool isSampleAnnouncement({
    required String id,
    required String title,
    required String author,
  }) {
    const seeded = {
      '1': 'parent-teacher meeting',
      '2': 'grade 4 field trip',
      '3': 'staff development day',
    };
    final expected = seeded[id.trim()];
    if (expected == null) return false;
    return title.trim().toLowerCase() == expected ||
        sampleStaffNames.contains(author.trim().toLowerCase());
  }

  static bool isSampleConversation({
    required String id,
    required String name,
  }) {
    const seeded = {
      '1': 'mr. bekele',
      '2': 'miss belen',
      '3': 'miss hana',
      '4': 'transport team',
    };
    final expected = seeded[id.trim()];
    if (expected == null) return false;
    return name.trim().toLowerCase() == expected;
  }

  static bool isSampleAttendance({
    required String className,
    required String conductedBy,
    required Iterable<String> studentNames,
  }) {
    const classes = {'grade 4a', 'grade 5b', 'grade 2c'};
    if (!classes.contains(className.trim().toLowerCase())) return false;
    if (!sampleStaffNames.contains(conductedBy.trim().toLowerCase())) {
      return false;
    }
    final names = studentNames
        .map((name) => name.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toList();
    if (names.isEmpty) return false;
    return names.every(sampleStudentNames.contains);
  }

  static bool isSampleLearningMaterial({
    required String id,
    required String bookName,
    required String teacherId,
  }) {
    if (id.trim().toLowerCase().startsWith('lm-sample-')) return true;
    if (sampleTeacherIds.contains(teacherId.trim().toUpperCase()) &&
        bookName.trim().toLowerCase().startsWith('sample ')) {
      return true;
    }
    return false;
  }

  static bool isSampleInventoryItem({
    required String name,
    String? supplier,
  }) {
    const seeds = {
      'mathematics textbook grade 5': 'ethio books plc',
      'student desk': 'addis furniture',
      'a4 exercise book': 'paper world',
    };
    return seeds[name.trim().toLowerCase()] ==
        (supplier ?? '').trim().toLowerCase();
  }

  static bool isSampleSchoolAsset({
    required String name,
    required String serialNumber,
  }) {
    return name.trim().toLowerCase() == 'epson projector' &&
        serialNumber.trim().toUpperCase() == 'EP-2024-001';
  }

  static bool isSampleGradeReport({
    required String studentName,
    String? studentId,
  }) {
    final id = (studentId ?? '').trim().toUpperCase();
    if (sampleStudentIds.contains(id)) return true;
    return sampleStudentNames.contains(studentName.trim().toLowerCase());
  }
}
