import 'package:flutter/foundation.dart';

import 'package:mayabela/models/hr_workforce_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/employee_registry_service.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

/// Leave register and employment files for the HR desk. Salary stays in Payroll.
class HrWorkforceService extends ChangeNotifier {
  HrWorkforceService._();
  static final instance = HrWorkforceService._();

  static const _filesKey = 'persisted_hr_employment_files';
  static const _leavesKey = 'persisted_hr_staff_leave';

  final List<StaffEmploymentFile> _files = [];
  final List<StaffLeaveRecord> _leaves = [];
  bool _loaded = false;

  List<StaffEmploymentFile> get files => List.unmodifiable(_files);
  List<StaffLeaveRecord> get leaves => List.unmodifiable(_leaves);

  void resetForTests() {
    _files.clear();
    _leaves.clear();
    _loaded = true;
    notifyListeners();
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final fileRows = await LocalJsonStore.readList(_filesKey);
    final leaveRows = await LocalJsonStore.readList(_leavesKey);
    _files
      ..clear()
      ..addAll(fileRows.map(StaffEmploymentFile.fromMap));
    _leaves
      ..clear()
      ..addAll(leaveRows.map(StaffLeaveRecord.fromMap));
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    await LocalJsonStore.writeList(
      _filesKey,
      _files.map((e) => e.toMap()).toList(),
    );
    await LocalJsonStore.writeList(
      _leavesKey,
      _leaves.map((e) => e.toMap()).toList(),
    );
    notifyListeners();
  }

  List<HrPersonRef> peopleForSchool(String? schoolId) {
    final sid = (schoolId ?? AuthService.activeSchoolId ?? '').trim().toUpperCase();
    final out = <HrPersonRef>[];
    for (final t in TeacherRegistryService.instance.visibleTeachers(
      schoolId: sid,
      includeInactive: false,
    )) {
      out.add(
        HrPersonRef(
          personId: t.teacherId,
          schoolId: t.schoolId,
          name: t.fullName,
          kind: t.staffRoles.isNotEmpty ? HrPersonKind.admin : HrPersonKind.teacher,
          title: t.staffRoles.isNotEmpty
              ? t.staffRoles.join(', ')
              : (t.assignedClass.isEmpty ? 'Teacher' : t.assignedClass),
        ),
      );
    }
    for (final e in EmployeeRegistryService.instance.employeesForSchool(
      sid,
      includeInactive: false,
    )) {
      out.add(
        HrPersonRef(
          personId: e.employeeId,
          schoolId: e.schoolId,
          name: e.fullName,
          kind: HrPersonKind.employee,
          title: e.jobTitle,
        ),
      );
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  StaffEmploymentFile? fileFor(String personId, {String? schoolId}) {
    final sid = (schoolId ?? AuthService.activeSchoolId ?? '').trim().toUpperCase();
    for (final file in _files) {
      if (file.personId == personId && file.schoolId == sid) return file;
    }
    return null;
  }

  List<StaffLeaveRecord> leavesForSchool(String? schoolId) {
    final sid = (schoolId ?? AuthService.activeSchoolId ?? '').trim().toUpperCase();
    return _leaves.where((l) => l.schoolId == sid).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<StaffEmploymentFile> filesForSchool(String? schoolId) {
    final sid = (schoolId ?? AuthService.activeSchoolId ?? '').trim().toUpperCase();
    return _files.where((f) => f.schoolId == sid).toList();
  }

  HrWorkforceSnapshot snapshot(String? schoolId, {DateTime? asOf}) {
    final sid = (schoolId ?? AuthService.activeSchoolId ?? '').trim().toUpperCase();
    final now = asOf ?? DateTime.now();
    var admin = 0;
    var teachers = 0;
    for (final t in TeacherRegistryService.instance.visibleTeachers(
      schoolId: sid,
      includeInactive: false,
    )) {
      if (t.staffRoles.isNotEmpty) {
        admin++;
      } else {
        teachers++;
      }
    }
    final other = EmployeeRegistryService.instance
        .employeesForSchool(sid, includeInactive: false)
        .length;
    final schoolLeaves = leavesForSchool(sid);
    final onLeave = schoolLeaves
        .where((l) => l.status == StaffLeaveStatus.approved && l.covers(now))
        .map((l) => l.personId)
        .toSet()
        .length;
    final pending = schoolLeaves
        .where((l) => l.status == StaffLeaveStatus.pending)
        .length;
    final watch = filesForSchool(sid)
        .where((f) {
          final stage = f.stageOn(now);
          return stage == StaffEmploymentStage.endingSoon ||
              stage == StaffEmploymentStage.expired ||
              stage == StaffEmploymentStage.probation;
        })
        .length;
    return HrWorkforceSnapshot(
      adminStaff: admin,
      teachers: teachers,
      otherStaff: other,
      onLeaveToday: onLeave,
      pendingLeave: pending,
      contractsWatch: watch,
    );
  }

  Future<void> upsertEmployment(StaffEmploymentFile file) async {
    await ensureLoaded();
    final idx = _files.indexWhere(
      (f) => f.personId == file.personId && f.schoolId == file.schoolId,
    );
    if (idx >= 0) {
      _files[idx] = file;
    } else {
      _files.add(file);
    }
    await _persist();
  }

  Future<StaffLeaveRecord> requestLeave({
    required HrPersonRef person,
    required StaffLeaveType type,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    await ensureLoaded();
    if (endDate.isBefore(startDate)) {
      throw ArgumentError('Leave cannot end before it starts.');
    }
    final record = StaffLeaveRecord(
      id: 'LV-${DateTime.now().millisecondsSinceEpoch}',
      schoolId: person.schoolId.trim().toUpperCase(),
      personId: person.personId,
      personName: person.name,
      kind: person.kind,
      type: type,
      startDate: startDate,
      endDate: endDate,
      reason: reason.trim(),
      createdAt: DateTime.now(),
    );
    _leaves.insert(0, record);
    await _persist();
    return record;
  }

  Future<void> reviewLeave({
    required String leaveId,
    required StaffLeaveStatus status,
    String? reviewedBy,
  }) async {
    await ensureLoaded();
    final idx = _leaves.indexWhere((l) => l.id == leaveId);
    if (idx < 0) return;
    _leaves[idx] = _leaves[idx].copyWith(
      status: status,
      reviewedBy: reviewedBy ?? AuthService.currentUser?.fullName ?? '',
    );
    await _persist();
  }
}
