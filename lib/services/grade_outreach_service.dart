import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

enum GradeRankScope { section, gradeWide }

class GradeOutreachService {
  GradeOutreachService._();
  static final instance = GradeOutreachService._();

  final _data = SchoolDataService.instance;
  final _sentCongratsKeys = <String>{};
  final _sentRecommendationKeys = <String>{};

  String? parentNameForStudent(String studentName) {
    return StudentRegistryService.instance
        .lookupByName(studentName)
        ?.primaryParentName
        ?.trim();
  }

  String congratsMessage({
    required StudentGradeReport report,
    required int rank,
    required GradeRankScope scope,
    required String gradeLevel,
    required String sectionLabel,
  }) {
    final scopeLabel = scope == GradeRankScope.gradeWide
        ? 'grade-wide ranking in $gradeLevel'
        : 'section $sectionLabel ranking in ${report.className}';
    return 'Congratulations! ${report.studentName} achieved rank #$rank in the '
        '$scopeLabel with an average of ${report.average.toStringAsFixed(1)}% '
        'for ${report.term}. We are proud of this achievement and encourage '
        'continued excellence.';
  }

  String homeroomRecommendationRequest({
    required StudentGradeReport report,
  }) {
    return 'Please share your recommendations to help ${report.studentName} '
        '(${report.className}) improve their academic performance. '
        'Their current average is ${report.average.toStringAsFixed(1)}% for '
        '${report.term}, which is below the 50% threshold. '
        'Include specific steps, support, or interventions you suggest.';
  }

  String _congratsKey(StudentGradeReport report, GradeRankScope scope, int rank) =>
      'congrats|${report.studentName}|${report.className}|${scope.name}|$rank|${report.term}';

  String _recommendationKey(StudentGradeReport report) =>
      'recommend|${report.studentName}|${report.className}|${report.term}';

  bool wasCongratsSent(StudentGradeReport report, GradeRankScope scope, int rank) =>
      _sentCongratsKeys.contains(_congratsKey(report, scope, rank));

  bool wasRecommendationRequested(StudentGradeReport report) =>
      _sentRecommendationKeys.contains(_recommendationKey(report));

  bool sendCongratsToParent({
    required StudentGradeReport report,
    required int rank,
    required GradeRankScope scope,
    required String gradeLevel,
    required String sectionLabel,
  }) {
    final parent = parentNameForStudent(report.studentName);
    if (parent == null || parent.isEmpty) return false;

    final body = congratsMessage(
      report: report,
      rank: rank,
      scope: scope,
      gradeLevel: gradeLevel,
      sectionLabel: sectionLabel,
    );

    final sent = _data.sendAdminDirectMessage(
      parentName: parent,
      subject: 'Congratulations — ${report.studentName}',
      body: body,
    );
    if (sent.isNotEmpty) {
      _sentCongratsKeys.add(_congratsKey(report, scope, rank));
    }
    return sent.isNotEmpty;
  }

  bool requestHomeroomRecommendation({required StudentGradeReport report}) {
    final teacherId = _data.homeroomTeacherIdForClass(report.className);
    if (teacherId == null || teacherId.trim().isEmpty) return false;

    final body = homeroomRecommendationRequest(report: report);
    final sent = _data.sendAdminDirectMessage(
      staffId: teacherId,
      subject: 'Improvement plan — ${report.studentName}',
      body: body,
    );
    if (sent.isNotEmpty) {
      _sentRecommendationKeys.add(_recommendationKey(report));
    }
    return sent.isNotEmpty;
  }

  int sendBulkCongrats({
    required List<({StudentGradeReport report, int rank})> entries,
    required GradeRankScope scope,
    required String gradeLevel,
    required String sectionLabel,
  }) {
    var count = 0;
    for (final entry in entries) {
      if (sendCongratsToParent(
        report: entry.report,
        rank: entry.rank,
        scope: scope,
        gradeLevel: gradeLevel,
        sectionLabel: sectionLabel,
      )) {
        count++;
      }
    }
    return count;
  }

  int sendBulkHomeroomRequests({required List<StudentGradeReport> reports}) {
    var count = 0;
    for (final report in reports) {
      if (requestHomeroomRecommendation(report: report)) count++;
    }
    return count;
  }
}
