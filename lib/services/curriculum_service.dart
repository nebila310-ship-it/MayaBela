import 'package:flutter/foundation.dart';

import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/models/calendar_event.dart';
import 'package:mayabela/models/curriculum_models.dart';
import 'package:mayabela/models/lesson_plan_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/lesson_plan_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/persistence/curriculum_persistence_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/utils/short_registry_id.dart';

/// Published-plan coverage against curriculum units. Not a grade.
class CurriculumAlignmentSnapshot {
  const CurriculumAlignmentSnapshot({
    required this.publishedPlanCount,
    required this.linkedPublishedPlanCount,
    required this.unlinkedPublishedPlans,
    required this.unitCount,
    required this.unitsWithStandards,
    this.unlinkedBySubject = const {},
  });

  final int publishedPlanCount;
  final int linkedPublishedPlanCount;
  final List<LessonPlan> unlinkedPublishedPlans;
  final int unitCount;
  final int unitsWithStandards;
  final Map<String, int> unlinkedBySubject;

  int get unlinkedPublishedPlanCount => unlinkedPublishedPlans.length;
}

/// Curriculum office, feedback, DH reviews, academic evaluations, meetings.
/// Does not write grades, exam scores, or admissions fields.
class CurriculumService extends ChangeNotifier {
  CurriculumService._();
  static final instance = CurriculumService._();

  final List<CurriculumUnit> _units = [];
  final List<CurriculumFeedback> _feedback = [];
  final List<LessonPlanReview> _reviews = [];
  final List<TeacherEvaluation> _evaluations = [];
  final List<AcademicMeeting> _meetings = [];
  bool _loaded = false;

  List<CurriculumUnit> get units => List.unmodifiable(_units);
  List<CurriculumFeedback> get feedback => List.unmodifiable(_feedback);
  List<LessonPlanReview> get reviews => List.unmodifiable(_reviews);
  List<TeacherEvaluation> get evaluations => List.unmodifiable(_evaluations);
  List<AcademicMeeting> get meetings => List.unmodifiable(_meetings);

  @visibleForTesting
  static void resetForTests() {
    instance._units.clear();
    instance._feedback.clear();
    instance._reviews.clear();
    instance._evaluations.clear();
    instance._meetings.clear();
    instance._loaded = true;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    await CurriculumPersistenceService.instance.loadIntoService();
  }

  String get _schoolId =>
      (AuthService.activeSchoolId ?? AuthService.currentUser?.schoolId ?? '')
          .trim()
          .toUpperCase();

  String get _username => AuthService.currentUser?.username ?? '';

  bool get _isStudent =>
      AuthService.currentUser?.roleKey == AuthService.roleStudent;
  bool get _isParent =>
      AuthService.currentUser?.roleKey == AuthService.roleParent;
  bool get _isPublicReader => _isStudent || _isParent;

  bool get canLeadAcademics => ModuleAccess.canManage('curriculum');

  List<CurriculumUnit> unitsForSchool([String? schoolId]) {
    final sid = (schoolId ?? _schoolId).toUpperCase();
    var list = sid.isEmpty
        ? _units.toList()
        : _units.where((u) => u.schoolId == sid).toList();
    if (_isPublicReader) {
      list = list.where((u) => u.isPublished).toList();
    }
    return list..sort((a, b) => a.title.compareTo(b.title));
  }

  List<CurriculumUnit> publishedForClass(String className, {String? schoolId}) {
    return unitsForSchool(schoolId)
        .where(
          (u) =>
              u.isPublished &&
              (u.className == null ||
                  u.className!.isEmpty ||
                  StudentRegistryService.classNamesMatch(
                    u.className!,
                    className,
                  )),
        )
        .toList();
  }

  CurriculumUnit? unitById(String id) {
    for (final u in _units) {
      if (u.id == id) return u;
    }
    return null;
  }

  int unpublishedCount([String? schoolId]) => unitsForSchool(schoolId)
      .where((u) => u.status == CurriculumUnitStatus.draft)
      .length;

  Future<CurriculumUnit> createUnit({
    required String title,
    required String subject,
    String? gradeLevel,
    String? className,
    String strand = '',
    String description = '',
    String objectives = '',
    CurriculumFramework framework = CurriculumFramework.national,
    List<String> standardCodes = const [],
    List<String> examPaperIds = const [],
    List<String> homeworkIds = const [],
    List<String> attachmentPaths = const [],
    String? schoolId,
  }) async {
    final now = DateTime.now();
    final unit = CurriculumUnit(
      id: _id('CU', _units.map((u) => u.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      title: title.trim(),
      subject: subject.trim(),
      gradeLevel: gradeLevel?.trim(),
      className: className?.trim(),
      strand: strand.trim(),
      description: description.trim(),
      objectives: objectives.trim(),
      framework: framework,
      standardCodes: List.of(standardCodes),
      examPaperIds: List.of(examPaperIds),
      homeworkIds: List.of(homeworkIds),
      attachmentPaths: List.of(attachmentPaths),
      createdBy: _username,
      createdAt: now,
      updatedAt: now,
    );
    _units.add(unit);
    await _persist();
    return unit;
  }

  Future<CurriculumUnit?> updateUnit(
    String id, {
    String? title,
    String? subject,
    String? gradeLevel,
    String? className,
    String? strand,
    String? description,
    String? objectives,
    CurriculumFramework? framework,
    List<String>? standardCodes,
    List<String>? examPaperIds,
    List<String>? homeworkIds,
    List<String>? lessonPlanIds,
    List<String>? attachmentPaths,
    String? note,
  }) async {
    final unit = unitById(id);
    if (unit == null) return null;
    unit.versions = [
      ...unit.versions,
      CurriculumUnitVersion(
        version: unit.version,
        snapshot: unit.toMap(includeHistory: false),
        changedBy: _username,
        changedAt: DateTime.now(),
        note: note,
      ),
    ];
    unit.version += 1;
    if (title != null) unit.title = title.trim();
    if (subject != null) unit.subject = subject.trim();
    if (gradeLevel != null) unit.gradeLevel = gradeLevel.trim();
    if (className != null) unit.className = className.trim();
    if (strand != null) unit.strand = strand.trim();
    if (description != null) unit.description = description.trim();
    if (objectives != null) unit.objectives = objectives.trim();
    if (framework != null) unit.framework = framework;
    if (standardCodes != null) unit.standardCodes = List.of(standardCodes);
    if (examPaperIds != null) unit.examPaperIds = List.of(examPaperIds);
    if (homeworkIds != null) unit.homeworkIds = List.of(homeworkIds);
    if (lessonPlanIds != null) unit.lessonPlanIds = List.of(lessonPlanIds);
    if (attachmentPaths != null) {
      unit.attachmentPaths = List.of(attachmentPaths);
    }
    unit.updatedAt = DateTime.now();
    await _persist();
    return unit;
  }

  Future<CurriculumUnit?> setUnitStatus(
    String id,
    CurriculumUnitStatus status,
  ) async {
    final unit = unitById(id);
    if (unit == null) return null;
    unit.versions = [
      ...unit.versions,
      CurriculumUnitVersion(
        version: unit.version,
        snapshot: unit.toMap(includeHistory: false),
        changedBy: _username,
        changedAt: DateTime.now(),
        note: status == CurriculumUnitStatus.published
            ? 'Published'
            : 'Status: ${status.name}',
      ),
    ];
    unit.version += 1;
    unit.status = status;
    unit.updatedAt = DateTime.now();
    unit.publishedAt =
        status == CurriculumUnitStatus.published ? unit.updatedAt : null;
    await _persist();
    return unit;
  }

  List<CurriculumFeedback> feedbackForSchool([String? schoolId]) {
    final sid = (schoolId ?? _schoolId).toUpperCase();
    var list = sid.isEmpty
        ? _feedback.toList()
        : _feedback.where((f) => f.schoolId == sid).toList();
    if (_isPublicReader || !_canSeeAllFeedback) {
      list = list.where((f) => f.authorUsername == _username).toList();
    }
    return list..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  bool get _canSeeAllFeedback => canLeadAcademics;

  int openFeedbackCount([String? schoolId]) => feedbackForSchool(schoolId)
      .where((f) => f.status == CurriculumFeedbackStatus.open)
      .length;

  Future<CurriculumFeedback> addFeedback({
    required String curriculumUnitId,
    required String body,
    int? rating,
    String? authorRole,
    String? schoolId,
  }) async {
    final now = DateTime.now();
    final item = CurriculumFeedback(
      id: _id('CF', _feedback.map((f) => f.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      curriculumUnitId: curriculumUnitId,
      authorRole: authorRole ?? AuthService.currentUser?.roleKey ?? 'teacher',
      authorUsername: _username,
      authorName: AuthService.currentUser?.fullName,
      body: body.trim(),
      rating: rating,
      createdAt: now,
      updatedAt: now,
    );
    _feedback.add(item);
    await _persist();
    return item;
  }

  Future<CurriculumFeedback?> setFeedbackStatus(
    String id,
    CurriculumFeedbackStatus status,
  ) async {
    CurriculumFeedback? item;
    for (final f in _feedback) {
      if (f.id == id) item = f;
    }
    if (item == null) return null;
    item.status = status;
    item.updatedAt = DateTime.now();
    await _persist();
    return item;
  }

  Future<LessonPlanReview> reviewLessonPlan({
    required String lessonPlanId,
    required LessonPlanReviewDecision decision,
    String notes = '',
    String? curriculumUnitId,
    String? schoolId,
  }) async {
    final now = DateTime.now();
    final review = LessonPlanReview(
      id: _id('LR', _reviews.map((r) => r.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      lessonPlanId: lessonPlanId,
      curriculumUnitId: curriculumUnitId ??
          LessonPlanService.instance.planById(lessonPlanId)?.curriculumUnitId,
      decision: decision,
      reviewerUsername: _username,
      reviewerRole: _firstStaffRole,
      notes: notes.trim(),
      createdAt: now,
    );
    _reviews.add(review);
    await LessonPlanService.instance.applyReview(
      id: lessonPlanId,
      reviewStatus: decision == LessonPlanReviewDecision.approved
          ? LessonPlanReviewStatus.approved
          : LessonPlanReviewStatus.changesRequested,
      latestReviewId: review.id,
    );
    _notifyTeacherOfReview(review);
    await _persist();
    return review;
  }

  void _notifyTeacherOfReview(LessonPlanReview review) {
    final plan = LessonPlanService.instance.planById(review.lessonPlanId);
    final teacher = (plan?.createdBy ?? '').trim();
    if (teacher.isEmpty) return;
    final approved = review.decision == LessonPlanReviewDecision.approved;
    NotificationService.instance.push(
      title: approved
          ? 'Lesson plan approved'
          : 'Lesson plan needs changes',
      body: approved
          ? '${plan?.title ?? 'A lesson plan'} was approved by academic leadership.'
          : '${plan?.title ?? 'A lesson plan'} needs changes'
              '${review.notes.isEmpty ? '.' : ': ${review.notes}'}',
      type: NotificationType.general,
      fromRole: AuthService.roleAdmin,
      fromName: AuthService.currentUser?.fullName ?? 'Academic leadership',
      recipientRole: AuthService.roleTeacher,
      recipientUsername: teacher,
      targetClassName: plan?.className,
      showOnMessagesBadge: false,
    );
  }

  List<LessonPlanReview> reviewsForSchool([String? schoolId]) {
    final sid = (schoolId ?? _schoolId).toUpperCase();
    if (_isPublicReader) return const [];
    return (sid.isEmpty
            ? _reviews.toList()
            : _reviews.where((r) => r.schoolId == sid).toList())
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<TeacherEvaluation> evaluationsForSchool([String? schoolId]) {
    if (_isPublicReader) return const [];
    final sid = (schoolId ?? _schoolId).toUpperCase();
    var list = sid.isEmpty
        ? _evaluations.toList()
        : _evaluations.where((e) => e.schoolId == sid).toList();
    if (!canLeadAcademics) {
      final tid = TeacherAccessService.instance.teacherId;
      list = list
          .where(
            (e) =>
                e.teacherId == tid ||
                e.teacherUsername == _username ||
                e.evaluatorUsername == _username ||
                e.teacherId == _username,
          )
          .toList();
    }
    return list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  String? get _firstStaffRole {
    final roles = AuthService.currentUser?.staffRoles ?? const <String>[];
    return roles.isEmpty ? null : roles.first;
  }

  Future<void> attachLessonPlan(String unitId, String planId) async {
    final unit = unitById(unitId);
    if (unit == null || planId.trim().isEmpty) return;
    if (unit.lessonPlanIds.contains(planId)) return;
    await updateUnit(
      unitId,
      lessonPlanIds: [...unit.lessonPlanIds, planId],
      note: 'Linked lesson plan',
    );
  }

  Future<void> detachLessonPlan(String unitId, String planId) async {
    final unit = unitById(unitId);
    if (unit == null || !unit.lessonPlanIds.contains(planId)) return;
    await updateUnit(
      unitId,
      lessonPlanIds: unit.lessonPlanIds.where((id) => id != planId).toList(),
      note: 'Unlinked lesson plan',
    );
  }

  Future<void> syncLessonPlanUnit({
    required String planId,
    String? previousUnitId,
    String? nextUnitId,
  }) async {
    final prev = (previousUnitId ?? '').trim();
    final next = (nextUnitId ?? '').trim();
    if (prev.isNotEmpty && prev != next) {
      await detachLessonPlan(prev, planId);
    }
    if (next.isNotEmpty) {
      await attachLessonPlan(next, planId);
    }
  }

  List<LessonPlan> plansForUnit(String unitId) {
    final ids = <String>{
      ...?unitById(unitId)?.lessonPlanIds,
    };
    for (final plan in LessonPlanService.instance.plans) {
      if (plan.curriculumUnitId == unitId) ids.add(plan.id);
    }
    return [
      for (final id in ids)
        if (LessonPlanService.instance.planById(id) != null)
          LessonPlanService.instance.planById(id)!,
    ];
  }

  CurriculumAlignmentSnapshot alignmentForSchool([String? schoolId]) {
    final plans = LessonPlanService.instance
        .forSchool(schoolId)
        .where((p) => p.isPublished)
        .toList();
    final unlinked = plans
        .where((p) => (p.curriculumUnitId ?? '').trim().isEmpty)
        .toList();
    final units = unitsForSchool(schoolId);
    final unlinkedBySubject = <String, int>{};
    for (final plan in unlinked) {
      final subject =
          plan.subject.trim().isEmpty ? 'Unassigned' : plan.subject.trim();
      unlinkedBySubject[subject] = (unlinkedBySubject[subject] ?? 0) + 1;
    }
    return CurriculumAlignmentSnapshot(
      publishedPlanCount: plans.length,
      linkedPublishedPlanCount: plans.length - unlinked.length,
      unlinkedPublishedPlans: unlinked,
      unitCount: units.length,
      unitsWithStandards: units.where((u) => u.standardCodes.isNotEmpty).length,
      unlinkedBySubject: unlinkedBySubject,
    );
  }

  Future<CurriculumUnit?> restoreUnitVersion(String id, int version) async {
    final unit = unitById(id);
    if (unit == null) return null;
    CurriculumUnitVersion? entry;
    for (final item in unit.versions) {
      if (item.version == version) entry = item;
    }
    if (entry == null) return null;
    final snap = CurriculumUnit.fromMap({
      ...entry.snapshot,
      'id': unit.id,
      'schoolId': unit.schoolId,
      'createdAt': unit.createdAt.toIso8601String(),
      'updatedAt': unit.updatedAt.toIso8601String(),
    });
    return updateUnit(
      id,
      title: snap.title,
      subject: snap.subject,
      gradeLevel: snap.gradeLevel ?? '',
      className: snap.className ?? '',
      strand: snap.strand,
      description: snap.description,
      objectives: snap.objectives,
      framework: snap.framework,
      standardCodes: snap.standardCodes,
      examPaperIds: snap.examPaperIds,
      homeworkIds: snap.homeworkIds,
      lessonPlanIds: snap.lessonPlanIds,
      attachmentPaths: snap.attachmentPaths,
      note: 'Restored from v$version',
    );
  }

  Future<TeacherEvaluation> recordEvaluation({
    required String teacherId,
    required String teacherName,
    required String periodLabel,
    String? teacherUsername,
    int curriculumFidelity = 3,
    int planningQuality = 3,
    int assessmentAlignment = 3,
    String notes = '',
    List<String> lessonPlanReviewIds = const [],
    String? schoolId,
  }) async {
    final now = DateTime.now();
    final item = TeacherEvaluation(
      id: _id('TE', _evaluations.map((e) => e.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      teacherId: teacherId,
      teacherName: teacherName.trim(),
      teacherUsername: teacherUsername?.trim(),
      periodLabel: periodLabel.trim(),
      curriculumFidelity: curriculumFidelity.clamp(1, 5),
      planningQuality: planningQuality.clamp(1, 5),
      assessmentAlignment: assessmentAlignment.clamp(1, 5),
      notes: notes.trim(),
      evaluatorUsername: _username,
      evaluatorRole: _firstStaffRole,
      lessonPlanReviewIds: List.of(lessonPlanReviewIds),
      createdAt: now,
      updatedAt: now,
    );
    _evaluations.add(item);
    await _persist();
    return item;
  }

  List<AcademicMeeting> meetingsForSchool([String? schoolId]) {
    if (_isPublicReader) return const [];
    final sid = (schoolId ?? _schoolId).toUpperCase();
    return (sid.isEmpty
            ? _meetings.toList()
            : _meetings.where((m) => m.schoolId == sid).toList())
          ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
  }

  AcademicMeeting? meetingById(String id) {
    for (final m in _meetings) {
      if (m.id == id) return m;
    }
    return null;
  }

  Future<AcademicMeeting> recordMeeting({
    required String title,
    required DateTime startsAt,
    DateTime? endsAt,
    String agenda = '',
    String notes = '',
    List<String> attendeeRoles = const [],
    bool publishToCalendar = false,
    String? schoolId,
  }) async {
    final now = DateTime.now();
    String? calendarEventId;
    if (publishToCalendar) {
      calendarEventId = _scheduleStaffMeeting(
        title: title.trim(),
        agenda: agenda.trim(),
        startsAt: startsAt,
      );
    }
    final item = AcademicMeeting(
      id: _id('AM', _meetings.map((m) => m.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      title: title.trim(),
      startsAt: startsAt,
      endsAt: endsAt ?? startsAt.add(const Duration(hours: 1)),
      agenda: agenda.trim(),
      notes: notes.trim(),
      attendeeRoles: List.of(attendeeRoles),
      createdBy: _username,
      calendarEventId: calendarEventId,
      createdAt: now,
      updatedAt: now,
    );
    _meetings.add(item);
    await _persist();
    return item;
  }

  Future<AcademicMeeting?> updateMeeting(
    String id, {
    String? title,
    DateTime? startsAt,
    DateTime? endsAt,
    String? agenda,
    String? notes,
    List<String>? attendeeRoles,
    bool? publishToCalendar,
  }) async {
    final item = meetingById(id);
    if (item == null) return null;
    if (title != null) item.title = title.trim();
    if (startsAt != null) item.startsAt = startsAt;
    if (endsAt != null) item.endsAt = endsAt;
    if (agenda != null) item.agenda = agenda.trim();
    if (notes != null) item.notes = notes.trim();
    if (attendeeRoles != null) item.attendeeRoles = List.of(attendeeRoles);
    if (publishToCalendar == true && (item.calendarEventId ?? '').isEmpty) {
      item.calendarEventId = _scheduleStaffMeeting(
        title: item.title,
        agenda: item.agenda,
        startsAt: item.startsAt,
      );
    }
    item.updatedAt = DateTime.now();
    await _persist();
    return item;
  }

  String _scheduleStaffMeeting({
    required String title,
    required String agenda,
    required DateTime startsAt,
  }) {
    final event = SchoolDataService.instance.scheduleCalendarEvent(
      title: title,
      description: agenda.isEmpty ? title : agenda,
      date: startsAt,
      type: CalendarEventType.meeting,
      audience: 'staff',
      autoAnnounce: false,
      time:
          '${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')}',
    );
    return event.id;
  }

  void applyPersistedData({
    List<CurriculumUnit>? units,
    List<CurriculumFeedback>? feedback,
    List<LessonPlanReview>? reviews,
    List<TeacherEvaluation>? evaluations,
    List<AcademicMeeting>? meetings,
    bool merge = false,
  }) {
    void mergeList<T>(List<T> local, List<T> incoming, String Function(T) idOf) {
      if (!merge) {
        local
          ..clear()
          ..addAll(incoming);
        return;
      }
      final byId = {for (final item in local) idOf(item): item};
      for (final item in incoming) {
        byId[idOf(item)] = item;
      }
      local
        ..clear()
        ..addAll(byId.values);
    }

    if (units != null) mergeList(_units, units, (u) => u.id);
    if (feedback != null) mergeList(_feedback, feedback, (f) => f.id);
    if (reviews != null) {
      if (_isPublicReader) {
        _reviews.clear();
      } else {
        mergeList(_reviews, reviews, (r) => r.id);
      }
    }
    if (evaluations != null) {
      if (_isPublicReader) {
        _evaluations.clear();
      } else {
        mergeList(_evaluations, evaluations, (e) => e.id);
      }
    }
    if (meetings != null) {
      if (_isPublicReader) {
        _meetings.clear();
      } else {
        mergeList(_meetings, meetings, (m) => m.id);
      }
    }
    _loaded = true;
    notifyListeners();
  }

  List<Map<String, dynamic>> unitMaps() =>
      _units.map((u) => u.toMap()).toList();
  List<Map<String, dynamic>> feedbackMaps() =>
      _feedback.map((f) => f.toMap()).toList();
  List<Map<String, dynamic>> reviewMaps() =>
      _reviews.map((r) => r.toMap()).toList();
  List<Map<String, dynamic>> evaluationMaps() =>
      _evaluations.map((e) => e.toMap()).toList();
  List<Map<String, dynamic>> meetingMaps() =>
      _meetings.map((m) => m.toMap()).toList();

  Future<void> _persist() async {
    notifyListeners();
    await CurriculumPersistenceService.instance.saveFromService();
  }

  String _id(String prefix, Iterable<String> existing) {
    return ShortRegistryId.allocate(
      prefix: prefix,
      existingIds: existing,
      isTaken: (id) => existing.contains(id),
    );
  }
}
