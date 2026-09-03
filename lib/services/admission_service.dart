import 'package:flutter/foundation.dart';

import 'package:mayabela/models/admission_application.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/persistence/admission_persistence_service.dart';
import 'package:mayabela/services/persistence/student_persistence_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/utils/short_registry_id.dart';

/// Admissions desk: inquiry through enrollment, plus funnel analytics.
class AdmissionService extends ChangeNotifier {
  AdmissionService._();
  static final instance = AdmissionService._();

  final List<AdmissionApplication> _items = [];
  bool _loaded = false;

  List<AdmissionApplication> get all => List.unmodifiable(_items);

  @visibleForTesting
  static void resetForTests() {
    instance._items.clear();
    instance._loaded = true;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    await AdmissionPersistenceService.instance.loadIntoService();
  }

  List<AdmissionApplication> forSchool(String? schoolId) {
    final sid = schoolId?.trim().toUpperCase();
    if (sid == null || sid.isEmpty) return all;
    return _items.where((a) => a.schoolId == sid).toList();
  }

  AdmissionApplication? byId(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<AdmissionApplication> createInquiry({
    required String fullName,
    String gradeApplying = '',
    String campus = '',
    DateTime? dateOfBirth,
    String? gender,
    String guardianName = '',
    String guardianPhone = '',
    String guardianEmail = '',
    String previousSchool = '',
    String notes = '',
    AdmissionSource source = AdmissionSource.staff,
    AdmissionStage stage = AdmissionStage.inquiry,
    String? schoolId,
  }) async {
    final user = AuthService.currentUser;
    final now = DateTime.now();
    final sid = (schoolId ?? AuthService.activeSchoolId ?? user?.schoolId ?? '')
        .trim()
        .toUpperCase();
    final application = AdmissionApplication(
      id: _allocateId(),
      schoolId: sid,
      fullName: fullName.trim(),
      stage: stage,
      source: source,
      gradeApplying: gradeApplying.trim(),
      campus: campus.trim(),
      dateOfBirth: dateOfBirth,
      gender: gender?.trim(),
      guardianName: guardianName.trim(),
      guardianPhone: guardianPhone.trim(),
      guardianEmail: guardianEmail.trim(),
      previousSchool: previousSchool.trim(),
      notes: notes.trim(),
      documents: AdmissionApplication.defaultDocuments(),
      createdById: user?.username ?? '',
      createdByName: user?.fullName ?? user?.username ?? 'Admissions',
      createdAt: now,
      updatedAt: now,
    );
    _items.insert(0, application);
    notifyListeners();
    await AdmissionPersistenceService.instance.saveFromService();
    return application;
  }

  /// Merge a public/online application that already has an id.
  Future<AdmissionApplication> ingestRemote(AdmissionApplication incoming) async {
    final index = _items.indexWhere((a) => a.id == incoming.id);
    if (index >= 0) {
      final existing = _items[index];
      if (incoming.updatedAt.isAfter(existing.updatedAt)) {
        _items[index] = incoming;
      }
    } else {
      _items.insert(0, incoming);
    }
    notifyListeners();
    await AdmissionPersistenceService.instance.saveFromService(pushCloud: false);
    return byId(incoming.id) ?? incoming;
  }

  Future<AdmissionApplication?> update(
    String id,
    AdmissionApplication Function(AdmissionApplication current) mutate,
  ) async {
    final index = _items.indexWhere((a) => a.id == id);
    if (index < 0) return null;
    _items[index] = mutate(_items[index]).copyWith(updatedAt: DateTime.now());
    notifyListeners();
    await AdmissionPersistenceService.instance.saveFromService();
    return _items[index];
  }

  Future<AdmissionApplication?> moveTo(
    String id,
    AdmissionStage next, {
    String reason = '',
  }) async {
    final current = byId(id);
    if (current == null) return null;
    if (!current.canMoveTo(next)) return current;
    if (next == AdmissionStage.documentsVerified &&
        !current.documentsComplete) {
      return current;
    }
    return update(id, (a) {
      var nextApp = a.copyWith(stage: next, decisionReason: reason);
      if (next == AdmissionStage.offered) {
        nextApp = nextApp.copyWith(
          offerSentAt: DateTime.now(),
          offerExpiresAt: DateTime.now().add(const Duration(days: 14)),
        );
      }
      return nextApp;
    });
  }

  Future<AdmissionApplication?> setDocument(
    String applicationId,
    String documentId, {
    bool? submitted,
    bool? verified,
    String? notes,
  }) {
    return update(applicationId, (a) {
      final docs = [
        for (final d in a.documents)
          if (d.id == documentId)
            d.copyWith(
              submitted: submitted,
              verified: verified,
              notes: notes,
            )
          else
            d,
      ];
      var stage = a.stage;
      if (docs.isNotEmpty &&
          docs.every((d) => d.verified) &&
          (stage == AdmissionStage.application ||
              stage == AdmissionStage.documentsPending)) {
        stage = AdmissionStage.documentsVerified;
      } else if (stage == AdmissionStage.inquiry ||
          stage == AdmissionStage.application) {
        stage = AdmissionStage.documentsPending;
      }
      return a.copyWith(documents: docs, stage: stage);
    });
  }

  Future<AdmissionApplication?> recordExam(
    String id, {
    DateTime? examDate,
    double? score,
    double? maxScore,
    String notes = '',
  }) {
    return update(id, (a) {
      var stage = a.stage;
      if (score != null) {
        stage = AdmissionStage.examScored;
      } else if (examDate != null) {
        stage = AdmissionStage.examScheduled;
      }
      return a.copyWith(
        examDate: examDate ?? a.examDate,
        examScore: score ?? a.examScore,
        examMaxScore: maxScore ?? a.examMaxScore,
        examNotes: notes.trim().isEmpty ? a.examNotes : notes.trim(),
        stage: stage,
      );
    });
  }

  Future<AdmissionApplication?> placeOnWaitlist(String id, {int? rank}) {
    return update(
      id,
      (a) => a.copyWith(
        stage: AdmissionStage.waitlist,
        waitlistRank: rank ?? a.waitlistRank ?? _nextWaitlistRank(a.schoolId),
      ),
    );
  }

  /// Convert an accepted (or offered) application into a student registry row.
  Future<AdminStudentRecord?> enroll(
    String id, {
    required String className,
    String? campus,
    String? grade,
  }) async {
    final app = byId(id);
    if (app == null) return null;
    if (app.stage != AdmissionStage.accepted &&
        app.stage != AdmissionStage.offered) {
      return null;
    }
    if (app.enrolledStudentId != null && app.enrolledStudentId!.isNotEmpty) {
      return StudentRegistryService.instance.lookupById(app.enrolledStudentId!);
    }

    final student = StudentRegistryService.instance.addStudent(
      schoolId: app.schoolId,
      fullName: app.fullName,
      grade: (grade ?? app.gradeApplying).trim(),
      className: className.trim(),
      dateOfBirth: app.dateOfBirth ?? DateTime(2015, 1, 1),
      gender: app.gender,
      guardianName: app.guardianName,
      guardianPhone: app.guardianPhone,
      campus: campus ?? app.campus,
      emergencyContact: app.guardianPhone,
    );
    await StudentPersistenceService.instance.saveRegistryFromService(
      syncStudentId: student.studentId,
    );
    await update(
      id,
      (a) => a.copyWith(
        stage: AdmissionStage.enrolled,
        enrolledStudentId: student.studentId,
        enrolledClassName: student.className,
        enrolledAt: DateTime.now(),
      ),
    );
    return student;
  }

  Map<AdmissionStage, int> funnelCounts(String? schoolId) {
    final counts = {for (final s in AdmissionApplication.funnelStages) s: 0};
    for (final item in forSchool(schoolId)) {
      counts[item.stage] = (counts[item.stage] ?? 0) + 1;
    }
    return counts;
  }

  int openCount(String? schoolId) =>
      forSchool(schoolId).where((a) => a.isOpen).length;

  int waitlistCount(String? schoolId) => forSchool(schoolId)
      .where((a) => a.stage == AdmissionStage.waitlist)
      .length;

  int enrolledThisYear(String? schoolId) {
    final year = DateTime.now().year;
    return forSchool(schoolId).where((a) {
      if (a.stage != AdmissionStage.enrolled) return false;
      final at = a.enrolledAt ?? a.updatedAt;
      return at.year == year;
    }).length;
  }

  void applyPersistedData(
    List<AdmissionApplication> items, {
    bool merge = false,
  }) {
    if (!merge) {
      _items
        ..clear()
        ..addAll(items);
    } else {
      final byId = {for (final a in _items) a.id: a};
      for (final incoming in items) {
        final existing = byId[incoming.id];
        if (existing == null ||
            incoming.updatedAt.isAfter(existing.updatedAt)) {
          byId[incoming.id] = incoming;
        }
      }
      _items
        ..clear()
        ..addAll(byId.values);
    }
    _items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _loaded = true;
    notifyListeners();
  }

  List<Map<String, dynamic>> snapshotMaps() =>
      _items.map((a) => a.toMap()).toList();

  int _nextWaitlistRank(String schoolId) {
    var max = 0;
    for (final item in forSchool(schoolId)) {
      if (item.stage != AdmissionStage.waitlist) continue;
      final rank = item.waitlistRank ?? 0;
      if (rank > max) max = rank;
    }
    return max + 1;
  }

  String _allocateId() {
    return ShortRegistryId.allocate(
      prefix: 'APP',
      existingIds: _items.map((a) => a.id),
      isTaken: (id) => _items.any((a) => a.id == id),
    );
  }
}
