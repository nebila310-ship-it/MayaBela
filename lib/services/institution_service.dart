import 'package:flutter/foundation.dart';

import 'package:mayabela/models/institution_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/persistence/institution_persistence_service.dart';
import 'package:mayabela/services/school_registry_service.dart';

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
  }) {
    return _mutate(schoolId, (current) => current.copyWith(profile: profile));
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
