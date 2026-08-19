/// EDUABA Quality Assurance — findings & improvement plans register (§2).
///
/// QA audits academic and operational standards (teaching quality, assessment
/// integrity, grading process, Student Affairs fairness, policy compliance),
/// records findings with severity, attaches an improvement plan, and reports
/// quality metrics up to the Deputy General Manager / General Manager.
enum QaFindingArea {
  academic,
  assessment,
  grading,
  studentAffairs,
  compliance,
  finance,
  hr,
  transport,
  operations,
}

enum QaFindingSeverity { low, medium, high, critical }

enum QaFindingStatus { open, inReview, actionPlanned, resolved }

class QaFinding {
  const QaFinding({
    required this.id,
    required this.schoolId,
    required this.area,
    required this.title,
    required this.details,
    this.severity = QaFindingSeverity.medium,
    this.status = QaFindingStatus.open,
    this.improvementPlan = '',
    this.ownerRole = '',
    this.raisedById = '',
    this.raisedByName = '',
    this.dueDate,
    this.resolvedAt,
    this.resolutionNotes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String schoolId;
  final QaFindingArea area;
  final String title;
  final String details;
  final QaFindingSeverity severity;
  final QaFindingStatus status;

  /// The corrective / improvement plan QA issued for this finding.
  final String improvementPlan;

  /// Role responsible for executing the improvement plan (e.g. 'principal').
  final String ownerRole;

  final String raisedById;
  final String raisedByName;
  final DateTime? dueDate;
  final DateTime? resolvedAt;
  final String resolutionNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOpen => status != QaFindingStatus.resolved;

  bool get isOverdue =>
      isOpen && dueDate != null && dueDate!.isBefore(DateTime.now());

  QaFinding copyWith({
    QaFindingArea? area,
    String? title,
    String? details,
    QaFindingSeverity? severity,
    QaFindingStatus? status,
    String? improvementPlan,
    String? ownerRole,
    DateTime? dueDate,
    DateTime? resolvedAt,
    String? resolutionNotes,
    DateTime? updatedAt,
  }) {
    return QaFinding(
      id: id,
      schoolId: schoolId,
      area: area ?? this.area,
      title: title ?? this.title,
      details: details ?? this.details,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      improvementPlan: improvementPlan ?? this.improvementPlan,
      ownerRole: ownerRole ?? this.ownerRole,
      raisedById: raisedById,
      raisedByName: raisedByName,
      dueDate: dueDate ?? this.dueDate,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'area': area.name,
        'title': title,
        'details': details,
        'severity': severity.name,
        'status': status.name,
        'improvementPlan': improvementPlan,
        'ownerRole': ownerRole,
        'raisedById': raisedById,
        'raisedByName': raisedByName,
        'dueDate': dueDate?.toIso8601String(),
        'resolvedAt': resolvedAt?.toIso8601String(),
        'resolutionNotes': resolutionNotes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  static QaFinding fromMap(Map<String, dynamic> map) {
    DateTime parseDate(Object? v) =>
        DateTime.tryParse('${v ?? ''}') ?? DateTime.now();
    DateTime? parseOpt(Object? v) =>
        v == null ? null : DateTime.tryParse('$v');
    return QaFinding(
      id: '${map['id'] ?? map['_docId'] ?? ''}',
      schoolId: '${map['schoolId'] ?? ''}'.toUpperCase(),
      area: QaFindingArea.values.firstWhere(
        (a) => a.name == map['area'],
        orElse: () => QaFindingArea.operations,
      ),
      title: '${map['title'] ?? ''}',
      details: '${map['details'] ?? ''}',
      severity: QaFindingSeverity.values.firstWhere(
        (s) => s.name == map['severity'],
        orElse: () => QaFindingSeverity.medium,
      ),
      status: QaFindingStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => QaFindingStatus.open,
      ),
      improvementPlan: '${map['improvementPlan'] ?? ''}',
      ownerRole: '${map['ownerRole'] ?? ''}',
      raisedById: '${map['raisedById'] ?? ''}',
      raisedByName: '${map['raisedByName'] ?? ''}',
      dueDate: parseOpt(map['dueDate']),
      resolvedAt: parseOpt(map['resolvedAt']),
      resolutionNotes: '${map['resolutionNotes'] ?? ''}',
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  static String areaLabel(QaFindingArea a) => switch (a) {
        QaFindingArea.academic => 'Academic standards',
        QaFindingArea.assessment => 'Assessment integrity',
        QaFindingArea.grading => 'Exam / grading process',
        QaFindingArea.studentAffairs => 'Student Affairs fairness',
        QaFindingArea.compliance => 'Policy compliance',
        QaFindingArea.finance => 'Finance',
        QaFindingArea.hr => 'Human Resources',
        QaFindingArea.transport => 'Transport',
        QaFindingArea.operations => 'Operations',
      };

  static String severityLabel(QaFindingSeverity s) => switch (s) {
        QaFindingSeverity.low => 'Low',
        QaFindingSeverity.medium => 'Medium',
        QaFindingSeverity.high => 'High',
        QaFindingSeverity.critical => 'Critical',
      };

  static String statusLabel(QaFindingStatus s) => switch (s) {
        QaFindingStatus.open => 'Open',
        QaFindingStatus.inReview => 'In review',
        QaFindingStatus.actionPlanned => 'Action planned',
        QaFindingStatus.resolved => 'Resolved',
      };
}
