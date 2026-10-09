import 'package:flutter/foundation.dart';

import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/models/lesson_plan_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/persistence/lesson_plan_persistence_service.dart';
import 'package:mayabela/services/profile_photo_codec.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
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

  bool get _restrictTeacherToSubjects {
    if (AuthService.currentUser?.roleKey != AuthService.roleTeacher) {
      return false;
    }
    return TeacherAccessService.instance.teachingAssignments().isNotEmpty;
  }

  bool _teacherMayPrepare(String className, String subject) {
    if (!_restrictTeacherToSubjects) return true;
    return TeacherAccessService.instance.canPrepareLessonPlan(
      className: className,
      subject: subject,
    );
  }

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
    return visibleForCurrentUser(className: className, schoolId: schoolId);
  }

  /// Teachers see only their subjects. Parents/students see published class plans.
  /// Management sees every plan in the school.
  List<LessonPlan> visibleForCurrentUser({
    String? className,
    String? schoolId,
  }) {
    var list = forSchool(schoolId);
    if (className != null) {
      list = list
          .where(
            (p) => StudentRegistryService.classNamesMatch(
              p.className,
              className,
            ),
          )
          .toList();
    }
    if (_restrictTeacherToSubjects) {
      final access = TeacherAccessService.instance;
      list = list
          .where(
            (p) => access.canPrepareLessonPlan(
              className: p.className,
              subject: p.subject,
            ),
          )
          .toList();
    }
    list.sort((a, b) => b.weekStart.compareTo(a.weekStart));
    return list;
  }

  double? averageAchievement({String? className, String? schoolId}) {
    final scored = visibleForCurrentUser(
      className: className,
      schoolId: schoolId,
    ).where((p) => p.achievementPercent != null).toList();
    if (scored.isEmpty) return null;
    final total = scored.fold<int>(0, (sum, p) => sum + p.achievementPercent!);
    return total / scored.length;
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
    String successCriteria = '',
    String keyVocabulary = '',
    String priorKnowledge = '',
    String starter = '',
    String activities = '',
    String plenary = '',
    String differentiation = '',
    String assessment = '',
    String homeLearning = '',
    String inclusionNotes = '',
    int? durationMinutes,
    String periodLabel = '',
    List<String> homeworkIds = const [],
    List<String> examPaperIds = const [],
    List<String> learningMaterialIds = const [],
    List<String> attachmentPaths = const [],
    String? curriculumUnitId,
    String? schoolId,
    String? onlineSessionUrl,
    String? onlineSessionLabel,
    bool onlineSessionIsLive = false,
  }) async {
    if (!_teacherMayPrepare(className, subject)) {
      throw StateError(
        'Teachers can only prepare lesson plans for their own subjects.',
      );
    }
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
      successCriteria: successCriteria.trim(),
      keyVocabulary: keyVocabulary.trim(),
      priorKnowledge: priorKnowledge.trim(),
      starter: starter.trim(),
      activities: activities.trim(),
      plenary: plenary.trim(),
      differentiation: differentiation.trim(),
      assessment: assessment.trim(),
      homeLearning: homeLearning.trim(),
      inclusionNotes: inclusionNotes.trim(),
      durationMinutes: durationMinutes,
      periodLabel: periodLabel.trim(),
      homeworkIds: List.of(homeworkIds),
      examPaperIds: List.of(examPaperIds),
      learningMaterialIds: List.of(learningMaterialIds),
      attachmentPaths: List.of(attachmentPaths),
      curriculumUnitId: curriculumUnitId,
      onlineSessionUrl: onlineSessionUrl?.trim().isEmpty == true
          ? null
          : onlineSessionUrl?.trim(),
      onlineSessionLabel: onlineSessionLabel?.trim().isEmpty == true
          ? null
          : onlineSessionLabel?.trim(),
      onlineSessionIsLive: onlineSessionIsLive,
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
    String? successCriteria,
    String? keyVocabulary,
    String? priorKnowledge,
    String? starter,
    String? activities,
    String? plenary,
    String? differentiation,
    String? assessment,
    String? homeLearning,
    String? inclusionNotes,
    int? durationMinutes,
    bool clearDuration = false,
    String? periodLabel,
    List<String>? homeworkIds,
    List<String>? examPaperIds,
    List<String>? learningMaterialIds,
    List<String>? attachmentPaths,
    String? curriculumUnitId,
    bool clearCurriculumUnit = false,
    String? onlineSessionUrl,
    String? onlineSessionLabel,
    bool? onlineSessionIsLive,
    bool clearOnlineSession = false,
  }) async {
    final plan = planById(id);
    if (plan == null) return null;
    final nextClass = (className ?? plan.className).trim();
    final nextSubject = (subject ?? plan.subject).trim();
    if (!_teacherMayPrepare(nextClass, nextSubject)) {
      return null;
    }
    if (title != null) plan.title = title.trim();
    if (className != null) plan.className = className.trim();
    if (subject != null) plan.subject = subject.trim();
    if (weekStart != null) plan.weekStart = LessonPlan.mondayOf(weekStart);
    if (objectives != null) plan.objectives = objectives.trim();
    if (successCriteria != null) plan.successCriteria = successCriteria.trim();
    if (keyVocabulary != null) plan.keyVocabulary = keyVocabulary.trim();
    if (priorKnowledge != null) plan.priorKnowledge = priorKnowledge.trim();
    if (starter != null) plan.starter = starter.trim();
    if (activities != null) plan.activities = activities.trim();
    if (plenary != null) plan.plenary = plenary.trim();
    if (differentiation != null) {
      plan.differentiation = differentiation.trim();
    }
    if (assessment != null) plan.assessment = assessment.trim();
    if (homeLearning != null) plan.homeLearning = homeLearning.trim();
    if (inclusionNotes != null) plan.inclusionNotes = inclusionNotes.trim();
    if (clearDuration) {
      plan.durationMinutes = null;
    } else if (durationMinutes != null) {
      plan.durationMinutes = durationMinutes;
    }
    if (periodLabel != null) plan.periodLabel = periodLabel.trim();
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
    if (clearOnlineSession) {
      plan.onlineSessionUrl = null;
      plan.onlineSessionLabel = null;
      plan.onlineSessionIsLive = false;
    } else {
      if (onlineSessionUrl != null) {
        plan.onlineSessionUrl = onlineSessionUrl.trim().isEmpty
            ? null
            : onlineSessionUrl.trim();
      }
      if (onlineSessionLabel != null) {
        plan.onlineSessionLabel = onlineSessionLabel.trim().isEmpty
            ? null
            : onlineSessionLabel.trim();
      }
      if (onlineSessionIsLive != null) {
        plan.onlineSessionIsLive = onlineSessionIsLive;
      }
    }
    plan.updatedAt = DateTime.now();
    await _persist();
    return plan;
  }

  /// Management records how well this weekly plan achieved its aims (0–100).
  Future<LessonPlan?> evaluatePlan(
    String id, {
    required int percent,
    String notes = '',
  }) async {
    if (_isPublicReader) return null;
    final plan = planById(id);
    if (plan == null) return null;
    plan.achievementPercent = LessonPlan.clampPercent(percent);
    plan.achievementNotes = notes.trim();
    plan.evaluatedBy = AuthService.currentUser?.username;
    plan.evaluatedAt = DateTime.now();
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
    final wasPublished = plan.isPublished;
    plan.status = status;
    plan.updatedAt = DateTime.now();
    plan.publishedAt =
        status == LessonPlanStatus.published ? plan.updatedAt : null;
    if (status == LessonPlanStatus.published &&
        plan.reviewStatus == LessonPlanReviewStatus.none) {
      plan.reviewStatus = LessonPlanReviewStatus.pending;
    }
    await _persist();
    if (!wasPublished && plan.isPublished) {
      _notifyPublished(plan);
    }
    return plan;
  }

  /// Publish and queue department-head review. Does not write grades.
  Future<LessonPlan?> submitForReview(String id) async {
    final plan = planById(id);
    if (plan == null) return null;
    final wasPublished = plan.isPublished;
    plan.status = LessonPlanStatus.published;
    plan.reviewStatus = LessonPlanReviewStatus.pending;
    plan.updatedAt = DateTime.now();
    plan.publishedAt = plan.updatedAt;
    await _persist();
    if (!wasPublished) {
      _notifyPublished(plan);
    }
    return plan;
  }

  void _notifyPublished(LessonPlan plan) {
    final fromRole =
        AuthService.currentUser?.roleKey ?? AuthService.roleTeacher;
    final fullName = AuthService.currentUser?.fullName?.trim() ?? '';
    final fromName = fullName.isNotEmpty
        ? fullName
        : AuthService.displayNameForRole(fromRole);
    final title = 'New lesson plan — ${plan.subject}';
    final body =
        '${plan.title} for ${plan.className}, week ${plan.weekLabel}.';
    for (final role in [
      AuthService.roleParent,
      AuthService.roleTeacher,
      AuthService.roleAdmin,
    ]) {
      NotificationService.instance.push(
        title: title,
        body: body,
        type: NotificationType.lessonPlan,
        fromRole: fromRole,
        fromName: fromName,
        recipientRole: role,
        targetClassName: plan.className,
        showOnMessagesBadge: false,
      );
    }
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

  List<Map<String, dynamic>> snapshotMaps() {
    return _plans.map((p) {
      final map = Map<String, dynamic>.from(p.toMap());
      map['attachmentPaths'] = p.attachmentPaths
          .where((path) => !ProfilePhotoCodec.isDeviceLocalPath(path))
          .toList();
      final studentIds = StudentRegistryService.instance
          .studentsForClass(p.className)
          .map((s) => s.studentId.trim())
          .where((id) => id.isNotEmpty)
          .toList();
      if (studentIds.isNotEmpty) map['studentIds'] = studentIds;
      return map;
    }).toList();
  }

  Future<void> _persist() async {
    notifyListeners();
    await LessonPlanPersistenceService.instance.saveFromService();
  }
}
