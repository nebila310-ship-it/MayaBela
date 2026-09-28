import 'package:excel_plus/excel_plus.dart';

import 'package:mayabela/models/golive_models.dart';

/// Parses CSV or xlsx class lists into [StudentImportRow]s.
/// Does not write the registry — [GoliveService] calls addStudent.
abstract final class StudentExcelImport {
  static List<StudentImportRow> parseCsv(String text) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return const [];
    final rows = lines.map(_splitCsvLine).toList();
    return _rowsFromTable(rows);
  }

  static List<StudentImportRow> parseXlsx(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return const [];
    final sheet = excel.tables.values.first;
    final table = <List<String>>[];
    for (final row in sheet.rows) {
      table.add([
        for (final cell in row) _cellText(cell?.value),
      ]);
    }
    return _rowsFromTable(table);
  }

  static List<StudentImportRow> parseBytes({
    required List<int> bytes,
    required String filename,
  }) {
    final name = filename.toLowerCase();
    if (name.endsWith('.xlsx') || name.endsWith('.xls')) {
      return parseXlsx(bytes);
    }
    return parseCsv(String.fromCharCodes(bytes));
  }

  static List<StudentImportRow> _rowsFromTable(List<List<String>> table) {
    if (table.isEmpty) return const [];
    final header = table.first.map(_normHeader).toList();
    final nameIdx = _indexOf(header, const ['full name', 'name', 'fullname']);
    final gradeIdx = _indexOf(header, const ['grade', 'year']);
    final classIdx = _indexOf(header, const ['class', 'class name', 'classname']);
    final dobIdx = _indexOf(header, const [
      'date of birth',
      'dob',
      'birth date',
      'birthday',
    ]);
    if (nameIdx == null || gradeIdx == null || classIdx == null || dobIdx == null) {
      throw StateError(
        'File needs columns for Full Name, Grade, Class, and Date of Birth.',
      );
    }
    final genderIdx = _indexOf(header, const ['gender']);
    final fatherNameIdx = _indexOf(header, const ['father name', 'father']);
    final fatherPhoneIdx = _indexOf(header, const ['father phone', 'father tel']);
    final motherNameIdx = _indexOf(header, const ['mother name', 'mother']);
    final motherPhoneIdx = _indexOf(header, const ['mother phone', 'mother tel']);
    final idIdx = _indexOf(header, const ['student id', 'id', 'stu']);

    final out = <StudentImportRow>[];
    for (var i = 1; i < table.length; i++) {
      final row = table[i];
      String at(int? idx) {
        if (idx == null || idx >= row.length) return '';
        return row[idx].trim();
      }

      final name = at(nameIdx);
      final grade = at(gradeIdx);
      final className = at(classIdx);
      final dob = parseDate(at(dobIdx));
      if (name.isEmpty || grade.isEmpty || className.isEmpty || dob == null) {
        continue;
      }
      final existing = at(idIdx);
      out.add(
        StudentImportRow(
          fullName: name,
          grade: grade,
          className: className,
          dateOfBirth: dob,
          gender: _emptyToNull(at(genderIdx)),
          fatherName: _emptyToNull(at(fatherNameIdx)),
          fatherPhone: _emptyToNull(at(fatherPhoneIdx)),
          motherName: _emptyToNull(at(motherNameIdx)),
          motherPhone: _emptyToNull(at(motherPhoneIdx)),
          existingId: existing.isEmpty ? null : existing.toUpperCase(),
        ),
      );
    }
    return out;
  }

  static DateTime? parseDate(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final iso = DateTime.tryParse(text);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    final parts = text.split(RegExp(r'[/-]'));
    if (parts.length == 3) {
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      final c = int.tryParse(parts[2]);
      if (a == null || b == null || c == null) return null;
      if (parts[0].length == 4) return DateTime(a, b, c);
      if (parts[2].length == 4) return DateTime(c, b, a);
    }
    return null;
  }

  static String _normHeader(String value) =>
      value.trim().toLowerCase().replaceAll('_', ' ');

  static int? _indexOf(List<String> header, List<String> aliases) {
    for (var i = 0; i < header.length; i++) {
      if (aliases.contains(header[i])) return i;
    }
    return null;
  }

  static String _cellText(Object? value) {
    if (value == null) return '';
    if (value is DateTime) {
      return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
          '${value.day.toString().padLeft(2, '0')}';
    }
    return value.toString().trim();
  }

  static String? _emptyToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();

  static List<String> _splitCsvLine(String line) {
    final out = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        out.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    out.add(buf.toString());
    return out;
  }
}
