enum ClassTeacherRole { homeroom, subject }

class ClassAssignment {
  ClassAssignment({
    required this.className,
    required this.role,
    required this.room,
    required this.schedule,
    required this.students,
    this.subject,
    this.homeroomTeacherName,
  });

  final String className;
  final ClassTeacherRole role;
  final String room;
  final String schedule;
  final List<StudentRef> students;
  final String? subject;
  final String? homeroomTeacherName;

  bool get isHomeroom => role == ClassTeacherRole.homeroom;
  int get studentCount => students.length;
}

class StudentRef {
  StudentRef({
    required this.id,
    required this.name,
    required this.grade,
    this.parentName,
    this.registryStudentId,
    this.parentPhone,
  });

  final String id;
  final String name;
  final String grade;
  final String? parentName;
  final String? registryStudentId;
  final String? parentPhone;
  String? photoPath;

  String get inviteStudentId => registryStudentId ?? id;
}

enum AttendanceStatus { present, absent, late }

class StudentAttendanceEntry {
  StudentAttendanceEntry({
    required this.studentName,
    required this.status,
  });

  final String studentName;
  AttendanceStatus status;
}

class AttendanceSession {
  AttendanceSession({
    required this.className,
    required this.date,
    required this.conductedBy,
    required this.entries,
  });

  final String className;
  final DateTime date;
  final String conductedBy;
  final List<StudentAttendanceEntry> entries;
}

class AttendanceSessionSummary {
  const AttendanceSessionSummary({
    required this.className,
    required this.conductedBy,
    required this.presentCount,
    required this.lateCount,
    required this.absentCount,
  });

  final String className;
  final String conductedBy;
  final int presentCount;
  final int lateCount;
  final int absentCount;
}

class StudentAttendanceRecord {
  const StudentAttendanceRecord({
    required this.studentName,
    required this.grade,
    required this.className,
    required this.status,
    required this.conductedBy,
    this.date,
  });

  final String studentName;
  final String grade;
  final String className;
  final AttendanceStatus status;
  final String conductedBy;
  final DateTime? date;
}

class AttendanceDateRangeReport {
  const AttendanceDateRangeReport({
    required this.fromDate,
    required this.toDate,
    required this.presentCount,
    required this.lateCount,
    required this.absentCount,
    required this.dailyReports,
    required this.records,
  });

  final DateTime fromDate;
  final DateTime toDate;
  final int presentCount;
  final int lateCount;
  final int absentCount;
  final List<DailyAttendanceReport> dailyReports;
  final List<StudentAttendanceRecord> records;

  int get totalCount => presentCount + lateCount + absentCount;

  int get dayCount => dailyReports.where((d) => d.totalCount > 0).length;
}

class DailyAttendanceReport {
  const DailyAttendanceReport({
    required this.date,
    required this.presentCount,
    required this.lateCount,
    required this.absentCount,
    required this.sessions,
    required this.records,
  });

  final DateTime date;
  final int presentCount;
  final int lateCount;
  final int absentCount;
  final List<AttendanceSessionSummary> sessions;
  final List<StudentAttendanceRecord> records;

  int get totalCount => presentCount + lateCount + absentCount;

  List<StudentAttendanceRecord> recordsForStatus(AttendanceStatus status) {
    return records.where((r) => r.status == status).toList();
  }

  Map<String, int> gradeCountsForStatus(AttendanceStatus status) {
    final counts = <String, int>{};
    for (final record in recordsForStatus(status)) {
      counts[record.grade] = (counts[record.grade] ?? 0) + 1;
    }
    return counts;
  }
}

class HomeworkItem {
  HomeworkItem({
    required this.id,
    required this.className,
    required this.subject,
    required this.description,
    required this.teacherName,
    required this.teacherId,
    required this.postedAt,
    this.subjectId,
    this.teachingSlotId,
    List<String>? attachmentPaths,
    Map<String, List<String>>? studentWorksheetPaths,
  })  : attachmentPaths = attachmentPaths ?? [],
        studentWorksheetPaths = studentWorksheetPaths ?? {};

  final String id;
  final String className;
  final String subject;
  String description;
  final String teacherName;
  final String teacherId;
  final DateTime postedAt;
  final String? subjectId;
  final String? teachingSlotId;
  List<String> attachmentPaths;
  Map<String, List<String>> studentWorksheetPaths;

  List<String> worksheetsForStudent(String studentId) {
    final key = studentId.trim().toUpperCase();
    return List<String>.from(studentWorksheetPaths[key] ?? const []);
  }
}

extension HomeworkItemPersistence on HomeworkItem {
  Map<String, dynamic> toMap() => {
        'id': id,
        'className': className,
        'subject': subject,
        'description': description,
        'teacherName': teacherName,
        'teacherId': teacherId,
        'postedAt': postedAt.toIso8601String(),
        if (subjectId != null) 'subjectId': subjectId,
        if (teachingSlotId != null) 'teachingSlotId': teachingSlotId,
        'attachmentPaths': attachmentPaths,
        'studentWorksheetPaths': studentWorksheetPaths.map(
          (key, value) => MapEntry(key, value),
        ),
      };

  static HomeworkItem fromMap(Map<String, dynamic> map) {
    final rawWorksheets = map['studentWorksheetPaths'] as Map?;
    final worksheets = <String, List<String>>{};
    if (rawWorksheets != null) {
      for (final entry in rawWorksheets.entries) {
        worksheets[entry.key.toString()] = (entry.value as List? ?? const [])
            .map((item) => item.toString())
            .toList();
      }
    }
    return HomeworkItem(
      id: map['id'] as String,
      className: map['className'] as String,
      subject: map['subject'] as String,
      description: map['description'] as String? ?? '',
      teacherName: map['teacherName'] as String? ?? 'Teacher',
      teacherId: map['teacherId'] as String? ?? '',
      postedAt: DateTime.parse(map['postedAt'] as String),
      subjectId: map['subjectId'] as String?,
      teachingSlotId: map['teachingSlotId'] as String?,
      attachmentPaths: List<String>.from(map['attachmentPaths'] as List? ?? []),
      studentWorksheetPaths: worksheets,
    );
  }
}

class LearningMaterialItem {
  LearningMaterialItem({
    required this.id,
    required this.className,
    required this.subject,
    required this.bookName,
    required this.materialName,
    required this.filePath,
    required this.teacherId,
    required this.teacherName,
    required this.postedAt,
    this.subjectId,
    this.teachingSlotId,
    this.isFree = true,
    this.price,
  });

  final String id;
  final String className;
  final String subject;
  String bookName;
  String materialName;
  String filePath;
  final String teacherId;
  final String teacherName;
  final DateTime postedAt;
  final String? subjectId;
  final String? teachingSlotId;

  /// Free materials are visible to every student/parent in the class.
  /// Paid materials stay locked until access is granted per student.
  bool isFree;

  /// Optional price shown on locked paid materials (ETB).
  double? price;
}

extension LearningMaterialItemPersistence on LearningMaterialItem {
  Map<String, dynamic> toMap() => {
        'id': id,
        'className': className,
        'subject': subject,
        'bookName': bookName,
        'materialName': materialName,
        'filePath': filePath,
        'teacherId': teacherId,
        'teacherName': teacherName,
        'postedAt': postedAt.toIso8601String(),
        if (subjectId != null) 'subjectId': subjectId,
        if (teachingSlotId != null) 'teachingSlotId': teachingSlotId,
        'isFree': isFree,
        if (price != null) 'price': price,
      };

  static LearningMaterialItem fromMap(Map<String, dynamic> map) {
    return LearningMaterialItem(
      id: map['id'] as String,
      className: map['className'] as String,
      subject: map['subject'] as String? ?? '',
      bookName: map['bookName'] as String? ?? '',
      materialName: map['materialName'] as String? ?? '',
      filePath: map['filePath'] as String? ?? '',
      teacherId: map['teacherId'] as String? ?? '',
      teacherName: map['teacherName'] as String? ?? 'Teacher',
      postedAt: DateTime.parse(map['postedAt'] as String),
      subjectId: map['subjectId'] as String?,
      teachingSlotId: map['teachingSlotId'] as String?,
      isFree: map['isFree'] as bool? ?? true,
      price: (map['price'] as num?)?.toDouble(),
    );
  }
}

enum GalleryPostType { photo, video, note }

class GalleryPost {
  GalleryPost({
    required this.id,
    required this.className,
    required this.type,
    required this.title,
    required this.caption,
    required this.authorName,
    required this.postedAt,
    this.mediaLabel,
    this.mediaPath,
  });

  final String id;
  final String className;
  final GalleryPostType type;
  final String title;
  final String caption;
  final String authorName;
  final DateTime postedAt;
  final String? mediaLabel;
  final String? mediaPath;
}

class DailyActivityOption {
  DailyActivityOption({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

class DailyActivityReport {
  DailyActivityReport({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.date,
    required this.selectedOptionIds,
    required this.teacherComment,
    required this.teacherName,
    this.parentComment,
    this.parentSeenAt,
    this.parentSeenBy,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String className;
  final DateTime date;
  List<String> selectedOptionIds;
  String teacherComment;
  final String teacherName;
  String? parentComment;
  DateTime? parentSeenAt;
  String? parentSeenBy;

  bool get parentHasSeen => parentSeenAt != null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'studentId': studentId,
        'studentName': studentName,
        'className': className,
        'date': date.toIso8601String(),
        'selectedOptionIds': selectedOptionIds,
        'teacherComment': teacherComment,
        'teacherName': teacherName,
        'parentComment': parentComment,
        'parentSeenAt': parentSeenAt?.toIso8601String(),
        'parentSeenBy': parentSeenBy,
      };

  factory DailyActivityReport.fromMap(Map<String, dynamic> map) {
    return DailyActivityReport(
      id: map['id'] as String,
      studentId: map['studentId'] as String,
      studentName: map['studentName'] as String,
      className: map['className'] as String,
      date: DateTime.parse(map['date'] as String),
      selectedOptionIds: List<String>.from(map['selectedOptionIds'] as List),
      teacherComment: map['teacherComment'] as String? ?? '',
      teacherName: map['teacherName'] as String,
      parentComment: map['parentComment'] as String?,
      parentSeenAt: map['parentSeenAt'] != null
          ? DateTime.parse(map['parentSeenAt'] as String)
          : null,
      parentSeenBy: map['parentSeenBy'] as String?,
    );
  }
}

class ClassSubjectTeacher {
  ClassSubjectTeacher({
    required this.subject,
    required this.teacherId,
    required this.teacherName,
  });

  final String subject;
  final String teacherId;
  final String teacherName;
}
