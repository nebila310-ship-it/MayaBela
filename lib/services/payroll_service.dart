import 'package:flutter/foundation.dart';

import 'package:mayabela/models/payroll_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/employee_registry_service.dart';
import 'package:mayabela/services/ethiopia_payroll_tax.dart';
import 'package:mayabela/services/persistence/payroll_persistence_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

class PayrollService extends ChangeNotifier {
  PayrollService._();
  static final instance = PayrollService._();

  final List<PayrollProfile> _profiles = [];
  final List<PayrollRun> _runs = [];
  var _loaded = false;

  bool get canManage => ModuleAccess.canManage('hr');

  String get _schoolId =>
      (AuthService.activeSchoolId ?? AuthService.currentUser?.schoolId ?? '')
          .trim()
          .toUpperCase();

  String get _username => AuthService.currentUser?.username ?? '';

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await PayrollPersistenceService.instance.loadIntoService();
    _loaded = true;
  }

  void applyPersistedData({
    List<PayrollProfile>? profiles,
    List<PayrollRun>? runs,
    bool merge = false,
  }) {
    if (profiles != null) {
      if (!merge) _profiles.clear();
      for (final row in profiles) {
        _profiles.removeWhere((p) => p.id == row.id);
        _profiles.add(row);
      }
    }
    if (runs != null) {
      if (!merge) _runs.clear();
      for (final row in runs) {
        _runs.removeWhere((p) => p.id == row.id);
        _runs.add(row);
      }
    }
    notifyListeners();
  }

  List<Map<String, dynamic>> profileMaps() =>
      _profiles.map((e) => e.toMap()).toList();

  List<Map<String, dynamic>> runMaps() => _runs.map((e) => e.toMap()).toList();

  List<PayrollPerson> peopleForSchool([String? schoolId]) {
    final sid = (schoolId ?? _schoolId).toUpperCase();
    final people = <PayrollPerson>[];
    for (final t in TeacherRegistryService.instance.teachersForSchool(
      sid,
      includeInactive: true,
    )) {
      people.add(
        PayrollPerson(
          kind: PayrollPersonKind.teacher,
          personId: t.teacherId,
          schoolId: t.schoolId,
          fullName: t.fullName,
          jobTitle: t.subject.isEmpty ? 'Teacher' : t.subject,
          isActive: t.isActive,
        ),
      );
    }
    for (final e in EmployeeRegistryService.instance.employeesForSchool(
      sid,
      includeInactive: true,
    )) {
      people.add(
        PayrollPerson(
          kind: PayrollPersonKind.employee,
          personId: e.employeeId,
          schoolId: e.schoolId,
          fullName: e.fullName,
          jobTitle: e.jobTitle,
          isActive: e.isActive,
        ),
      );
    }
    for (final d in DriverRegistryService.instance.driversForSchool(sid)) {
      people.add(
        PayrollPerson(
          kind: PayrollPersonKind.driver,
          personId: d.driverId,
          schoolId: d.schoolId,
          fullName: d.fullName,
          jobTitle: 'Driver · ${d.busNumber}',
          isActive: d.isActive,
        ),
      );
    }
    people.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    return people;
  }

  PayrollProfile? profileFor(PayrollPerson person) {
    for (final row in _profiles) {
      if (row.id == person.profileId) return row;
    }
    return null;
  }

  EthiopianPayslipBreakdown previewFor(PayrollPerson person) {
    final profile = profileFor(person);
    if (profile == null) {
      return EthiopianPayrollTax.breakdown(basicSalary: 0);
    }
    return profile.preview;
  }

  Future<PayrollProfile> upsertProfile({
    required PayrollPerson person,
    required double basicSalary,
    double taxableAllowances = 0,
    double exemptAllowances = 0,
    bool pensionEligible = true,
    String notes = '',
  }) async {
    if (!canManage) {
      throw StateError('You cannot edit payroll.');
    }
    final now = DateTime.now().toUtc();
    final row = PayrollProfile(
      id: person.profileId,
      schoolId: person.schoolId.toUpperCase(),
      kind: person.kind,
      personId: person.personId,
      basicSalary: basicSalary,
      taxableAllowances: taxableAllowances,
      exemptAllowances: exemptAllowances,
      pensionEligible: pensionEligible,
      notes: notes.trim(),
      updatedAt: now,
    );
    _profiles.removeWhere((p) => p.id == row.id);
    _profiles.add(row);
    await PayrollPersistenceService.instance.saveFromService();
    notifyListeners();
    return row;
  }

  List<PayrollRun> runsForSchool([String? schoolId]) {
    final sid = (schoolId ?? _schoolId).toUpperCase();
    return _runs.where((r) => r.schoolId == sid).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  PayrollRun? latestRun([String? schoolId]) {
    final rows = runsForSchool(schoolId);
    return rows.isEmpty ? null : rows.first;
  }

  Future<PayrollRun> runPayroll({
    required String periodYm,
    String notes = '',
  }) async {
    if (!canManage) {
      throw StateError('You cannot run payroll.');
    }
    final sid = _schoolId;
    if (sid.isEmpty) {
      throw StateError('Sign in to a school before running payroll.');
    }
    final slips = <PayrollSlip>[];
    for (final person in peopleForSchool(sid).where((p) => p.isActive)) {
      final profile = profileFor(person);
      if (profile == null || profile.basicSalary <= 0) continue;
      final calc = profile.preview;
      slips.add(
        PayrollSlip(
          personId: person.personId,
          kind: person.kind,
          fullName: person.fullName,
          jobTitle: person.jobTitle,
          basicSalary: calc.basicSalary,
          taxableAllowances: calc.taxableAllowances,
          exemptAllowances: calc.exemptAllowances,
          taxableIncome: calc.taxableIncome,
          paye: calc.paye,
          employeePension: calc.employeePension,
          employerPension: calc.employerPension,
          gross: calc.gross,
          net: calc.net,
          pensionEligible: calc.pensionEligible,
        ),
      );
    }
    if (slips.isEmpty) {
      throw StateError('Set a basic salary for at least one staff member.');
    }
    final run = PayrollRun(
      id: 'PAY-${DateTime.now().millisecondsSinceEpoch}',
      schoolId: sid,
      periodYm: periodYm,
      createdAt: DateTime.now().toUtc(),
      createdBy: _username,
      slips: slips,
      notes: notes.trim(),
    );
    _runs.add(run);
    await PayrollPersistenceService.instance.saveFromService();
    notifyListeners();
    return run;
  }
}
