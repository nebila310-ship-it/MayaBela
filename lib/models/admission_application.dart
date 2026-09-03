/// LIA TOR Phase A — admissions pipeline before a student is enrolled.
///
/// Inquiry → Application → Documents → Exam → Waitlist/Offer → Enrollment.
/// Enrolled applicants become [AdminStudentRecord]s. Alumni live on the
/// student registry as [StudentLifecycleStatus.graduated].
enum AdmissionStage {
  inquiry,
  application,
  documentsPending,
  documentsVerified,
  examScheduled,
  examScored,
  waitlist,
  offered,
  accepted,
  enrolled,
  declined,
  rejected,
  withdrawn,
}

enum AdmissionSource { walkIn, online, phone, staff }

class AdmissionDocument {
  const AdmissionDocument({
    required this.id,
    required this.label,
    this.submitted = false,
    this.verified = false,
    this.notes = '',
  });

  final String id;
  final String label;
  final bool submitted;
  final bool verified;
  final String notes;

  AdmissionDocument copyWith({
    String? label,
    bool? submitted,
    bool? verified,
    String? notes,
  }) {
    return AdmissionDocument(
      id: id,
      label: label ?? this.label,
      submitted: submitted ?? this.submitted,
      verified: verified ?? this.verified,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'submitted': submitted,
        'verified': verified,
        'notes': notes,
      };

  factory AdmissionDocument.fromMap(Map<String, dynamic> map) {
    return AdmissionDocument(
      id: (map['id'] as String? ?? '').trim(),
      label: (map['label'] as String? ?? '').trim(),
      submitted: map['submitted'] == true,
      verified: map['verified'] == true,
      notes: (map['notes'] as String? ?? '').trim(),
    );
  }
}

class AdmissionApplication {
  const AdmissionApplication({
    required this.id,
    required this.schoolId,
    required this.fullName,
    required this.stage,
    required this.createdAt,
    required this.updatedAt,
    this.source = AdmissionSource.staff,
    this.gradeApplying = '',
    this.campus = '',
    this.dateOfBirth,
    this.gender,
    this.guardianName = '',
    this.guardianPhone = '',
    this.guardianEmail = '',
    this.previousSchool = '',
    this.notes = '',
    this.documents = const [],
    this.examDate,
    this.examScore,
    this.examMaxScore = 100,
    this.examNotes = '',
    this.waitlistRank,
    this.offerSentAt,
    this.offerExpiresAt,
    this.offerMessage = '',
    this.enrolledStudentId,
    this.enrolledClassName,
    this.enrolledAt,
    this.decisionReason = '',
    this.createdById = '',
    this.createdByName = '',
  });

  final String id;
  final String schoolId;
  final String fullName;
  final AdmissionStage stage;
  final AdmissionSource source;
  final String gradeApplying;
  final String campus;
  final DateTime? dateOfBirth;
  final String? gender;
  final String guardianName;
  final String guardianPhone;
  final String guardianEmail;
  final String previousSchool;
  final String notes;
  final List<AdmissionDocument> documents;
  final DateTime? examDate;
  final double? examScore;
  final double examMaxScore;
  final String examNotes;
  final int? waitlistRank;
  final DateTime? offerSentAt;
  final DateTime? offerExpiresAt;
  final String offerMessage;
  final String? enrolledStudentId;
  final String? enrolledClassName;
  final DateTime? enrolledAt;
  final String decisionReason;
  final String createdById;
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOpen => !isTerminal;

  bool get isTerminal =>
      stage == AdmissionStage.enrolled ||
      stage == AdmissionStage.declined ||
      stage == AdmissionStage.rejected ||
      stage == AdmissionStage.withdrawn;

  bool get documentsComplete =>
      documents.isNotEmpty && documents.every((d) => d.verified);

  String get stageLabel => stageLabelOf(stage);

  static String stageLabelOf(AdmissionStage stage) => switch (stage) {
        AdmissionStage.inquiry => 'Inquiry',
        AdmissionStage.application => 'Application',
        AdmissionStage.documentsPending => 'Documents pending',
        AdmissionStage.documentsVerified => 'Documents verified',
        AdmissionStage.examScheduled => 'Exam scheduled',
        AdmissionStage.examScored => 'Exam scored',
        AdmissionStage.waitlist => 'Waitlist',
        AdmissionStage.offered => 'Offer sent',
        AdmissionStage.accepted => 'Offer accepted',
        AdmissionStage.enrolled => 'Enrolled',
        AdmissionStage.declined => 'Offer declined',
        AdmissionStage.rejected => 'Rejected',
        AdmissionStage.withdrawn => 'Withdrawn',
      };

  static const funnelStages = <AdmissionStage>[
    AdmissionStage.inquiry,
    AdmissionStage.application,
    AdmissionStage.documentsPending,
    AdmissionStage.documentsVerified,
    AdmissionStage.examScheduled,
    AdmissionStage.examScored,
    AdmissionStage.waitlist,
    AdmissionStage.offered,
    AdmissionStage.accepted,
    AdmissionStage.enrolled,
  ];

  static List<AdmissionDocument> defaultDocuments() {
    const labels = [
      'Birth certificate',
      'Previous school report',
      'Passport photo',
      'Parent / guardian ID',
    ];
    return [
      for (var i = 0; i < labels.length; i++)
        AdmissionDocument(id: 'doc-$i', label: labels[i]),
    ];
  }

  /// Next staff-driven stages from [stage]. Empty when terminal.
  static List<AdmissionStage> nextStages(AdmissionStage stage) {
    return switch (stage) {
      AdmissionStage.inquiry => const [
          AdmissionStage.application,
          AdmissionStage.withdrawn,
        ],
      AdmissionStage.application => const [
          AdmissionStage.documentsPending,
          AdmissionStage.rejected,
          AdmissionStage.withdrawn,
        ],
      AdmissionStage.documentsPending => const [
          AdmissionStage.documentsVerified,
          AdmissionStage.rejected,
          AdmissionStage.withdrawn,
        ],
      AdmissionStage.documentsVerified => const [
          AdmissionStage.examScheduled,
          AdmissionStage.waitlist,
          AdmissionStage.offered,
          AdmissionStage.rejected,
        ],
      AdmissionStage.examScheduled => const [
          AdmissionStage.examScored,
          AdmissionStage.withdrawn,
        ],
      AdmissionStage.examScored => const [
          AdmissionStage.waitlist,
          AdmissionStage.offered,
          AdmissionStage.rejected,
        ],
      AdmissionStage.waitlist => const [
          AdmissionStage.offered,
          AdmissionStage.rejected,
          AdmissionStage.withdrawn,
        ],
      AdmissionStage.offered => const [
          AdmissionStage.accepted,
          AdmissionStage.declined,
          AdmissionStage.withdrawn,
        ],
      AdmissionStage.accepted => const [
          AdmissionStage.enrolled,
          AdmissionStage.withdrawn,
        ],
      AdmissionStage.enrolled ||
      AdmissionStage.declined ||
      AdmissionStage.rejected ||
      AdmissionStage.withdrawn =>
        const [],
    };
  }

  bool canMoveTo(AdmissionStage next) => nextStages(stage).contains(next);

  AdmissionApplication copyWith({
    String? fullName,
    AdmissionStage? stage,
    AdmissionSource? source,
    String? gradeApplying,
    String? campus,
    DateTime? dateOfBirth,
    String? gender,
    String? guardianName,
    String? guardianPhone,
    String? guardianEmail,
    String? previousSchool,
    String? notes,
    List<AdmissionDocument>? documents,
    DateTime? examDate,
    double? examScore,
    double? examMaxScore,
    String? examNotes,
    int? waitlistRank,
    DateTime? offerSentAt,
    DateTime? offerExpiresAt,
    String? offerMessage,
    String? enrolledStudentId,
    String? enrolledClassName,
    DateTime? enrolledAt,
    String? decisionReason,
    DateTime? updatedAt,
  }) {
    return AdmissionApplication(
      id: id,
      schoolId: schoolId,
      fullName: fullName ?? this.fullName,
      stage: stage ?? this.stage,
      source: source ?? this.source,
      gradeApplying: gradeApplying ?? this.gradeApplying,
      campus: campus ?? this.campus,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      guardianName: guardianName ?? this.guardianName,
      guardianPhone: guardianPhone ?? this.guardianPhone,
      guardianEmail: guardianEmail ?? this.guardianEmail,
      previousSchool: previousSchool ?? this.previousSchool,
      notes: notes ?? this.notes,
      documents: documents ?? this.documents,
      examDate: examDate ?? this.examDate,
      examScore: examScore ?? this.examScore,
      examMaxScore: examMaxScore ?? this.examMaxScore,
      examNotes: examNotes ?? this.examNotes,
      waitlistRank: waitlistRank ?? this.waitlistRank,
      offerSentAt: offerSentAt ?? this.offerSentAt,
      offerExpiresAt: offerExpiresAt ?? this.offerExpiresAt,
      offerMessage: offerMessage ?? this.offerMessage,
      enrolledStudentId: enrolledStudentId ?? this.enrolledStudentId,
      enrolledClassName: enrolledClassName ?? this.enrolledClassName,
      enrolledAt: enrolledAt ?? this.enrolledAt,
      decisionReason: decisionReason ?? this.decisionReason,
      createdById: createdById,
      createdByName: createdByName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'fullName': fullName,
        'stage': stage.name,
        'source': source.name,
        'gradeApplying': gradeApplying,
        'campus': campus,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'gender': gender,
        'guardianName': guardianName,
        'guardianPhone': guardianPhone,
        'guardianEmail': guardianEmail,
        'previousSchool': previousSchool,
        'notes': notes,
        'documents': documents.map((d) => d.toMap()).toList(),
        'examDate': examDate?.toIso8601String(),
        'examScore': examScore,
        'examMaxScore': examMaxScore,
        'examNotes': examNotes,
        'waitlistRank': waitlistRank,
        'offerSentAt': offerSentAt?.toIso8601String(),
        'offerExpiresAt': offerExpiresAt?.toIso8601String(),
        'offerMessage': offerMessage,
        'enrolledStudentId': enrolledStudentId,
        'enrolledClassName': enrolledClassName,
        'enrolledAt': enrolledAt?.toIso8601String(),
        'decisionReason': decisionReason,
        'createdById': createdById,
        'createdByName': createdByName,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory AdmissionApplication.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic raw) {
      if (raw is DateTime) return raw;
      if (raw is String && raw.trim().isNotEmpty) {
        return DateTime.tryParse(raw);
      }
      return null;
    }

    AdmissionStage parseStage(String? raw) {
      final key = (raw ?? '').trim();
      for (final value in AdmissionStage.values) {
        if (value.name == key) return value;
      }
      return AdmissionStage.inquiry;
    }

    AdmissionSource parseSource(String? raw) {
      final key = (raw ?? '').trim();
      for (final value in AdmissionSource.values) {
        if (value.name == key) return value;
      }
      return AdmissionSource.staff;
    }

    final docsRaw = map['documents'];
    final docs = <AdmissionDocument>[];
    if (docsRaw is List) {
      for (final item in docsRaw) {
        if (item is Map) {
          docs.add(
            AdmissionDocument.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return AdmissionApplication(
      id: (map['id'] as String? ?? '').trim(),
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      fullName: (map['fullName'] as String? ?? '').trim(),
      stage: parseStage(map['stage'] as String?),
      source: parseSource(map['source'] as String?),
      gradeApplying: (map['gradeApplying'] as String? ?? '').trim(),
      campus: (map['campus'] as String? ?? '').trim(),
      dateOfBirth: parseDate(map['dateOfBirth']),
      gender: (map['gender'] as String?)?.trim(),
      guardianName: (map['guardianName'] as String? ?? '').trim(),
      guardianPhone: (map['guardianPhone'] as String? ?? '').trim(),
      guardianEmail: (map['guardianEmail'] as String? ?? '').trim(),
      previousSchool: (map['previousSchool'] as String? ?? '').trim(),
      notes: (map['notes'] as String? ?? '').trim(),
      documents: docs,
      examDate: parseDate(map['examDate']),
      examScore: (map['examScore'] as num?)?.toDouble(),
      examMaxScore: (map['examMaxScore'] as num?)?.toDouble() ?? 100,
      examNotes: (map['examNotes'] as String? ?? '').trim(),
      waitlistRank: (map['waitlistRank'] as num?)?.toInt(),
      offerSentAt: parseDate(map['offerSentAt']),
      offerExpiresAt: parseDate(map['offerExpiresAt']),
      offerMessage: (map['offerMessage'] as String? ?? '').trim(),
      enrolledStudentId: (map['enrolledStudentId'] as String?)?.trim(),
      enrolledClassName: (map['enrolledClassName'] as String?)?.trim(),
      enrolledAt: parseDate(map['enrolledAt']),
      decisionReason: (map['decisionReason'] as String? ?? '').trim(),
      createdById: (map['createdById'] as String? ?? '').trim(),
      createdByName: (map['createdByName'] as String? ?? '').trim(),
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: parseDate(map['updatedAt']) ?? DateTime.now(),
    );
  }
}
