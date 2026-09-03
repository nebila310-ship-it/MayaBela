import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/models/school_lifecycle.dart';
import 'package:mayabela/models/school_logo_style.dart';
import 'package:mayabela/models/student_portal.dart';
import 'package:mayabela/models/grade_workflow.dart';
import 'package:mayabela/models/markbook.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/school_registry_persistence_service.dart';
import 'package:mayabela/services/persistence/teacher_persistence_service.dart';
import 'package:mayabela/services/platform_audit_log_service.dart';
import 'package:mayabela/services/platform_owner_service.dart';
import 'package:mayabela/services/platform_schools_cloud_service.dart';
import 'package:mayabela/services/school_logo_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

class SchoolRecord {
  SchoolRecord({
    required this.id,
    required this.name,
    this.city,
    this.academicYear,
    this.gradeLevels = const [],
    this.sections = const [],
    this.campuses = const [],
    this.registeredAt,
    this.status = SchoolLifecycleStatus.active,
    this.subscriptionExpiresAt,
    this.notes,
    this.adminContactPhone,
    this.address,
    this.officePhone,
    this.logoPath,
    this.logoUrl,
    this.logoStyle = SchoolLogoStyle.rectangular,
    this.contractedSeats,
    this.ratePerStudentMonthEtb,
    this.minimumMonthlyEtb,
    this.adminInitialPassword,
    this.adminFullName,
    this.studentPortal = const StudentPortalSettings(),
    this.gradeWorkflow = const GradeWorkflowSettings(),
    this.markbookSettings = MarkbookSettings.liaDefaults,
    this.allowSelfApproval = false,
  });

  final String id;
  String name;
  String? city;
  final String? academicYear;
  final List<String> gradeLevels;
  final List<String> sections;
  final List<String> campuses;
  final DateTime? registeredAt;
  SchoolLifecycleStatus status;
  DateTime? subscriptionExpiresAt;
  String? notes;
  String? adminContactPhone;
  String? address;
  String? officePhone;
  String? logoPath;
  String? logoUrl;
  SchoolLogoStyle logoStyle;
  int? contractedSeats;
  int? ratePerStudentMonthEtb;
  int? minimumMonthlyEtb;
  String? adminInitialPassword;
  String? adminFullName;
  StudentPortalSettings studentPortal;
  GradeWorkflowSettings gradeWorkflow;
  MarkbookSettings markbookSettings;

  /// Whether a requester may approve their own purchase / issue requests.
  /// Off by default (separation of duties); only the owner can enable it.
  /// Mirrored to `data.settings.allowSelfApproval`, which the SQL
  /// write-guard reads via school_setting_bool().
  bool allowSelfApproval;

  SchoolAccessBlock? get accessBlock {
    if (status == SchoolLifecycleStatus.inactive) {
      return SchoolAccessBlock.inactive;
    }
    if (status == SchoolLifecycleStatus.suspended) {
      return SchoolAccessBlock.suspended;
    }
    final expiry = subscriptionExpiresAt;
    if (expiry != null && DateTime.now().isAfter(expiry)) {
      return SchoolAccessBlock.expired;
    }
    return null;
  }

  bool get isAccessible => accessBlock == null;

  SchoolRecord copyWith({
    String? name,
    String? city,
    String? academicYear,
    List<String>? gradeLevels,
    List<String>? sections,
    List<String>? campuses,
    SchoolLifecycleStatus? status,
    DateTime? subscriptionExpiresAt,
    bool clearSubscriptionExpiresAt = false,
    String? notes,
    String? adminContactPhone,
    String? address,
    String? officePhone,
    String? logoPath,
    String? logoUrl,
    SchoolLogoStyle? logoStyle,
    int? contractedSeats,
    int? ratePerStudentMonthEtb,
    int? minimumMonthlyEtb,
    String? adminInitialPassword,
    String? adminFullName,
    StudentPortalSettings? studentPortal,
    GradeWorkflowSettings? gradeWorkflow,
    MarkbookSettings? markbookSettings,
    bool? allowSelfApproval,
  }) {
    return SchoolRecord(
      id: id,
      name: name ?? this.name,
      city: city ?? this.city,
      academicYear: academicYear ?? this.academicYear,
      gradeLevels: gradeLevels ?? List.from(this.gradeLevels),
      sections: sections ?? List.from(this.sections),
      campuses: campuses ?? List.from(this.campuses),
      registeredAt: registeredAt,
      status: status ?? this.status,
      subscriptionExpiresAt: clearSubscriptionExpiresAt
          ? null
          : (subscriptionExpiresAt ?? this.subscriptionExpiresAt),
      notes: notes ?? this.notes,
      adminContactPhone: adminContactPhone ?? this.adminContactPhone,
      address: address ?? this.address,
      officePhone: officePhone ?? this.officePhone,
      logoPath: logoPath ?? this.logoPath,
      logoUrl: logoUrl ?? this.logoUrl,
      logoStyle: logoStyle ?? this.logoStyle,
      contractedSeats: contractedSeats ?? this.contractedSeats,
      ratePerStudentMonthEtb: ratePerStudentMonthEtb ?? this.ratePerStudentMonthEtb,
      minimumMonthlyEtb: minimumMonthlyEtb ?? this.minimumMonthlyEtb,
      adminInitialPassword: adminInitialPassword ?? this.adminInitialPassword,
      adminFullName: adminFullName ?? this.adminFullName,
      studentPortal: studentPortal ?? this.studentPortal,
      gradeWorkflow: gradeWorkflow ?? this.gradeWorkflow,
      markbookSettings: markbookSettings ?? this.markbookSettings,
      allowSelfApproval: allowSelfApproval ?? this.allowSelfApproval,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'city': city,
        'academicYear': academicYear,
        'gradeLevels': gradeLevels,
        'sections': sections,
        'campuses': campuses,
        'registeredAt': registeredAt?.toIso8601String(),
        'status': status.name,
        'subscriptionExpiresAt': subscriptionExpiresAt?.toIso8601String(),
        'notes': notes,
        'adminContactPhone': adminContactPhone,
        'address': address,
        'officePhone': officePhone,
        'logoPath': logoPath,
        'logoUrl': logoUrl,
        'logoStyle': logoStyle.name,
        'contractedSeats': contractedSeats,
        'ratePerStudentMonthEtb': ratePerStudentMonthEtb,
        'minimumMonthlyEtb': minimumMonthlyEtb,
        'adminInitialPassword': adminInitialPassword,
        'adminFullName': adminFullName,
        'studentPortal': studentPortal.toMap(),
        'gradeWorkflow': gradeWorkflow.toMap(),
        'markbookSettings': markbookSettings.toMap(),
        // The SQL write-guard reads data->settings->allowSelfApproval.
        'settings': {'allowSelfApproval': allowSelfApproval},
      };

  factory SchoolRecord.fromJson(Map<String, dynamic> json) {
    return SchoolRecord(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      city: json['city'] as String?,
      academicYear: json['academicYear'] as String?,
      gradeLevels: (json['gradeLevels'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      sections: (json['sections'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      campuses: (json['campuses'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['Main Campus'],
      registeredAt: json['registeredAt'] != null
          ? DateTime.tryParse(json['registeredAt'] as String)
          : null,
      status: SchoolLifecycleStatus.parse(json['status'] as String?),
      subscriptionExpiresAt: json['subscriptionExpiresAt'] != null
          ? DateTime.tryParse(json['subscriptionExpiresAt'] as String)
          : null,
      notes: json['notes'] as String?,
      adminContactPhone: json['adminContactPhone'] as String?,
      address: json['address'] as String?,
      officePhone: json['officePhone'] as String?,
      logoPath: json['logoPath'] as String?,
      logoUrl: json['logoUrl'] as String?,
      logoStyle: SchoolLogoStyle.parse(json['logoStyle'] as String?),
      contractedSeats: json['contractedSeats'] as int?,
      ratePerStudentMonthEtb: json['ratePerStudentMonthEtb'] as int?,
      minimumMonthlyEtb: json['minimumMonthlyEtb'] as int?,
      adminInitialPassword: json['adminInitialPassword'] as String?,
      adminFullName: json['adminFullName'] as String?,
      studentPortal: StudentPortalSettings.fromMap(
        json['studentPortal'] as Map<String, dynamic>?,
      ),
      gradeWorkflow: GradeWorkflowSettings.fromMap(
        json['gradeWorkflow'] as Map<String, dynamic>?,
      ),
      markbookSettings: MarkbookSettings.fromMap(
        json['markbookSettings'] as Map<String, dynamic>?,
      ),
      allowSelfApproval:
          ((json['settings'] as Map<String, dynamic>?)?['allowSelfApproval']
                  as bool?) ??
              false,
    );
  }
}

class SchoolRegistryService {
  SchoolRegistryService._();
  static final instance = SchoolRegistryService._();

  final List<SchoolRecord> _schools = [];

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;

    await SchoolRegistryPersistenceService.instance.loadIntoService();
    // Never seed the fake TB-001 school in release — it hides real cloud schools
    // on fresh phones/browsers. Debug may still seed for local UI work.
    if (_schools.isEmpty && kDebugMode) {
      _seedDemoSchool();
      await _persist(pushCloud: false);
    }
    _loaded = true;
  }

  /// Local sandbox school for the public student demo login. Never pushed.
  void ensureLocalDemoSchool() {
    if (lookup('TB-001') != null) return;
    _seedDemoSchool();
  }

  /// Used by platform console after a cloud list pull.
  void removeDemoIfNotInCloud({required Set<String> cloudIds}) {
    final upper = cloudIds.map((e) => e.toUpperCase()).toSet();
    if (upper.isEmpty) return;
    if (upper.contains('TB-001')) return;
    final demo = lookup('TB-001');
    if (demo == null) return;
    if (demo.name == 'Maya School') {
      _schools.removeWhere((s) => s.id.toUpperCase() == 'TB-001');
    }
  }

  void _seedDemoSchool() {
    _schools.add(
      SchoolRecord(
        id: 'TB-001',
        name: 'Maya School',
        city: 'Addis Ababa',
        academicYear: '2025/2026',
        gradeLevels: ['Kindergarten', 'Grade 1', 'Grade 2', 'Grade 4', 'Grade 5'],
        sections: ['Grade 1A', 'Grade 2C', 'Grade 4A', 'Grade 4B', 'Grade 5B'],
        campuses: ['Main Campus', 'Bole Campus'],
        registeredAt: DateTime(2024, 9, 1),
        status: SchoolLifecycleStatus.active,
        ratePerStudentMonthEtb: 8,
        minimumMonthlyEtb: 500,
        adminInitialPassword: AuthService.tempPassword,
        adminContactPhone: '0911000003',
        adminFullName: 'School Admin',
      ),
    );
  }

  Future<void> _persist({bool pushCloud = true}) async {
    await SchoolRegistryPersistenceService.instance.saveFromService(
      pushCloud: pushCloud,
    );
  }

  void applyPersistedSchools(List<SchoolRecord> schools) {
    _schools
      ..clear()
      ..addAll(schools);
    _loaded = true;
  }

  /// Merge one school from cloud login so fresh browsers can pass the
  /// local registry gate without replacing the whole list.
  void upsertSchool(SchoolRecord school) {
    final id = school.id.trim().toUpperCase();
    if (id.isEmpty) return;
    final record = id == school.id
        ? school
        : SchoolRecord.fromJson({...school.toJson(), 'id': id});
    final index = _schools.indexWhere((s) => s.id.toUpperCase() == id);
    if (index >= 0) {
      _schools[index] = record;
    } else {
      _schools.add(record);
    }
    _loaded = true;
  }

  List<SchoolRecord> allSchoolsSnapshot() => List.from(_schools);

  bool exists(String? schoolId) {
    if (schoolId == null || schoolId.trim().isEmpty) return false;
    final id = schoolId.trim().toUpperCase();
    return _schools.any((school) => school.id.toUpperCase() == id);
  }

  SchoolAccessBlock? accessBlockFor(String? schoolId) {
    final record = lookup(schoolId);
    if (record == null) return SchoolAccessBlock.notFound;
    return record.accessBlock;
  }

  /// Login gate — school must exist and be active with valid subscription.
  bool isValid(String? schoolId) => accessBlockFor(schoolId) == null;

  SchoolRecord? lookup(String? schoolId) {
    if (schoolId == null || schoolId.trim().isEmpty) return null;
    final id = schoolId.trim().toUpperCase();
    try {
      return _schools.firstWhere((school) => school.id.toUpperCase() == id);
    } catch (_) {
      return null;
    }
  }

  String displayName(String? schoolId) {
    return lookup(schoolId)?.name ?? 'Maya School Management';
  }

  List<String> campusesForSchool(String? schoolId) {
    final school = lookup(schoolId);
    if (school != null && school.campuses.isNotEmpty) {
      return List.unmodifiable(school.campuses);
    }
    return const ['Main Campus'];
  }

  // —— Campus management ——

  Future<bool> addCampus(String schoolId, String name) async {
    final school = lookup(schoolId);
    final trimmed = name.trim();
    if (school == null || trimmed.isEmpty) return false;
    final current = campusesForSchool(schoolId);
    if (current.any((c) => c.toLowerCase() == trimmed.toLowerCase())) {
      return false;
    }
    await updateSchool(school.copyWith(campuses: [...current, trimmed]));
    return true;
  }

  /// Renames a campus and reassigns every student/teacher on it.
  Future<bool> renameCampus(
    String schoolId, {
    required String from,
    required String to,
  }) async {
    final school = lookup(schoolId);
    final target = to.trim();
    if (school == null || target.isEmpty || target == from) return false;
    final current = campusesForSchool(schoolId).toList();
    final idx = current.indexOf(from);
    if (idx < 0) return false;
    if (current.any((c) => c.toLowerCase() == target.toLowerCase())) {
      return false;
    }
    current[idx] = target;
    await updateSchool(school.copyWith(campuses: current));

    StudentRegistryService.instance
        .reassignCampusForSchool(schoolId, from: from, to: target);
    final teachersChanged = TeacherRegistryService.instance
        .reassignCampusForSchool(schoolId, from: from, to: target);
    if (teachersChanged > 0) {
      await TeacherPersistenceService.instance.saveRegistryFromService();
    }
    return true;
  }

  /// Removes an empty campus. Refuses if it is the last campus or if any
  /// student/teacher is still assigned to it.
  Future<bool> removeCampus(String schoolId, String name) async {
    final school = lookup(schoolId);
    if (school == null) return false;
    final current = campusesForSchool(schoolId).toList();
    if (current.length <= 1 || !current.contains(name)) return false;

    final hasStudents = StudentRegistryService.instance
        .studentsForSchool(schoolId)
        .any((s) => s.campus == name);
    final hasTeachers = TeacherRegistryService.instance
        .teachersForSchool(schoolId)
        .any((t) => t.campus == name);
    if (hasStudents || hasTeachers) return false;

    current.remove(name);
    await updateSchool(school.copyWith(campuses: current));
    return true;
  }

  List<SchoolRecord> getAllSchools() {
    final copy = List<SchoolRecord>.from(_schools);
    copy.sort((a, b) => a.name.compareTo(b.name));
    return List.unmodifiable(copy);
  }

  String generateSchoolId(String schoolName) {
    final letters =
        schoolName.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
    final prefix =
        letters.length >= 3 ? letters.substring(0, 3) : (letters.padRight(3, 'X'));
    final suffix = 100 + Random().nextInt(900);
    var candidate = '$prefix$suffix';
    while (_schools.any((s) => s.id.toUpperCase() == candidate)) {
      candidate = '$prefix${100 + Random().nextInt(900)}';
    }
    return candidate;
  }

  /// Build a school record without persisting (used before cloud create).
  SchoolRecord draftSchool({
    required String name,
    required String city,
    required SchoolSetup setup,
    required String adminUsername,
    String? id,
    String? adminContactPhone,
    String? address,
    String? officePhone,
    DateTime? subscriptionExpiresAt,
    String? notes,
    int? ratePerStudentMonthEtb,
    int? minimumMonthlyEtb,
    String? adminInitialPassword,
    String? adminFullName,
  }) {
    final schoolId = (id ?? generateSchoolId(name)).trim().toUpperCase();
    return SchoolRecord(
      id: schoolId,
      name: name.trim(),
      city: city.trim(),
      academicYear: setup.academicYear,
      gradeLevels: List.from(setup.gradeLevels),
      sections: List.from(setup.sections),
      registeredAt: DateTime.now(),
      status: SchoolLifecycleStatus.active,
      subscriptionExpiresAt: subscriptionExpiresAt,
      notes: notes,
      adminContactPhone: adminContactPhone ?? adminUsername.trim(),
      address: address?.trim().isEmpty ?? true ? null : address!.trim(),
      officePhone: officePhone?.trim().isEmpty ?? true ? null : officePhone!.trim(),
      ratePerStudentMonthEtb: ratePerStudentMonthEtb ?? 8,
      minimumMonthlyEtb: minimumMonthlyEtb ?? 500,
      adminInitialPassword: adminInitialPassword,
      adminFullName:
          adminFullName?.trim().isEmpty ?? true ? null : adminFullName!.trim(),
    );
  }

  /// Persist a school that was already created in cloud (or local-only draft).
  Future<SchoolRecord> commitSchool(
    SchoolRecord record, {
    bool pushCloud = false,
  }) async {
    upsertSchool(record);
    await _persist(pushCloud: false);
    if (pushCloud) {
      try {
        await CloudAppStore.instance.pushSchool(record);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[SchoolRegistry] cloud push after commit failed: $e');
        }
      }
    }
    try {
      await PlatformAuditLogService.instance.log(
        action: 'school_created',
        schoolId: record.id,
        schoolName: record.name,
        detail: record.city,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SchoolRegistry] audit log after create failed: $e');
      }
    }
    return record;
  }

  Future<SchoolRecord> registerSchool({
    required String name,
    required String city,
    required SchoolSetup setup,
    required String adminUsername,
    String? adminContactPhone,
    String? address,
    String? officePhone,
    DateTime? subscriptionExpiresAt,
    String? notes,
    int? ratePerStudentMonthEtb,
    int? minimumMonthlyEtb,
    String? adminInitialPassword,
    String? adminFullName,
    String? id,
    bool pushCloud = true,
  }) async {
    final record = draftSchool(
      name: name,
      city: city,
      setup: setup,
      adminUsername: adminUsername,
      id: id,
      adminContactPhone: adminContactPhone,
      address: address,
      officePhone: officePhone,
      subscriptionExpiresAt: subscriptionExpiresAt,
      notes: notes,
      ratePerStudentMonthEtb: ratePerStudentMonthEtb,
      minimumMonthlyEtb: minimumMonthlyEtb,
      adminInitialPassword: adminInitialPassword,
      adminFullName: adminFullName,
    );
    return commitSchool(record, pushCloud: pushCloud);
  }

  /// Sync one school_registry row to cloud.
  /// Owner console uses [platform-update-school] (PIN); school sessions use JWT push.
  Future<PlatformSchoolCloudResult> syncSchoolToCloud(
    SchoolRecord school, {
    String? adminPassword,
    bool preferPlatformEdge = false,
  }) async {
    final pin = PlatformOwnerService.instance.sessionOwnerPin;
    final usePlatform = preferPlatformEdge ||
        (pin != null && pin.trim().length >= PlatformOwnerService.minPinLength);
    if (usePlatform) {
      return PlatformSchoolsCloudService.instance.updateSchoolInCloud(
        school: school,
        adminPassword: adminPassword,
        adminUsername: school.adminContactPhone,
      );
    }
    try {
      await CloudAppStore.instance.pushSchool(school);
      return PlatformSchoolCloudResult(
        ok: true,
        schoolId: school.id.trim().toUpperCase(),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SchoolRegistry] pushSchool failed: $e');
      }
      return PlatformSchoolCloudResult(
        ok: false,
        errorCode: 'invalid',
        errorMessage: e.toString(),
      );
    }
  }

  Future<PlatformSchoolCloudResult> updateSchool(
    SchoolRecord updated, {
    bool preferPlatformCloud = false,
    String? adminPassword,
  }) async {
    final index = _schools.indexWhere(
      (s) => s.id.toUpperCase() == updated.id.toUpperCase(),
    );
    if (index < 0) {
      return const PlatformSchoolCloudResult(
        ok: false,
        errorCode: 'not_found',
        errorMessage: 'School not found locally.',
      );
    }
    _schools[index] = updated;
    await _persist(pushCloud: false);
    final cloud = await syncSchoolToCloud(
      updated,
      adminPassword: adminPassword,
      preferPlatformEdge: preferPlatformCloud,
    );
    try {
      await PlatformAuditLogService.instance.log(
        action: 'school_updated',
        schoolId: updated.id,
        schoolName: updated.name,
      );
    } catch (_) {}
    return cloud;
  }

  /// Owner-only toggle: may a requester approve their own purchase / issue
  /// requests? The value syncs into school_registry so the SQL write-guard
  /// enforces the same rule server-side.
  Future<PlatformSchoolCloudResult> setAllowSelfApproval(
    String schoolId,
    bool value, {
    bool preferPlatformCloud = false,
  }) async {
    final record = lookup(schoolId);
    if (record == null) {
      return const PlatformSchoolCloudResult(
        ok: false,
        errorCode: 'not_found',
        errorMessage: 'School not found locally.',
      );
    }
    if (record.allowSelfApproval == value) {
      return PlatformSchoolCloudResult(ok: true, schoolId: record.id);
    }
    record.allowSelfApproval = value;
    final cloud = await updateSchool(
      record,
      preferPlatformCloud: preferPlatformCloud,
    );
    try {
      await PlatformAuditLogService.instance.log(
        action: 'self_approval_setting_changed',
        schoolId: record.id,
        schoolName: record.name,
        detail: value ? 'enabled' : 'disabled',
      );
    } catch (_) {}
    return cloud;
  }

  Future<PlatformSchoolCloudResult> setStatus(
    String schoolId,
    SchoolLifecycleStatus status, {
    bool preferPlatformCloud = false,
  }) async {
    final record = lookup(schoolId);
    if (record == null) {
      return const PlatformSchoolCloudResult(
        ok: false,
        errorCode: 'not_found',
        errorMessage: 'School not found locally.',
      );
    }
    record.status = status;
    final cloud = await updateSchool(
      record,
      preferPlatformCloud: preferPlatformCloud,
    );
    try {
      await PlatformAuditLogService.instance.log(
        action: 'status_changed',
        schoolId: record.id,
        schoolName: record.name,
        detail: status.name,
      );
    } catch (_) {}
    return cloud;
  }

  Future<PlatformSchoolCloudResult> setSubscriptionExpiry(
    String schoolId,
    DateTime? expiry, {
    bool preferPlatformCloud = false,
  }) async {
    final record = lookup(schoolId);
    if (record == null) {
      return const PlatformSchoolCloudResult(
        ok: false,
        errorCode: 'not_found',
        errorMessage: 'School not found locally.',
      );
    }
    record.subscriptionExpiresAt = expiry;
    final cloud = await updateSchool(
      record,
      preferPlatformCloud: preferPlatformCloud,
    );
    try {
      await PlatformAuditLogService.instance.log(
        action: 'subscription_set',
        schoolId: record.id,
        schoolName: record.name,
        detail: expiry?.toIso8601String(),
      );
    } catch (_) {}
    return cloud;
  }

  Future<PlatformSchoolCloudResult> renewSubscription(
    String schoolId, {
    required int days,
    bool preferPlatformCloud = false,
  }) async {
    final record = lookup(schoolId);
    if (record == null) {
      return const PlatformSchoolCloudResult(
        ok: false,
        errorCode: 'not_found',
        errorMessage: 'School not found locally.',
      );
    }
    final base = record.subscriptionExpiresAt;
    final now = DateTime.now();
    final start = (base != null && base.isAfter(now)) ? base : now;
    record.subscriptionExpiresAt = start.add(Duration(days: days));
    record.status = SchoolLifecycleStatus.active;
    final cloud = await updateSchool(
      record,
      preferPlatformCloud: preferPlatformCloud,
    );
    try {
      await PlatformAuditLogService.instance.log(
        action: 'subscription_renewed',
        schoolId: record.id,
        schoolName: record.name,
        detail: '+$days days',
      );
    } catch (_) {}
    return cloud;
  }

  Future<void> removeSchool(String schoolId) async {
    final id = schoolId.trim().toUpperCase();
    final record = lookup(id);
    await SchoolLogoService.instance.deleteLogo(id);
    _schools.removeWhere((s) => s.id.toUpperCase() == id);
    await _persist();
    await CloudAppStore.instance.deleteSchool(id);
    if (record != null) {
      await PlatformAuditLogService.instance.log(
        action: 'school_deleted',
        schoolId: record.id,
        schoolName: record.name,
      );
    }
  }

  Future<void> setSchoolLogo(
    String schoolId, {
    String? localPath,
    String? remoteUrl,
    SchoolLogoStyle? style,
  }) async {
    final record = lookup(schoolId);
    if (record == null) return;
    record.logoPath = localPath;
    if (remoteUrl != null) record.logoUrl = remoteUrl;
    if (style != null) record.logoStyle = style;
    await updateSchool(record);
    try {
      await PlatformAuditLogService.instance.log(
        action: 'logo_updated',
        schoolId: record.id,
        schoolName: record.name,
        detail: style?.label,
      );
    } catch (_) {}
  }

  Future<void> clearSchoolLogo(String schoolId) async {
    await SchoolLogoService.instance.deleteLogo(schoolId);
    final record = lookup(schoolId);
    if (record == null) return;
    record.logoPath = null;
    record.logoUrl = null;
    await updateSchool(record);
    try {
      await PlatformAuditLogService.instance.log(
        action: 'logo_removed',
        schoolId: record.id,
        schoolName: record.name,
      );
    } catch (_) {}
  }

  Future<void> setContractedSeats(String schoolId, int? seats) async {
    final record = lookup(schoolId);
    if (record == null) return;
    record.contractedSeats = seats;
    await updateSchool(record);
  }

  List<String> sectionsForSchool(String? schoolId) {
    return lookup(schoolId)?.sections ?? [];
  }

  List<String> sectionLabelsForGrade(String? schoolId, String grade) {
    if (schoolId == null) return [];
    final g = grade.trim();
    return lookup(schoolId)
            ?.sections
            .where((className) => className.startsWith(g))
            .map((className) => _sectionLabel(className, g))
            .toList() ??
        [];
  }

  Future<bool> addSectionForGrade({
    required String schoolId,
    required String grade,
    required String section,
  }) async {
    final record = lookup(schoolId);
    if (record == null) return false;
    final className = StudentRegistryService.buildClassName(grade, section);
    final sections = List<String>.from(record.sections);
    if (sections.contains(className)) return true;
    sections.add(className);
    await updateSchool(record.copyWith(sections: sections));
    return true;
  }

  static String _sectionLabel(String className, String grade) {
    if (className.length > grade.length) {
      return className.substring(grade.length).trim();
    }
    return className;
  }
}
