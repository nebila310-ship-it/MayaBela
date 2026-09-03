import 'package:mayabela/models/dosa_models.dart';
import 'package:mayabela/services/dosa_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';

class DosaPersistenceService {
  DosaPersistenceService._();
  static final instance = DosaPersistenceService._();

  static const _clubsKey = 'extracurricular_clubs_v1';
  static const _membershipsKey = 'club_memberships_v1';
  static const _scholarshipsKey = 'scholarships_v1';
  static const _grievancesKey = 'grievances_v1';
  static const _internshipsKey = 'internships_v1';
  static const _meetingsKey = 'dosa_meetings_v1';

  Future<void> loadIntoService() async {
    final clubs = <ExtracurricularClub>[];
    for (final map in await LocalJsonStore.readList(_clubsKey)) {
      try {
        clubs.add(ExtracurricularClub.fromMap(map));
      } catch (_) {}
    }
    final memberships = <ClubMembership>[];
    for (final map in await LocalJsonStore.readList(_membershipsKey)) {
      try {
        memberships.add(ClubMembership.fromMap(map));
      } catch (_) {}
    }
    final scholarships = <ScholarshipRecord>[];
    for (final map in await LocalJsonStore.readList(_scholarshipsKey)) {
      try {
        scholarships.add(ScholarshipRecord.fromMap(map));
      } catch (_) {}
    }
    final grievances = <Grievance>[];
    for (final map in await LocalJsonStore.readList(_grievancesKey)) {
      try {
        grievances.add(Grievance.fromMap(map));
      } catch (_) {}
    }
    final internships = <Internship>[];
    for (final map in await LocalJsonStore.readList(_internshipsKey)) {
      try {
        internships.add(Internship.fromMap(map));
      } catch (_) {}
    }
    final meetings = <DosaMeeting>[];
    for (final map in await LocalJsonStore.readList(_meetingsKey)) {
      try {
        meetings.add(DosaMeeting.fromMap(map));
      } catch (_) {}
    }
    DosaService.instance.applyPersistedData(
      clubs: clubs,
      memberships: memberships,
      scholarships: scholarships,
      grievances: grievances,
      internships: internships,
      meetings: meetings,
    );
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    final svc = DosaService.instance;
    await LocalJsonStore.writeList(_clubsKey, svc.clubMaps());
    await LocalJsonStore.writeList(_membershipsKey, svc.membershipMaps());
    await LocalJsonStore.writeList(_scholarshipsKey, svc.scholarshipMaps());
    await LocalJsonStore.writeList(_grievancesKey, svc.grievanceMaps());
    await LocalJsonStore.writeList(_internshipsKey, svc.internshipMaps());
    await LocalJsonStore.writeList(_meetingsKey, svc.meetingMaps());
    if (pushCloud) {
      await CloudAppStore.instance.pushAllDosa();
    }
  }
}
