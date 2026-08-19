/// Student portal account lifecycle.
enum StudentAccountStatus {
  active,
  inactive,
  suspended,
  graduated,
  transferred;

  static StudentAccountStatus parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return StudentAccountStatus.inactive;
    return StudentAccountStatus.values.firstWhere(
      (value) => value.name == raw.trim().toLowerCase(),
      orElse: () => StudentAccountStatus.inactive,
    );
  }

  bool get canLogin => this == StudentAccountStatus.active;
}

enum StudentUsernameFormat {
  firstNameLast4Id;

  static StudentUsernameFormat parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return StudentUsernameFormat.firstNameLast4Id;
    }
    return StudentUsernameFormat.values.firstWhere(
      (value) => value.name == raw.trim(),
      orElse: () => StudentUsernameFormat.firstNameLast4Id,
    );
  }
}

/// Per-school student portal configuration.
class StudentPortalSettings {
  const StudentPortalSettings({
    this.enabled = true,
    this.minimumGrade = 7,
    this.usernameFormat = StudentUsernameFormat.firstNameLast4Id,
    this.tempPasswordTemplate = 'EduAba@2026',
    this.allowHomeworkUpload = true,
    this.allowReportDownload = true,
    this.allowStudentMessaging = false,
    this.allowClassRank = false,
  });

  final bool enabled;
  final int minimumGrade;
  final StudentUsernameFormat usernameFormat;
  final String tempPasswordTemplate;
  final bool allowHomeworkUpload;
  final bool allowReportDownload;
  final bool allowStudentMessaging;
  final bool allowClassRank;

  StudentPortalSettings copyWith({
    bool? enabled,
    int? minimumGrade,
    StudentUsernameFormat? usernameFormat,
    String? tempPasswordTemplate,
    bool? allowHomeworkUpload,
    bool? allowReportDownload,
    bool? allowStudentMessaging,
    bool? allowClassRank,
  }) {
    return StudentPortalSettings(
      enabled: enabled ?? this.enabled,
      minimumGrade: minimumGrade ?? this.minimumGrade,
      usernameFormat: usernameFormat ?? this.usernameFormat,
      tempPasswordTemplate: tempPasswordTemplate ?? this.tempPasswordTemplate,
      allowHomeworkUpload: allowHomeworkUpload ?? this.allowHomeworkUpload,
      allowReportDownload: allowReportDownload ?? this.allowReportDownload,
      allowStudentMessaging:
          allowStudentMessaging ?? this.allowStudentMessaging,
      allowClassRank: allowClassRank ?? this.allowClassRank,
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'minimumGrade': minimumGrade,
        'usernameFormat': usernameFormat.name,
        'tempPasswordTemplate': tempPasswordTemplate,
        'allowHomeworkUpload': allowHomeworkUpload,
        'allowReportDownload': allowReportDownload,
        'allowStudentMessaging': allowStudentMessaging,
        'allowClassRank': allowClassRank,
      };

  factory StudentPortalSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return const StudentPortalSettings();
    return StudentPortalSettings(
      enabled: map['enabled'] as bool? ?? true,
      minimumGrade: map['minimumGrade'] as int? ?? 7,
      usernameFormat:
          StudentUsernameFormat.parse(map['usernameFormat'] as String?),
      tempPasswordTemplate:
          map['tempPasswordTemplate'] as String? ?? 'EduAba@2026',
      allowHomeworkUpload: map['allowHomeworkUpload'] as bool? ?? true,
      allowReportDownload: map['allowReportDownload'] as bool? ?? true,
      allowStudentMessaging: map['allowStudentMessaging'] as bool? ?? false,
      allowClassRank: map['allowClassRank'] as bool? ?? false,
    );
  }
}

enum StudentPortalAuditAction {
  login,
  loginFailed,
  passwordChange,
  passwordReset,
  accountCreated,
  accountStatusChanged,
  passwordResetRequested,
}

class StudentPortalAuditEntry {
  StudentPortalAuditEntry({
    required this.id,
    required this.at,
    required this.action,
    required this.schoolId,
    this.studentId,
    this.username,
    this.actor,
    this.detail,
  });

  final String id;
  final DateTime at;
  final StudentPortalAuditAction action;
  final String schoolId;
  final String? studentId;
  final String? username;
  final String? actor;
  final String? detail;

  Map<String, dynamic> toMap() => {
        'id': id,
        'at': at.toIso8601String(),
        'action': action.name,
        'schoolId': schoolId,
        if (studentId != null) 'studentId': studentId,
        if (username != null) 'username': username,
        if (actor != null) 'actor': actor,
        if (detail != null) 'detail': detail,
      };

  factory StudentPortalAuditEntry.fromMap(Map<String, dynamic> map) {
    return StudentPortalAuditEntry(
      id: map['id'] as String? ?? '',
      at: DateTime.tryParse(map['at'] as String? ?? '') ?? DateTime.now(),
      action: StudentPortalAuditAction.values.firstWhere(
        (value) => value.name == (map['action'] as String? ?? ''),
        orElse: () => StudentPortalAuditAction.login,
      ),
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      studentId: map['studentId'] as String?,
      username: map['username'] as String?,
      actor: map['actor'] as String?,
      detail: map['detail'] as String?,
    );
  }
}

class StudentPasswordResetRequest {
  StudentPasswordResetRequest({
    required this.id,
    required this.studentId,
    required this.schoolId,
    required this.requestedAt,
    this.username,
    this.studentName,
    this.status = 'pending',
    this.resolvedAt,
    this.resolvedBy,
  });

  final String id;
  final String studentId;
  final String schoolId;
  final DateTime requestedAt;
  final String? username;
  final String? studentName;
  final String status;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  Map<String, dynamic> toMap() => {
        'id': id,
        'studentId': studentId,
        'schoolId': schoolId,
        'requestedAt': requestedAt.toIso8601String(),
        if (username != null) 'username': username,
        if (studentName != null) 'studentName': studentName,
        'status': status,
        if (resolvedAt != null) 'resolvedAt': resolvedAt!.toIso8601String(),
        if (resolvedBy != null) 'resolvedBy': resolvedBy,
      };

  factory StudentPasswordResetRequest.fromMap(Map<String, dynamic> map) {
    return StudentPasswordResetRequest(
      id: map['id'] as String? ?? '',
      studentId: (map['studentId'] as String? ?? '').trim().toUpperCase(),
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      requestedAt:
          DateTime.tryParse(map['requestedAt'] as String? ?? '') ?? DateTime.now(),
      username: map['username'] as String?,
      studentName: map['studentName'] as String?,
      status: map['status'] as String? ?? 'pending',
      resolvedAt: map['resolvedAt'] != null
          ? DateTime.tryParse(map['resolvedAt'] as String)
          : null,
      resolvedBy: map['resolvedBy'] as String?,
    );
  }
}
