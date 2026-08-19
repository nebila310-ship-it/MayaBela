import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/models/grade_workflow.dart';

enum AnnouncementPriority { normal, important, urgent }

/// Role keys used when targeting announcement audiences.
class AnnouncementAudiences {
  AnnouncementAudiences._();

  static const all = 'all';
  static const parents = 'parents';
  static const teachers = 'teachers';
  static const students = 'students';
  static const transport = 'transport';
  static const admin = 'admin';

  static const selectable = [parents, teachers, students, transport, admin];

  static String normalizeLegacy(String raw) {
    switch (raw.trim()) {
      case 'All':
        return all;
      case 'Parents':
        return parents;
      case 'Teachers':
        return teachers;
      case 'Staff':
        return admin;
      case 'Students':
        return students;
      default:
        final lower = raw.trim().toLowerCase();
        if (lower == all ||
            lower == parents ||
            lower == teachers ||
            lower == students ||
            lower == transport ||
            lower == admin) {
          return lower;
        }
        return all;
    }
  }
}

class AnnouncementAttachment {
  const AnnouncementAttachment({
    required this.id,
    required this.fileName,
    required this.filePath,
    this.fileSizeBytes,
  });

  final String id;
  final String fileName;
  final String filePath;
  final int? fileSizeBytes;
}

class Announcement {
  Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.author,
    required this.date,
    List<String>? audienceKeys,
    String? audience,
    this.isPinned = false,
    this.priority = AnnouncementPriority.normal,
    this.attachments = const [],
    this.createdByRole,
    this.createdByAuthor,
  }) : audienceKeys = audienceKeys != null && audienceKeys.isNotEmpty
            ? _normalizeKeys(audienceKeys)
            : [AnnouncementAudiences.normalizeLegacy(audience ?? 'All')];

  final String id;
  final String title;
  final String body;
  final String author;
  final DateTime date;
  final List<String> audienceKeys;
  final bool isPinned;
  final AnnouncementPriority priority;
  final List<AnnouncementAttachment> attachments;
  final String? createdByRole;
  final String? createdByAuthor;

  /// Legacy single-audience label for older call sites.
  String get audience {
    if (audienceKeys.contains(AnnouncementAudiences.all)) {
      return 'All';
    }
    if (audienceKeys.length == 1) {
      return _legacyLabelForKey(audienceKeys.first);
    }
    return audienceKeys.map(_legacyLabelForKey).join(', ');
  }

  bool isVisibleToRole(String? roleKey) {
    if (roleKey == AuthService.roleAdmin) return true;
    final user = AuthService.currentUser;
    if (user != null) {
      if (createdByAuthor != null &&
          createdByAuthor!.trim().toLowerCase() ==
              user.fullName?.trim().toLowerCase()) {
        return true;
      }
      if (createdByRole != null && createdByRole == roleKey) return true;
    }
    if (audienceKeys.contains(AnnouncementAudiences.all)) return true;
    return switch (roleKey) {
      AuthService.roleParent =>
        audienceKeys.contains(AnnouncementAudiences.parents),
      AuthService.roleTeacher =>
        audienceKeys.contains(AnnouncementAudiences.teachers),
      AuthService.roleDriver =>
        audienceKeys.contains(AnnouncementAudiences.transport),
      AuthService.roleStudent => _visibleToStudentAudience(audienceKeys),
      _ => false,
    };
  }

  static bool _visibleToStudentAudience(List<String> keys) {
    if (keys.contains(AnnouncementAudiences.students)) return true;
    // Class-specific keys, e.g. homeroom posts targeted at "Grade 7A".
    final classes = SchoolDataService.instance
        .getChildren()
        .map((child) => child.className.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet();
    for (final key in keys) {
      final normalized = key.trim().toLowerCase();
      if (classes.contains(normalized)) return true;
    }
    return false;
  }

  static List<String> _normalizeKeys(List<String> keys) {
    if (keys.contains(AnnouncementAudiences.all)) {
      return [AnnouncementAudiences.all];
    }
    return keys.map(AnnouncementAudiences.normalizeLegacy).toSet().toList();
  }

  static String _legacyLabelForKey(String key) {
    return switch (key) {
      AnnouncementAudiences.all => 'All',
      AnnouncementAudiences.parents => 'Parents',
      AnnouncementAudiences.teachers => 'Teachers',
      AnnouncementAudiences.students => 'Students',
      AnnouncementAudiences.transport => 'Transport',
      AnnouncementAudiences.admin => 'Admin',
      _ => key,
    };
  }
}

class SubjectGrade {
  SubjectGrade({
    required this.subject,
    required this.score,
    required this.maxScore,
    this.comment,
    this.enteredByTeacherId,
    this.subjectId,
    this.teachingSlotId,
    this.publishedToParents = false,
    this.publishedAt,
    SubjectGradeStatus? status,
    this.approvalLevelIndex = 0,
    this.submittedAt,
    this.submittedByTeacherId,
    this.reviewComment,
    this.lastReviewedBy,
    this.lastReviewedAt,
    List<String>? markPhotoPaths,
    List<String>? attachmentPaths,
  })  : status = status ??
            (publishedToParents
                ? SubjectGradeStatus.approved
                : SubjectGradeStatus.draft),
        markPhotoPaths = markPhotoPaths ?? [],
        attachmentPaths = attachmentPaths ?? [];

  final String subject;
  double score;
  final double maxScore;

  String? comment;
  String? enteredByTeacherId;
  String? subjectId;
  String? teachingSlotId;
  bool publishedToParents;
  DateTime? publishedAt;
  SubjectGradeStatus status;
  int approvalLevelIndex;
  DateTime? submittedAt;
  String? submittedByTeacherId;
  String? reviewComment;
  String? lastReviewedBy;
  DateTime? lastReviewedAt;
  List<String> markPhotoPaths;
  List<String> attachmentPaths;

  bool get canTeacherEdit => status.canTeacherEdit;

  bool get isVisibleToParent =>
      status == SubjectGradeStatus.approved && publishedToParents;

  double get percentage => maxScore == 0 ? 0 : (score / maxScore) * 100;

  String get letterGrade {
    final p = percentage;
    if (p >= 90) return 'A';
    if (p >= 80) return 'B';
    if (p >= 70) return 'C';
    if (p >= 60) return 'D';
    return 'F';
  }

  Map<String, dynamic> toMap() => {
        'subject': subject,
        'score': score,
        'maxScore': maxScore,
        if (comment != null) 'comment': comment,
        if (enteredByTeacherId != null) 'enteredByTeacherId': enteredByTeacherId,
        if (subjectId != null) 'subjectId': subjectId,
        if (teachingSlotId != null) 'teachingSlotId': teachingSlotId,
        'publishedToParents': publishedToParents,
        if (publishedAt != null) 'publishedAt': publishedAt!.toIso8601String(),
        'status': status.name,
        'approvalLevelIndex': approvalLevelIndex,
        if (submittedAt != null) 'submittedAt': submittedAt!.toIso8601String(),
        if (submittedByTeacherId != null)
          'submittedByTeacherId': submittedByTeacherId,
        if (reviewComment != null) 'reviewComment': reviewComment,
        if (lastReviewedBy != null) 'lastReviewedBy': lastReviewedBy,
        if (lastReviewedAt != null)
          'lastReviewedAt': lastReviewedAt!.toIso8601String(),
        'markPhotoPaths': markPhotoPaths,
        'attachmentPaths': attachmentPaths,
      };

  factory SubjectGrade.fromMap(Map<String, dynamic> map) {
    final published = map['publishedToParents'] as bool? ?? false;
    final parsedStatus = map['status'] != null
        ? SubjectGradeStatus.parse(map['status'] as String?)
        : (published ? SubjectGradeStatus.approved : SubjectGradeStatus.draft);
    return SubjectGrade(
      subject: map['subject'] as String? ?? '',
      score: (map['score'] as num?)?.toDouble() ?? 0,
      maxScore: (map['maxScore'] as num?)?.toDouble() ?? 100,
      comment: map['comment'] as String?,
      enteredByTeacherId: map['enteredByTeacherId'] as String?,
      subjectId: map['subjectId'] as String?,
      teachingSlotId: map['teachingSlotId'] as String?,
      publishedToParents: published,
      publishedAt: map['publishedAt'] != null
          ? DateTime.tryParse(map['publishedAt'] as String)
          : null,
      status: parsedStatus,
      approvalLevelIndex: map['approvalLevelIndex'] as int? ?? 0,
      submittedAt: map['submittedAt'] != null
          ? DateTime.tryParse(map['submittedAt'] as String)
          : null,
      submittedByTeacherId: map['submittedByTeacherId'] as String?,
      reviewComment: map['reviewComment'] as String?,
      lastReviewedBy: map['lastReviewedBy'] as String?,
      lastReviewedAt: map['lastReviewedAt'] != null
          ? DateTime.tryParse(map['lastReviewedAt'] as String)
          : null,
      markPhotoPaths: (map['markPhotoPaths'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      attachmentPaths: (map['attachmentPaths'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class StudentGradeReport {
  StudentGradeReport({
    required this.studentName,
    required this.className,
    required this.term,
    required this.subjects,
    this.studentId,
  });

  final String studentName;
  final String className;
  final String term;
  final List<SubjectGrade> subjects;
  final String? studentId;

  double get average {
    if (subjects.isEmpty) return 0;
    return subjects.map((s) => s.percentage).reduce((a, b) => a + b) /
        subjects.length;
  }

  Map<String, dynamic> toMap() => {
        'studentName': studentName,
        'className': className,
        'term': term,
        if (studentId != null) 'studentId': studentId,
        'subjects': subjects.map((s) => s.toMap()).toList(),
      };

  factory StudentGradeReport.fromMap(Map<String, dynamic> map) {
    return StudentGradeReport(
      studentName: map['studentName'] as String? ?? '',
      className: map['className'] as String? ?? '',
      term: map['term'] as String? ?? 'Term 1',
      studentId: map['studentId'] as String?,
      subjects: (map['subjects'] as List?)
              ?.whereType<Map>()
              .map((e) => SubjectGrade.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
    );
  }

  StudentGradeReport copyWithSubjects(List<SubjectGrade> nextSubjects) {
    return StudentGradeReport(
      studentName: studentName,
      className: className,
      term: term,
      studentId: studentId,
      subjects: nextSubjects,
    );
  }
}

class CreateAnnouncementDraft {
  const CreateAnnouncementDraft({
    required this.title,
    required this.body,
    required this.audienceKeys,
    required this.priority,
    this.attachments = const [],
  });

  final String title;
  final String body;
  final List<String> audienceKeys;
  final AnnouncementPriority priority;
  final List<AnnouncementAttachment> attachments;
}
