/// Phase 1 Institutional Management records — governance of the institution,
/// not SIS / academic / HR / finance operations.

enum InstitutionLegalForm { privateSchool, foundation, company, academy, other }

enum LeadershipSeatType {
  owner,
  boardChair,
  boardMember,
  principal,
  director,
  vicePrincipal,
  campusDirector,
  other,
}

enum OrgUnitKind { academicDepartment, supportDivision }

enum InstitutionSiteStatus { active, planned, suspended }

enum PolicyStatus { draft, active, superseded, withdrawn }

enum ResolutionStatus { open, inProgress, done, vacated }

enum LicenseHealth { valid, expiring, expired, none }

enum CommitteeStatus { active, paused, dissolved }

enum InstitutionStaffKind { teacher, employee, admin }

enum MeetingBodyKind { board, slt, committee, other }

enum RiskLikelihood { low, medium, high }

enum RiskImpact { low, medium, high }

enum RiskStatus { open, monitoring, closed }

enum PartnerKind { ministry, accreditor, sisterSchool, mou, other }

enum PartnerStatus { active, ended }

enum SefJudgment { emerging, developing, good, outstanding }

enum SefStatus { draft, inReview, published }

enum CapaSource { sef, risk, license, resolution, other }

enum CapaStatus { open, inProgress, done, vacated }

enum KpiTheme { governance, compliance, safeguarding, community, estate, other }

enum KpiStatus { onTrack, atRisk, offTrack }

enum PropertyKind { land, building, facility, other }

enum PropertyStatus { inUse, planned, leased, disposed }

enum ArchiveSeries { policies, minutes, licenses, sef, other }

enum ArchiveStatus { current, archived, destroyed }

List<String> institutionStringList(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if ('$item'.trim().isNotEmpty) '$item'.trim(),
  ];
}

List<InstitutionStaffMember> institutionStaffList(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map)
        InstitutionStaffMember.fromMap(Map<String, dynamic>.from(item)),
  ].where((m) => m.personId.isNotEmpty).toList();
}

class InstitutionProfile {
  const InstitutionProfile({
    this.legalName = '',
    this.tradingName = '',
    this.legalForm = InstitutionLegalForm.privateSchool,
    this.registrationNumber = '',
    this.foundingDate = '',
    this.registeredAddress = '',
    this.operatingAddress = '',
    this.motto = '',
    this.vision = '',
    this.mission = '',
    this.officialLanguages = 'English',
  });

  final String legalName;
  final String tradingName;
  final InstitutionLegalForm legalForm;
  final String registrationNumber;
  final String foundingDate;
  final String registeredAddress;
  final String operatingAddress;
  final String motto;
  final String vision;
  final String mission;
  final String officialLanguages;

  InstitutionProfile copyWith({
    String? legalName,
    String? tradingName,
    InstitutionLegalForm? legalForm,
    String? registrationNumber,
    String? foundingDate,
    String? registeredAddress,
    String? operatingAddress,
    String? motto,
    String? vision,
    String? mission,
    String? officialLanguages,
  }) {
    return InstitutionProfile(
      legalName: legalName ?? this.legalName,
      tradingName: tradingName ?? this.tradingName,
      legalForm: legalForm ?? this.legalForm,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      foundingDate: foundingDate ?? this.foundingDate,
      registeredAddress: registeredAddress ?? this.registeredAddress,
      operatingAddress: operatingAddress ?? this.operatingAddress,
      motto: motto ?? this.motto,
      vision: vision ?? this.vision,
      mission: mission ?? this.mission,
      officialLanguages: officialLanguages ?? this.officialLanguages,
    );
  }

  Map<String, dynamic> toMap() => {
    'legalName': legalName,
    'tradingName': tradingName,
    'legalForm': legalForm.name,
    'registrationNumber': registrationNumber,
    'foundingDate': foundingDate,
    'registeredAddress': registeredAddress,
    'operatingAddress': operatingAddress,
    'motto': motto,
    'vision': vision,
    'mission': mission,
    'officialLanguages': officialLanguages,
  };

  static InstitutionProfile fromMap(Map<String, dynamic>? map) {
    if (map == null) return const InstitutionProfile();
    return InstitutionProfile(
      legalName: '${map['legalName'] ?? ''}',
      tradingName: '${map['tradingName'] ?? ''}',
      legalForm: InstitutionLegalForm.values.firstWhere(
        (v) => v.name == map['legalForm'],
        orElse: () => InstitutionLegalForm.privateSchool,
      ),
      registrationNumber: '${map['registrationNumber'] ?? ''}',
      foundingDate: '${map['foundingDate'] ?? ''}',
      registeredAddress: '${map['registeredAddress'] ?? ''}',
      operatingAddress: '${map['operatingAddress'] ?? ''}',
      motto: '${map['motto'] ?? ''}',
      vision: '${map['vision'] ?? ''}',
      mission: '${map['mission'] ?? ''}',
      officialLanguages: '${map['officialLanguages'] ?? 'English'}',
    );
  }

  static String legalFormLabel(InstitutionLegalForm form) => switch (form) {
    InstitutionLegalForm.privateSchool => 'Private school',
    InstitutionLegalForm.foundation => 'Foundation',
    InstitutionLegalForm.company => 'Company',
    InstitutionLegalForm.academy => 'Academy / international school',
    InstitutionLegalForm.other => 'Other',
  };
}

class LeadershipSeat {
  const LeadershipSeat({
    required this.id,
    required this.seatType,
    required this.personName,
    this.title = '',
    this.termStart = '',
    this.termEnd = '',
    this.isActing = false,
    this.notes = '',
  });

  final String id;
  final LeadershipSeatType seatType;
  final String personName;
  final String title;
  final String termStart;
  final String termEnd;
  final bool isActing;
  final String notes;

  LeadershipSeat copyWith({
    LeadershipSeatType? seatType,
    String? personName,
    String? title,
    String? termStart,
    String? termEnd,
    bool? isActing,
    String? notes,
  }) {
    return LeadershipSeat(
      id: id,
      seatType: seatType ?? this.seatType,
      personName: personName ?? this.personName,
      title: title ?? this.title,
      termStart: termStart ?? this.termStart,
      termEnd: termEnd ?? this.termEnd,
      isActing: isActing ?? this.isActing,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'seatType': seatType.name,
    'personName': personName,
    'title': title,
    'termStart': termStart,
    'termEnd': termEnd,
    'isActing': isActing,
    'notes': notes,
  };

  static LeadershipSeat fromMap(Map<String, dynamic> map) {
    return LeadershipSeat(
      id: '${map['id'] ?? ''}',
      seatType: LeadershipSeatType.values.firstWhere(
        (v) => v.name == map['seatType'],
        orElse: () => LeadershipSeatType.other,
      ),
      personName: '${map['personName'] ?? ''}',
      title: '${map['title'] ?? ''}',
      termStart: '${map['termStart'] ?? ''}',
      termEnd: '${map['termEnd'] ?? ''}',
      isActing: map['isActing'] == true,
      notes: '${map['notes'] ?? ''}',
    );
  }

  static String seatLabel(LeadershipSeatType type) => switch (type) {
    LeadershipSeatType.owner => 'Owner / proprietor',
    LeadershipSeatType.boardChair => 'Board chair',
    LeadershipSeatType.boardMember => 'Board member',
    LeadershipSeatType.principal => 'Principal',
    LeadershipSeatType.director => 'Director',
    LeadershipSeatType.vicePrincipal => 'Vice principal',
    LeadershipSeatType.campusDirector => 'Campus director',
    LeadershipSeatType.other => 'Other seat',
  };
}

class OrgUnit {
  const OrgUnit({
    required this.id,
    required this.name,
    required this.kind,
    this.headName = '',
    this.mandate = '',
  });

  final String id;
  final String name;
  final OrgUnitKind kind;
  final String headName;
  final String mandate;

  OrgUnit copyWith({
    String? name,
    OrgUnitKind? kind,
    String? headName,
    String? mandate,
  }) {
    return OrgUnit(
      id: id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      headName: headName ?? this.headName,
      mandate: mandate ?? this.mandate,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'headName': headName,
    'mandate': mandate,
  };

  static OrgUnit fromMap(Map<String, dynamic> map) {
    return OrgUnit(
      id: '${map['id'] ?? ''}',
      name: '${map['name'] ?? ''}',
      kind: OrgUnitKind.values.firstWhere(
        (v) => v.name == map['kind'],
        orElse: () => OrgUnitKind.academicDepartment,
      ),
      headName: '${map['headName'] ?? ''}',
      mandate: '${map['mandate'] ?? ''}',
    );
  }

  static String kindLabel(OrgUnitKind kind) => switch (kind) {
    OrgUnitKind.academicDepartment => 'Academic department',
    OrgUnitKind.supportDivision => 'Support division',
  };
}

class InstitutionSite {
  const InstitutionSite({
    required this.id,
    required this.campusName,
    this.isHeadquarters = false,
    this.status = InstitutionSiteStatus.active,
    this.notes = '',
  });

  final String id;
  final String campusName;
  final bool isHeadquarters;
  final InstitutionSiteStatus status;
  final String notes;

  InstitutionSite copyWith({
    String? campusName,
    bool? isHeadquarters,
    InstitutionSiteStatus? status,
    String? notes,
  }) {
    return InstitutionSite(
      id: id,
      campusName: campusName ?? this.campusName,
      isHeadquarters: isHeadquarters ?? this.isHeadquarters,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'campusName': campusName,
    'isHeadquarters': isHeadquarters,
    'status': status.name,
    'notes': notes,
  };

  static InstitutionSite fromMap(Map<String, dynamic> map) {
    return InstitutionSite(
      id: '${map['id'] ?? ''}',
      campusName: '${map['campusName'] ?? ''}',
      isHeadquarters: map['isHeadquarters'] == true,
      status: InstitutionSiteStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => InstitutionSiteStatus.active,
      ),
      notes: '${map['notes'] ?? ''}',
    );
  }
}

class InstitutionPolicy {
  const InstitutionPolicy({
    required this.id,
    required this.number,
    required this.title,
    this.owner = '',
    this.status = PolicyStatus.draft,
    this.reviewDate = '',
    this.notes = '',
    this.attachmentPaths = const [],
  });

  final String id;
  final String number;
  final String title;
  final String owner;
  final PolicyStatus status;
  final String reviewDate;
  final String notes;
  final List<String> attachmentPaths;

  bool get reviewDueSoon {
    final due = DateTime.tryParse(reviewDate);
    if (due == null || status != PolicyStatus.active) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return !due.isBefore(today) &&
        !due.isAfter(today.add(const Duration(days: 60)));
  }

  InstitutionPolicy copyWith({
    String? number,
    String? title,
    String? owner,
    PolicyStatus? status,
    String? reviewDate,
    String? notes,
    List<String>? attachmentPaths,
  }) {
    return InstitutionPolicy(
      id: id,
      number: number ?? this.number,
      title: title ?? this.title,
      owner: owner ?? this.owner,
      status: status ?? this.status,
      reviewDate: reviewDate ?? this.reviewDate,
      notes: notes ?? this.notes,
      attachmentPaths: attachmentPaths ?? this.attachmentPaths,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'number': number,
    'title': title,
    'owner': owner,
    'status': status.name,
    'reviewDate': reviewDate,
    'notes': notes,
    'attachmentPaths': attachmentPaths,
  };

  static InstitutionPolicy fromMap(Map<String, dynamic> map) {
    return InstitutionPolicy(
      id: '${map['id'] ?? ''}',
      number: '${map['number'] ?? ''}',
      title: '${map['title'] ?? ''}',
      owner: '${map['owner'] ?? ''}',
      status: PolicyStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => PolicyStatus.draft,
      ),
      reviewDate: '${map['reviewDate'] ?? ''}',
      notes: '${map['notes'] ?? ''}',
      attachmentPaths: institutionStringList(map['attachmentPaths']),
    );
  }

  static String statusLabel(PolicyStatus status) => switch (status) {
    PolicyStatus.draft => 'Draft',
    PolicyStatus.active => 'Active',
    PolicyStatus.superseded => 'Superseded',
    PolicyStatus.withdrawn => 'Withdrawn',
  };
}

enum CircularAudience { teachers, administrativeStaff, both }

class OfficialCircular {
  const OfficialCircular({
    required this.id,
    required this.number,
    required this.title,
    this.issuedOn = '',
    this.body = '',
    this.audience = CircularAudience.both,
    this.attachmentPaths = const [],
  });

  final String id;
  final String number;
  final String title;
  final String issuedOn;
  final String body;
  final CircularAudience audience;
  final List<String> attachmentPaths;

  OfficialCircular copyWith({
    String? number,
    String? title,
    String? issuedOn,
    String? body,
    CircularAudience? audience,
    List<String>? attachmentPaths,
  }) {
    return OfficialCircular(
      id: id,
      number: number ?? this.number,
      title: title ?? this.title,
      issuedOn: issuedOn ?? this.issuedOn,
      body: body ?? this.body,
      audience: audience ?? this.audience,
      attachmentPaths: attachmentPaths ?? this.attachmentPaths,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'number': number,
    'title': title,
    'issuedOn': issuedOn,
    'body': body,
    'audience': audience.name,
    'attachmentPaths': attachmentPaths,
  };

  static OfficialCircular fromMap(Map<String, dynamic> map) {
    return OfficialCircular(
      id: '${map['id'] ?? ''}',
      number: '${map['number'] ?? ''}',
      title: '${map['title'] ?? ''}',
      issuedOn: '${map['issuedOn'] ?? ''}',
      body: '${map['body'] ?? ''}',
      audience: CircularAudience.values.firstWhere(
        (v) => v.name == map['audience'],
        orElse: () => CircularAudience.both,
      ),
      attachmentPaths: institutionStringList(map['attachmentPaths']),
    );
  }

  static String audienceLabel(CircularAudience audience) => switch (audience) {
    CircularAudience.teachers => 'Teachers',
    CircularAudience.administrativeStaff => 'Administrative staff',
    CircularAudience.both => 'Both',
  };
}

class InstitutionLicense {
  const InstitutionLicense({
    required this.id,
    required this.title,
    this.issuer = '',
    this.number = '',
    this.issuedOn = '',
    this.expiresOn = '',
    this.campusScope = 'Institution-wide',
    this.notes = '',
    this.attachmentPaths = const [],
  });

  final String id;
  final String title;
  final String issuer;
  final String number;
  final String issuedOn;
  final String expiresOn;
  final String campusScope;
  final String notes;
  final List<String> attachmentPaths;

  LicenseHealth get health {
    final expiry = DateTime.tryParse(expiresOn);
    if (expiry == null) return LicenseHealth.none;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (expiry.isBefore(today)) return LicenseHealth.expired;
    if (!expiry.isAfter(today.add(const Duration(days: 60)))) {
      return LicenseHealth.expiring;
    }
    return LicenseHealth.valid;
  }

  InstitutionLicense copyWith({
    String? title,
    String? issuer,
    String? number,
    String? issuedOn,
    String? expiresOn,
    String? campusScope,
    String? notes,
    List<String>? attachmentPaths,
  }) {
    return InstitutionLicense(
      id: id,
      title: title ?? this.title,
      issuer: issuer ?? this.issuer,
      number: number ?? this.number,
      issuedOn: issuedOn ?? this.issuedOn,
      expiresOn: expiresOn ?? this.expiresOn,
      campusScope: campusScope ?? this.campusScope,
      notes: notes ?? this.notes,
      attachmentPaths: attachmentPaths ?? this.attachmentPaths,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'issuer': issuer,
    'number': number,
    'issuedOn': issuedOn,
    'expiresOn': expiresOn,
    'campusScope': campusScope,
    'notes': notes,
    'attachmentPaths': attachmentPaths,
  };

  static InstitutionLicense fromMap(Map<String, dynamic> map) {
    return InstitutionLicense(
      id: '${map['id'] ?? ''}',
      title: '${map['title'] ?? ''}',
      issuer: '${map['issuer'] ?? ''}',
      number: '${map['number'] ?? ''}',
      issuedOn: '${map['issuedOn'] ?? ''}',
      expiresOn: '${map['expiresOn'] ?? ''}',
      campusScope: '${map['campusScope'] ?? 'Institution-wide'}',
      notes: '${map['notes'] ?? ''}',
      attachmentPaths: institutionStringList(map['attachmentPaths']),
    );
  }

  static String healthLabel(LicenseHealth health) => switch (health) {
    LicenseHealth.valid => 'Valid',
    LicenseHealth.expiring => 'Expiring',
    LicenseHealth.expired => 'Expired',
    LicenseHealth.none => 'No expiry',
  };
}

class InstitutionResolution {
  const InstitutionResolution({
    required this.id,
    required this.number,
    required this.title,
    this.decision = '',
    this.owner = '',
    this.dueDate = '',
    this.status = ResolutionStatus.open,
    this.meetingTitle = '',
    this.meetingId = '',
  });

  final String id;
  final String number;
  final String title;
  final String decision;
  final String owner;
  final String dueDate;
  final ResolutionStatus status;
  final String meetingTitle;
  final String meetingId;

  bool get isOpen =>
      status == ResolutionStatus.open || status == ResolutionStatus.inProgress;

  bool get isOverdue {
    if (!isOpen) return false;
    final due = DateTime.tryParse(dueDate);
    if (due == null) return false;
    final now = DateTime.now();
    return due.isBefore(DateTime(now.year, now.month, now.day));
  }

  InstitutionResolution copyWith({
    String? number,
    String? title,
    String? decision,
    String? owner,
    String? dueDate,
    ResolutionStatus? status,
    String? meetingTitle,
    String? meetingId,
  }) {
    return InstitutionResolution(
      id: id,
      number: number ?? this.number,
      title: title ?? this.title,
      decision: decision ?? this.decision,
      owner: owner ?? this.owner,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      meetingTitle: meetingTitle ?? this.meetingTitle,
      meetingId: meetingId ?? this.meetingId,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'number': number,
    'title': title,
    'decision': decision,
    'owner': owner,
    'dueDate': dueDate,
    'status': status.name,
    'meetingTitle': meetingTitle,
    'meetingId': meetingId,
  };

  static InstitutionResolution fromMap(Map<String, dynamic> map) {
    return InstitutionResolution(
      id: '${map['id'] ?? ''}',
      number: '${map['number'] ?? ''}',
      title: '${map['title'] ?? ''}',
      decision: '${map['decision'] ?? ''}',
      owner: '${map['owner'] ?? ''}',
      dueDate: '${map['dueDate'] ?? ''}',
      status: ResolutionStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => ResolutionStatus.open,
      ),
      meetingTitle: '${map['meetingTitle'] ?? ''}',
      meetingId: '${map['meetingId'] ?? ''}',
    );
  }

  static String statusLabel(ResolutionStatus status) => switch (status) {
    ResolutionStatus.open => 'Open',
    ResolutionStatus.inProgress => 'In progress',
    ResolutionStatus.done => 'Done',
    ResolutionStatus.vacated => 'Vacated',
  };
}

class InstitutionStaffMember {
  const InstitutionStaffMember({
    required this.kind,
    required this.personId,
    required this.name,
    this.title = '',
  });

  final InstitutionStaffKind kind;
  final String personId;
  final String name;
  final String title;

  String get key => '${kind.name}:$personId';

  InstitutionStaffMember copyWith({
    InstitutionStaffKind? kind,
    String? personId,
    String? name,
    String? title,
  }) {
    return InstitutionStaffMember(
      kind: kind ?? this.kind,
      personId: personId ?? this.personId,
      name: name ?? this.name,
      title: title ?? this.title,
    );
  }

  Map<String, dynamic> toMap() => {
    'kind': kind.name,
    'personId': personId,
    'name': name,
    'title': title,
  };

  static InstitutionStaffMember fromMap(Map<String, dynamic> map) {
    return InstitutionStaffMember(
      kind: InstitutionStaffKind.values.firstWhere(
        (v) => v.name == map['kind'],
        orElse: () => InstitutionStaffKind.employee,
      ),
      personId: '${map['personId'] ?? ''}'.trim(),
      name: '${map['name'] ?? ''}'.trim(),
      title: '${map['title'] ?? ''}'.trim(),
    );
  }

  static String kindLabel(InstitutionStaffKind kind) => switch (kind) {
    InstitutionStaffKind.teacher => 'Teacher',
    InstitutionStaffKind.employee => 'Employee',
    InstitutionStaffKind.admin => 'Administrative staff',
  };

  static String namesLabel(List<InstitutionStaffMember> list) => list
      .map((m) => m.name.trim())
      .where((name) => name.isNotEmpty)
      .join(', ');
}

class InstitutionCommittee {
  InstitutionCommittee({
    required this.id,
    required this.name,
    this.chairName = '',
    this.chairSeatId = '',
    String members = '',
    this.memberList = const [],
    this.termsOfReference = '',
    this.status = CommitteeStatus.active,
  }) : members = memberList.isNotEmpty ? membersLabel(memberList) : members;

  final String id;
  final String name;
  final String chairName;
  final String chairSeatId;
  final String members;
  final List<InstitutionStaffMember> memberList;
  final String termsOfReference;
  final CommitteeStatus status;

  InstitutionCommittee copyWith({
    String? name,
    String? chairName,
    String? chairSeatId,
    String? members,
    List<InstitutionStaffMember>? memberList,
    String? termsOfReference,
    CommitteeStatus? status,
  }) {
    final nextList = memberList ?? this.memberList;
    return InstitutionCommittee(
      id: id,
      name: name ?? this.name,
      chairName: chairName ?? this.chairName,
      chairSeatId: chairSeatId ?? this.chairSeatId,
      memberList: nextList,
      members:
          members ??
          (memberList != null ? membersLabel(memberList) : this.members),
      termsOfReference: termsOfReference ?? this.termsOfReference,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'chairName': chairName,
    'chairSeatId': chairSeatId,
    'members': members,
    'memberList': memberList.map((e) => e.toMap()).toList(),
    'termsOfReference': termsOfReference,
    'status': status.name,
  };

  static InstitutionCommittee fromMap(Map<String, dynamic> map) {
    final parsed = institutionStaffList(map['memberList']);
    return InstitutionCommittee(
      id: '${map['id'] ?? ''}',
      name: '${map['name'] ?? ''}',
      chairName: '${map['chairName'] ?? ''}',
      chairSeatId: '${map['chairSeatId'] ?? ''}',
      memberList: parsed,
      members: '${map['members'] ?? ''}',
      termsOfReference: '${map['termsOfReference'] ?? ''}',
      status: CommitteeStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => CommitteeStatus.active,
      ),
    );
  }

  static String membersLabel(List<InstitutionStaffMember> list) => list
      .map((m) => m.name.trim())
      .where((name) => name.isNotEmpty)
      .join(', ');

  static String statusLabel(CommitteeStatus status) => switch (status) {
    CommitteeStatus.active => 'Active',
    CommitteeStatus.paused => 'Paused',
    CommitteeStatus.dissolved => 'Dissolved',
  };
}

class InstitutionMeeting {
  InstitutionMeeting({
    required this.id,
    required this.title,
    this.heldOn = '',
    this.bodyKind = MeetingBodyKind.board,
    this.committeeId = '',
    String attendance = '',
    this.invitees = const [],
    this.venue = '',
    this.meetingLink = '',
    this.agenda = '',
    this.notes = '',
    this.attachmentPaths = const [],
    this.invitedKeys = const [],
  }) : attendance = invitees.isNotEmpty
           ? InstitutionStaffMember.namesLabel(invitees)
           : attendance;

  final String id;
  final String title;
  final String heldOn;
  final MeetingBodyKind bodyKind;
  final String committeeId;
  final String attendance;
  final List<InstitutionStaffMember> invitees;
  final String venue;
  final String meetingLink;
  final String agenda;
  final String notes;
  final List<String> attachmentPaths;
  final List<String> invitedKeys;

  InstitutionMeeting copyWith({
    String? title,
    String? heldOn,
    MeetingBodyKind? bodyKind,
    String? committeeId,
    String? attendance,
    List<InstitutionStaffMember>? invitees,
    String? venue,
    String? meetingLink,
    String? agenda,
    String? notes,
    List<String>? attachmentPaths,
    List<String>? invitedKeys,
  }) {
    final nextInvitees = invitees ?? this.invitees;
    return InstitutionMeeting(
      id: id,
      title: title ?? this.title,
      heldOn: heldOn ?? this.heldOn,
      bodyKind: bodyKind ?? this.bodyKind,
      committeeId: committeeId ?? this.committeeId,
      invitees: nextInvitees,
      attendance:
          attendance ??
          (invitees != null
              ? InstitutionStaffMember.namesLabel(invitees)
              : this.attendance),
      venue: venue ?? this.venue,
      meetingLink: meetingLink ?? this.meetingLink,
      agenda: agenda ?? this.agenda,
      notes: notes ?? this.notes,
      attachmentPaths: attachmentPaths ?? this.attachmentPaths,
      invitedKeys: invitedKeys ?? this.invitedKeys,
    );
  }

  String invitationText({
    String toName = 'colleague',
    String schoolName = '',
    String senderName = '',
  }) {
    final greeting = toName.trim().isEmpty ? 'colleague' : toName.trim();
    final lines = <String>[
      'Dear $greeting,',
      '',
      'You are invited to the following institutional meeting.',
      '',
      'Title: $title',
      'Body: ${bodyLabel(bodyKind)}',
      if (heldOn.trim().isNotEmpty) 'Date: ${heldOn.trim()}',
      if (venue.trim().isNotEmpty) 'Venue: ${venue.trim()}',
      if (meetingLink.trim().isNotEmpty) 'Join link: ${meetingLink.trim()}',
      if (agenda.trim().isNotEmpty) ...['', 'Agenda:', agenda.trim()],
      if (attachmentPaths.isNotEmpty)
        'Attachments: ${attachmentPaths.length} file(s) included with this invitation.',
      '',
      'Please acknowledge that you will attend.',
      '',
      'Regards,',
      if (senderName.trim().isNotEmpty) senderName.trim(),
      if (schoolName.trim().isNotEmpty) schoolName.trim(),
    ];
    return lines.join('\n');
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'heldOn': heldOn,
    'bodyKind': bodyKind.name,
    'committeeId': committeeId,
    'attendance': attendance,
    'invitees': invitees.map((e) => e.toMap()).toList(),
    'venue': venue,
    'meetingLink': meetingLink,
    'agenda': agenda,
    'notes': notes,
    'attachmentPaths': attachmentPaths,
    'invitedKeys': invitedKeys,
  };

  static InstitutionMeeting fromMap(Map<String, dynamic> map) {
    return InstitutionMeeting(
      id: '${map['id'] ?? ''}',
      title: '${map['title'] ?? ''}',
      heldOn: '${map['heldOn'] ?? ''}',
      bodyKind: MeetingBodyKind.values.firstWhere(
        (v) => v.name == map['bodyKind'],
        orElse: () => MeetingBodyKind.board,
      ),
      committeeId: '${map['committeeId'] ?? ''}',
      invitees: institutionStaffList(map['invitees']),
      attendance: '${map['attendance'] ?? ''}',
      venue: '${map['venue'] ?? ''}',
      meetingLink: '${map['meetingLink'] ?? ''}',
      agenda: '${map['agenda'] ?? ''}',
      notes: '${map['notes'] ?? ''}',
      attachmentPaths: institutionStringList(map['attachmentPaths']),
      invitedKeys: institutionStringList(map['invitedKeys']),
    );
  }

  static String bodyLabel(MeetingBodyKind kind) => switch (kind) {
    MeetingBodyKind.board => 'Board',
    MeetingBodyKind.slt => 'Senior leadership team',
    MeetingBodyKind.committee => 'Committee',
    MeetingBodyKind.other => 'Other body',
  };
}

class InstitutionRisk {
  const InstitutionRisk({
    required this.id,
    required this.title,
    this.owner = '',
    this.likelihood = RiskLikelihood.medium,
    this.impact = RiskImpact.medium,
    this.reviewDate = '',
    this.status = RiskStatus.open,
    this.notes = '',
  });

  final String id;
  final String title;
  final String owner;
  final RiskLikelihood likelihood;
  final RiskImpact impact;
  final String reviewDate;
  final RiskStatus status;
  final String notes;

  bool get isOpen =>
      status == RiskStatus.open || status == RiskStatus.monitoring;

  bool get isOverdue {
    if (!isOpen) return false;
    final due = DateTime.tryParse(reviewDate);
    if (due == null) return false;
    final now = DateTime.now();
    return due.isBefore(DateTime(now.year, now.month, now.day));
  }

  bool get reviewDueSoon {
    if (!isOpen) return false;
    final due = DateTime.tryParse(reviewDate);
    if (due == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return !due.isAfter(today.add(const Duration(days: 60)));
  }

  InstitutionRisk copyWith({
    String? title,
    String? owner,
    RiskLikelihood? likelihood,
    RiskImpact? impact,
    String? reviewDate,
    RiskStatus? status,
    String? notes,
  }) {
    return InstitutionRisk(
      id: id,
      title: title ?? this.title,
      owner: owner ?? this.owner,
      likelihood: likelihood ?? this.likelihood,
      impact: impact ?? this.impact,
      reviewDate: reviewDate ?? this.reviewDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'owner': owner,
    'likelihood': likelihood.name,
    'impact': impact.name,
    'reviewDate': reviewDate,
    'status': status.name,
    'notes': notes,
  };

  static InstitutionRisk fromMap(Map<String, dynamic> map) {
    return InstitutionRisk(
      id: '${map['id'] ?? ''}',
      title: '${map['title'] ?? ''}',
      owner: '${map['owner'] ?? ''}',
      likelihood: RiskLikelihood.values.firstWhere(
        (v) => v.name == map['likelihood'],
        orElse: () => RiskLikelihood.medium,
      ),
      impact: RiskImpact.values.firstWhere(
        (v) => v.name == map['impact'],
        orElse: () => RiskImpact.medium,
      ),
      reviewDate: '${map['reviewDate'] ?? ''}',
      status: RiskStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => RiskStatus.open,
      ),
      notes: '${map['notes'] ?? ''}',
    );
  }

  static String likelihoodLabel(RiskLikelihood v) => switch (v) {
    RiskLikelihood.low => 'Low',
    RiskLikelihood.medium => 'Medium',
    RiskLikelihood.high => 'High',
  };

  static String impactLabel(RiskImpact v) => switch (v) {
    RiskImpact.low => 'Low',
    RiskImpact.medium => 'Medium',
    RiskImpact.high => 'High',
  };

  static String statusLabel(RiskStatus status) => switch (status) {
    RiskStatus.open => 'Open',
    RiskStatus.monitoring => 'Monitoring',
    RiskStatus.closed => 'Closed',
  };
}

class InstitutionPartner {
  const InstitutionPartner({
    required this.id,
    required this.name,
    this.kind = PartnerKind.mou,
    this.contact = '',
    this.agreementRef = '',
    this.status = PartnerStatus.active,
    this.notes = '',
  });

  final String id;
  final String name;
  final PartnerKind kind;
  final String contact;
  final String agreementRef;
  final PartnerStatus status;
  final String notes;

  InstitutionPartner copyWith({
    String? name,
    PartnerKind? kind,
    String? contact,
    String? agreementRef,
    PartnerStatus? status,
    String? notes,
  }) {
    return InstitutionPartner(
      id: id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      contact: contact ?? this.contact,
      agreementRef: agreementRef ?? this.agreementRef,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'contact': contact,
    'agreementRef': agreementRef,
    'status': status.name,
    'notes': notes,
  };

  static InstitutionPartner fromMap(Map<String, dynamic> map) {
    return InstitutionPartner(
      id: '${map['id'] ?? ''}',
      name: '${map['name'] ?? ''}',
      kind: PartnerKind.values.firstWhere(
        (v) => v.name == map['kind'],
        orElse: () => PartnerKind.mou,
      ),
      contact: '${map['contact'] ?? ''}',
      agreementRef: '${map['agreementRef'] ?? ''}',
      status: PartnerStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => PartnerStatus.active,
      ),
      notes: '${map['notes'] ?? ''}',
    );
  }

  static String kindLabel(PartnerKind kind) => switch (kind) {
    PartnerKind.ministry => 'Ministry / regulator',
    PartnerKind.accreditor => 'Accreditor',
    PartnerKind.sisterSchool => 'Sister school',
    PartnerKind.mou => 'MOU / affiliation',
    PartnerKind.other => 'Other',
  };

  static String statusLabel(PartnerStatus status) => switch (status) {
    PartnerStatus.active => 'Active',
    PartnerStatus.ended => 'Ended',
  };
}

class InstitutionSefEntry {
  const InstitutionSefEntry({
    required this.id,
    required this.cycle,
    required this.area,
    this.judgment = SefJudgment.developing,
    this.evidence = '',
    this.owner = '',
    this.status = SefStatus.draft,
  });

  final String id;
  final String cycle;
  final String area;
  final SefJudgment judgment;
  final String evidence;
  final String owner;
  final SefStatus status;

  InstitutionSefEntry copyWith({
    String? cycle,
    String? area,
    SefJudgment? judgment,
    String? evidence,
    String? owner,
    SefStatus? status,
  }) {
    return InstitutionSefEntry(
      id: id,
      cycle: cycle ?? this.cycle,
      area: area ?? this.area,
      judgment: judgment ?? this.judgment,
      evidence: evidence ?? this.evidence,
      owner: owner ?? this.owner,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'cycle': cycle,
    'area': area,
    'judgment': judgment.name,
    'evidence': evidence,
    'owner': owner,
    'status': status.name,
  };

  static InstitutionSefEntry fromMap(Map<String, dynamic> map) {
    return InstitutionSefEntry(
      id: '${map['id'] ?? ''}',
      cycle: '${map['cycle'] ?? ''}',
      area: '${map['area'] ?? ''}',
      judgment: SefJudgment.values.firstWhere(
        (v) => v.name == map['judgment'],
        orElse: () => SefJudgment.developing,
      ),
      evidence: '${map['evidence'] ?? ''}',
      owner: '${map['owner'] ?? ''}',
      status: SefStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => SefStatus.draft,
      ),
    );
  }

  static String judgmentLabel(SefJudgment v) => switch (v) {
    SefJudgment.emerging => 'Emerging',
    SefJudgment.developing => 'Developing',
    SefJudgment.good => 'Good',
    SefJudgment.outstanding => 'Outstanding',
  };

  static String statusLabel(SefStatus status) => switch (status) {
    SefStatus.draft => 'Draft',
    SefStatus.inReview => 'In review',
    SefStatus.published => 'Published',
  };
}

class InstitutionCapa {
  const InstitutionCapa({
    required this.id,
    required this.number,
    required this.title,
    this.source = CapaSource.other,
    this.sefId = '',
    this.riskId = '',
    this.owner = '',
    this.dueDate = '',
    this.status = CapaStatus.open,
    this.notes = '',
  });

  final String id;
  final String number;
  final String title;
  final CapaSource source;
  final String sefId;
  final String riskId;
  final String owner;
  final String dueDate;
  final CapaStatus status;
  final String notes;

  bool get isOpen =>
      status == CapaStatus.open || status == CapaStatus.inProgress;

  bool get isOverdue {
    if (!isOpen) return false;
    final due = DateTime.tryParse(dueDate);
    if (due == null) return false;
    final now = DateTime.now();
    return due.isBefore(DateTime(now.year, now.month, now.day));
  }

  InstitutionCapa copyWith({
    String? number,
    String? title,
    CapaSource? source,
    String? sefId,
    String? riskId,
    String? owner,
    String? dueDate,
    CapaStatus? status,
    String? notes,
  }) {
    return InstitutionCapa(
      id: id,
      number: number ?? this.number,
      title: title ?? this.title,
      source: source ?? this.source,
      sefId: sefId ?? this.sefId,
      riskId: riskId ?? this.riskId,
      owner: owner ?? this.owner,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'number': number,
    'title': title,
    'source': source.name,
    'sefId': sefId,
    'riskId': riskId,
    'owner': owner,
    'dueDate': dueDate,
    'status': status.name,
    'notes': notes,
  };

  static InstitutionCapa fromMap(Map<String, dynamic> map) {
    return InstitutionCapa(
      id: '${map['id'] ?? ''}',
      number: '${map['number'] ?? ''}',
      title: '${map['title'] ?? ''}',
      source: CapaSource.values.firstWhere(
        (v) => v.name == map['source'],
        orElse: () => CapaSource.other,
      ),
      sefId: '${map['sefId'] ?? ''}',
      riskId: '${map['riskId'] ?? ''}',
      owner: '${map['owner'] ?? ''}',
      dueDate: '${map['dueDate'] ?? ''}',
      status: CapaStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => CapaStatus.open,
      ),
      notes: '${map['notes'] ?? ''}',
    );
  }

  static String sourceLabel(CapaSource source) => switch (source) {
    CapaSource.sef => 'SEF',
    CapaSource.risk => 'Risk register',
    CapaSource.license => 'Licence / accreditation',
    CapaSource.resolution => 'Resolution',
    CapaSource.other => 'Other',
  };

  static String statusLabel(CapaStatus status) => switch (status) {
    CapaStatus.open => 'Open',
    CapaStatus.inProgress => 'In progress',
    CapaStatus.done => 'Done',
    CapaStatus.vacated => 'Vacated',
  };
}

class InstitutionKpi {
  const InstitutionKpi({
    required this.id,
    required this.name,
    this.theme = KpiTheme.governance,
    this.target = '',
    this.actual = '',
    this.period = '',
    this.status = KpiStatus.onTrack,
    this.notes = '',
  });

  final String id;
  final String name;
  final KpiTheme theme;
  final String target;
  final String actual;
  final String period;
  final KpiStatus status;
  final String notes;

  InstitutionKpi copyWith({
    String? name,
    KpiTheme? theme,
    String? target,
    String? actual,
    String? period,
    KpiStatus? status,
    String? notes,
  }) {
    return InstitutionKpi(
      id: id,
      name: name ?? this.name,
      theme: theme ?? this.theme,
      target: target ?? this.target,
      actual: actual ?? this.actual,
      period: period ?? this.period,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'theme': theme.name,
    'target': target,
    'actual': actual,
    'period': period,
    'status': status.name,
    'notes': notes,
  };

  static InstitutionKpi fromMap(Map<String, dynamic> map) {
    return InstitutionKpi(
      id: '${map['id'] ?? ''}',
      name: '${map['name'] ?? ''}',
      theme: KpiTheme.values.firstWhere(
        (v) => v.name == map['theme'],
        orElse: () => KpiTheme.governance,
      ),
      target: '${map['target'] ?? ''}',
      actual: '${map['actual'] ?? ''}',
      period: '${map['period'] ?? ''}',
      status: KpiStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => KpiStatus.onTrack,
      ),
      notes: '${map['notes'] ?? ''}',
    );
  }

  static String themeLabel(KpiTheme theme) => switch (theme) {
    KpiTheme.governance => 'Governance',
    KpiTheme.compliance => 'Compliance',
    KpiTheme.safeguarding => 'Safeguarding',
    KpiTheme.community => 'Community',
    KpiTheme.estate => 'Estate',
    KpiTheme.other => 'Other',
  };

  static String statusLabel(KpiStatus status) => switch (status) {
    KpiStatus.onTrack => 'On track',
    KpiStatus.atRisk => 'At risk',
    KpiStatus.offTrack => 'Off track',
  };
}

class InstitutionProperty {
  const InstitutionProperty({
    required this.id,
    required this.name,
    this.kind = PropertyKind.building,
    this.campusScope = 'Institution-wide',
    this.status = PropertyStatus.inUse,
    this.acquiredOn = '',
    this.notes = '',
  });

  final String id;
  final String name;
  final PropertyKind kind;
  final String campusScope;
  final PropertyStatus status;
  final String acquiredOn;
  final String notes;

  InstitutionProperty copyWith({
    String? name,
    PropertyKind? kind,
    String? campusScope,
    PropertyStatus? status,
    String? acquiredOn,
    String? notes,
  }) {
    return InstitutionProperty(
      id: id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      campusScope: campusScope ?? this.campusScope,
      status: status ?? this.status,
      acquiredOn: acquiredOn ?? this.acquiredOn,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'campusScope': campusScope,
    'status': status.name,
    'acquiredOn': acquiredOn,
    'notes': notes,
  };

  static InstitutionProperty fromMap(Map<String, dynamic> map) {
    return InstitutionProperty(
      id: '${map['id'] ?? ''}',
      name: '${map['name'] ?? ''}',
      kind: PropertyKind.values.firstWhere(
        (v) => v.name == map['kind'],
        orElse: () => PropertyKind.building,
      ),
      campusScope: '${map['campusScope'] ?? 'Institution-wide'}',
      status: PropertyStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => PropertyStatus.inUse,
      ),
      acquiredOn: '${map['acquiredOn'] ?? ''}',
      notes: '${map['notes'] ?? ''}',
    );
  }

  static String kindLabel(PropertyKind kind) => switch (kind) {
    PropertyKind.land => 'Land',
    PropertyKind.building => 'Building',
    PropertyKind.facility => 'Facility',
    PropertyKind.other => 'Other',
  };

  static String statusLabel(PropertyStatus status) => switch (status) {
    PropertyStatus.inUse => 'In use',
    PropertyStatus.planned => 'Planned',
    PropertyStatus.leased => 'Leased',
    PropertyStatus.disposed => 'Disposed',
  };
}

class InstitutionArchiveItem {
  const InstitutionArchiveItem({
    required this.id,
    required this.title,
    this.series = ArchiveSeries.other,
    this.retentionUntil = '',
    this.location = '',
    this.status = ArchiveStatus.current,
    this.notes = '',
  });

  final String id;
  final String title;
  final ArchiveSeries series;
  final String retentionUntil;
  final String location;
  final ArchiveStatus status;
  final String notes;

  bool get retentionLapsed {
    if (status == ArchiveStatus.destroyed) return false;
    final due = DateTime.tryParse(retentionUntil);
    if (due == null) return false;
    final now = DateTime.now();
    return !due.isAfter(DateTime(now.year, now.month, now.day));
  }

  InstitutionArchiveItem copyWith({
    String? title,
    ArchiveSeries? series,
    String? retentionUntil,
    String? location,
    ArchiveStatus? status,
    String? notes,
  }) {
    return InstitutionArchiveItem(
      id: id,
      title: title ?? this.title,
      series: series ?? this.series,
      retentionUntil: retentionUntil ?? this.retentionUntil,
      location: location ?? this.location,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'series': series.name,
    'retentionUntil': retentionUntil,
    'location': location,
    'status': status.name,
    'notes': notes,
  };

  static InstitutionArchiveItem fromMap(Map<String, dynamic> map) {
    return InstitutionArchiveItem(
      id: '${map['id'] ?? ''}',
      title: '${map['title'] ?? ''}',
      series: ArchiveSeries.values.firstWhere(
        (v) => v.name == map['series'],
        orElse: () => ArchiveSeries.other,
      ),
      retentionUntil: '${map['retentionUntil'] ?? ''}',
      location: '${map['location'] ?? ''}',
      status: ArchiveStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => ArchiveStatus.current,
      ),
      notes: '${map['notes'] ?? ''}',
    );
  }

  static String seriesLabel(ArchiveSeries series) => switch (series) {
    ArchiveSeries.policies => 'Policies',
    ArchiveSeries.minutes => 'Minutes / resolutions',
    ArchiveSeries.licenses => 'Licences',
    ArchiveSeries.sef => 'SEF / self-evaluation',
    ArchiveSeries.other => 'Other',
  };

  static String statusLabel(ArchiveStatus status) => switch (status) {
    ArchiveStatus.current => 'Current',
    ArchiveStatus.archived => 'Archived',
    ArchiveStatus.destroyed => 'Destroyed / disposed',
  };
}

class InstitutionRecord {
  const InstitutionRecord({
    required this.schoolId,
    required this.profile,
    this.leadership = const [],
    this.orgUnits = const [],
    this.sites = const [],
    this.policies = const [],
    this.circulars = const [],
    this.licenses = const [],
    this.resolutions = const [],
    this.committees = const [],
    this.meetings = const [],
    this.risks = const [],
    this.partners = const [],
    this.sefEntries = const [],
    this.capas = const [],
    this.kpis = const [],
    this.properties = const [],
    this.archive = const [],
    required this.updatedAt,
  });

  final String schoolId;
  final InstitutionProfile profile;
  final List<LeadershipSeat> leadership;
  final List<OrgUnit> orgUnits;
  final List<InstitutionSite> sites;
  final List<InstitutionPolicy> policies;
  final List<OfficialCircular> circulars;
  final List<InstitutionLicense> licenses;
  final List<InstitutionResolution> resolutions;
  final List<InstitutionCommittee> committees;
  final List<InstitutionMeeting> meetings;
  final List<InstitutionRisk> risks;
  final List<InstitutionPartner> partners;
  final List<InstitutionSefEntry> sefEntries;
  final List<InstitutionCapa> capas;
  final List<InstitutionKpi> kpis;
  final List<InstitutionProperty> properties;
  final List<InstitutionArchiveItem> archive;
  final DateTime updatedAt;

  String get id => schoolId;

  String meetingTitleFor(String meetingId) {
    if (meetingId.isEmpty) return '';
    for (final meeting in meetings) {
      if (meeting.id == meetingId) return meeting.title;
    }
    return '';
  }

  String committeeNameFor(String committeeId) {
    if (committeeId.isEmpty) return '';
    for (final committee in committees) {
      if (committee.id == committeeId) return committee.name;
    }
    return '';
  }

  String sefTitleFor(String sefId) {
    if (sefId.isEmpty) return '';
    for (final row in sefEntries) {
      if (row.id == sefId) return '${row.cycle} · ${row.area}';
    }
    return '';
  }

  String riskTitleFor(String riskId) {
    if (riskId.isEmpty) return '';
    for (final row in risks) {
      if (row.id == riskId) return row.title;
    }
    return '';
  }

  InstitutionRecord copyWith({
    InstitutionProfile? profile,
    List<LeadershipSeat>? leadership,
    List<OrgUnit>? orgUnits,
    List<InstitutionSite>? sites,
    List<InstitutionPolicy>? policies,
    List<OfficialCircular>? circulars,
    List<InstitutionLicense>? licenses,
    List<InstitutionResolution>? resolutions,
    List<InstitutionCommittee>? committees,
    List<InstitutionMeeting>? meetings,
    List<InstitutionRisk>? risks,
    List<InstitutionPartner>? partners,
    List<InstitutionSefEntry>? sefEntries,
    List<InstitutionCapa>? capas,
    List<InstitutionKpi>? kpis,
    List<InstitutionProperty>? properties,
    List<InstitutionArchiveItem>? archive,
    DateTime? updatedAt,
  }) {
    return InstitutionRecord(
      schoolId: schoolId,
      profile: profile ?? this.profile,
      leadership: leadership ?? this.leadership,
      orgUnits: orgUnits ?? this.orgUnits,
      sites: sites ?? this.sites,
      policies: policies ?? this.policies,
      circulars: circulars ?? this.circulars,
      licenses: licenses ?? this.licenses,
      resolutions: resolutions ?? this.resolutions,
      committees: committees ?? this.committees,
      meetings: meetings ?? this.meetings,
      risks: risks ?? this.risks,
      partners: partners ?? this.partners,
      sefEntries: sefEntries ?? this.sefEntries,
      capas: capas ?? this.capas,
      kpis: kpis ?? this.kpis,
      properties: properties ?? this.properties,
      archive: archive ?? this.archive,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': schoolId,
    'schoolId': schoolId,
    'profile': profile.toMap(),
    'leadership': leadership.map((e) => e.toMap()).toList(),
    'orgUnits': orgUnits.map((e) => e.toMap()).toList(),
    'sites': sites.map((e) => e.toMap()).toList(),
    'policies': policies.map((e) => e.toMap()).toList(),
    'circulars': circulars.map((e) => e.toMap()).toList(),
    'licenses': licenses.map((e) => e.toMap()).toList(),
    'resolutions': resolutions.map((e) => e.toMap()).toList(),
    'committees': committees.map((e) => e.toMap()).toList(),
    'meetings': meetings.map((e) => e.toMap()).toList(),
    'risks': risks.map((e) => e.toMap()).toList(),
    'partners': partners.map((e) => e.toMap()).toList(),
    'sefEntries': sefEntries.map((e) => e.toMap()).toList(),
    'capas': capas.map((e) => e.toMap()).toList(),
    'kpis': kpis.map((e) => e.toMap()).toList(),
    'properties': properties.map((e) => e.toMap()).toList(),
    'archive': archive.map((e) => e.toMap()).toList(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static InstitutionRecord fromMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>> list(Object? raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    DateTime parseDate(Object? v) =>
        DateTime.tryParse('${v ?? ''}') ?? DateTime.now();

    final schoolId = '${map['schoolId'] ?? map['id'] ?? ''}'
        .trim()
        .toUpperCase();
    return InstitutionRecord(
      schoolId: schoolId,
      profile: InstitutionProfile.fromMap(
        map['profile'] is Map
            ? Map<String, dynamic>.from(map['profile'] as Map)
            : null,
      ),
      leadership: list(map['leadership']).map(LeadershipSeat.fromMap).toList(),
      orgUnits: list(map['orgUnits']).map(OrgUnit.fromMap).toList(),
      sites: list(map['sites']).map(InstitutionSite.fromMap).toList(),
      policies: list(map['policies']).map(InstitutionPolicy.fromMap).toList(),
      circulars: list(map['circulars']).map(OfficialCircular.fromMap).toList(),
      licenses: list(map['licenses']).map(InstitutionLicense.fromMap).toList(),
      resolutions: list(
        map['resolutions'],
      ).map(InstitutionResolution.fromMap).toList(),
      committees: list(
        map['committees'],
      ).map(InstitutionCommittee.fromMap).toList(),
      meetings: list(map['meetings']).map(InstitutionMeeting.fromMap).toList(),
      risks: list(map['risks']).map(InstitutionRisk.fromMap).toList(),
      partners: list(map['partners']).map(InstitutionPartner.fromMap).toList(),
      sefEntries: list(
        map['sefEntries'],
      ).map(InstitutionSefEntry.fromMap).toList(),
      capas: list(map['capas']).map(InstitutionCapa.fromMap).toList(),
      kpis: list(map['kpis']).map(InstitutionKpi.fromMap).toList(),
      properties: list(
        map['properties'],
      ).map(InstitutionProperty.fromMap).toList(),
      archive: list(
        map['archive'],
      ).map(InstitutionArchiveItem.fromMap).toList(),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}
