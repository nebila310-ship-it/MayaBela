// LIA Phase H — DoSA programs: clubs/Gojo, scholarships, grievances,
// internships, leadership meetings. Not a grade store and not Phase G care.

enum ClubKind { club, gojo, sport, arts, other }

enum MembershipStatus { pending, active, withdrawn }

enum ScholarshipStatus { draft, applied, eligible, awarded, declined }

enum GrievanceStatus { open, reviewing, resolved, dismissed }

enum InternshipStatus { planned, active, completed }

enum DosaMeetingKind { leadership, graduation, event }

class ExtracurricularClub {
  ExtracurricularClub({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.kind = ClubKind.club,
    this.description = '',
    this.advisorName = '',
    this.meetingDay = '',
    this.published = true,
    this.calendarEventId,
    this.createdBy,
  });

  final String id;
  final String schoolId;
  String name;
  ClubKind kind;
  String description;
  String advisorName;
  String meetingDay;
  bool published;
  String? calendarEventId;
  String? createdBy;
  final DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'name': name,
        'kind': kind.name,
        'description': description,
        'advisorName': advisorName,
        'meetingDay': meetingDay,
        'published': published,
        if (calendarEventId != null) 'calendarEventId': calendarEventId,
        if (createdBy != null) 'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ExtracurricularClub.fromMap(Map<String, dynamic> map) {
    return ExtracurricularClub(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      name: map['name'] as String? ?? '',
      kind: ClubKind.values.firstWhere(
        (v) => v.name == map['kind'],
        orElse: () => ClubKind.club,
      ),
      description: map['description'] as String? ?? '',
      advisorName: map['advisorName'] as String? ?? '',
      meetingDay: map['meetingDay'] as String? ?? '',
      published: map['published'] as bool? ?? true,
      calendarEventId: map['calendarEventId'] as String?,
      createdBy: map['createdBy'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class ClubMembership {
  ClubMembership({
    required this.id,
    required this.schoolId,
    required this.clubId,
    required this.studentId,
    required this.studentName,
    required this.createdAt,
    required this.updatedAt,
    this.className,
    this.role = 'member',
    this.status = MembershipStatus.pending,
    this.gojoHours = 0,
    this.createdBy,
  });

  final String id;
  final String schoolId;
  final String clubId;
  final String studentId;
  String studentName;
  String? className;
  String role;
  MembershipStatus status;
  int gojoHours;
  String? createdBy;
  final DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'clubId': clubId,
        'studentId': studentId,
        'studentName': studentName,
        if (className != null) 'className': className,
        'role': role,
        'status': status.name,
        'gojoHours': gojoHours,
        if (createdBy != null) 'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ClubMembership.fromMap(Map<String, dynamic> map) {
    return ClubMembership(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      clubId: map['clubId'] as String? ?? '',
      studentId: (map['studentId'] as String? ?? '').trim().toUpperCase(),
      studentName: map['studentName'] as String? ?? '',
      className: map['className'] as String?,
      role: map['role'] as String? ?? 'member',
      status: MembershipStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => MembershipStatus.pending,
      ),
      gojoHours: (map['gojoHours'] as num?)?.toInt() ?? 0,
      createdBy: map['createdBy'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class ScholarshipRecord {
  ScholarshipRecord({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.createdAt,
    required this.updatedAt,
    this.className,
    this.title = '',
    this.minAverage = 80,
    this.snapshotAverage,
    this.status = ScholarshipStatus.applied,
    this.note = '',
    this.createdBy,
  });

  final String id;
  final String schoolId;
  final String studentId;
  String studentName;
  String? className;
  String title;
  double minAverage;
  double? snapshotAverage;
  ScholarshipStatus status;
  String note;
  String? createdBy;
  final DateTime createdAt;
  DateTime updatedAt;

  bool get meetsThreshold =>
      snapshotAverage != null && snapshotAverage! >= minAverage;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'studentId': studentId,
        'studentName': studentName,
        if (className != null) 'className': className,
        'title': title,
        'minAverage': minAverage,
        if (snapshotAverage != null) 'snapshotAverage': snapshotAverage,
        'status': status.name,
        'note': note,
        if (createdBy != null) 'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ScholarshipRecord.fromMap(Map<String, dynamic> map) {
    return ScholarshipRecord(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      studentId: (map['studentId'] as String? ?? '').trim().toUpperCase(),
      studentName: map['studentName'] as String? ?? '',
      className: map['className'] as String?,
      title: map['title'] as String? ?? '',
      minAverage: (map['minAverage'] as num?)?.toDouble() ?? 80,
      snapshotAverage: (map['snapshotAverage'] as num?)?.toDouble(),
      status: ScholarshipStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => ScholarshipStatus.applied,
      ),
      note: map['note'] as String? ?? '',
      createdBy: map['createdBy'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class Grievance {
  Grievance({
    required this.id,
    required this.schoolId,
    required this.authorUsername,
    required this.createdAt,
    required this.updatedAt,
    this.studentId = '',
    this.studentName = '',
    this.className,
    this.title = '',
    this.details = '',
    this.status = GrievanceStatus.open,
    this.resolution = '',
    this.authorRole,
  });

  final String id;
  final String schoolId;
  String studentId;
  String studentName;
  String? className;
  String title;
  String details;
  GrievanceStatus status;
  String resolution;
  final String authorUsername;
  String? authorRole;
  final DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'studentId': studentId,
        'studentName': studentName,
        if (className != null) 'className': className,
        'title': title,
        'details': details,
        'status': status.name,
        'resolution': resolution,
        'authorUsername': authorUsername,
        if (authorRole != null) 'authorRole': authorRole,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Grievance.fromMap(Map<String, dynamic> map) {
    return Grievance(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      studentId: (map['studentId'] as String? ?? '').trim().toUpperCase(),
      studentName: map['studentName'] as String? ?? '',
      className: map['className'] as String?,
      title: map['title'] as String? ?? '',
      details: map['details'] as String? ?? '',
      status: GrievanceStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => GrievanceStatus.open,
      ),
      resolution: map['resolution'] as String? ?? '',
      authorUsername: map['authorUsername'] as String? ?? '',
      authorRole: map['authorRole'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class Internship {
  Internship({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.createdAt,
    required this.updatedAt,
    this.className,
    this.host = '',
    this.role = '',
    this.notes = '',
    this.status = InternshipStatus.planned,
    this.startsAt,
    this.endsAt,
    this.createdBy,
  });

  final String id;
  final String schoolId;
  final String studentId;
  String studentName;
  String? className;
  String host;
  String role;
  String notes;
  InternshipStatus status;
  DateTime? startsAt;
  DateTime? endsAt;
  String? createdBy;
  final DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'studentId': studentId,
        'studentName': studentName,
        if (className != null) 'className': className,
        'host': host,
        'role': role,
        'notes': notes,
        'status': status.name,
        if (startsAt != null) 'startsAt': startsAt!.toIso8601String(),
        if (endsAt != null) 'endsAt': endsAt!.toIso8601String(),
        if (createdBy != null) 'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Internship.fromMap(Map<String, dynamic> map) {
    return Internship(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      studentId: (map['studentId'] as String? ?? '').trim().toUpperCase(),
      studentName: map['studentName'] as String? ?? '',
      className: map['className'] as String?,
      host: map['host'] as String? ?? '',
      role: map['role'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      status: InternshipStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => InternshipStatus.planned,
      ),
      startsAt: map['startsAt'] != null
          ? DateTime.tryParse(map['startsAt'] as String)
          : null,
      endsAt: map['endsAt'] != null
          ? DateTime.tryParse(map['endsAt'] as String)
          : null,
      createdBy: map['createdBy'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class DosaTask {
  DosaTask({
    required this.id,
    required this.title,
    this.assignee = '',
    this.done = false,
  });

  final String id;
  String title;
  String assignee;
  bool done;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'assignee': assignee,
        'done': done,
      };

  factory DosaTask.fromMap(Map<String, dynamic> map) {
    return DosaTask(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      assignee: map['assignee'] as String? ?? '',
      done: map['done'] as bool? ?? false,
    );
  }
}

class DosaEngagementSnapshot {
  const DosaEngagementSnapshot({
    required this.publishedClubs,
    required this.activeMembers,
    required this.pendingMembers,
    required this.gojoHours,
    required this.pendingScholarships,
    required this.awardedScholarships,
    required this.openGrievances,
    required this.internships,
    required this.upcomingMeetings,
  });

  final int publishedClubs;
  final int activeMembers;
  final int pendingMembers;
  final int gojoHours;
  final int pendingScholarships;
  final int awardedScholarships;
  final int openGrievances;
  final int internships;
  final int upcomingMeetings;
}

class DosaMeeting {
  DosaMeeting({
    required this.id,
    required this.schoolId,
    required this.title,
    required this.startsAt,
    required this.createdAt,
    required this.updatedAt,
    this.kind = DosaMeetingKind.leadership,
    this.agenda = '',
    this.notes = '',
    this.calendarEventId,
    this.tasks = const [],
    this.createdBy,
  });

  final String id;
  final String schoolId;
  DosaMeetingKind kind;
  String title;
  String agenda;
  String notes;
  DateTime startsAt;
  String? calendarEventId;
  List<DosaTask> tasks;
  String? createdBy;
  final DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'kind': kind.name,
        'title': title,
        'agenda': agenda,
        'notes': notes,
        'startsAt': startsAt.toIso8601String(),
        if (calendarEventId != null) 'calendarEventId': calendarEventId,
        'tasks': tasks.map((t) => t.toMap()).toList(),
        if (createdBy != null) 'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory DosaMeeting.fromMap(Map<String, dynamic> map) {
    final rawTasks = map['tasks'];
    return DosaMeeting(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      kind: DosaMeetingKind.values.firstWhere(
        (v) => v.name == map['kind'],
        orElse: () => DosaMeetingKind.leadership,
      ),
      title: map['title'] as String? ?? '',
      agenda: map['agenda'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      startsAt:
          DateTime.tryParse(map['startsAt'] as String? ?? '') ?? DateTime.now(),
      calendarEventId: map['calendarEventId'] as String?,
      tasks: rawTasks is List
          ? rawTasks
              .whereType<Map>()
              .map((row) => DosaTask.fromMap(Map<String, dynamic>.from(row)))
              .toList()
          : const [],
      createdBy: map['createdBy'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
