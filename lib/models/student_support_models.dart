// LIA Phase G — student support care records.
// Sensitive. Child-protection files never go to parents, students, or
// classroom teachers. Not a grade store and not a second SIS.

enum HealthRecordType {
  clinicVisit,
  vaccination,
  medication,
  emergencyAlert,
  medicalCheckup,
  accident,
}

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

/// International-school care vocabulary used on the existing desks.
/// Labels only — values stay as strings on the current care stores.
abstract final class StudentSupportPlaybook {
  static const dispositions = <(String, String)>[
    ('returnToClass', 'Return to class'),
    ('sendHome', 'Send home'),
    ('observeClinic', 'Observe in clinic'),
    ('referExternal', 'Refer to external clinician'),
  ];

  static const parentContactMethods = <(String, String)>[
    ('phone', 'Phone'),
    ('inPerson', 'In person'),
    ('sms', 'SMS'),
    ('email', 'Email'),
  ];

  static const medRoutes = <(String, String)>[
    ('oral', 'Oral'),
    ('topical', 'Topical'),
    ('inhaled', 'Inhaled'),
    ('injection', 'Injection'),
    ('other', 'Other'),
  ];

  static const vaultCategories = <(String, String)>[
    ('psychoEd', 'Psycho-educational report'),
    ('medicalLetter', 'Medical / IHCP letter'),
    ('accessArrangement', 'Access-arrangement evidence'),
    ('legal', 'Legal / court'),
    ('identity', 'Identity'),
    ('transcript', 'Transcript'),
    ('other', 'Other'),
  ];

  static const confidentiality = <(String, String)>[
    ('staff', 'Care staff'),
    ('restricted', 'Restricted (LST / clinic)'),
    ('leadership', 'Leadership only'),
  ];

  static const counselingFormats = <(String, String)>[
    ('individual', 'Individual'),
    ('group', 'Group'),
    ('crisis', 'Crisis / same-day'),
  ];

  static const riskWatch = <(String, String)>[
    ('none', 'No extra watch'),
    ('monitor', 'Monitor on this desk'),
  ];

  static const accessArrangements = <(String, String)>[
    ('extraTime', 'Extra time'),
    ('scribe', 'Scribe'),
    ('reader', 'Reader'),
    ('separateRoom', 'Separate room'),
    ('bilingualDict', 'Bilingual dictionary'),
  ];

  static const reviewCycles = <(String, String)>[
    ('termly', 'Termly'),
    ('biannual', 'Biannual'),
    ('annual', 'Annual'),
  ];

  static const applicationSystems = <(String, String)>[
    ('ucas', 'UCAS'),
    ('commonApp', 'Common App'),
    ('both', 'UCAS + Common App'),
    ('other', 'Other / national'),
  ];

  static const requestPriorities = <(String, String)>[
    ('urgent', 'Urgent'),
    ('high', 'High'),
    ('normal', 'Normal'),
    ('low', 'Low'),
  ];

  static const safeguardingCategories = <(String, String)>[
    ('physical', 'Physical harm'),
    ('emotional', 'Emotional / wellbeing'),
    ('neglect', 'Neglect'),
    ('online', 'Online safety'),
    ('other', 'Other concern'),
  ];

  static const banners = <String, String>{
    'health':
        'Clinic log follows an international-school infirmary: complaint, '
        'treatment, disposition (return / send home / refer), vitals, and '
        'how the parent was reached. Emergency stays on this register.',
    'meds':
        'Medication Administration Record: original labelled pack, parent '
        'consent, route, prescriber, batch/expiry, and a witness for '
        'controlled drugs. Clinic shelf only — not the school store.',
    'vault':
        'Confidential student file: psycho-ed, medical/IHCP, and exam-access '
        'letters with review and expiry. Leadership-only files stay off the '
        'parent tile. Admission checklists stay on Admissions.',
    'counseling':
        'Short-term individual, group, or crisis work. Confidentiality holds '
        'unless child protection. Risk-watch stays here — it does not open a '
        'safeguarding case. Intensive therapy is an external referral.',
    'iep':
        'MTSS / learning-support plan: Tier 1 classroom, Tier 2 intervention, '
        'Tier 3 IEP with SMART goals, IB/Cambridge access arrangements, and '
        'a termly or biannual review with parent and teacher.',
    'college':
        'University guidance: UCAS / Common App track, testing plan, counselor, '
        'destination country, essays, recommendations, and deadlines.',
    'requests':
        'Parent and student intake queue with priority, assignee, due date, '
        'and last action. Counseling, IEP agreement, and college bookings '
        'share this tracker.',
    'safeguarding':
        'DSL / DDSL chronology. Category, agency referral, and next review '
        'stay on this desk. Never put case narrative in parent chat.',
    'sel':
        'CASEL-style staff ratings (1–5) by domain. Averages are descriptive '
        'analytics for the care desk — not predictive scoring or ML.',
  };

  static String collegeLifecycle(CollegeStage stage) => switch (stage) {
        CollegeStage.exploring => 'Direction',
        CollegeStage.readiness => 'Readiness',
        CollegeStage.applying => 'Application',
        CollegeStage.accepted ||
        CollegeStage.enrolled ||
        CollegeStage.deferred =>
          'Decision',
      };

  static String label(List<(String, String)> pairs, String key) {
    for (final pair in pairs) {
      if (pair.$1 == key) return pair.$2;
    }
    return key;
  }
}

class HealthClinicSummary {
  const HealthClinicSummary({
    required this.day,
    required this.visits,
    required this.vaccinations,
    required this.medications,
    required this.alerts,
    this.checkups = 0,
    this.accidents = 0,
  });

  final DateTime day;
  final int visits;
  final int vaccinations;
  final int medications;
  final int alerts;
  final int checkups;
  final int accidents;

  int get total =>
      visits + vaccinations + medications + alerts + checkups + accidents;
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
    this.witnessedBy = '',
  });

  final String id;
  final double delta;
  final String reason;
  final String? studentId;
  final String? studentName;
  final String note;
  final String? createdBy;
  final double? quantityAfter;
  final String witnessedBy;
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
        if (witnessedBy.isNotEmpty) 'witnessedBy': witnessedBy,
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
      witnessedBy: map['witnessedBy'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class SafeguardingChronologyEntry {
  SafeguardingChronologyEntry({
    required this.id,
    required this.createdAt,
    this.note = '',
    this.author = '',
  });

  final String id;
  String note;
  String author;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'note': note,
        'author': author,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SafeguardingChronologyEntry.fromMap(Map<String, dynamic> map) {
    return SafeguardingChronologyEntry(
      id: map['id'] as String? ?? '',
      note: map['note'] as String? ?? '',
      author: map['author'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

enum CounselingKind { session, appointment, referral }

enum IepStage { intake, draftPlan, parentAgreement, review }

enum CollegeStage {
  exploring,
  readiness,
  applying,
  accepted,
  enrolled,
  deferred,
}

enum CollegeArtifactKind { essay, recLetter, transcript, deadline, event, other }

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
    this.disposition = '',
    this.followUpAt,
    this.vitalNotes = '',
    this.parentContactMethod = '',
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
  String disposition;
  DateTime? followUpAt;
  String vitalNotes;
  String parentContactMethod;
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
        if (disposition.isNotEmpty) 'disposition': disposition,
        if (followUpAt != null) 'followUpAt': followUpAt!.toIso8601String(),
        if (vitalNotes.isNotEmpty) 'vitalNotes': vitalNotes,
        if (parentContactMethod.isNotEmpty)
          'parentContactMethod': parentContactMethod,
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
      disposition: map['disposition'] as String? ?? '',
      followUpAt: map['followUpAt'] != null
          ? DateTime.tryParse(map['followUpAt'] as String)
          : null,
      vitalNotes: map['vitalNotes'] as String? ?? '',
      parentContactMethod: map['parentContactMethod'] as String? ?? '',
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
    this.format = 'individual',
    this.durationMinutes,
    this.followUpAt,
    this.confidentialityLimit = 'confidentialUnlessSafeguarding',
    this.riskWatch = 'none',
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
  String format;
  int? durationMinutes;
  DateTime? followUpAt;
  String confidentialityLimit;
  String riskWatch;
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
        if (format.isNotEmpty) 'format': format,
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
        if (followUpAt != null) 'followUpAt': followUpAt!.toIso8601String(),
        if (confidentialityLimit.isNotEmpty)
          'confidentialityLimit': confidentialityLimit,
        if (riskWatch.isNotEmpty) 'riskWatch': riskWatch,
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
      format: map['format'] as String? ?? 'individual',
      durationMinutes: (map['durationMinutes'] as num?)?.toInt(),
      followUpAt: map['followUpAt'] != null
          ? DateTime.tryParse(map['followUpAt'] as String)
          : null,
      confidentialityLimit: map['confidentialityLimit'] as String? ??
          'confidentialUnlessSafeguarding',
      riskWatch: map['riskWatch'] as String? ?? 'none',
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
    this.mtssTier = 1,
    this.accessArrangements = const [],
    this.reviewCycle = 'termly',
    this.externalReportRef = '',
    this.intakeAssessment = '',
    this.evaluationNotes = '',
    this.lastEvaluatedAt,
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
  int mtssTier;
  List<String> accessArrangements;
  String reviewCycle;
  String externalReportRef;
  String intakeAssessment;
  String evaluationNotes;
  DateTime? lastEvaluatedAt;
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
        'mtssTier': mtssTier,
        'accessArrangements': accessArrangements,
        if (reviewCycle.isNotEmpty) 'reviewCycle': reviewCycle,
        if (externalReportRef.isNotEmpty)
          'externalReportRef': externalReportRef,
        if (intakeAssessment.isNotEmpty) 'intakeAssessment': intakeAssessment,
        if (evaluationNotes.isNotEmpty) 'evaluationNotes': evaluationNotes,
        if (lastEvaluatedAt != null)
          'lastEvaluatedAt': lastEvaluatedAt!.toIso8601String(),
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
      mtssTier: (map['mtssTier'] as num?)?.toInt() ?? 1,
      accessArrangements: (map['accessArrangements'] as List?)
              ?.map((item) => '$item')
              .where((item) => item.trim().isNotEmpty)
              .toList() ??
          const [],
      reviewCycle: map['reviewCycle'] as String? ?? 'termly',
      externalReportRef: map['externalReportRef'] as String? ?? '',
      intakeAssessment: map['intakeAssessment'] as String? ?? '',
      evaluationNotes: map['evaluationNotes'] as String? ?? '',
      lastEvaluatedAt: map['lastEvaluatedAt'] != null
          ? DateTime.tryParse(map['lastEvaluatedAt'] as String)
          : null,
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
    this.audience = 'teacher',
  });

  final String id;
  String topic;
  DateTime? trainedAt;
  String trainer;
  String notes;
  String audience;

  Map<String, dynamic> toMap() => {
        'id': id,
        'topic': topic,
        if (trainedAt != null) 'trainedAt': trainedAt!.toIso8601String(),
        'trainer': trainer,
        'notes': notes,
        if (audience.isNotEmpty) 'audience': audience,
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
      audience: map['audience'] as String? ?? 'teacher',
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
    this.applicationSystem = '',
    this.testingPlan = '',
    this.counselorName = '',
    this.destinationCountry = '',
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
  String applicationSystem;
  String testingPlan;
  String counselorName;
  String destinationCountry;
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
        if (applicationSystem.isNotEmpty)
          'applicationSystem': applicationSystem,
        if (testingPlan.isNotEmpty) 'testingPlan': testingPlan,
        if (counselorName.isNotEmpty) 'counselorName': counselorName,
        if (destinationCountry.isNotEmpty)
          'destinationCountry': destinationCountry,
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
      applicationSystem: map['applicationSystem'] as String? ?? '',
      testingPlan: map['testingPlan'] as String? ?? '',
      counselorName: map['counselorName'] as String? ?? '',
      destinationCountry: map['destinationCountry'] as String? ?? '',
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
    this.priority = 'normal',
    this.assignedTo = '',
    this.dueAt,
    this.lastActionNote = '',
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
  String priority;
  String assignedTo;
  DateTime? dueAt;
  String lastActionNote;
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
        if (priority.isNotEmpty) 'priority': priority,
        if (assignedTo.isNotEmpty) 'assignedTo': assignedTo,
        if (dueAt != null) 'dueAt': dueAt!.toIso8601String(),
        if (lastActionNote.isNotEmpty) 'lastActionNote': lastActionNote,
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
      priority: map['priority'] as String? ?? 'normal',
      assignedTo: map['assignedTo'] as String? ?? '',
      dueAt: map['dueAt'] != null
          ? DateTime.tryParse(map['dueAt'] as String)
          : null,
      lastActionNote: map['lastActionNote'] as String? ?? '',
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
    this.category = 'other',
    this.dslName = '',
    this.nextReviewAt,
    this.agencyReferred = '',
    this.chronology = const [],
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
  String category;
  String dslName;
  DateTime? nextReviewAt;
  String agencyReferred;
  List<SafeguardingChronologyEntry> chronology;
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
        if (category.isNotEmpty) 'category': category,
        if (dslName.isNotEmpty) 'dslName': dslName,
        if (nextReviewAt != null)
          'nextReviewAt': nextReviewAt!.toIso8601String(),
        if (agencyReferred.isNotEmpty) 'agencyReferred': agencyReferred,
        'chronology': chronology.map((row) => row.toMap()).toList(),
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
      category: map['category'] as String? ?? 'other',
      dslName: map['dslName'] as String? ?? '',
      nextReviewAt: map['nextReviewAt'] != null
          ? DateTime.tryParse(map['nextReviewAt'] as String)
          : null,
      agencyReferred: map['agencyReferred'] as String? ?? '',
      chronology: (map['chronology'] as List?)
              ?.whereType<Map>()
              .map(
                (row) => SafeguardingChronologyEntry.fromMap(
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
    this.confidentiality = 'staff',
    this.expiresAt,
    this.reviewAt,
    this.source = '',
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
  String confidentiality;
  DateTime? expiresAt;
  DateTime? reviewAt;
  String source;
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
        if (confidentiality.isNotEmpty) 'confidentiality': confidentiality,
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        if (reviewAt != null) 'reviewAt': reviewAt!.toIso8601String(),
        if (source.isNotEmpty) 'source': source,
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
      confidentiality: map['confidentiality'] as String? ?? 'staff',
      expiresAt: map['expiresAt'] != null
          ? DateTime.tryParse(map['expiresAt'] as String)
          : null,
      reviewAt: map['reviewAt'] != null
          ? DateTime.tryParse(map['reviewAt'] as String)
          : null,
      source: map['source'] as String? ?? '',
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
    this.controlledDrug = false,
    this.route = 'oral',
    this.parentConsentOnFile = false,
    this.prescriber = '',
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
  bool controlledDrug;
  String route;
  bool parentConsentOnFile;
  String prescriber;
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
        'controlledDrug': controlledDrug,
        if (route.isNotEmpty) 'route': route,
        'parentConsentOnFile': parentConsentOnFile,
        if (prescriber.isNotEmpty) 'prescriber': prescriber,
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
      controlledDrug: map['controlledDrug'] as bool? ?? false,
      route: map['route'] as String? ?? 'oral',
      parentConsentOnFile: map['parentConsentOnFile'] as bool? ?? false,
      prescriber: map['prescriber'] as String? ?? '',
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class SelAnalytics {
  const SelAnalytics({
    required this.observations,
    required this.studentsCovered,
    required this.domainAverages,
    this.overall,
  });

  final int observations;
  final int studentsCovered;
  final Map<SelDomain, double> domainAverages;
  final double? overall;
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
