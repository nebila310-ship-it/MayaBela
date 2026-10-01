import 'package:flutter/foundation.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/institution_models.dart';
import 'package:mayabela/models/message.dart';
import 'package:mayabela/services/admin_registry_service.dart';
import 'package:mayabela/models/school_logo_style.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/employee_registry_service.dart';
import 'package:mayabela/services/login_prefs_service.dart';
import 'package:mayabela/services/persistence/institution_persistence_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

/// Institutional Management register — local + cloud snapshot.
class InstitutionService extends ChangeNotifier {
  InstitutionService._();
  static final instance = InstitutionService._();

  final Map<String, InstitutionRecord> _bySchool = {};
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    await InstitutionPersistenceService.instance.loadIntoService();
  }

  @visibleForTesting
  void resetForTests() {
    _bySchool.clear();
    _loaded = true;
  }

  String? get _schoolId {
    final sid = (AuthService.activeSchoolId ?? '').trim().toUpperCase();
    return sid.isEmpty ? null : sid;
  }

  /// Teachers plus HR employees for the school, keyed by their IDs.
  /// An HR row is skipped when a teacher already uses that employeeId.
  List<InstitutionStaffMember> staffDirectory(String? schoolId) {
    final sid = (schoolId ?? _schoolId ?? '').trim().toUpperCase();
    if (sid.isEmpty) return const [];
    final teachers = TeacherRegistryService.instance.teachersForSchool(sid);
    final linkedEmployeeIds = <String>{
      for (final teacher in teachers)
        if ((teacher.employeeId ?? '').trim().isNotEmpty)
          teacher.employeeId!.trim().toUpperCase(),
    };
    final staff = <InstitutionStaffMember>[
      for (final teacher in teachers)
        InstitutionStaffMember(
          kind: InstitutionStaffKind.teacher,
          personId: teacher.teacherId,
          name: teacher.fullName,
          title: teacher.subject,
        ),
    ];
    for (final employee in EmployeeRegistryService.instance.employeesForSchool(
      sid,
    )) {
      if (linkedEmployeeIds.contains(employee.employeeId.toUpperCase())) {
        continue;
      }
      staff.add(
        InstitutionStaffMember(
          kind: InstitutionStaffKind.employee,
          personId: employee.employeeId,
          name: employee.fullName,
          title: employee.jobTitle,
        ),
      );
    }
    for (final admin in AdminRegistryService.instance.getAllAdmins()) {
      if (admin.schoolId.trim().toUpperCase() != sid) continue;
      staff.add(
        InstitutionStaffMember(
          kind: InstitutionStaffKind.admin,
          personId: admin.adminId,
          name: admin.fullName,
          title: admin.position,
        ),
      );
    }
    staff.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return staff;
  }

  String? messagingStaffIdFor(InstitutionStaffMember member) {
    return switch (member.kind) {
      InstitutionStaffKind.teacher => StaffMemberOption.teacherKey(
        member.personId,
      ),
      InstitutionStaffKind.admin => StaffMemberOption.adminKey(member.personId),
      InstitutionStaffKind.employee => null,
    };
  }

  /// Sends a formal invitation to newly added teachers and administrative
  /// staff via in-app Messages. HR-only employees stay on the attendance list.
  Future<int> deliverMeetingInvites(
    InstitutionMeeting meeting, {
    String? schoolId,
  }) async {
    final sid = (schoolId ?? _schoolId ?? '').trim().toUpperCase();
    if (sid.isEmpty) return 0;
    final already = meeting.invitedKeys.toSet();
    final me = StaffMemberOption.viewerCompositeStaffId(
      AuthService.currentUser?.roleKey,
    );
    final senderName =
        AuthService.currentUser?.fullName?.trim().isNotEmpty == true
        ? AuthService.currentUser!.fullName!.trim()
        : AuthService.displayNameForRole(
            AuthService.currentUser?.roleKey ?? AuthService.roleAdmin,
          );
    final schoolName = displayNameFor(sid);
    final attachments = [
      for (final path in meeting.attachmentPaths)
        if (path.trim().isNotEmpty)
          AnnouncementAttachment(
            id: path,
            fileName: _fileName(path),
            filePath: path,
          ),
    ];
    final sentKeys = <String>[];
    final skipKeys = <String>[];
    for (final member in meeting.invitees) {
      if (already.contains(member.key)) continue;
      final staffId = messagingStaffIdFor(member);
      if (staffId == null) continue;
      if (me != null && StaffMemberOption.idsEqual(me, staffId)) {
        skipKeys.add(member.key);
        continue;
      }
      final ids = SchoolDataService.instance.sendAdminDirectMessage(
        body: meeting.invitationText(
          toName: member.name,
          schoolName: schoolName,
          senderName: senderName,
        ),
        subject: 'Meeting invitation: ${meeting.title}',
        staffId: staffId,
        attachments: attachments,
      );
      if (ids.isNotEmpty) sentKeys.add(member.key);
    }
    if (sentKeys.isEmpty && skipKeys.isEmpty) return 0;
    await upsertMeeting(
      meeting.copyWith(invitedKeys: [...already, ...sentKeys, ...skipKeys]),
      schoolId: sid,
    );
    return sentKeys.length;
  }

  /// Sends a formal circular notice to teachers and/or administrative staff
  /// in Messages, matching the circular audience.
  Future<int> deliverCircularNotices(
    OfficialCircular circular, {
    String? schoolId,
  }) async {
    final sid = (schoolId ?? _schoolId ?? '').trim().toUpperCase();
    if (sid.isEmpty) return 0;
    final already = circular.deliveredKeys.toSet();
    final me = StaffMemberOption.viewerCompositeStaffId(
      AuthService.currentUser?.roleKey,
    );
    final senderName =
        AuthService.currentUser?.fullName?.trim().isNotEmpty == true
        ? AuthService.currentUser!.fullName!.trim()
        : AuthService.displayNameForRole(
            AuthService.currentUser?.roleKey ?? AuthService.roleAdmin,
          );
    final schoolName = displayNameFor(sid);
    final attachments = [
      for (final path in circular.attachmentPaths)
        if (path.trim().isNotEmpty)
          AnnouncementAttachment(
            id: path,
            fileName: _fileName(path),
            filePath: path,
          ),
    ];
    final sentKeys = <String>[];
    final skipKeys = <String>[];
    for (final member in staffDirectory(sid)) {
      if (!circular.includesKind(member.kind)) continue;
      if (already.contains(member.key)) continue;
      final staffId = messagingStaffIdFor(member);
      if (staffId == null) continue;
      if (me != null && StaffMemberOption.idsEqual(me, staffId)) {
        skipKeys.add(member.key);
        continue;
      }
      final ids = SchoolDataService.instance.sendAdminDirectMessage(
        body: circular.noticeText(
          toName: member.name,
          schoolName: schoolName,
          senderName: senderName,
        ),
        subject: circular.number.trim().isEmpty
            ? 'Official circular: ${circular.title}'
            : 'Official circular ${circular.number}: ${circular.title}',
        staffId: staffId,
        attachments: attachments,
      );
      if (ids.isNotEmpty) sentKeys.add(member.key);
    }
    if (sentKeys.isEmpty && skipKeys.isEmpty) return 0;
    await upsertCircular(
      circular.copyWith(deliveredKeys: [...already, ...sentKeys, ...skipKeys]),
      schoolId: sid,
    );
    return sentKeys.length;
  }

  String _fileName(String path) {
    final parts = path.replaceAll('\\', '/').split('/');
    return parts.isEmpty || parts.last.isEmpty ? path : parts.last;
  }

  /// Trading / display name from a *saved* Institutional Management profile.
  /// [schoolId] must be explicit so compact headers without an id stay empty.
  /// Seeded unsaved records are ignored so locale defaults stay until save.
  String? savedPublicName(String? schoolId) {
    final sid = (schoolId ?? '').trim().toUpperCase();
    if (sid.isEmpty) return null;
    final rec = _bySchool[sid];
    if (rec == null) return null;
    final trading = rec.profile.tradingName.trim();
    if (trading.isNotEmpty) return trading;
    final legal = rec.profile.legalName.trim();
    if (legal.isNotEmpty) return legal;
    return null;
  }

  /// School name shown on role dashboards after an IM profile save.
  String displayNameFor(String? schoolId, {String? fallback}) {
    final saved = savedPublicName(schoolId);
    if (saved != null) return saved;
    final trimmed = fallback?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
    final registry = SchoolRegistryService.instance
        .lookup(schoolId)
        ?.name
        .trim();
    if (registry != null && registry.isNotEmpty) return registry;
    return SchoolRegistryService.instance.displayName(schoolId);
  }

  InstitutionRecord recordFor(String? schoolId) {
    final sid = (schoolId ?? _schoolId ?? '').trim().toUpperCase();
    if (sid.isEmpty) {
      return InstitutionRecord(
        schoolId: '',
        profile: const InstitutionProfile(),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
    }
    final existing = _bySchool[sid];
    if (existing != null) return existing;
    final school = SchoolRegistryService.instance.lookup(sid);
    return InstitutionRecord(
      schoolId: sid,
      profile: InstitutionProfile(
        legalName: school?.name ?? '',
        tradingName: school?.name ?? '',
        operatingAddress: school?.address ?? '',
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Future<InstitutionRecord> _mutate(
    String? schoolId,
    InstitutionRecord Function(InstitutionRecord current) update,
  ) async {
    final sid = (schoolId ?? _schoolId ?? '').trim().toUpperCase();
    if (sid.isEmpty) {
      throw StateError('No active school.');
    }
    final next = update(recordFor(sid)).copyWith(updatedAt: DateTime.now());
    _bySchool[sid] = next;
    notifyListeners();
    await InstitutionPersistenceService.instance.saveFromService();
    return next;
  }

  Future<InstitutionRecord> saveProfile(
    InstitutionProfile profile, {
    String? schoolId,
  }) async {
    final next = await _mutate(
      schoolId,
      (current) => current.copyWith(profile: profile),
    );
    await _syncDashboardSchoolName(next);
    return next;
  }

  Future<void> _syncDashboardSchoolName(InstitutionRecord rec) async {
    final name = savedPublicName(rec.schoolId);
    if (name == null) return;
    final school = SchoolRegistryService.instance.lookup(rec.schoolId);
    // In-memory only. Do not persist or push the full school row — that
    // overwrites academic year, campuses, modules, and other ERP settings.
    if (school != null && school.name != name) {
      school.name = name;
    }
    try {
      await LoginPrefsService.instance.rememberSchoolBrand(
        schoolId: rec.schoolId,
        name: name,
        logoUrl: school?.logoUrl,
        logoPath: school?.logoPath,
        logoStyle: school?.logoStyle ?? SchoolLogoStyle.rectangular,
      );
    } catch (_) {}
  }

  Future<InstitutionRecord> upsertLeadership(
    LeadershipSeat seat, {
    String? schoolId,
  }) {
    return _mutate(schoolId, (current) {
      final next = [...current.leadership];
      final i = next.indexWhere((e) => e.id == seat.id);
      if (i < 0) {
        next.insert(0, seat);
      } else {
        next[i] = seat;
      }
      return current.copyWith(leadership: next);
    });
  }

  Future<InstitutionRecord> deleteLeadership(String id, {String? schoolId}) {
    return _mutate(
      schoolId,
      (current) => current.copyWith(
        leadership: current.leadership.where((e) => e.id != id).toList(),
      ),
    );
  }

  Future<InstitutionRecord> upsertOrgUnit(OrgUnit unit, {String? schoolId}) {
    return _mutate(schoolId, (current) {
      final next = [...current.orgUnits];
      final i = next.indexWhere((e) => e.id == unit.id);
      if (i < 0) {
        next.insert(0, unit);
      } else {
        next[i] = unit;
      }
      return current.copyWith(orgUnits: next);
    });
  }

  Future<InstitutionRecord> deleteOrgUnit(String id, {String? schoolId}) {
    return _mutate(
      schoolId,
      (current) => current.copyWith(
        orgUnits: current.orgUnits.where((e) => e.id != id).toList(),
      ),
    );
  }

  Future<InstitutionRecord> upsertSite(
    InstitutionSite site, {
    String? schoolId,
  }) {
    return _mutate(schoolId, (current) {
      var next = [...current.sites];
      if (site.isHeadquarters) {
        next = [
          for (final row in next)
            row.id == site.id ? site : row.copyWith(isHeadquarters: false),
        ];
      }
      final i = next.indexWhere((e) => e.id == site.id);
      if (i < 0) {
        next.insert(0, site);
      } else {
        next[i] = site;
      }
      return current.copyWith(sites: next);
    });
  }

  Future<InstitutionRecord> deleteSite(String id, {String? schoolId}) {
    return _mutate(
      schoolId,
      (current) => current.copyWith(
        sites: current.sites.where((e) => e.id != id).toList(),
      ),
    );
  }

  Future<InstitutionRecord> upsertPolicy(
    InstitutionPolicy policy, {
    String? schoolId,
  }) {
    return _mutate(schoolId, (current) {
      final next = [...current.policies];
      final i = next.indexWhere((e) => e.id == policy.id);
      if (i < 0) {
        next.insert(0, policy);
      } else {
        next[i] = policy;
      }
      return current.copyWith(policies: next);
    });
  }

  Future<InstitutionRecord> deletePolicy(String id, {String? schoolId}) {
    return _mutate(
      schoolId,
      (current) => current.copyWith(
        policies: current.policies.where((e) => e.id != id).toList(),
      ),
    );
  }

  Future<InstitutionRecord> upsertCircular(
    OfficialCircular circular, {
    String? schoolId,
  }) {
    return _mutate(schoolId, (current) {
      final next = [...current.circulars];
      final i = next.indexWhere((e) => e.id == circular.id);
      if (i < 0) {
        next.insert(0, circular);
      } else {
        next[i] = circular;
      }
      return current.copyWith(circulars: next);
    });
  }

  Future<InstitutionRecord> deleteCircular(String id, {String? schoolId}) {
    return _mutate(
      schoolId,
      (current) => current.copyWith(
        circulars: current.circulars.where((e) => e.id != id).toList(),
      ),
    );
  }

  Future<InstitutionRecord> upsertLicense(
    InstitutionLicense license, {
    String? schoolId,
  }) {
    return _mutate(schoolId, (current) {
      final next = [...current.licenses];
      final i = next.indexWhere((e) => e.id == license.id);
      if (i < 0) {
        next.insert(0, license);
      } else {
        next[i] = license;
      }
      return current.copyWith(licenses: next);
    });
  }

  Future<InstitutionRecord> deleteLicense(String id, {String? schoolId}) {
    return _mutate(
      schoolId,
      (current) => current.copyWith(
        licenses: current.licenses.where((e) => e.id != id).toList(),
      ),
    );
  }

  Future<InstitutionRecord> upsertResolution(
    InstitutionResolution resolution, {
    String? schoolId,
  }) {
    return _mutate(schoolId, (current) {
      final next = [...current.resolutions];
      final i = next.indexWhere((e) => e.id == resolution.id);
      if (i < 0) {
        next.insert(0, resolution);
      } else {
        next[i] = resolution;
      }
      return current.copyWith(resolutions: next);
    });
  }

  Future<InstitutionRecord> deleteResolution(String id, {String? schoolId}) {
    return _mutate(
      schoolId,
      (current) => current.copyWith(
        resolutions: current.resolutions.where((e) => e.id != id).toList(),
      ),
    );
  }

  Future<InstitutionRecord> upsertCommittee(
    InstitutionCommittee committee, {
    String? schoolId,
  }) {
    return _mutate(schoolId, (current) {
      final next = [...current.committees];
      final i = next.indexWhere((e) => e.id == committee.id);
      if (i < 0) {
        next.insert(0, committee);
      } else {
        next[i] = committee;
      }
      return current.copyWith(committees: next);
    });
  }

  Future<InstitutionRecord> deleteCommittee(String id, {String? schoolId}) {
    return _mutate(
      schoolId,
      (current) => current.copyWith(
        committees: current.committees.where((e) => e.id != id).toList(),
      ),
    );
  }

  Future<InstitutionRecord> upsertMeeting(
    InstitutionMeeting meeting, {
    String? schoolId,
  }) {
    return _mutate(schoolId, (current) {
      final next = [...current.meetings];
      final i = next.indexWhere((e) => e.id == meeting.id);
      if (i < 0) {
        next.insert(0, meeting);
      } else {
        next[i] = meeting;
      }
      return current.copyWith(meetings: next);
    });
  }

  Future<InstitutionRecord> deleteMeeting(String id, {String? schoolId}) {
    return _mutate(
      schoolId,
      (current) => current.copyWith(
        meetings: current.meetings.where((e) => e.id != id).toList(),
      ),
    );
  }

  Future<InstitutionRecord> upsertRisk(
    InstitutionRisk risk, {
    String? schoolId,
  }) {
    return _mutate(schoolId, (current) {
      final next = [...current.risks];
      final i = next.indexWhere((e) => e.id == risk.id);
      if (i < 0) {
        next.insert(0, risk);
      } else {
        next[i] = risk;
      }
      return current.copyWith(risks: next);
    });
  }

  Future<InstitutionRecord> deleteRisk(String id, {String? schoolId}) {
    return _mutate(
      schoolId,
      (current) => current.copyWith(
        risks: current.risks.where((e) => e.id != id).toList(),
      ),
    );
  }

  Future<InstitutionRecord> upsertPartner(
    InstitutionPartner partner, {
    String? schoolId,
  }) {
    return _mutate(schoolId, (current) {
      final next = [...current.partners];
      final i = next.indexWhere((e) => e.id == partner.id);
      if (i < 0) {
        next.insert(0, partner);
      } else {
        next[i] = partner;
      }
      return current.copyWith(partners: next);
    });
  }

  Future<InstitutionRecord> deletePartner(String id, {String? schoolId}) {
    return _mutate(
      schoolId,
      (current) => current.copyWith(
        partners: current.partners.where((e) => e.id != id).toList(),
      ),
    );
  }

  Future<InstitutionRecord> upsertSef(
    InstitutionSefEntry entry, {
    String? schoolId,
  }) {
    return _mutate(schoolId, (current) {
      final next = [...current.sefEntries];
      final i = next.indexWhere((e) => e.id == entry.id);
      if (i < 0) {
        next.insert(0, entry);
      } else {
        next[i] = entry;
      }
      return current.copyWith(sefEntries: next);
    });
  }

  Future<InstitutionRecord> deleteSef(String id, {String? schoolId}) {
    return _mutate(
      schoolId,
      (current) => current.copyWith(
        sefEntries: current.sefEntries.where((e) => e.id != id).toList(),
      ),
    );
  }

  Future<InstitutionRecord> upsertCapa(
    InstitutionCapa capa, {
    String? schoolId,
  }) {
    return _mutate(schoolId, (current) {
      final next = [...current.capas];
      final i = next.indexWhere((e) => e.id == capa.id);
      if (i < 0) {
        next.insert(0, capa);
      } else {
        next[i] = capa;
      }
      return current.copyWith(capas: next);
    });
  }

  Future<InstitutionRecord> deleteCapa(String id, {String? schoolId}) {
    return _mutate(
      schoolId,
      (current) => current.copyWith(
        capas: current.capas.where((e) => e.id != id).toList(),
      ),
    );
  }

  Future<InstitutionRecord> upsertKpi(InstitutionKpi kpi, {String? schoolId}) {
    return _mutate(schoolId, (current) {
      final next = [...current.kpis];
      final i = next.indexWhere((e) => e.id == kpi.id);
      if (i < 0) {
        next.insert(0, kpi);
      } else {
        next[i] = kpi;
      }
      return current.copyWith(kpis: next);
    });
  }

  Future<InstitutionRecord> deleteKpi(String id, {String? schoolId}) {
    return _mutate(
      schoolId,
      (current) => current.copyWith(
        kpis: current.kpis.where((e) => e.id != id).toList(),
      ),
    );
  }

  Future<InstitutionRecord> upsertProperty(
    InstitutionProperty property, {
    String? schoolId,
  }) {
    return _mutate(schoolId, (current) {
      final next = [...current.properties];
      final i = next.indexWhere((e) => e.id == property.id);
      if (i < 0) {
        next.insert(0, property);
      } else {
        next[i] = property;
      }
      return current.copyWith(properties: next);
    });
  }

  Future<InstitutionRecord> deleteProperty(String id, {String? schoolId}) {
    return _mutate(
      schoolId,
      (current) => current.copyWith(
        properties: current.properties.where((e) => e.id != id).toList(),
      ),
    );
  }

  Future<InstitutionRecord> upsertArchive(
    InstitutionArchiveItem item, {
    String? schoolId,
  }) {
    return _mutate(schoolId, (current) {
      final next = [...current.archive];
      final i = next.indexWhere((e) => e.id == item.id);
      if (i < 0) {
        next.insert(0, item);
      } else {
        next[i] = item;
      }
      return current.copyWith(archive: next);
    });
  }

  Future<InstitutionRecord> deleteArchive(String id, {String? schoolId}) {
    return _mutate(
      schoolId,
      (current) => current.copyWith(
        archive: current.archive.where((e) => e.id != id).toList(),
      ),
    );
  }

  ({
    int activePolicies,
    int expiringLicenses,
    int expiredLicenses,
    int openResolutions,
    int overdueResolutions,
    int activeCommittees,
    int openRisks,
    int risksDueSoon,
    int activePartners,
    int openCapas,
    int overdueCapas,
    int kpisOffTrack,
    int retentionLapsed,
  })
  metricsFor(String? schoolId) {
    final rec = recordFor(schoolId);
    var expiring = 0, expired = 0;
    for (final license in rec.licenses) {
      switch (license.health) {
        case LicenseHealth.expiring:
          expiring++;
        case LicenseHealth.expired:
          expired++;
        case LicenseHealth.valid:
        case LicenseHealth.none:
          break;
      }
    }
    var open = 0, overdue = 0;
    for (final row in rec.resolutions) {
      if (row.isOpen) open++;
      if (row.isOverdue) overdue++;
    }
    var openRisks = 0, risksDueSoon = 0;
    for (final risk in rec.risks) {
      if (risk.isOpen) openRisks++;
      if (risk.reviewDueSoon) risksDueSoon++;
    }
    var openCapas = 0, overdueCapas = 0;
    for (final row in rec.capas) {
      if (row.isOpen) openCapas++;
      if (row.isOverdue) overdueCapas++;
    }
    return (
      activePolicies: rec.policies
          .where((p) => p.status == PolicyStatus.active)
          .length,
      expiringLicenses: expiring,
      expiredLicenses: expired,
      openResolutions: open,
      overdueResolutions: overdue,
      activeCommittees: rec.committees
          .where((c) => c.status == CommitteeStatus.active)
          .length,
      openRisks: openRisks,
      risksDueSoon: risksDueSoon,
      activePartners: rec.partners
          .where((p) => p.status == PartnerStatus.active)
          .length,
      openCapas: openCapas,
      overdueCapas: overdueCapas,
      kpisOffTrack: rec.kpis
          .where((k) => k.status == KpiStatus.offTrack)
          .length,
      retentionLapsed: rec.archive.where((a) => a.retentionLapsed).length,
    );
  }

  void applyPersistedData(List<InstitutionRecord> items, {bool merge = false}) {
    if (!merge) {
      _bySchool
        ..clear()
        ..addEntries(items.map((e) => MapEntry(e.schoolId, e)));
    } else {
      for (final incoming in items) {
        final existing = _bySchool[incoming.schoolId];
        if (existing == null ||
            incoming.updatedAt.isAfter(existing.updatedAt)) {
          _bySchool[incoming.schoolId] = incoming;
        }
      }
    }
    _loaded = true;
    notifyListeners();
  }

  List<Map<String, dynamic>> snapshotMaps() =>
      _bySchool.values.map((e) => e.toMap()).toList();

  static String newId(String prefix) =>
      '$prefix-${DateTime.now().millisecondsSinceEpoch}';
}
