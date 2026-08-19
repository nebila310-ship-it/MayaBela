/// School-scoped operational audit entry (Phase F).
///
/// Append-only in SQL (`school_audit_log`). Captures who did what, with
/// optional before/after snapshots for critical changes.
class SchoolAuditEntry {
  SchoolAuditEntry({
    required this.id,
    required this.at,
    required this.action,
    required this.schoolId,
    this.actorId,
    this.actorName,
    this.actorRole,
    this.entityType,
    this.entityId,
    this.detail,
    this.before,
    this.after,
  });

  final String id;
  final DateTime at;
  final String action;
  final String schoolId;
  final String? actorId;
  final String? actorName;
  final String? actorRole;
  final String? entityType;
  final String? entityId;
  final String? detail;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;

  Map<String, dynamic> toMap() => {
        'id': id,
        'at': at.toIso8601String(),
        'action': action,
        'schoolId': schoolId,
        if (actorId != null) 'actorId': actorId,
        if (actorName != null) 'actorName': actorName,
        if (actorRole != null) 'actorRole': actorRole,
        if (entityType != null) 'entityType': entityType,
        if (entityId != null) 'entityId': entityId,
        if (detail != null) 'detail': detail,
        if (before != null) 'before': before,
        if (after != null) 'after': after,
      };

  static SchoolAuditEntry fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? asMap(dynamic raw) {
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return null;
    }

    return SchoolAuditEntry(
      id: map['id'] as String,
      at: DateTime.tryParse(map['at'] as String? ?? '') ?? DateTime.now(),
      action: map['action'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      actorId: map['actorId'] as String?,
      actorName: map['actorName'] as String?,
      actorRole: map['actorRole'] as String?,
      entityType: map['entityType'] as String?,
      entityId: map['entityId'] as String?,
      detail: map['detail'] as String?,
      before: asMap(map['before']),
      after: asMap(map['after']),
    );
  }
}
