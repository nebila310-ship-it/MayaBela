import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/markbook.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/markbook_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

/// Class attendance and markbook CSV for year-start desks.
class YearStartSheetService {
  YearStartSheetService._();
  static final instance = YearStartSheetService._();

  String attendanceCsv({
    required String className,
    required DateTime date,
    String? schoolId,
  }) {
    final day = DateTime(date.year, date.month, date.day);
    final session = SchoolDataService.instance.getAttendanceSession(
      className,
      day,
    );
    final roster = StudentRegistryService.instance.studentsForClass(
      className,
      schoolId: schoolId,
    );
    final byId = {
      for (final e in session?.entries ?? const <StudentAttendanceEntry>[])
        if ((e.studentId ?? '').trim().isNotEmpty)
          e.studentId!.trim().toUpperCase(): e.status,
    };
    final byName = {
      for (final e in session?.entries ?? const <StudentAttendanceEntry>[])
        e.studentName.trim().toLowerCase(): e.status,
    };
    final rows = <List<String>>[
      ['Class', 'Date', 'Student ID', 'Name', 'Status'],
    ];
    if (roster.isEmpty) {
      for (final e in session?.entries ?? const <StudentAttendanceEntry>[]) {
        rows.add([
          className,
          _isoDay(day),
          e.studentId ?? '',
          e.studentName,
          _statusToken(e.status),
        ]);
      }
    } else {
      for (final student in roster) {
        final status = byId[student.studentId] ??
            byName[student.fullName.trim().toLowerCase()];
        rows.add([
          className,
          _isoDay(day),
          student.studentId,
          student.fullName,
          status == null ? '' : _statusToken(status),
        ]);
      }
    }
    return rows.map(_csvLine).join('\n');
  }

  int importAttendanceCsv(
    String text, {
    required String conductedBy,
  }) {
    final table = _parseTable(text);
    if (table.length < 2) return 0;
    final header = table.first.map(_norm).toList();
    final classIdx = _indexOf(header, const ['class', 'class name']);
    final dateIdx = _indexOf(header, const ['date']);
    final idIdx = _indexOf(header, const ['student id', 'id', 'stu']);
    final nameIdx = _indexOf(header, const ['name', 'full name', 'student']);
    final statusIdx = _indexOf(header, const ['status', 'mark', 'attendance']);
    if (classIdx == null || nameIdx == null || statusIdx == null) {
      throw StateError('CSV needs Class, Name, and Status columns.');
    }
    final grouped = <String, List<StudentAttendanceEntry>>{};
    final dates = <String, DateTime>{};
    for (var i = 1; i < table.length; i++) {
      final row = table[i];
      String at(int? idx) =>
          (idx == null || idx >= row.length) ? '' : row[idx].trim();
      final className = at(classIdx);
      final name = at(nameIdx);
      final status = _parseStatus(at(statusIdx));
      if (className.isEmpty || name.isEmpty || status == null) continue;
      final date = _parseDate(at(dateIdx)) ?? DateTime.now();
      final key = '${className.toLowerCase()}|${_isoDay(date)}';
      dates[key] = DateTime(date.year, date.month, date.day);
      grouped.putIfAbsent(key, () => []).add(
            StudentAttendanceEntry(
              studentName: name,
              studentId: at(idIdx).isEmpty ? null : at(idIdx).toUpperCase(),
              status: status,
              updatedAt: DateTime.now(),
            ),
          );
    }
    var saved = 0;
    for (final entry in grouped.entries) {
      final rawClass = entry.key.split('|').first;
      final originalClass = table
          .skip(1)
          .map((r) => r[classIdx].trim())
          .firstWhere(
            (c) => c.toLowerCase() == rawClass,
            orElse: () => rawClass,
          );
      final ok = SchoolDataService.instance.saveAttendanceSession(
        className: originalClass,
        date: dates[entry.key]!,
        conductedBy: conductedBy,
        entries: entry.value,
      );
      if (ok) saved += entry.value.length;
    }
    return saved;
  }

  String gradeCsv({
    required String className,
    required String subject,
    String? schoolId,
  }) {
    final cats = MarkbookService.instance.settingsForSchool().categories;
    final students = StudentRegistryService.instance.studentsForClass(
      className,
      schoolId: schoolId,
    );
    final reports = SchoolDataService.instance.getGradeReportsForClass(className);
    final header = [
      'Class',
      'Subject',
      'Student ID',
      'Name',
      ...cats.map((c) => c.id),
    ];
    final rows = <List<String>>[header];
    final names = students.isEmpty
        ? reports.map((r) => (id: r.studentId ?? '', name: r.studentName))
        : students.map((s) => (id: s.studentId, name: s.fullName));
    for (final student in names) {
      SubjectGrade? grade;
      for (final report in reports) {
        if (report.studentName != student.name) continue;
        for (final item in report.subjects) {
          if (item.subject == subject) {
            grade = item;
            break;
          }
        }
      }
      final marks = grade == null
          ? MarkbookService.instance.templateMarks()
          : MarkbookService.instance.marksForSubject(grade);
      final byId = {for (final m in marks) m.categoryId: m.score};
      rows.add([
        className,
        subject,
        student.id,
        student.name,
        ...cats.map((c) {
          final score = byId[c.id];
          return score == null ? '' : score.toStringAsFixed(0);
        }),
      ]);
    }
    return rows.map(_csvLine).join('\n');
  }

  int importGradeCsv(
    String text, {
    required String teacherId,
  }) {
    final table = _parseTable(text);
    if (table.length < 2) return 0;
    final header = table.first.map((h) => h.trim()).toList();
    final headerNorm = header.map(_norm).toList();
    final classIdx = _indexOf(headerNorm, const ['class', 'class name']);
    final subjectIdx = _indexOf(headerNorm, const ['subject']);
    final nameIdx = _indexOf(headerNorm, const ['name', 'full name', 'student']);
    if (classIdx == null || subjectIdx == null || nameIdx == null) {
      throw StateError('CSV needs Class, Subject, and Name columns.');
    }
    final cats = MarkbookService.instance.settingsForSchool().categories;
    final catIdx = <String, int>{};
    for (final cat in cats) {
      for (var i = 0; i < headerNorm.length; i++) {
        if (headerNorm[i] == _norm(cat.id) || headerNorm[i] == _norm(cat.label)) {
          catIdx[cat.id] = i;
        }
      }
    }
    if (catIdx.isEmpty) {
      throw StateError('CSV needs at least one markbook category column.');
    }
    var saved = 0;
    for (var i = 1; i < table.length; i++) {
      final row = table[i];
      String at(int idx) => idx >= row.length ? '' : row[idx].trim();
      final className = at(classIdx);
      final subject = at(subjectIdx);
      final name = at(nameIdx);
      if (className.isEmpty || subject.isEmpty || name.isEmpty) continue;
      final marks = <AssessmentMark>[];
      var any = false;
      for (final cat in cats) {
        final idx = catIdx[cat.id];
        double? score;
        if (idx != null) {
          final raw = at(idx);
          if (raw.isNotEmpty) {
            score = double.tryParse(raw)?.clamp(0, 100);
            if (score != null) any = true;
          }
        }
        marks.add(
          AssessmentMark(
            categoryId: cat.id,
            label: cat.label,
            weightPercent: cat.weightPercent,
            score: score,
            enteredAt: score == null ? null : DateTime.now(),
          ),
        );
      }
      if (!any) continue;
      final result = MarkbookService.instance.enterClassAssessments(
        className: className,
        subject: subject,
        teacherId: teacherId,
        assessmentsByStudent: {name: marks},
      );
      saved += result.saved;
    }
    return saved;
  }

  Future<void> shareCsv({
    required String csv,
    required String fileName,
    required String subject,
  }) async {
    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(csv)),
      mimeType: 'text/csv',
      name: fileName,
    );
    await Share.shareXFiles([file], subject: subject, text: subject);
  }

  static String _statusToken(AttendanceStatus status) => switch (status) {
        AttendanceStatus.present => 'P',
        AttendanceStatus.absent => 'A',
        AttendanceStatus.late => 'L',
        AttendanceStatus.excused => 'E',
      };

  static AttendanceStatus? _parseStatus(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'p':
      case 'present':
        return AttendanceStatus.present;
      case 'a':
      case 'absent':
        return AttendanceStatus.absent;
      case 'l':
      case 'late':
        return AttendanceStatus.late;
      case 'e':
      case 'excused':
        return AttendanceStatus.excused;
      default:
        return null;
    }
  }

  static DateTime? _parseDate(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final iso = DateTime.tryParse(t);
    if (iso != null) return iso;
    final parts = t.split(RegExp(r'[/-]'));
    if (parts.length != 3) return null;
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    final c = int.tryParse(parts[2]);
    if (a == null || b == null || c == null) return null;
    if (a > 31) return DateTime(a, b, c);
    return DateTime(c, b, a);
  }

  static String _isoDay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static List<List<String>> _parseTable(String text) {
    return text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map(_splitCsvLine)
        .toList();
  }

  static List<String> _splitCsvLine(String line) {
    final out = <String>[];
    final buf = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (ch == ',' && !quoted) {
        out.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    out.add(buf.toString());
    return out;
  }

  static String _csvLine(List<String> cells) {
    return cells.map((cell) {
      if (cell.contains(',') || cell.contains('"') || cell.contains('\n')) {
        return '"${cell.replaceAll('"', '""')}"';
      }
      return cell;
    }).join(',');
  }

  static String _norm(String value) =>
      value.trim().toLowerCase().replaceAll('_', ' ');

  static int? _indexOf(List<String> header, List<String> aliases) {
    for (var i = 0; i < header.length; i++) {
      if (aliases.contains(header[i])) return i;
    }
    return null;
  }
}
