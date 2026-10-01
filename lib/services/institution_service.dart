import 'package:flutter/foundation.dart';

import 'package:mayabela/models/institution_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/persistence/institution_persistence_service.dart';
import 'package:mayabela/services/school_registry_service.dart';

/// Phase 1 Institutional Management register — local + cloud snapshot.
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

  ({
    int activePolicies,
    int expiringLicenses,
    int expiredLicenses,
    int openResolutions,
    int overdueResolutions,
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
    return (
      activePolicies: rec.policies
          .where((p) => p.status == PolicyStatus.active)
          .length,
      expiringLicenses: expiring,
      expiredLicenses: expired,
      openResolutions: open,
      overdueResolutions: overdue,
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
