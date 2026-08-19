class PlatformAuditEntry {
  PlatformAuditEntry({
    required this.id,
    required this.at,
    required this.action,
    this.schoolId,
    this.schoolName,
    this.detail,
  });

  final String id;
  final DateTime at;
  final String action;
  final String? schoolId;
  final String? schoolName;
  final String? detail;

  String get actionLabel => switch (action) {
        'school_created' => 'School created',
        'school_updated' => 'Profile updated',
        'school_deleted' => 'School deleted',
        'status_changed' => 'Status changed',
        'subscription_renewed' => 'Subscription renewed',
        'subscription_set' => 'Subscription date set',
        'logo_updated' => 'Logo updated',
        'logo_removed' => 'Logo removed',
        'backup_exported' => 'Backup exported',
        'bulk_sms_sent' => 'Bulk SMS sent',
        _ => action,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'action': action,
        'schoolId': schoolId,
        'schoolName': schoolName,
        'detail': detail,
      };

  factory PlatformAuditEntry.fromJson(Map<String, dynamic> json) {
    return PlatformAuditEntry(
      id: json['id'] as String,
      at: DateTime.parse(json['at'] as String),
      action: json['action'] as String,
      schoolId: json['schoolId'] as String?,
      schoolName: json['schoolName'] as String?,
      detail: json['detail'] as String?,
    );
  }
}
