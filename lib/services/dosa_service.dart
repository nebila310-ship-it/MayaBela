import 'package:flutter/foundation.dart';

import 'package:mayabela/models/calendar_event.dart';
import 'package:mayabela/models/dosa_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/persistence/dosa_persistence_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/utils/short_registry_id.dart';

/// Phase H DoSA desk. Clubs/Gojo, scholarships, grievances, internships,
/// and leadership meetings. Reads Phase B averages; never writes grades.
class DosaService extends ChangeNotifier {
  DosaService._();
  static final instance = DosaService._();

  final List<ExtracurricularClub> _clubs = [];
  final List<ClubMembership> _memberships = [];
  final List<ScholarshipRecord> _scholarships = [];
  final List<Grievance> _grievances = [];
  final List<Internship> _internships = [];
  final List<DosaMeeting> _meetings = [];
  bool _loaded = false;

  @visibleForTesting
  static void resetForTests() {
    instance._clubs.clear();
    instance._memberships.clear();
    instance._scholarships.clear();
    instance._grievances.clear();
    instance._internships.clear();
    instance._meetings.clear();
    instance._loaded = true;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    await DosaPersistenceService.instance.loadIntoService();
  }

  String get _schoolId =>
      (AuthService.activeSchoolId ?? AuthService.currentUser?.schoolId ?? '')
          .trim()
          .toUpperCase();

  String get _username => AuthService.currentUser?.username ?? '';

  bool get _isStudent =>
      AuthService.currentUser?.roleKey == AuthService.roleStudent;
  bool get _isParent =>
      AuthService.currentUser?.roleKey == AuthService.roleParent;
  bool get _isPublicReader => _isStudent || _isParent;

  bool get canManageDesk => ModuleAccess.canManage('student_affairs');
  bool get canViewDesk => ModuleAccess.canView('student_affairs');

  List<ExtracurricularClub> clubsForSchool([String? schoolId]) {
    var list = _schoolFilter(_clubs, schoolId);
    if (_isPublicReader) {
      list = list.where((row) => row.published).toList();
    }
    return list..sort((a, b) => a.name.compareTo(b.name));
  }

  List<ClubMembership> membershipsForSchool([String? schoolId]) {
    var list = _schoolFilter(_memberships, schoolId);
    if (_isPublicReader) {
      list = list.where((row) => _ownsStudent(row.studentId)).toList();
    }
    return list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<ScholarshipRecord> scholarshipsForSchool([String? schoolId]) {
    var list = _schoolFilter(_scholarships, schoolId);
    if (_isPublicReader) {
      list = list.where((row) => _ownsStudent(row.studentId)).toList();
    }
    return list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<Grievance> grievancesForSchool([String? schoolId]) {
    var list = _schoolFilter(_grievances, schoolId);
    if (_isPublicReader) {
      final uname = _username.trim().toLowerCase();
      list = list
          .where(
            (row) =>
                _ownsStudent(row.studentId) ||
                (uname.isNotEmpty &&
                    row.authorUsername.trim().toLowerCase() == uname),
          )
          .toList();
    }
    return list..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<Internship> internshipsForSchool([String? schoolId]) {
    var list = _schoolFilter(_internships, schoolId);
    if (_isPublicReader) {
      list = list.where((row) => _ownsStudent(row.studentId)).toList();
    }
    return list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<DosaMeeting> meetingsForSchool([String? schoolId]) {
    var list = _schoolFilter(_meetings, schoolId);
    if (_isPublicReader) {
      list = list
          .where((row) => row.kind == DosaMeetingKind.graduation)
          .toList();
    }
    return list..sort((a, b) => b.startsAt.compareTo(a.startsAt));
  }

  List<ClubMembership> membershipsForClub(String clubId) =>
      membershipsForSchool().where((row) => row.clubId == clubId).toList();

  int openGrievanceCount([String? schoolId]) => grievancesForSchool(schoolId)
      .where((row) => row.status == GrievanceStatus.open)
      .length;

  int pendingScholarshipCount([String? schoolId]) =>
      scholarshipsForSchool(schoolId)
          .where(
            (row) =>
                row.status == ScholarshipStatus.applied ||
                row.status == ScholarshipStatus.eligible,
          )
          .length;

  int activeClubCount([String? schoolId]) =>
      clubsForSchool(schoolId).where((row) => row.published).length;

  int upcomingMeetingCount([String? schoolId]) {
    final now = DateTime.now();
    return meetingsForSchool(schoolId)
        .where((row) => row.startsAt.isAfter(now.subtract(const Duration(hours: 2))))
        .length;
  }

  DosaEngagementSnapshot engagementForSchool([String? schoolId]) {
    final memberships = membershipsForSchool(schoolId);
    final scholarships = scholarshipsForSchool(schoolId);
    return DosaEngagementSnapshot(
      publishedClubs: activeClubCount(schoolId),
      activeMembers: memberships
          .where((row) => row.status == MembershipStatus.active)
          .length,
      pendingMembers: memberships
          .where((row) => row.status == MembershipStatus.pending)
          .length,
      gojoHours: memberships.fold<int>(0, (sum, row) => sum + row.gojoHours),
      pendingScholarships: pendingScholarshipCount(schoolId),
      awardedScholarships: scholarships
          .where((row) => row.status == ScholarshipStatus.awarded)
          .length,
      openGrievances: openGrievanceCount(schoolId),
      internships: internshipsForSchool(schoolId).length,
      upcomingMeetings: upcomingMeetingCount(schoolId),
    );
  }

  /// Read-only Phase B average. Never writes the markbook.
  double? markbookAverageFor(String studentId) {
    final report =
        SchoolDataService.instance.getGradeReportForStudentId(studentId);
    if (report == null || report.subjects.isEmpty) return null;
    return report.average;
  }

  Future<ExtracurricularClub> createClub({
    required String name,
    ClubKind kind = ClubKind.club,
    String description = '',
    String advisorName = '',
    String meetingDay = '',
    bool published = true,
    String? schoolId,
  }) async {
    _requireStaffDesk();
    final now = DateTime.now();
    final club = ExtracurricularClub(
      id: _id('CLB', _clubs.map((row) => row.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      name: name.trim(),
      kind: kind,
      description: description.trim(),
      advisorName: advisorName.trim(),
      meetingDay: meetingDay.trim(),
      published: published,
      createdBy: _username,
      createdAt: now,
      updatedAt: now,
    );
    _clubs.add(club);
    await _persist();
    return club;
  }

  Future<ClubMembership> joinClub({
    required String clubId,
    required String studentId,
    String role = 'member',
    String? schoolId,
  }) async {
    if (!_isParent && !_isStudent && !canManageDesk) {
      throw StateError('You cannot join a club for this student.');
    }
    if (_isPublicReader && !_ownsStudent(studentId)) {
      throw StateError('You can only join a club for your linked student.');
    }
    final club = _clubs.cast<ExtracurricularClub?>().firstWhere(
          (row) => row?.id == clubId,
          orElse: () => null,
        );
    if (club == null) {
      throw StateError('Club not found.');
    }
    final existing = _memberships.cast<ClubMembership?>().firstWhere(
          (row) =>
              row?.clubId == clubId &&
              row?.studentId == studentId.trim().toUpperCase() &&
              row?.status != MembershipStatus.withdrawn,
          orElse: () => null,
        );
    if (existing != null) return existing;
    final now = DateTime.now();
    final meta = _studentMeta(studentId);
    final membership = ClubMembership(
      id: _id('MBR', _memberships.map((row) => row.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      clubId: clubId,
      studentId: studentId.trim().toUpperCase(),
      studentName: meta.name,
      className: meta.className,
      role: role.trim().isEmpty ? 'member' : role.trim(),
      status: canManageDesk ? MembershipStatus.active : MembershipStatus.pending,
      createdBy: _username,
      createdAt: now,
      updatedAt: now,
    );
    _memberships.add(membership);
    await _persist();
    return membership;
  }

  Future<ClubMembership> setMembershipStatus(
    String id,
    MembershipStatus status,
  ) async {
    _requireStaffDesk();
    final row = _memberships.cast<ClubMembership?>().firstWhere(
          (item) => item?.id == id,
          orElse: () => null,
        );
    if (row == null) {
      throw StateError('Membership not found.');
    }
    row.status = status;
    row.updatedAt = DateTime.now();
    await _persist();
    return row;
  }

  Future<ClubMembership> addGojoHours(String id, int hours) async {
    _requireStaffDesk();
    final row = _memberships.cast<ClubMembership?>().firstWhere(
          (item) => item?.id == id,
          orElse: () => null,
        );
    if (row == null) {
      throw StateError('Membership not found.');
    }
    row.gojoHours = (row.gojoHours + hours).clamp(0, 9999);
    row.updatedAt = DateTime.now();
    await _persist();
    return row;
  }

  Future<ScholarshipRecord> applyScholarship({
    required String studentId,
    String title = 'Merit scholarship',
    double minAverage = 80,
    String note = '',
    String? schoolId,
  }) async {
    if (!_isParent && !_isStudent && !canManageDesk) {
      throw StateError('You cannot apply for a scholarship.');
    }
    if (_isPublicReader && !_ownsStudent(studentId)) {
      throw StateError('You can only apply for your linked student.');
    }
    final now = DateTime.now();
    final meta = _studentMeta(studentId);
    final snapshot = markbookAverageFor(studentId);
    final record = ScholarshipRecord(
      id: _id('SCH', _scholarships.map((row) => row.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      studentId: studentId.trim().toUpperCase(),
      studentName: meta.name,
      className: meta.className,
      title: title.trim().isEmpty ? 'Merit scholarship' : title.trim(),
      minAverage: minAverage,
      snapshotAverage: snapshot,
      status: snapshot != null && snapshot >= minAverage
          ? ScholarshipStatus.eligible
          : ScholarshipStatus.applied,
      note: note.trim(),
      createdBy: _username,
      createdAt: now,
      updatedAt: now,
    );
    _scholarships.add(record);
    await _persist();
    return record;
  }

  Future<ScholarshipRecord> reviewScholarship(
    String id,
    ScholarshipStatus status, {
    String note = '',
  }) async {
    _requireStaffDesk();
    final row = _scholarships.cast<ScholarshipRecord?>().firstWhere(
          (item) => item?.id == id,
          orElse: () => null,
        );
    if (row == null) {
      throw StateError('Scholarship not found.');
    }
    row.snapshotAverage ??= markbookAverageFor(row.studentId);
    row.status = status;
    if (note.trim().isNotEmpty) row.note = note.trim();
    row.updatedAt = DateTime.now();
    await _persist();
    return row;
  }

  Future<Grievance> fileGrievance({
    required String title,
    String details = '',
    String studentId = '',
    String? schoolId,
  }) async {
    if (!_isParent && !_isStudent && !canManageDesk) {
      throw StateError('You cannot file a grievance.');
    }
    if (_isPublicReader &&
        studentId.trim().isNotEmpty &&
        !_ownsStudent(studentId)) {
      throw StateError('You can only file a grievance for your linked student.');
    }
    final now = DateTime.now();
    final sid = studentId.trim().toUpperCase();
    final meta = sid.isEmpty
        ? (name: AuthService.currentUser?.fullName ?? _username, className: null)
        : _studentMeta(sid);
    final row = Grievance(
      id: _id('GRV', _grievances.map((item) => item.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      studentId: sid,
      studentName: meta.name,
      className: meta.className,
      title: title.trim(),
      details: details.trim(),
      authorUsername: _username,
      authorRole: AuthService.currentUser?.roleKey,
      createdAt: now,
      updatedAt: now,
    );
    _grievances.add(row);
    await _persist();
    return row;
  }

  Future<Grievance> reviewGrievance(
    String id,
    GrievanceStatus status, {
    String resolution = '',
  }) async {
    _requireStaffDesk();
    final row = _grievances.cast<Grievance?>().firstWhere(
          (item) => item?.id == id,
          orElse: () => null,
        );
    if (row == null) {
      throw StateError('Grievance not found.');
    }
    row.status = status;
    if (resolution.trim().isNotEmpty) row.resolution = resolution.trim();
    row.updatedAt = DateTime.now();
    await _persist();
    return row;
  }

  Future<Internship> addInternship({
    required String studentId,
    String host = '',
    String role = '',
    String notes = '',
    InternshipStatus status = InternshipStatus.planned,
    DateTime? startsAt,
    DateTime? endsAt,
    String? schoolId,
  }) async {
    _requireStaffDesk();
    final now = DateTime.now();
    final meta = _studentMeta(studentId);
    final row = Internship(
      id: _id('INT', _internships.map((item) => item.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      studentId: studentId.trim().toUpperCase(),
      studentName: meta.name,
      className: meta.className,
      host: host.trim(),
      role: role.trim(),
      notes: notes.trim(),
      status: status,
      startsAt: startsAt,
      endsAt: endsAt,
      createdBy: _username,
      createdAt: now,
      updatedAt: now,
    );
    _internships.add(row);
    await _persist();
    return row;
  }

  Future<Internship> updateInternshipStatus(
    String id,
    InternshipStatus status, {
    String notes = '',
  }) async {
    if (!canManageDesk && !_isStudent) {
      throw StateError('Only the care desk or the intern can update this.');
    }
    final row = _internships.cast<Internship?>().firstWhere(
          (item) => item?.id == id,
          orElse: () => null,
        );
    if (row == null) {
      throw StateError('Internship not found.');
    }
    if (_isStudent && !_ownsStudent(row.studentId)) {
      throw StateError('You can only update your own internship.');
    }
    row.status = status;
    if (notes.trim().isNotEmpty) row.notes = notes.trim();
    row.updatedAt = DateTime.now();
    await _persist();
    return row;
  }

  Future<DosaMeeting> recordMeeting({
    required String title,
    required DateTime startsAt,
    DosaMeetingKind kind = DosaMeetingKind.leadership,
    String agenda = '',
    String notes = '',
    List<DosaTask> tasks = const [],
    String? schoolId,
  }) async {
    _requireStaffDesk();
    final now = DateTime.now();
    String? calendarEventId;
    if (kind == DosaMeetingKind.graduation || kind == DosaMeetingKind.event) {
      final event = SchoolDataService.instance.scheduleCalendarEvent(
        title: title.trim(),
        description: agenda.trim().isEmpty ? title.trim() : agenda.trim(),
        date: startsAt,
        type: CalendarEventType.meeting,
        audience: 'All',
        autoAnnounce: false,
      );
      calendarEventId = event.id;
    }
    final row = DosaMeeting(
      id: _id('DOS', _meetings.map((item) => item.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      title: title.trim(),
      kind: kind,
      agenda: agenda.trim(),
      notes: notes.trim(),
      startsAt: startsAt,
      calendarEventId: calendarEventId,
      tasks: List.of(tasks),
      createdBy: _username,
      createdAt: now,
      updatedAt: now,
    );
    _meetings.add(row);
    await _persist();
    return row;
  }

  /// Staff-only DoSA group. Minutes stay on the meeting record, not in chat.
  String openLeadershipChat() {
    _requireStaffDesk();
    if (_username.trim().isEmpty) {
      throw StateError('Sign in to open the leadership chat.');
    }
    return SchoolDataService.instance.openOrCreateGroupConversation(
      parentNames: const [],
      staffIds: [_username],
      groupName: 'DoSA leadership',
    );
  }

  Future<DosaMeeting> toggleTask(String meetingId, String taskId) async {
    _requireStaffDesk();
    final meeting = _meetings.cast<DosaMeeting?>().firstWhere(
          (item) => item?.id == meetingId,
          orElse: () => null,
        );
    if (meeting == null) {
      throw StateError('Meeting not found.');
    }
    for (final task in meeting.tasks) {
      if (task.id == taskId) {
        task.done = !task.done;
        break;
      }
    }
    meeting.updatedAt = DateTime.now();
    await _persist();
    return meeting;
  }

  void applyPersistedData({
    List<ExtracurricularClub>? clubs,
    List<ClubMembership>? memberships,
    List<ScholarshipRecord>? scholarships,
    List<Grievance>? grievances,
    List<Internship>? internships,
    List<DosaMeeting>? meetings,
    bool merge = false,
  }) {
    void mergeList<T>(
      List<T> local,
      List<T> incoming,
      String Function(T) idOf,
    ) {
      if (!merge) {
        local
          ..clear()
          ..addAll(incoming);
        return;
      }
      final byId = {for (final item in local) idOf(item): item};
      for (final item in incoming) {
        byId[idOf(item)] = item;
      }
      local
        ..clear()
        ..addAll(byId.values);
    }

    if (clubs != null) mergeList(_clubs, clubs, (row) => row.id);
    if (memberships != null) {
      mergeList(_memberships, memberships, (row) => row.id);
    }
    if (scholarships != null) {
      mergeList(_scholarships, scholarships, (row) => row.id);
    }
    if (grievances != null) mergeList(_grievances, grievances, (row) => row.id);
    if (internships != null) {
      mergeList(_internships, internships, (row) => row.id);
    }
    if (meetings != null) {
      if (_isPublicReader) {
        mergeList(
          _meetings,
          meetings.where((row) => row.kind == DosaMeetingKind.graduation).toList(),
          (row) => row.id,
        );
      } else {
        mergeList(_meetings, meetings, (row) => row.id);
      }
    }
    _loaded = true;
    notifyListeners();
  }

  List<Map<String, dynamic>> clubMaps() =>
      _clubs.map((row) => row.toMap()).toList();
  List<Map<String, dynamic>> membershipMaps() =>
      _memberships.map((row) => row.toMap()).toList();
  List<Map<String, dynamic>> scholarshipMaps() =>
      _scholarships.map((row) => row.toMap()).toList();
  List<Map<String, dynamic>> grievanceMaps() =>
      _grievances.map((row) => row.toMap()).toList();
  List<Map<String, dynamic>> internshipMaps() =>
      _internships.map((row) => row.toMap()).toList();
  List<Map<String, dynamic>> meetingMaps() =>
      _meetings.map((row) => row.toMap()).toList();

  List<T> _schoolFilter<T>(List<T> rows, String? schoolId) {
    final sid = (schoolId ?? _schoolId).toUpperCase();
    if (sid.isEmpty) return List<T>.from(rows);
    return rows.where((row) {
      final rowSchool = switch (row) {
        ExtracurricularClub r => r.schoolId,
        ClubMembership r => r.schoolId,
        ScholarshipRecord r => r.schoolId,
        Grievance r => r.schoolId,
        Internship r => r.schoolId,
        DosaMeeting r => r.schoolId,
        _ => '',
      };
      return rowSchool == sid;
    }).toList();
  }

  ({String name, String? className}) _studentMeta(String studentId) {
    final student = StudentRegistryService.instance.lookupById(studentId);
    return (
      name: student?.fullName ?? studentId.trim().toUpperCase(),
      className: student?.className,
    );
  }

  bool _ownsStudent(String studentId) {
    final id = studentId.trim().toUpperCase();
    if (id.isEmpty) return false;
    if (_isStudent) {
      final self = (AuthService.currentUser?.linkedStudentId ?? '')
          .trim()
          .toUpperCase();
      return self.isNotEmpty && self == id;
    }
    return AuthService.activeLinkedStudentIds()
        .map((value) => value.trim().toUpperCase())
        .contains(id);
  }

  void _requireStaffDesk() {
    if (!canManageDesk) {
      throw StateError('Student programs can only be written by the DoSA desk.');
    }
  }

  Future<void> _persist() async {
    notifyListeners();
    await DosaPersistenceService.instance.saveFromService();
  }

  String _id(String prefix, Iterable<String> existing) {
    return ShortRegistryId.allocate(
      prefix: prefix,
      existingIds: existing,
      isTaken: (id) => existing.contains(id),
    );
  }
}
