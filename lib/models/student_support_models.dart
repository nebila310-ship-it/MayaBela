// LIA Phase G — student support care records.
// Sensitive. Child-protection files never go to parents, students, or
// classroom teachers. Not a grade store and not a second SIS.

enum HealthRecordType { clinicVisit, vaccination, medication, emergencyAlert }

/// Suggested vaccine names — stored as free text on [HealthRecord.vaccineName].
abstract final class HealthVaccineHints {
  static const names = <String>[
    'BCG',
    'OPV',
    'DTP',
    'MMR',
    'HepB',
    'HPV',
    'Td',
    'COVID-19',
  ];
}

class HealthClinicSummary {
  const HealthClinicSummary({
    required this.day,
    required this.visits,
    required this.vaccinations,
    required this.medications,
    required this.alerts,
  });

  final DateTime day;
  final int visits;
  final int vaccinations;
  final int medications;
  final int alerts;

  int get total => visits + vaccinations + medications + alerts;
}

class MedicationStockMovement {
  MedicationStockMovement({
    required this.id,
    required this.delta,
    required this.createdAt,
    this.reason = 'adjust',
    this.studentId,
    this.studentName,
    this.note = '',
    this.createdBy,
    this.quantityAfter,
  });

  final String id;
  final double delta;
  final String reason;
  final String? studentId;
  final String? studentName;
  final String note;
  final String? createdBy;
  final double? quantityAfter;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'delta': delta,
        'reason': reason,
        if (studentId != null) 'studentId': studentId,
        if (studentName != null) 'studentName': studentName,
        'note': note,
        if (createdBy != null) 'createdBy': createdBy,
        if (quantityAfter != null) 'quantityAfter': quantityAfter,
        'createdAt': createdAt.toIso8601String(),
      };

  factory MedicationStockMovement.fromMap(Map<String, dynamic> map) {
    return MedicationStockMovement(
      id: map['id'] as String? ?? '',
      delta: (map['delta'] as num?)?.toDouble() ?? 0,
      reason: map['reason'] as String? ?? 'adjust',
      studentId: map['studentId'] as String?,
      studentName: map['studentName'] as String?,
      note: map['note'] as String? ?? '',
      createdBy: map['createdBy'] as String?,
      quantityAfter: (map['quantityAfter'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

enum CounselingKind { session, appointment, referral }

enum IepStage { intake, draftPlan, parentAgreement, review }

enum CollegeStage { exploring, applying, accepted, enrolled, deferred }

enum CollegeArtifactKind { essay, recLetter, transcript, deadline, other }

enum SupportRequestKind {
  counselingAppointment,
  iepAgreement,
  collegeAppointment,
}

enum SupportRequestStatus { open, acknowledged, completed }

enum SafeguardingStatus { open, investigating, referred, closed }

class HealthRecord {
  HealthRecord({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.className,
    this.title = '',
    this.details = '',
    this.staffNotes = '',
    this.occurredAt,
    this.createdBy,
    this.severity = 'routine',
    this.vaccineName = '',
    this.doseNumber,
    this.nextDueAt,
    this.medicationStockItemId,
    this.quantity,
    this.unit = '',
    this.parentNotifiedAt,
    this.parentNotifiedBy,
  });

  final String id;
  final String schoolId;
  final String studentId;
  String studentName;
  String? className;
  HealthRecordType type;
  String title;
  String details;
  String staffNotes;
  DateTime? occurredAt;
  String? createdBy;
  String severity;
  String vaccineName;
  int? doseNumber;
  DateTime? nextDueAt;
  String? medicationStockItemId;
  double? quantity;
  String unit;
  DateTime? parentNotifiedAt;
  String? parentNotifiedBy;
  final DateTime createdAt;
  DateTime updatedAt;

  DateTime get recordedAt => occurredAt ?? createdAt;

  bool get isUrgent =>
      severity == 'urgent' || type == HealthRecordType.emergencyAlert;

  Map<String, dynamic> toMap({bool includeStaffNotes = true}) => {
        'id': id,
        'schoolId': schoolId,
        'studentId': studentId,
        'studentName': studentName,
        if (className != null) 'className': className,
        'type': type.name,
        'title': title,
        'details': details,
        if (includeStaffNotes) 'staffNotes': staffNotes,
        if (occurredAt != null) 'occurredAt': occurredAt!.toIso8601String(),
        if (createdBy != null) 'createdBy': createdBy,
        'severity': severity,
        if (vaccineName.isNotEmpty) 'vaccineName': vaccineName,
        if (doseNumber != null) 'doseNumber': doseNumber,
        if (nextDueAt != null) 'nextDueAt': nextDueAt!.toIso8601String(),
        if (medicationStockItemId != null)
          'medicationStockItemId': medicationStockItemId,
        if (quantity != null) 'quantity': quantity,
        if (unit.isNotEmpty) 'unit': unit,
        if (parentNotifiedAt != null)
          'parentNotifiedAt': parentNotifiedAt!.toIso8601String(),
        if (parentNotifiedBy != null) 'parentNotifiedBy': parentNotifiedBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory HealthRecord.fromMap(Map<String, dynamic> map) {
    return HealthRecord(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      studentId: (map['studentId'] as String? ?? '').trim().toUpperCase(),
      studentName: map['studentName'] as String? ?? '',
      className: map['className'] as String?,
      type: HealthRecordType.values.firstWhere(
        (v) => v.name == map['type'],
        orElse: () => HealthRecordType.clinicVisit,
      ),
      title: map['title'] as String? ?? '',
      details: map['details'] as String? ?? '',
      staffNotes: map['staffNotes'] as String? ?? '',
      occurredAt: map['occurredAt'] != null
          ? DateTime.tryParse(map['occurredAt'] as String)
          : null,
      createdBy: map['createdBy'] as String?,
      severity: map['severity'] as String? ?? 'routine',
      vaccineName: map['vaccineName'] as String? ?? '',
      doseNumber: (map['doseNumber'] as num?)?.toInt(),
      nextDueAt: map['nextDueAt'] != null
          ? DateTime.tryParse(map['nextDueAt'] as String)
          : null,
      medicationStockItemId: map['medicationStockItemId'] as String?,
      quantity: (map['quantity'] as num?)?.toDouble(),
      unit: map['unit'] as String? ?? '',
      parentNotifiedAt: map['parentNotifiedAt'] != null
          ? DateTime.tryParse(map['parentNotifiedAt'] as String)
          : null,
      parentNotifiedBy: map['parentNotifiedBy'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class CounselingRecord {
  CounselingRecord({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.kind,
    required this.createdAt,
    required this.updatedAt,
    this.className,
    this.title = '',
    this.parentSummary = '',
    this.staffNotes = '',
    this.referralTo,
    this.startsAt,
    this.createdBy,
  });

  final String id;
  final String schoolId;
  final String studentId;
  String studentName;
  String? className;
  CounselingKind kind;
  String title;
  String parentSummary;
  String staffNotes;
  String? referralTo;
  DateTime? startsAt;
  String? createdBy;
  final DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toMap({bool includeStaffNotes = true}) => {
        'id': id,
        'schoolId': schoolId,
        'studentId': studentId,
        'studentName': studentName,
        if (className != null) 'className': className,
        'kind': kind.name,
        'title': title,
        'parentSummary': parentSummary,
        if (includeStaffNotes) 'staffNotes': staffNotes,
        if (referralTo != null) 'referralTo': referralTo,
        if (startsAt != null) 'startsAt': startsAt!.toIso8601String(),
        if (createdBy != null) 'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CounselingRecord.fromMap(Map<String, dynamic> map) {
    return CounselingRecord(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      studentId: (map['studentId'] as String? ?? '').trim().toUpperCase(),
      studentName: map['studentName'] as String? ?? '',
      className: map['className'] as String?,
      kind: CounselingKind.values.firstWhere(
        (v) => v.name == map['kind'],
        orElse: () => CounselingKind.session,
      ),
      title: map['title'] as String? ?? '',
      parentSummary: map['parentSummary'] as String? ?? '',
      staffNotes: map['staffNotes'] as String? ?? '',
      referralTo: map['referralTo'] as String?,
      startsAt: map['startsAt'] != null
          ? DateTime.tryParse(map['startsAt'] as String)
          : null,
      createdBy: map['createdBy'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class IepPlan {
  IepPlan({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.createdAt,
    required this.updatedAt,
    this.className,
    this.stage = IepStage.intake,
    this.goals = '',
    this.accommodations = '',
    this.staffNotes = '',
    this.parentAgreementText = '',
    this.parentSignedAt,
    this.parentSignedBy,
    this.nextReviewAt,
    this.createdBy,
    this.trainingSessions = const [],
  });

  final String id;
  final String schoolId;
  final String studentId;
  String studentName;
  String? className;
  IepStage stage;
  String goals;
  String accommodations;
  String staffNotes;
  String parentAgreementText;
  DateTime? parentSignedAt;
  String? parentSignedBy;
  DateTime? nextReviewAt;
  String? createdBy;
  List<IepTrainingSession> trainingSessions;
  final DateTime createdAt;
  DateTime updatedAt;

  bool get parentAgreed => parentSignedAt != null;

  Map<String, dynamic> toMap({bool includeStaffNotes = true}) => {
        'id': id,
        'schoolId': schoolId,
        'studentId': studentId,
        'studentName': studentName,
        if (className != null) 'className': className,
        'stage': stage.name,
        'goals': goals,
        'accommodations': accommodations,
        if (includeStaffNotes) 'staffNotes': staffNotes,
        'parentAgreementText': parentAgreementText,
        if (parentSignedAt != null)
          'parentSignedAt': parentSignedAt!.toIso8601String(),
        if (parentSignedBy != null) 'parentSignedBy': parentSignedBy,
        if (nextReviewAt != null)
          'nextReviewAt': nextReviewAt!.toIso8601String(),
        if (createdBy != null) 'createdBy': createdBy,
        'trainingSessions':
            trainingSessions.map((row) => row.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory IepPlan.fromMap(Map<String, dynamic> map) {
    return IepPlan(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      studentId: (map['studentId'] as String? ?? '').trim().toUpperCase(),
      studentName: map['studentName'] as String? ?? '',
      className: map['className'] as String?,
      stage: IepStage.values.firstWhere(
        (v) => v.name == map['stage'],
        orElse: () => IepStage.intake,
      ),
      goals: map['goals'] as String? ?? '',
      accommodations: map['accommodations'] as String? ?? '',
      staffNotes: map['staffNotes'] as String? ?? '',
      parentAgreementText: map['parentAgreementText'] as String? ?? '',
      parentSignedAt: map['parentSignedAt'] != null
          ? DateTime.tryParse(map['parentSignedAt'] as String)
          : null,
      parentSignedBy: map['parentSignedBy'] as String?,
      nextReviewAt: map['nextReviewAt'] != null
          ? DateTime.tryParse(map['nextReviewAt'] as String)
          : null,
      createdBy: map['createdBy'] as String?,
      trainingSessions: (map['trainingSessions'] as List?)
              ?.whereType<Map>()
              .map(
                (row) => IepTrainingSession.fromMap(
                  Map<String, dynamic>.from(row),
                ),
              )
              .toList() ??
          const [],
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class IepTrainingSession {
  IepTrainingSession({
    required this.id,
    required this.topic,
    this.trainedAt,
    this.trainer = '',
    this.notes = '',
  });

  final String id;
  String topic;
  DateTime? trainedAt;
  String trainer;
  String notes;

  Map<String, dynamic> toMap() => {
        'id': id,
        'topic': topic,
        if (trainedAt != null) 'trainedAt': trainedAt!.toIso8601String(),
        'trainer': trainer,
        'notes': notes,
      };

  factory IepTrainingSession.fromMap(Map<String, dynamic> map) {
    return IepTrainingSession(
      id: map['id'] as String? ?? '',
      topic: map['topic'] as String? ?? '',
      trainedAt: map['trainedAt'] != null
          ? DateTime.tryParse(map['trainedAt'] as String)
          : null,
      trainer: map['trainer'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
    );
  }
}

class CollegeGuidancePlan {
  CollegeGuidancePlan({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.createdAt,
    required this.updatedAt,
    this.className,
    this.stage = CollegeStage.exploring,
    this.targets = '',
    this.portfolio = '',
    this.notes = '',
    this.nextAppointmentAt,
    this.createdBy,
    this.artifacts = const [],
  });

  final String id;
  final String schoolId;
  final String studentId;
  String studentName;
  String? className;
  CollegeStage stage;
  String targets;
  String portfolio;
  String notes;
  DateTime? nextAppointmentAt;
  String? createdBy;
  List<CollegeArtifact> artifacts;
  final DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'studentId': studentId,
        'studentName': studentName,
        if (className != null) 'className': className,
        'stage': stage.name,
        'targets': targets,
        'portfolio': portfolio,
        'notes': notes,
        if (nextAppointmentAt != null)
          'nextAppointmentAt': nextAppointmentAt!.toIso8601String(),
        if (createdBy != null) 'createdBy': createdBy,
        'artifacts': artifacts.map((row) => row.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CollegeGuidancePlan.fromMap(Map<String, dynamic> map) {
    return CollegeGuidancePlan(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      studentId: (map['studentId'] as String? ?? '').trim().toUpperCase(),
      studentName: map['studentName'] as String? ?? '',
      className: map['className'] as String?,
      stage: CollegeStage.values.firstWhere(
        (v) => v.name == map['stage'],
        orElse: () => CollegeStage.exploring,
      ),
      targets: map['targets'] as String? ?? '',
      portfolio: map['portfolio'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      nextAppointmentAt: map['nextAppointmentAt'] != null
          ? DateTime.tryParse(map['nextAppointmentAt'] as String)
          : null,
      createdBy: map['createdBy'] as String?,
      artifacts: (map['artifacts'] as List?)
              ?.whereType<Map>()
              .map(
                (row) =>
                    CollegeArtifact.fromMap(Map<String, dynamic>.from(row)),
              )
              .toList() ??
          const [],
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class CollegeArtifact {
  CollegeArtifact({
    required this.id,
    required this.title,
    this.kind = CollegeArtifactKind.other,
    this.dueAt,
    this.filePath,
    this.done = false,
    this.notes = '',
  });

  final String id;
  CollegeArtifactKind kind;
  String title;
  DateTime? dueAt;
  String? filePath;
  bool done;
  String notes;

  Map<String, dynamic> toMap() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        if (dueAt != null) 'dueAt': dueAt!.toIso8601String(),
        if (filePath != null) 'filePath': filePath,
        'done': done,
        'notes': notes,
      };

  factory CollegeArtifact.fromMap(Map<String, dynamic> map) {
    return CollegeArtifact(
      id: map['id'] as String? ?? '',
      kind: CollegeArtifactKind.values.firstWhere(
        (v) => v.name == map['kind'],
        orElse: () => CollegeArtifactKind.other,
      ),
      title: map['title'] as String? ?? '',
      dueAt: map['dueAt'] != null
          ? DateTime.tryParse(map['dueAt'] as String)
          : null,
      filePath: map['filePath'] as String?,
      done: map['done'] as bool? ?? false,
      notes: map['notes'] as String? ?? '',
    );
  }
}

class SupportRequest {
  SupportRequest({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.kind,
    required this.authorUsername,
    required this.createdAt,
    required this.updatedAt,
    this.className,
    this.body = '',
    this.status = SupportRequestStatus.open,
    this.authorRole,
    this.relatedPlanId,
  });

  final String id;
  final String schoolId;
  final String studentId;
  String studentName;
  String? className;
  SupportRequestKind kind;
  String body;
  SupportRequestStatus status;
  final String authorUsername;
  String? authorRole;
  String? relatedPlanId;
  final DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'studentId': studentId,
        'studentName': studentName,
        if (className != null) 'className': className,
        'kind': kind.name,
        'body': body,
        'status': status.name,
        'authorUsername': authorUsername,
        if (authorRole != null) 'authorRole': authorRole,
        if (relatedPlanId != null) 'relatedPlanId': relatedPlanId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SupportRequest.fromMap(Map<String, dynamic> map) {
    return SupportRequest(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      studentId: (map['studentId'] as String? ?? '').trim().toUpperCase(),
      studentName: map['studentName'] as String? ?? '',
      className: map['className'] as String?,
      kind: SupportRequestKind.values.firstWhere(
        (v) => v.name == map['kind'],
        orElse: () => SupportRequestKind.counselingAppointment,
      ),
      body: map['body'] as String? ?? '',
      status: SupportRequestStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => SupportRequestStatus.open,
      ),
      authorUsername: map['authorUsername'] as String? ?? '',
      authorRole: map['authorRole'] as String?,
      relatedPlanId: map['relatedPlanId'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class SafeguardingCase {
  SafeguardingCase({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.createdAt,
    required this.updatedAt,
    this.className,
    this.title = '',
    this.details = '',
    this.status = SafeguardingStatus.open,
    this.severity = 'standard',
    this.reporterUsername,
    this.assignedRole,
  });

  final String id;
  final String schoolId;
  final String studentId;
  String studentName;
  String? className;
  String title;
  String details;
  SafeguardingStatus status;
  String severity;
  String? reporterUsername;
  String? assignedRole;
  final DateTime createdAt;
  DateTime updatedAt;

  bool get isOpen =>
      status == SafeguardingStatus.open ||
      status == SafeguardingStatus.investigating ||
      status == SafeguardingStatus.referred;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'studentId': studentId,
        'studentName': studentName,
        if (className != null) 'className': className,
        'title': title,
        'details': details,
        'status': status.name,
        'severity': severity,
        if (reporterUsername != null) 'reporterUsername': reporterUsername,
        if (assignedRole != null) 'assignedRole': assignedRole,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SafeguardingCase.fromMap(Map<String, dynamic> map) {
    return SafeguardingCase(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      studentId: (map['studentId'] as String? ?? '').trim().toUpperCase(),
      studentName: map['studentName'] as String? ?? '',
      className: map['className'] as String?,
      title: map['title'] as String? ?? '',
      details: map['details'] as String? ?? '',
      status: SafeguardingStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => SafeguardingStatus.open,
      ),
      severity: map['severity'] as String? ?? 'standard',
      reporterUsername: map['reporterUsername'] as String?,
      assignedRole: map['assignedRole'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class StudentDocument {
  StudentDocument({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.createdAt,
    required this.updatedAt,
    this.className,
    this.title = '',
    this.category = 'other',
    this.filePath,
    this.notes = '',
    this.uploadedBy,
  });

  final String id;
  final String schoolId;
  final String studentId;
  String studentName;
  String? className;
  String title;
  String category;
  String? filePath;
  String notes;
  String? uploadedBy;
  final DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'studentId': studentId,
        'studentName': studentName,
        if (className != null) 'className': className,
        'title': title,
        'category': category,
        if (filePath != null) 'filePath': filePath,
        'notes': notes,
        if (uploadedBy != null) 'uploadedBy': uploadedBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory StudentDocument.fromMap(Map<String, dynamic> map) {
    return StudentDocument(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      studentId: (map['studentId'] as String? ?? '').trim().toUpperCase(),
      studentName: map['studentName'] as String? ?? '',
      className: map['className'] as String?,
      title: map['title'] as String? ?? '',
      category: map['category'] as String? ?? 'other',
      filePath: map['filePath'] as String?,
      notes: map['notes'] as String? ?? '',
      uploadedBy: map['uploadedBy'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// Clinic medication shelf. Unversioned — do not use inventory_items.
class MedicationStockItem {
  MedicationStockItem({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.unit = 'unit',
    this.quantityOnHand = 0,
    this.reorderLevel = 0,
    this.notes = '',
    this.createdBy,
    this.batchNumber = '',
    this.expiresAt,
    this.movements = const [],
  });

  final String id;
  final String schoolId;
  String name;
  String unit;
  double quantityOnHand;
  double reorderLevel;
  String notes;
  String? createdBy;
  String batchNumber;
  DateTime? expiresAt;
  List<MedicationStockMovement> movements;
  final DateTime createdAt;
  DateTime updatedAt;

  bool get needsReorder =>
      reorderLevel > 0 && quantityOnHand <= reorderLevel;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'name': name,
        'unit': unit,
        'quantityOnHand': quantityOnHand,
        'reorderLevel': reorderLevel,
        'notes': notes,
        if (createdBy != null) 'createdBy': createdBy,
        if (batchNumber.isNotEmpty) 'batchNumber': batchNumber,
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        'movements': movements.map((row) => row.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory MedicationStockItem.fromMap(Map<String, dynamic> map) {
    return MedicationStockItem(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      name: map['name'] as String? ?? '',
      unit: map['unit'] as String? ?? 'unit',
      quantityOnHand: (map['quantityOnHand'] as num?)?.toDouble() ?? 0,
      reorderLevel: (map['reorderLevel'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] as String? ?? '',
      createdBy: map['createdBy'] as String?,
      batchNumber: map['batchNumber'] as String? ?? '',
      expiresAt: map['expiresAt'] != null
          ? DateTime.tryParse(map['expiresAt'] as String)
          : null,
      movements: (map['movements'] as List?)
              ?.whereType<Map>()
              .map(
                (row) => MedicationStockMovement.fromMap(
                  Map<String, dynamic>.from(row),
                ),
              )
              .toList() ??
          const [],
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

enum SelDomain {
  selfAwareness,
  selfManagement,
  socialAwareness,
  relationship,
  responsibleDecision,
}

class SelObservation {
  SelObservation({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.createdAt,
    required this.updatedAt,
    this.className,
    this.domain = SelDomain.selfAwareness,
    this.rating = 3,
    this.notes = '',
    this.observedAt,
    this.createdBy,
  });

  final String id;
  final String schoolId;
  final String studentId;
  String studentName;
  String? className;
  SelDomain domain;
  int rating;
  String notes;
  DateTime? observedAt;
  String? createdBy;
  final DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'studentId': studentId,
        'studentName': studentName,
        if (className != null) 'className': className,
        'domain': domain.name,
        'rating': rating,
        'notes': notes,
        if (observedAt != null) 'observedAt': observedAt!.toIso8601String(),
        if (createdBy != null) 'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SelObservation.fromMap(Map<String, dynamic> map) {
    return SelObservation(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      studentId: (map['studentId'] as String? ?? '').trim().toUpperCase(),
      studentName: map['studentName'] as String? ?? '',
      className: map['className'] as String?,
      domain: SelDomain.values.firstWhere(
        (v) => v.name == map['domain'],
        orElse: () => SelDomain.selfAwareness,
      ),
      rating: (map['rating'] as num?)?.toInt() ?? 3,
      notes: map['notes'] as String? ?? '',
      observedAt: map['observedAt'] != null
          ? DateTime.tryParse(map['observedAt'] as String)
          : null,
      createdBy: map['createdBy'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
