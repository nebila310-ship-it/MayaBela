import 'package:flutter/foundation.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/markbook.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_registry_service.dart';

/// Weighted markbook + term report cards on top of [SchoolDataService].
class MarkbookService extends ChangeNotifier {
  MarkbookService._();
  static final instance = MarkbookService._();

  final _data = SchoolDataService.instance;
  final _registry = SchoolRegistryService.instance;

  MarkbookSettings settingsForSchool([String? schoolId]) {
    final id = schoolId ?? AuthService.activeSchoolId;
    if (id == null || id.isEmpty) return MarkbookSettings.liaDefaults;
    return _registry.lookup(id)?.markbookSettings ?? MarkbookSettings.liaDefaults;
  }

  Future<String?> saveSettings(MarkbookSettings settings, {String? schoolId}) async {
    final id = schoolId ?? AuthService.activeSchoolId;
    if (id == null || id.isEmpty) return 'No school selected.';
    final error = settings.weightError;
    if (error != null) return error;
    final school = _registry.lookup(id);
    if (school == null) return 'School not found.';
    school.markbookSettings = settings;
    await _registry.updateSchool(school);
    notifyListeners();
    return null;
  }

  List<AssessmentMark> templateMarks([String? schoolId]) {
    return [
      for (final cat in settingsForSchool(schoolId).categories)
        AssessmentMark(
          categoryId: cat.id,
          label: cat.label,
          weightPercent: cat.weightPercent,
        ),
    ];
  }

  List<AssessmentMark> marksForSubject(
    SubjectGrade grade, {
    String? schoolId,
  }) {
    final template = templateMarks(schoolId);
    if (template.isEmpty) return List<AssessmentMark>.from(grade.assessments);
    final existing = {for (final m in grade.assessments) m.categoryId: m};
    return [
      for (final cat in template)
        AssessmentMark(
          categoryId: cat.categoryId,
          label: cat.label,
          weightPercent: cat.weightPercent,
          score: existing[cat.categoryId]?.score,
          maxScore: existing[cat.categoryId]?.maxScore ?? 100,
          enteredAt: existing[cat.categoryId]?.enteredAt,
        ),
    ];
  }

  SubjectGradesClassEntryResult enterClassAssessments({
    required String className,
    required String subject,
    required String teacherId,
    required Map<String, List<AssessmentMark>> assessmentsByStudent,
    Map<String, String>? commentsByStudentName,
    bool submitForApproval = false,
    String? subjectId,
    String? teachingSlotId,
  }) {
    final scores = <String, double>{};
    final missingAsZero = settingsForSchool().missingCountsAsZero;
    for (final entry in assessmentsByStudent.entries) {
      if (!entry.value.any((m) => m.isEntered)) continue;
      scores[entry.key] = MarkbookMath.weightedPercentage(
        entry.value,
        missingCountsAsZero: missingAsZero,
      );
    }
    if (scores.isEmpty) {
      return const SubjectGradesClassEntryResult(saved: 0, skippedLocked: 0);
    }
    final result = _data.enterSubjectGradesForClass(
      className: className,
      subject: subject,
      teacherId: teacherId,
      scoresByStudentName: scores,
      commentsByStudentName: commentsByStudentName,
      assessmentsByStudentName: assessmentsByStudent,
      publishToParents: submitForApproval,
      subjectId: subjectId,
      teachingSlotId: teachingSlotId,
    );
    notifyListeners();
    return result;
  }

  bool publishReportCard({
    required String studentName,
    required String className,
    String? term,
    String? academicYear,
    String? homeroomComment,
    String? principalComment,
  }) {
    final school = _registry.lookup(AuthService.activeSchoolId ?? '');
    final ok = _data.updateTermReportCard(
      studentName: studentName,
      className: className,
      term: term,
      academicYear: academicYear ?? school?.academicYear,
      homeroomComment: homeroomComment,
      principalComment: principalComment,
      publish: true,
    );
    if (ok) notifyListeners();
    return ok;
  }

  bool saveReportCardDraft({
    required String studentName,
    required String className,
    String? term,
    String? academicYear,
    String? homeroomComment,
    String? principalComment,
  }) {
    final ok = _data.updateTermReportCard(
      studentName: studentName,
      className: className,
      term: term,
      academicYear: academicYear,
      homeroomComment: homeroomComment,
      principalComment: principalComment,
    );
    if (ok) notifyListeners();
    return ok;
  }

  int unpublishedCount({String? className}) =>
      _data.unpublishedReportCardCount(className: className);
}
