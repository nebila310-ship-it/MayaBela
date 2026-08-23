import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mayabela/services/persistence/employee_persistence_service.dart';
import 'package:mayabela/utils/short_registry_id.dart';

/// Record-only school employee (no app login). Managed by Human Resource.
class EmployeeRecord {
  EmployeeRecord({
    required this.employeeId,
    required this.schoolId,
    required this.fullName,
    required this.jobTitle,
    this.phone,
    this.department,
    this.notes,
    this.campus = 'Main Campus',
    this.isActive = true,
  });

  final String employeeId;
  final String schoolId;
  final String fullName;
  final String jobTitle;
  final String? phone;
  final String? department;
  final String? notes;
  final String campus;
  final bool isActive;

  EmployeeRecord copyWith({
    String? fullName,
    String? jobTitle,
    String? phone,
    String? department,
    String? notes,
    String? campus,
    bool? isActive,
    bool clearPhone = false,
    bool clearDepartment = false,
    bool clearNotes = false,
  }) {
    return EmployeeRecord(
      employeeId: employeeId,
      schoolId: schoolId,
      fullName: fullName ?? this.fullName,
      jobTitle: jobTitle ?? this.jobTitle,
      phone: clearPhone ? null : (phone ?? this.phone),
      department: clearDepartment ? null : (department ?? this.department),
      notes: clearNotes ? null : (notes ?? this.notes),
      campus: campus ?? this.campus,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() => {
        'employeeId': employeeId,
        'schoolId': schoolId,
        'fullName': fullName,
        'jobTitle': jobTitle,
        if (phone != null) 'phone': phone,
        if (department != null) 'department': department,
        if (notes != null) 'notes': notes,
        'campus': campus,
        'isActive': isActive,
      };

  factory EmployeeRecord.fromMap(Map<String, dynamic> map) {
    return EmployeeRecord(
      employeeId: (map['employeeId'] as String? ?? '').trim().toUpperCase(),
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      fullName: map['fullName'] as String? ?? '',
      jobTitle: map['jobTitle'] as String? ?? '',
      phone: map['phone'] as String?,
      department: map['department'] as String?,
      notes: map['notes'] as String?,
      campus: (map['campus'] as String?)?.trim().isNotEmpty == true
          ? (map['campus'] as String).trim()
          : 'Main Campus',
      isActive: map['isActive'] as bool? ?? true,
    );
  }
}

class EmployeeRegistryService extends ChangeNotifier {
  EmployeeRegistryService._();
  static final instance = EmployeeRegistryService._();

  int _nextId = 1001;
  final List<EmployeeRecord> _employees = [];

  int get nextEmployeeIdCounter => _nextId;

  List<EmployeeRecord> registrySnapshot() => List.unmodifiable(_employees);

  List<EmployeeRecord> employeesForSchool(
    String? schoolId, {
    bool includeInactive = false,
  }) {
    final sid = schoolId?.trim().toUpperCase();
    return _employees
        .where((e) {
          if (sid != null &&
              sid.isNotEmpty &&
              e.schoolId.toUpperCase() != sid) {
            return false;
          }
          if (!includeInactive && !e.isActive) return false;
          return true;
        })
        .toList(growable: false);
  }

  EmployeeRecord? lookupById(String employeeId) {
    final id = employeeId.trim().toUpperCase();
    for (final e in _employees) {
      if (e.employeeId == id) return e;
    }
    return null;
  }

  EmployeeRecord addEmployee({
    required String schoolId,
    required String fullName,
    required String jobTitle,
    String? phone,
    String? department,
    String? notes,
    String? campus,
  }) {
    final record = EmployeeRecord(
      employeeId: _allocateEmployeeId(),
      schoolId: schoolId.trim().toUpperCase(),
      fullName: fullName.trim(),
      jobTitle: jobTitle.trim(),
      phone: phone?.trim().isEmpty ?? true ? null : phone!.trim(),
      department:
          department?.trim().isEmpty ?? true ? null : department!.trim(),
      notes: notes?.trim().isEmpty ?? true ? null : notes!.trim(),
      campus: campus == null || campus.trim().isEmpty
          ? 'Main Campus'
          : campus.trim(),
    );
    _employees.add(record);
    notifyListeners();
    unawaited(EmployeePersistenceService.instance.saveRegistryFromService());
    return record;
  }

  String _allocateEmployeeId() {
    final id = ShortRegistryId.allocate(
      prefix: 'EMP',
      existingIds: _employees.map((e) => e.employeeId),
      isTaken: (id) => _employees.any((e) => e.employeeId == id),
      persistedNext: _nextId,
    );
    _nextId = (ShortRegistryId.parseNumber(id) ?? 0) + 1;
    return id;
  }

  bool updateEmployee(EmployeeRecord updated) {
    final index =
        _employees.indexWhere((e) => e.employeeId == updated.employeeId);
    if (index < 0) return false;
    _employees[index] = updated;
    notifyListeners();
    unawaited(EmployeePersistenceService.instance.saveRegistryFromService());
    return true;
  }

  bool deactivateEmployee(String employeeId) {
    final existing = lookupById(employeeId);
    if (existing == null || !existing.isActive) return false;
    return updateEmployee(existing.copyWith(isActive: false));
  }

  void applyPersistedEmployees(
    List<EmployeeRecord> employees, {
    int? nextId,
  }) {
    _employees
      ..clear()
      ..addAll(employees);
    final clamped = ShortRegistryId.clampCounter(nextId, fallback: _nextId);
    if (clamped > _nextId) _nextId = clamped;
    notifyListeners();
  }
}
