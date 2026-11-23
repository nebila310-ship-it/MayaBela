enum ConferenceSlotStatus { open, booked, completed, cancelled }

/// Homeroom parent–teacher sitting: a window of bookable slots.
class ConferenceWindow {
  const ConferenceWindow({
    required this.id,
    required this.schoolId,
    required this.className,
    required this.teacherId,
    required this.teacherName,
    required this.title,
    required this.heldOn,
    this.venue = '',
    this.slotMinutes = 15,
    this.slots = const [],
  });

  final String id;
  final String schoolId;
  final String className;
  final String teacherId;
  final String teacherName;
  final String title;
  final String heldOn;
  final String venue;
  final int slotMinutes;
  final List<ConferenceSlot> slots;

  int get openCount =>
      slots.where((s) => s.status == ConferenceSlotStatus.open).length;

  int get bookedCount =>
      slots.where((s) => s.status == ConferenceSlotStatus.booked).length;

  ConferenceWindow copyWith({List<ConferenceSlot>? slots}) {
    return ConferenceWindow(
      id: id,
      schoolId: schoolId,
      className: className,
      teacherId: teacherId,
      teacherName: teacherName,
      title: title,
      heldOn: heldOn,
      venue: venue,
      slotMinutes: slotMinutes,
      slots: slots ?? this.slots,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'schoolId': schoolId,
    'className': className,
    'teacherId': teacherId,
    'teacherName': teacherName,
    'title': title,
    'heldOn': heldOn,
    'venue': venue,
    'slotMinutes': slotMinutes,
    'slots': slots.map((s) => s.toMap()).toList(),
  };

  static ConferenceWindow fromMap(Map<String, dynamic> map) {
    return ConferenceWindow(
      id: '${map['id'] ?? ''}',
      schoolId: '${map['schoolId'] ?? ''}'.trim().toUpperCase(),
      className: '${map['className'] ?? ''}',
      teacherId: '${map['teacherId'] ?? ''}',
      teacherName: '${map['teacherName'] ?? ''}',
      title: '${map['title'] ?? 'Parent–teacher conference'}',
      heldOn: '${map['heldOn'] ?? ''}',
      venue: '${map['venue'] ?? ''}',
      slotMinutes: (map['slotMinutes'] as num?)?.toInt() ?? 15,
      slots: (map['slots'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => ConferenceSlot.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class ConferenceSlot {
  const ConferenceSlot({
    required this.id,
    required this.startsAt,
    this.studentId = '',
    this.studentName = '',
    this.parentName = '',
    this.status = ConferenceSlotStatus.open,
    this.teacherNotes = '',
    this.homeActions = '',
    this.packSummary = '',
  });

  final String id;
  final String startsAt;
  final String studentId;
  final String studentName;
  final String parentName;
  final ConferenceSlotStatus status;
  final String teacherNotes;
  final String homeActions;
  final String packSummary;

  ConferenceSlot copyWith({
    String? studentId,
    String? studentName,
    String? parentName,
    ConferenceSlotStatus? status,
    String? teacherNotes,
    String? homeActions,
    String? packSummary,
  }) {
    return ConferenceSlot(
      id: id,
      startsAt: startsAt,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      parentName: parentName ?? this.parentName,
      status: status ?? this.status,
      teacherNotes: teacherNotes ?? this.teacherNotes,
      homeActions: homeActions ?? this.homeActions,
      packSummary: packSummary ?? this.packSummary,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'startsAt': startsAt,
    if (studentId.isNotEmpty) 'studentId': studentId,
    if (studentName.isNotEmpty) 'studentName': studentName,
    if (parentName.isNotEmpty) 'parentName': parentName,
    'status': status.name,
    if (teacherNotes.isNotEmpty) 'teacherNotes': teacherNotes,
    if (homeActions.isNotEmpty) 'homeActions': homeActions,
    if (packSummary.isNotEmpty) 'packSummary': packSummary,
  };

  static ConferenceSlot fromMap(Map<String, dynamic> map) {
    return ConferenceSlot(
      id: '${map['id'] ?? ''}',
      startsAt: '${map['startsAt'] ?? ''}',
      studentId: '${map['studentId'] ?? ''}',
      studentName: '${map['studentName'] ?? ''}',
      parentName: '${map['parentName'] ?? ''}',
      status: ConferenceSlotStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => ConferenceSlotStatus.open,
      ),
      teacherNotes: '${map['teacherNotes'] ?? ''}',
      homeActions: '${map['homeActions'] ?? ''}',
      packSummary: '${map['packSummary'] ?? ''}',
    );
  }

  static String statusLabel(ConferenceSlotStatus status) => switch (status) {
    ConferenceSlotStatus.open => 'Open',
    ConferenceSlotStatus.booked => 'Booked',
    ConferenceSlotStatus.completed => 'Completed',
    ConferenceSlotStatus.cancelled => 'Cancelled',
  };
}
