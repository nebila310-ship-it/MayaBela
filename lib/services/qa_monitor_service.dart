import 'package:flutter/foundation.dart';

import 'package:mayabela/models/attendance_intelligence_models.dart';
import 'package:mayabela/models/qa_monitor_models.dart';
import 'package:mayabela/services/attendance_intelligence_service.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/curriculum_service.dart';
import 'package:mayabela/services/persistence/qa_monitor_persistence_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/utils/short_registry_id.dart';

/// Phase I QA monitoring. Reads Phase E units and Phase F risk profiles.
/// Never writes grades, exams, findings, or teacher_evaluations.
class QaMonitorService extends ChangeNotifier {
  QaMonitorService._();
  static final instance = QaMonitorService._();

  final List<TeachingObservation> _observations = [];
  final List<AcademicAudit> _audits = [];
  final List<QaSurvey> _surveys = [];
  final List<QaSurveyResponse> _responses = [];
  final List<ActionResearch> _research = [];
  bool _loaded = false;

  @visibleForTesting
  static void resetForTests() {
    instance._observations.clear();
    instance._audits.clear();
    instance._surveys.clear();
    instance._responses.clear();
    instance._research.clear();
    instance._loaded = true;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    await QaMonitorPersistenceService.instance.loadIntoService();
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

  bool get canManageDesk => ModuleAccess.canManage('quality_assurance');
  bool get canViewDesk => ModuleAccess.canView('quality_assurance');

  List<TeachingObservation> observationsForSchool([String? schoolId]) {
    var list = _schoolFilter(_observations, schoolId);
    if (_isPublicReader) return const [];
    if (!canViewDesk) {
      final uname = _username.trim().toLowerCase();
      list = list
          .where(
            (row) =>
                row.status == ObservationStatus.shared &&
                row.teacherUsername.trim().toLowerCase() == uname,
          )
          .toList();
    }
    return list..sort((a, b) => b.observedAt.compareTo(a.observedAt));
  }

  List<AcademicAudit> auditsForSchool([String? schoolId]) {
    if (_isPublicReader || !canViewDesk) return const [];
    return _schoolFilter(_audits, schoolId)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<QaSurvey> surveysForSchool([String? schoolId]) {
    var list = _schoolFilter(_surveys, schoolId);
    if (_isPublicReader || !canViewDesk) {
      list = list.where((row) {
        if (!row.published) return false;
        return _audienceMatches(row.audience);
      }).toList();
    }
    return list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<QaSurveyResponse> responsesForSchool([String? schoolId]) {
    var list = _schoolFilter(_responses, schoolId);
    if (_isPublicReader || !canViewDesk) {
      final uname = _username.trim().toLowerCase();
      list = list
          .where((row) => row.authorUsername.trim().toLowerCase() == uname)
          .toList();
    }
    return list..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<QaSurveyResponse> responsesForSurvey(String surveyId) =>
      responsesForSchool().where((row) => row.surveyId == surveyId).toList();

  List<ActionResearch> researchForSchool([String? schoolId]) {
    if (_isPublicReader || !canViewDesk) return const [];
    return _schoolFilter(_research, schoolId)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  int openSurveyCount([String? schoolId]) =>
      surveysForSchool(schoolId).where((row) => row.published).length;

  int draftObservationCount([String? schoolId]) =>
      observationsForSchool(schoolId)
          .where((row) => row.status == ObservationStatus.draft)
          .length;

  int openResearchCount([String? schoolId]) => researchForSchool(schoolId)
      .where((row) => row.status != ActionResearchStatus.complete)
      .length;

  double? surveyAverage(String surveyId, String questionId) {
    final scores = <double>[];
    for (final row in responsesForSurvey(surveyId)) {
      final raw = row.answers[questionId];
      final value = double.tryParse(raw ?? '');
      if (value != null) scores.add(value);
    }
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  /// Read-only Phase F snapshot. Never writes attendance or grades.
  QaAnalyticsSnapshot analyticsForSchool() {
    if (_isPublicReader) {
      return const QaAnalyticsSnapshot(
        atRisk: 0,
        academicWatch: 0,
        attendanceWatch: 0,
        withGrades: 0,
        averageAbsenceRate: 0,
      );
    }
    final profiles = AttendanceIntelligenceService.instance.profiles();
    var atRisk = 0, academic = 0, attendance = 0, withGrades = 0;
    var absenceSum = 0.0;
    for (final row in profiles) {
      if (row.level == RiskLevel.atRisk) atRisk++;
      if (row.level == RiskLevel.academicWatch) academic++;
      if (row.level == RiskLevel.attendanceWatch) attendance++;
      if (row.hasGrades) withGrades++;
      absenceSum += row.absenceRate;
    }
    return QaAnalyticsSnapshot(
      atRisk: atRisk,
      academicWatch: academic,
      attendanceWatch: attendance,
      withGrades: withGrades,
      averageAbsenceRate: profiles.isEmpty ? 0 : absenceSum / profiles.length,
    );
  }

  Future<TeachingObservation> recordObservation({
    required String teacherName,
    String teacherUsername = '',
    String? teacherId,
    String className = '',
    String subject = '',
    String? curriculumUnitId,
    DateTime? observedAt,
    int planning = 3,
    int instruction = 3,
    int engagement = 3,
    int assessment = 3,
    String notes = '',
    ObservationStatus status = ObservationStatus.submitted,
    String? schoolId,
  }) async {
    _requireStaffDesk();
    final now = DateTime.now();
    final row = TeachingObservation(
      id: _id('OBS', _observations.map((item) => item.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      teacherName: teacherName.trim(),
      teacherUsername: teacherUsername.trim(),
      teacherId: teacherId,
      className: className.trim(),
      subject: subject.trim(),
      curriculumUnitId: curriculumUnitId,
      observedAt: observedAt ?? now,
      planning: planning.clamp(1, 5),
      instruction: instruction.clamp(1, 5),
      engagement: engagement.clamp(1, 5),
      assessment: assessment.clamp(1, 5),
      notes: notes.trim(),
      status: status,
      observerUsername: _username,
      createdAt: now,
      updatedAt: now,
    );
    _observations.add(row);
    await _persist();
    return row;
  }

  Future<TeachingObservation> shareObservation(String id) async {
    _requireStaffDesk();
    final row = _observations.cast<TeachingObservation?>().firstWhere(
          (item) => item?.id == id,
          orElse: () => null,
        );
    if (row == null) {
      throw StateError('Observation not found.');
    }
    row.status = ObservationStatus.shared;
    row.updatedAt = DateTime.now();
    await _persist();
    return row;
  }

  Future<AcademicAudit> recordAudit({
    required String curriculumUnitId,
    AuditVerdict verdict = AuditVerdict.notReviewed,
    AuditStatus status = AuditStatus.completed,
    String notes = '',
    String? schoolId,
  }) async {
    _requireStaffDesk();
    final unit = CurriculumService.instance.unitById(curriculumUnitId);
    if (unit == null) {
      throw StateError('Curriculum unit not found.');
    }
    final now = DateTime.now();
    final row = AcademicAudit(
      id: _id('AUD', _audits.map((item) => item.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      curriculumUnitId: unit.id,
      unitTitle: unit.title,
      standardCodes: List.of(unit.standardCodes),
      verdict: verdict,
      status: status,
      notes: notes.trim(),
      auditorUsername: _username,
      createdAt: now,
      updatedAt: now,
    );
    _audits.add(row);
    await _persist();
    return row;
  }

  Future<QaSurvey> createSurvey({
    required String title,
    SurveyAudience audience = SurveyAudience.all,
    List<QaSurveyQuestion> questions = const [],
    bool published = false,
    String? schoolId,
  }) async {
    _requireStaffDesk();
    final now = DateTime.now();
    final row = QaSurvey(
      id: _id('SVY', _surveys.map((item) => item.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      title: title.trim(),
      audience: audience,
      questions: questions.isEmpty ? _defaultQuestions() : List.of(questions),
      published: published,
      createdBy: _username,
      createdAt: now,
      updatedAt: now,
    );
    _surveys.add(row);
    await _persist();
    return row;
  }

  Future<QaSurvey> publishSurvey(String id, {bool published = true}) async {
    _requireStaffDesk();
    final row = _surveys.cast<QaSurvey?>().firstWhere(
          (item) => item?.id == id,
          orElse: () => null,
        );
    if (row == null) {
      throw StateError('Survey not found.');
    }
    row.published = published;
    row.updatedAt = DateTime.now();
    await _persist();
    return row;
  }

  Future<QaSurveyResponse> submitSurveyResponse({
    required String surveyId,
    required Map<String, String> answers,
    String? schoolId,
  }) async {
    final survey = _surveys.cast<QaSurvey?>().firstWhere(
          (item) => item?.id == surveyId,
          orElse: () => null,
        );
    if (survey == null || !survey.published) {
      throw StateError('This survey is not open.');
    }
    if (!_audienceMatches(survey.audience)) {
      throw StateError('This survey is not for your role.');
    }
    if (_username.trim().isEmpty) {
      throw StateError('Sign in to submit a survey.');
    }
    final existing = _responses.cast<QaSurveyResponse?>().firstWhere(
          (item) =>
              item?.surveyId == surveyId &&
              item?.authorUsername.trim().toLowerCase() ==
                  _username.trim().toLowerCase(),
          orElse: () => null,
        );
    final now = DateTime.now();
    if (existing != null) {
      existing.answers = Map.of(answers);
      existing.updatedAt = now;
      await _persist();
      return existing;
    }
    final row = QaSurveyResponse(
      id: _id('SVR', _responses.map((item) => item.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      surveyId: surveyId,
      authorUsername: _username,
      authorRole: AuthService.currentUser?.roleKey,
      answers: Map.of(answers),
      createdAt: now,
      updatedAt: now,
    );
    _responses.add(row);
    await _persist();
    return row;
  }

  Future<ActionResearch> recordResearch({
    required String title,
    String inquiry = '',
    String method = '',
    String findings = '',
    String nextSteps = '',
    ActionResearchStatus status = ActionResearchStatus.planned,
    String? linkedFindingId,
    String? linkedUnitId,
    String? schoolId,
  }) async {
    _requireStaffDesk();
    final now = DateTime.now();
    final row = ActionResearch(
      id: _id('ARS', _research.map((item) => item.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      title: title.trim(),
      inquiry: inquiry.trim(),
      method: method.trim(),
      findings: findings.trim(),
      nextSteps: nextSteps.trim(),
      status: status,
      linkedFindingId: linkedFindingId,
      linkedUnitId: linkedUnitId,
      ownerUsername: _username,
      createdAt: now,
      updatedAt: now,
    );
    _research.add(row);
    await _persist();
    return row;
  }

  Future<ActionResearch> updateResearchStatus(
    String id,
    ActionResearchStatus status, {
    String findings = '',
    String nextSteps = '',
  }) async {
    _requireStaffDesk();
    final row = _research.cast<ActionResearch?>().firstWhere(
          (item) => item?.id == id,
          orElse: () => null,
        );
    if (row == null) {
      throw StateError('Action research not found.');
    }
    row.status = status;
    if (findings.trim().isNotEmpty) row.findings = findings.trim();
    if (nextSteps.trim().isNotEmpty) row.nextSteps = nextSteps.trim();
    row.updatedAt = DateTime.now();
    await _persist();
    return row;
  }

  void applyPersistedData({
    List<TeachingObservation>? observations,
    List<AcademicAudit>? audits,
    List<QaSurvey>? surveys,
    List<QaSurveyResponse>? responses,
    List<ActionResearch>? research,
    bool merge = false,
  }) {
    void mergeList<T>(
      List<T> local,
      List<T> incoming,
      String Function(T) idOf,
    ) {
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

    if (observations != null) {
      if (_isPublicReader) {
        mergeList(_observations, const [], (row) => row.id);
      } else {
        mergeList(_observations, observations, (row) => row.id);
      }
    }
    if (audits != null) {
      mergeList(
        _audits,
        _isPublicReader ? const [] : audits,
        (row) => row.id,
      );
    }
    if (surveys != null) mergeList(_surveys, surveys, (row) => row.id);
    if (responses != null) mergeList(_responses, responses, (row) => row.id);
    if (research != null) {
      mergeList(
        _research,
        _isPublicReader ? const [] : research,
        (row) => row.id,
      );
    }
    _loaded = true;
    notifyListeners();
  }

  List<Map<String, dynamic>> observationMaps() =>
      _observations.map((row) => row.toMap()).toList();
  List<Map<String, dynamic>> auditMaps() =>
      _audits.map((row) => row.toMap()).toList();
  List<Map<String, dynamic>> surveyMaps() =>
      _surveys.map((row) => row.toMap()).toList();
  List<Map<String, dynamic>> responseMaps() =>
      _responses.map((row) => row.toMap()).toList();
  List<Map<String, dynamic>> researchMaps() =>
      _research.map((row) => row.toMap()).toList();

  List<AdminTeacherRecord> teachersForPicker() {
    return TeacherRegistryService.instance
        .getAllTeachers()
        .where(
          (t) =>
              t.isActive &&
              (_schoolId.isEmpty ||
                  t.schoolId.trim().toUpperCase() == _schoolId),
        )
        .toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  List<T> _schoolFilter<T>(List<T> rows, String? schoolId) {
    final sid = (schoolId ?? _schoolId).toUpperCase();
    if (sid.isEmpty) return List<T>.from(rows);
    return rows.where((row) {
      final rowSchool = switch (row) {
        TeachingObservation r => r.schoolId,
        AcademicAudit r => r.schoolId,
        QaSurvey r => r.schoolId,
        QaSurveyResponse r => r.schoolId,
        ActionResearch r => r.schoolId,
        _ => '',
      };
      return rowSchool == sid;
    }).toList();
  }

  bool _audienceMatches(SurveyAudience audience) {
    if (audience == SurveyAudience.all) return true;
    if (_isParent) return audience == SurveyAudience.parent;
    if (_isStudent) return audience == SurveyAudience.student;
    return audience == SurveyAudience.teacher ||
        audience == SurveyAudience.all;
  }

  List<QaSurveyQuestion> _defaultQuestions() => [
        QaSurveyQuestion(
          id: 'Q-0001',
          prompt: 'How clear was teaching this term?',
        ),
        QaSurveyQuestion(
          id: 'Q-0002',
          prompt: 'How supported did learners feel?',
        ),
        QaSurveyQuestion(
          id: 'Q-0003',
          prompt: 'What should the school improve?',
          kind: SurveyQuestionKind.text,
        ),
      ];

  void _requireStaffDesk() {
    if (!canManageDesk) {
      throw StateError('Only the QA desk can write monitoring records.');
    }
  }

  Future<void> _persist() async {
    notifyListeners();
    await QaMonitorPersistenceService.instance.saveFromService();
  }

  String _id(String prefix, Iterable<String> existing) {
    return ShortRegistryId.allocate(
      prefix: prefix,
      existingIds: existing,
      isTaken: (id) => existing.contains(id),
    );
  }
}
