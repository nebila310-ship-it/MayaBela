import 'package:flutter/foundation.dart';

import 'package:mayabela/models/lesson_plan_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/persistence/lesson_plan_persistence_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/utils/short_registry_id.dart';

/// Weekly lesson plans. Does not write grades, exams, or admissions scores.
class LessonPlanService extends ChangeNotifier {
  LessonPlanService._();
  static final instance = LessonPlanService._();

  final List<LessonPlan> _plans = [];
  bool _loaded = false;

  List<LessonPlan> get plans => List.unmodifiable(_plans);

  @visibleForTesting
  static void resetForTests() {
    instance._plans.clear();
    instance._loaded = true;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    await LessonPlanPersistenceService.instance.loadIntoService();
  }

  String get _schoolId =>
      (AuthService.activeSchoolId ?? AuthService.currentUser?.schoolId ?? '')
          .trim()
          .toUpperCase();

  bool get _isPublicReader =>
      AuthService.currentUser?.roleKey == AuthService.roleStudent ||
      AuthService.currentUser?.roleKey == AuthService.roleParent;

  List<LessonPlan> forSchool([String? schoolId]) {
    final sid = (schoolId ?? _schoolId).toUpperCase();
    final list = sid.isEmpty
        ? _plans.toList()
        : _plans.where((p) => p.schoolId == sid).toList();
    if (_isPublicReader) {
      return list.where((p) => p.isPublished).toList();
    }
    return list;
  }

  List<LessonPlan> publishedForClass(String className, {String? schoolId}) {
    return forSchool(schoolId)
        .where(
          (p) =>
              StudentRegistryService.classNamesMatch(p.className, className) &&
              p.isPublished,
        )
        .toList()
      ..sort((a, b) => b.weekStart.compareTo(a.weekStart));
  }

  List<LessonPlan> forClass(String className, {String? schoolId}) {
    return forSchool(schoolId)
        .where(
          (p) => StudentRegistryService.classNamesMatch(p.className, className),
        )
        .toList()
      ..sort((a, b) => b.weekStart.compareTo(a.weekStart));
  }

  LessonPlan? planById(String id) {
    for (final p in _plans) {
      if (p.id == id) return p;
    }
    return null;
  }

  int draftCount([String? schoolId]) =>
      forSchool(schoolId).where((p) => p.status == LessonPlanStatus.draft).length;

  Future<LessonPlan> createPlan({
    required String title,
    required String className,
    required String subject,
    DateTime? weekStart,
    String objectives = '',
    String activities = '',
    List<String> homeworkIds = const [],
    List<String> examPaperIds = const [],
    List<String> learningMaterialIds = const [],
    List<String> attachmentPaths = const [],
    String? curriculumUnitId,
    String? schoolId,
  }) async {
    final now = DateTime.now();
    final plan = LessonPlan(
      id: ShortRegistryId.allocate(
        prefix: 'LP',
        existingIds: _plans.map((p) => p.id),
        isTaken: (id) => _plans.any((p) => p.id == id),
      ),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      title: title.trim(),
      className: className.trim(),
      subject: subject.trim(),
      weekStart: LessonPlan.mondayOf(weekStart ?? now),
      objectives: objectives.trim(),
      activities: activities.trim(),
      homeworkIds: List.of(homeworkIds),
      examPaperIds: List.of(examPaperIds),
      learningMaterialIds: List.of(learningMaterialIds),
      attachmentPaths: List.of(attachmentPaths),
      curriculumUnitId: curriculumUnitId,
      createdBy: AuthService.currentUser?.username,
      createdAt: now,
      updatedAt: now,
    );
    _plans.add(plan);
    await _persist();
    return plan;
  }

  Future<LessonPlan?> updatePlan(
    String id, {
    String? title,
    String? className,
    String? subject,
    DateTime? weekStart,
    String? objectives,
    String? activities,
    List<String>? homeworkIds,
    List<String>? examPaperIds,
    List<String>? learningMaterialIds,
    List<String>? attachmentPaths,
    String? curriculumUnitId,
    bool clearCurriculumUnit = false,
  }) async {
    final plan = planById(id);
    if (plan == null) return null;
    if (title != null) plan.title = title.trim();
    if (className != null) plan.className = className.trim();
    if (subject != null) plan.subject = subject.trim();
    if (weekStart != null) plan.weekStart = LessonPlan.mondayOf(weekStart);
    if (objectives != null) plan.objectives = objectives.trim();
    if (activities != null) plan.activities = activities.trim();
    if (homeworkIds != null) plan.homeworkIds = List.of(homeworkIds);
    if (examPaperIds != null) plan.examPaperIds = List.of(examPaperIds);
    if (learningMaterialIds != null) {
      plan.learningMaterialIds = List.of(learningMaterialIds);
    }
    if (attachmentPaths != null) {
      plan.attachmentPaths = List.of(attachmentPaths);
    }
    if (clearCurriculumUnit) {
      plan.curriculumUnitId = null;
    } else if (curriculumUnitId != null) {
      plan.curriculumUnitId = curriculumUnitId;
    }
    plan.updatedAt = DateTime.now();
    await _persist();
    return plan;
  }

  Future<LessonPlan?> applyReview({
    required String id,
    required LessonPlanReviewStatus reviewStatus,
    String? latestReviewId,
  }) async {
    final plan = planById(id);
    if (plan == null) return null;
    plan.reviewStatus = reviewStatus;
    if (latestReviewId != null) plan.latestReviewId = latestReviewId;
    plan.updatedAt = DateTime.now();
    await _persist();
    return plan;
  }

  int pendingReviewCount([String? schoolId]) => forSchool(schoolId)
      .where(
        (p) =>
            p.isPublished &&
            (p.reviewStatus == LessonPlanReviewStatus.none ||
                p.reviewStatus == LessonPlanReviewStatus.pending ||
                p.reviewStatus == LessonPlanReviewStatus.changesRequested),
      )
      .length;

  Future<LessonPlan?> setStatus(String id, LessonPlanStatus status) async {
    final plan = planById(id);
    if (plan == null) return null;
    plan.status = status;
    plan.updatedAt = DateTime.now();
    plan.publishedAt =
        status == LessonPlanStatus.published ? plan.updatedAt : null;
    await _persist();
    return plan;
  }

  void applyPersistedData(List<LessonPlan> incoming, {bool merge = false}) {
    var next = incoming;
    if (_isPublicReader) {
      next = incoming.where((p) => p.isPublished).toList();
    }
    if (!merge) {
      _plans
        ..clear()
        ..addAll(next);
    } else {
      final byId = {for (final p in _plans) p.id: p};
      for (final p in next) {
        byId[p.id] = p;
      }
      if (_isPublicReader) {
        byId.removeWhere((_, p) => !p.isPublished);
      }
      _plans
        ..clear()
        ..addAll(byId.values);
    }
    _loaded = true;
    notifyListeners();
  }

  List<Map<String, dynamic>> snapshotMaps() =>
      _plans.map((p) => p.toMap()).toList();

  Future<void> _persist() async {
    notifyListeners();
    await LessonPlanPersistenceService.instance.saveFromService();
  }
}
