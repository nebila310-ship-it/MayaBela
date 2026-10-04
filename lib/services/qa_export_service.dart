import 'package:mayabela/services/qa_findings_service.dart';
import 'package:mayabela/services/qa_monitor_service.dart';

/// CSV exports for the QA desk. Counts and titles only — no grade writes.
class QaExportService {
  QaExportService._();
  static final instance = QaExportService._();

  String findingsCsv({String? schoolId}) {
    final rows = <List<String>>[
      [
        'Id',
        'Area',
        'Severity',
        'Status',
        'Title',
        'Owner',
        'Due',
        'Raised by',
        'Created',
      ],
    ];
    for (final row in QaFindingsService.instance.forSchool(schoolId)) {
      rows.add([
        row.id,
        row.area.name,
        row.severity.name,
        row.status.name,
        row.title,
        row.ownerRole,
        _iso(row.dueDate),
        row.raisedByName,
        _iso(row.createdAt),
      ]);
    }
    return _table(rows);
  }

  String observationsCsv({String? schoolId}) {
    final rows = <List<String>>[
      [
        'Id',
        'Teacher',
        'Class',
        'Subject',
        'Average',
        'Status',
        'Observed',
      ],
    ];
    for (final row in QaMonitorService.instance.observationsForSchool(schoolId)) {
      rows.add([
        row.id,
        row.teacherName,
        row.className,
        row.subject,
        row.averageScore.toStringAsFixed(1),
        row.status.name,
        _iso(row.observedAt),
      ]);
    }
    return _table(rows);
  }

  String auditsCsv({String? schoolId}) {
    final rows = <List<String>>[
      ['Id', 'Unit', 'Verdict', 'Status', 'Notes', 'Updated'],
    ];
    for (final row in QaMonitorService.instance.auditsForSchool(schoolId)) {
      rows.add([
        row.id,
        row.unitTitle,
        row.verdict.name,
        row.status.name,
        row.notes,
        _iso(row.updatedAt),
      ]);
    }
    return _table(rows);
  }

  String surveysCsv({String? schoolId}) {
    final rows = <List<String>>[
      ['Id', 'Title', 'Audience', 'Published', 'Responses', 'Created'],
    ];
    final svc = QaMonitorService.instance;
    for (final row in svc.surveysForSchool(schoolId)) {
      final responses = svc
          .responsesForSchool(schoolId)
          .where((item) => item.surveyId == row.id)
          .length;
      rows.add([
        row.id,
        row.title,
        row.audience.name,
        row.published ? 'yes' : 'no',
        '$responses',
        _iso(row.createdAt),
      ]);
    }
    return _table(rows);
  }

  String researchCsv({String? schoolId}) {
    final rows = <List<String>>[
      ['Id', 'Title', 'Status', 'Inquiry', 'Findings', 'Updated'],
    ];
    for (final row in QaMonitorService.instance.researchForSchool(schoolId)) {
      rows.add([
        row.id,
        row.title,
        row.status.name,
        row.inquiry,
        row.findings,
        _iso(row.updatedAt),
      ]);
    }
    return _table(rows);
  }

  String allCsv({String? schoolId}) {
    final findings = QaFindingsService.instance.forSchool(schoolId);
    final open = findings.where((row) => row.isOpen).length;
    final overdue = findings.where((row) => row.isOverdue).length;
    final buf = StringBuffer()
      ..writeln('Section,Count')
      ..writeln('Open findings,$open')
      ..writeln('Overdue findings,$overdue')
      ..writeln(
        'Observations,${QaMonitorService.instance.observationsForSchool(schoolId).length}',
      )
      ..writeln(
        'Audits,${QaMonitorService.instance.auditsForSchool(schoolId).length}',
      )
      ..writeln(
        'Surveys,${QaMonitorService.instance.surveysForSchool(schoolId).length}',
      )
      ..writeln(
        'Action research,${QaMonitorService.instance.researchForSchool(schoolId).length}',
      )
      ..writeln()
      ..writeln(findingsCsv(schoolId: schoolId));
    return buf.toString();
  }

  static String _iso(DateTime? value) =>
      value == null ? '' : value.toIso8601String().split('T').first;

  static String _table(List<List<String>> rows) {
    return rows.map(_csvLine).join('\n');
  }

  static String _csvLine(List<String> cells) {
    return cells.map((cell) {
      if (cell.contains(',') || cell.contains('"') || cell.contains('\n')) {
        return '"${cell.replaceAll('"', '""')}"';
      }
      return cell;
    }).join(',');
  }
}
