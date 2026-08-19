/// EDUABA Student Affairs — behaviour / incident case lifecycle.
///
/// Homeroom teachers submit behaviour reports, subject teachers submit
/// incident reports; Student Affairs investigates, holds hearings with the
/// student (parents invited), then records the outcome. Critical cases can be
/// escalated to the Vice Principal / Principal.
enum DisciplineCaseKind { behaviour, incident }

enum DisciplineCaseStatus {
  submitted,
  investigating,
  hearingScheduled,
  resolved,
  dismissed,
  escalated,
}

enum DisciplineOutcome { none, warning, suspension, restorative }

class DisciplineCase {
  const DisciplineCase({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.reporterId,
    required this.reporterName,
    required this.reporterRole,
    required this.kind,
    required this.title,
    required this.description,
    this.status = DisciplineCaseStatus.submitted,
    this.outcome = DisciplineOutcome.none,
    this.outcomeNotes = '',
    this.hearingAt,
    this.parentInvited = false,
    this.parentNotified = false,
    this.escalatedTo = '',
    this.handledByName = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String schoolId;
  final String studentId;
  final String studentName;
  final String className;

  /// Staff participant id / teacher id of whoever reported the case.
  final String reporterId;
  final String reporterName;

  /// 'homeroom', 'subject', or a staff role key.
  final String reporterRole;

  final DisciplineCaseKind kind;
  final String title;
  final String description;
  final DisciplineCaseStatus status;
  final DisciplineOutcome outcome;
  final String outcomeNotes;
  final DateTime? hearingAt;
  final bool parentInvited;
  final bool parentNotified;

  /// 'vice_president' or 'principal' when escalated.
  final String escalatedTo;

  /// Student Affairs officer (or admin) who handled the case.
  final String handledByName;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOpen =>
      status != DisciplineCaseStatus.resolved &&
      status != DisciplineCaseStatus.dismissed;

  DisciplineCase copyWith({
    DisciplineCaseStatus? status,
    DisciplineOutcome? outcome,
    String? outcomeNotes,
    DateTime? hearingAt,
    bool? parentInvited,
    bool? parentNotified,
    String? escalatedTo,
    String? handledByName,
    DateTime? updatedAt,
  }) {
    return DisciplineCase(
      id: id,
      schoolId: schoolId,
      studentId: studentId,
      studentName: studentName,
      className: className,
      reporterId: reporterId,
      reporterName: reporterName,
      reporterRole: reporterRole,
      kind: kind,
      title: title,
      description: description,
      status: status ?? this.status,
      outcome: outcome ?? this.outcome,
      outcomeNotes: outcomeNotes ?? this.outcomeNotes,
      hearingAt: hearingAt ?? this.hearingAt,
      parentInvited: parentInvited ?? this.parentInvited,
      parentNotified: parentNotified ?? this.parentNotified,
      escalatedTo: escalatedTo ?? this.escalatedTo,
      handledByName: handledByName ?? this.handledByName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'studentId': studentId,
        'studentName': studentName,
        'className': className,
        'reporterId': reporterId,
        'reporterName': reporterName,
        'reporterRole': reporterRole,
        'kind': kind.name,
        'title': title,
        'description': description,
        'status': status.name,
        'outcome': outcome.name,
        'outcomeNotes': outcomeNotes,
        'hearingAt': hearingAt?.toIso8601String(),
        'parentInvited': parentInvited,
        'parentNotified': parentNotified,
        'escalatedTo': escalatedTo,
        'handledByName': handledByName,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  static DisciplineCase fromMap(Map<String, dynamic> map) {
    DateTime parseDate(Object? v) =>
        DateTime.tryParse('${v ?? ''}') ?? DateTime.now();
    return DisciplineCase(
      id: '${map['id'] ?? map['_docId'] ?? ''}',
      schoolId: '${map['schoolId'] ?? ''}'.toUpperCase(),
      studentId: '${map['studentId'] ?? ''}'.toUpperCase(),
      studentName: '${map['studentName'] ?? ''}',
      className: '${map['className'] ?? ''}',
      reporterId: '${map['reporterId'] ?? ''}',
      reporterName: '${map['reporterName'] ?? ''}',
      reporterRole: '${map['reporterRole'] ?? ''}',
      kind: DisciplineCaseKind.values.firstWhere(
        (k) => k.name == map['kind'],
        orElse: () => DisciplineCaseKind.behaviour,
      ),
      title: '${map['title'] ?? ''}',
      description: '${map['description'] ?? ''}',
      status: DisciplineCaseStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => DisciplineCaseStatus.submitted,
      ),
      outcome: DisciplineOutcome.values.firstWhere(
        (o) => o.name == map['outcome'],
        orElse: () => DisciplineOutcome.none,
      ),
      outcomeNotes: '${map['outcomeNotes'] ?? ''}',
      hearingAt: map['hearingAt'] == null
          ? null
          : DateTime.tryParse('${map['hearingAt']}'),
      parentInvited: map['parentInvited'] == true,
      parentNotified: map['parentNotified'] == true,
      escalatedTo: '${map['escalatedTo'] ?? ''}',
      handledByName: '${map['handledByName'] ?? ''}',
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}
