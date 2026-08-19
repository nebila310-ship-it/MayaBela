enum ParentLinkStatus { pending, approved, rejected }

enum ParentRelationship { father, mother, guardian }

enum TeacherStaffRole {
  homeroomTeacher,
  subjectTeacher,
}

/// One subject linked to a teacher for a specific grade/section.
class SubjectTeachingSlot {
  const SubjectTeachingSlot({
    required this.slotId,
    required this.subjectId,
    required this.subjectName,
  });

  final String slotId;
  final String subjectId;
  final String subjectName;

  Map<String, dynamic> toMap() => {
        'slotId': slotId,
        'subjectId': subjectId,
        'subjectName': subjectName,
      };

  factory SubjectTeachingSlot.fromMap(Map<String, dynamic> map) {
    return SubjectTeachingSlot(
      slotId: (map['slotId'] as String? ?? '').trim().toUpperCase(),
      subjectId: (map['subjectId'] as String? ?? '').trim().toUpperCase(),
      subjectName: map['subjectName'] as String? ?? '',
    );
  }
}

/// Homeroom or subject teacher assignment per class/grade.
class TeacherClassAssignment {
  const TeacherClassAssignment({
    required this.className,
    required this.role,
    this.teachingSlots = const [],
  });

  final String className;
  final TeacherStaffRole role;
  final List<SubjectTeachingSlot> teachingSlots;

  List<String> get subjectNames =>
      teachingSlots.map((slot) => slot.subjectName).toList();

  Map<String, dynamic> toMap() => {
        'className': className,
        'role': role.name,
        'teachingSlots': teachingSlots.map((slot) => slot.toMap()).toList(),
      };

  factory TeacherClassAssignment.fromMap(Map<String, dynamic> map) {
    final roleName = map['role'] as String? ?? TeacherStaffRole.subjectTeacher.name;
    final rawSlots = map['teachingSlots'] as List?;
    final teachingSlots = rawSlots == null
        ? const <SubjectTeachingSlot>[]
        : rawSlots
            .whereType<Map>()
            .map(
              (item) => SubjectTeachingSlot.fromMap(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();
    return TeacherClassAssignment(
      className: map['className'] as String? ?? '',
      role: TeacherStaffRole.values.firstWhere(
        (role) => role.name == roleName,
        orElse: () => TeacherStaffRole.subjectTeacher,
      ),
      teachingSlots: teachingSlots,
    );
  }

  TeacherClassAssignment copyWith({
    String? className,
    TeacherStaffRole? role,
    List<SubjectTeachingSlot>? teachingSlots,
  }) {
    return TeacherClassAssignment(
      className: className ?? this.className,
      role: role ?? this.role,
      teachingSlots: teachingSlots ?? this.teachingSlots,
    );
  }
}

class ParentChildRegistration {
  const ParentChildRegistration({
    required this.studentId,
    required this.dateOfBirth,
    required this.relationship,
    this.hasMedicalCondition = false,
    this.medicalConditionDetails,
    this.otherMedicalInfo,
  });

  final String studentId;
  final DateTime dateOfBirth;
  final ParentRelationship relationship;
  final bool hasMedicalCondition;
  final String? medicalConditionDetails;
  final String? otherMedicalInfo;
}

class ParentLinkRequest {
  ParentLinkRequest({
    required this.id,
    required this.parentUsername,
    required this.parentFullName,
    required this.studentId,
    required this.schoolId,
    required this.relationship,
    required this.requestedAt,
    this.status = ParentLinkStatus.pending,
    this.reviewedBy,
    this.reviewedAt,
    this.hasMedicalCondition = false,
    this.medicalConditionDetails,
    this.otherMedicalInfo,
  });

  final String id;
  final String parentUsername;
  final String parentFullName;
  final String studentId;
  final String schoolId;
  final ParentRelationship relationship;
  final DateTime requestedAt;
  ParentLinkStatus status;
  String? reviewedBy;
  DateTime? reviewedAt;
  final bool hasMedicalCondition;
  final String? medicalConditionDetails;
  final String? otherMedicalInfo;

  Map<String, dynamic> toMap() => {
        'id': id,
        'parentUsername': parentUsername,
        'parentFullName': parentFullName,
        'studentId': studentId,
        'schoolId': schoolId,
        'relationship': relationship.name,
        'requestedAt': requestedAt.toIso8601String(),
        'status': status.name,
        if (reviewedBy != null) 'reviewedBy': reviewedBy,
        if (reviewedAt != null) 'reviewedAt': reviewedAt!.toIso8601String(),
        'hasMedicalCondition': hasMedicalCondition,
        if (medicalConditionDetails != null)
          'medicalConditionDetails': medicalConditionDetails,
        if (otherMedicalInfo != null) 'otherMedicalInfo': otherMedicalInfo,
      };

  factory ParentLinkRequest.fromMap(Map<String, dynamic> map) {
    return ParentLinkRequest(
      id: map['id'] as String,
      parentUsername: map['parentUsername'] as String,
      parentFullName: map['parentFullName'] as String,
      studentId: map['studentId'] as String,
      schoolId: map['schoolId'] as String,
      relationship: ParentRelationship.values.byName(
        map['relationship'] as String,
      ),
      requestedAt: DateTime.parse(map['requestedAt'] as String),
      status: ParentLinkStatus.values.byName(
        map['status'] as String? ?? 'pending',
      ),
      reviewedBy: map['reviewedBy'] as String?,
      reviewedAt: map['reviewedAt'] != null
          ? DateTime.tryParse(map['reviewedAt'] as String)
          : null,
      hasMedicalCondition: map['hasMedicalCondition'] as bool? ?? false,
      medicalConditionDetails: map['medicalConditionDetails'] as String?,
      otherMedicalInfo: map['otherMedicalInfo'] as String?,
    );
  }
}

class SchoolSetup {
  SchoolSetup({
    required this.academicYear,
    required this.gradeLevels,
    this.sections = const [],
  });

  final String academicYear;
  final List<String> gradeLevels;
  final List<String> sections;
}
