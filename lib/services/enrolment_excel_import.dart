import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel_plus/excel_plus.dart';

import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/student_excel_import.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/utils/email_utils.dart';
import 'package:mayabela/utils/phone_utils.dart';

/// One Fenote enrolment workbook (form sheets + register sheets).
class EnrolmentWorkbookDraft {
  const EnrolmentWorkbookDraft({
    required this.students,
    required this.teachers,
    required this.staff,
    required this.skipped,
    this.isFenote = true,
  });

  final List<EnrolmentStudentDraft> students;
  final List<EnrolmentTeacherDraft> teachers;
  final List<EnrolmentStaffDraft> staff;
  final List<String> skipped;
  final bool isFenote;

  int get readyCount => students.length + teachers.length + staff.length;

  bool get isEmpty => readyCount == 0 && skipped.isEmpty;
}

class EnrolmentStudentDraft {
  const EnrolmentStudentDraft({
    required this.fullName,
    required this.grade,
    required this.className,
    required this.dateOfBirth,
    this.gender,
    this.fatherName,
    this.fatherPhone,
    this.motherName,
    this.motherPhone,
    this.guardianName,
    this.guardianPhone,
    this.emergencyContact1Name,
    this.emergencyPhone1,
    this.emergencyContact2Name,
    this.emergencyPhone2,
    this.campus,
    this.house,
    this.fundingType = StudentFundingType.regular,
    this.homeroomTeacherId,
    this.transportEnabled = false,
    this.transportId,
    this.hasMedicalCondition = false,
    this.medicalConditionDetails,
    this.otherMedicalInfo,
    this.academicYear,
    this.source = '',
  });

  final String fullName;
  final String grade;
  final String className;
  final DateTime dateOfBirth;
  final String? gender;
  final String? fatherName;
  final String? fatherPhone;
  final String? motherName;
  final String? motherPhone;
  final String? guardianName;
  final String? guardianPhone;
  final String? emergencyContact1Name;
  final String? emergencyPhone1;
  final String? emergencyContact2Name;
  final String? emergencyPhone2;
  final String? campus;
  final String? house;
  final StudentFundingType fundingType;
  final String? homeroomTeacherId;
  final bool transportEnabled;
  final String? transportId;
  final bool hasMedicalCondition;
  final String? medicalConditionDetails;
  final String? otherMedicalInfo;
  final String? academicYear;
  final String source;
}

class EnrolmentTeacherDraft {
  const EnrolmentTeacherDraft({
    required this.fullName,
    required this.email,
    required this.phone,
    this.employeeId,
    this.campus,
    this.roles = const [],
    this.subjects = const [],
    this.assignedClass = '',
    this.classAssignments = const [],
    this.source = '',
  });

  final String fullName;
  final String email;
  final String phone;
  final String? employeeId;
  final String? campus;
  final List<TeacherStaffRole> roles;
  final List<String> subjects;
  final String assignedClass;
  final List<TeacherClassAssignment> classAssignments;
  final String source;
}

class EnrolmentStaffDraft {
  const EnrolmentStaffDraft({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.staffRoles,
    this.employeeId,
    this.campus,
    this.source = '',
  });

  final String fullName;
  final String email;
  final String phone;
  final List<String> staffRoles;
  final String? employeeId;
  final String? campus;
  final String source;
}

class EnrolmentImportResult {
  const EnrolmentImportResult({
    required this.createdStudentIds,
    required this.createdTeacherIds,
    required this.createdStaffIds,
    required this.skipped,
  });

  final List<String> createdStudentIds;
  final List<String> createdTeacherIds;
  final List<String> createdStaffIds;
  final List<String> skipped;

  int get createdCount =>
      createdStudentIds.length +
      createdTeacherIds.length +
      createdStaffIds.length;
}

enum EnrolmentImportScope { students, teachers, staff, all }

/// Reads the Fenote Raey enrolment workbook (exact sheets/columns we generate).
/// Gold office ID columns are ignored. Empty rows are skipped. Partial rows
/// keep whatever the family/staff filled; only identity needed to save is
/// required (student name+DOB; teacher/staff name+email+phone).
abstract final class EnrolmentExcelImport {
  static const unassigned = 'Unassigned';

  static const _fenoteSheets = {
    'student form',
    'student register',
    'teacher form',
    'teacher register',
    'admin staff form',
    'staff register',
  };

  static bool looksLikeFenote(List<int> bytes) {
    try {
      final excel = Excel.decodeBytes(_normalizeXlsx(bytes));
      return excel.tables.keys.any(
        (name) => _fenoteSheets.contains(name.trim().toLowerCase()),
      );
    } catch (_) {
      return false;
    }
  }

  static EnrolmentWorkbookDraft parseBytes(List<int> bytes) {
    final excel = Excel.decodeBytes(_normalizeXlsx(bytes));
    final students = <EnrolmentStudentDraft>[];
    final teachers = <EnrolmentTeacherDraft>[];
    final staff = <EnrolmentStaffDraft>[];
    final skipped = <String>[];
    var recognised = false;

    for (final entry in excel.tables.entries) {
      final sheetName = entry.key.trim();
      final key = sheetName.toLowerCase();
      if (!_fenoteSheets.contains(key)) continue;
      recognised = true;
      final table = _sheetTable(entry.value);
      switch (key) {
        case 'student register':
          _parseStudentRegister(table, sheetName, students, skipped);
        case 'student form':
          _parseStudentForm(table, sheetName, students, skipped);
        case 'teacher register':
          _parseTeacherRegister(table, sheetName, teachers, skipped);
        case 'teacher form':
          _parseTeacherForm(table, sheetName, teachers, skipped);
        case 'admin staff form':
          _parseStaffForm(table, sheetName, staff, skipped);
        case 'staff register':
          _parseStaffRegister(table, sheetName, staff, skipped);
      }
    }

    if (!recognised) {
      return const EnrolmentWorkbookDraft(
        students: [],
        teachers: [],
        staff: [],
        skipped: [],
        isFenote: false,
      );
    }
    return EnrolmentWorkbookDraft(
      students: students,
      teachers: teachers,
      staff: staff,
      skipped: skipped,
    );
  }

  static List<List<String>> _sheetTable(Sheet sheet) {
    return [
      for (final row in sheet.rows)
        [for (final cell in row) _cellText(cell?.value)],
    ];
  }

  static void _parseStudentRegister(
    List<List<String>> table,
    String sheetName,
    List<EnrolmentStudentDraft> out,
    List<String> skipped,
  ) {
    final parsed = _headerMap(table);
    if (parsed == null) return;
    final header = parsed.header;
    final nameIdx = _idx(header, const ['full name', 'name']);
    if (nameIdx == null) return;

    for (var r = parsed.dataStart; r < table.length; r++) {
      final row = table[r];
      if (_rowEmpty(row, header)) continue;
      final loc = '$sheetName row ${r + 1}';
      final draft = _studentFromCells(
        (aliases) => _at(row, _idx(header, aliases)),
        loc,
        skipped,
      );
      if (draft != null) out.add(draft);
    }
  }

  static void _parseStudentForm(
    List<List<String>> table,
    String sheetName,
    List<EnrolmentStudentDraft> out,
    List<String> skipped,
  ) {
    final fields = _formFields(table);
    if (fields.isEmpty) return;
    if (_blank(fields, const ['full name', 'name'])) {
      if (_formHasAnyValue(fields)) {
        skipped.add('$sheetName: missing full name');
      }
      return;
    }
    final draft = _studentFromCells(
      (aliases) => _formGet(fields, aliases),
      sheetName,
      skipped,
    );
    if (draft != null) out.add(draft);
  }

  static void _parseTeacherRegister(
    List<List<String>> table,
    String sheetName,
    List<EnrolmentTeacherDraft> out,
    List<String> skipped,
  ) {
    final parsed = _headerMap(table);
    if (parsed == null) return;
    final header = parsed.header;
    if (_idx(header, const ['full name', 'name']) == null) return;

    for (var r = parsed.dataStart; r < table.length; r++) {
      final row = table[r];
      if (_rowEmpty(row, header)) continue;
      final loc = '$sheetName row ${r + 1}';
      final draft = _teacherFromCells(
        (aliases) => _at(row, _idx(header, aliases)),
        loc,
        skipped,
      );
      if (draft != null) out.add(draft);
    }
  }

  static void _parseTeacherForm(
    List<List<String>> table,
    String sheetName,
    List<EnrolmentTeacherDraft> out,
    List<String> skipped,
  ) {
    final fields = _formFields(table);
    if (fields.isEmpty) return;
    if (_blank(fields, const ['full name', 'name']) &&
        _blank(fields, const ['phone number login', 'phone login', 'phone']) &&
        _blank(fields, const ['email for password reset', 'email'])) {
      return;
    }
    final draft = _teacherFromCells(
      (aliases) => _formGet(fields, aliases),
      sheetName,
      skipped,
    );
    if (draft != null) out.add(draft);
  }

  static void _parseStaffRegister(
    List<List<String>> table,
    String sheetName,
    List<EnrolmentStaffDraft> out,
    List<String> skipped,
  ) {
    final parsed = _headerMap(table);
    if (parsed == null) return;
    final header = parsed.header;
    if (_idx(header, const ['full name', 'name']) == null) return;

    for (var r = parsed.dataStart; r < table.length; r++) {
      final row = table[r];
      if (_rowEmpty(row, header)) continue;
      final loc = '$sheetName row ${r + 1}';
      final primary = _at(row, _idx(header, const ['primary role']));
      final second = _at(row, _idx(header, const ['second role']));
      final roles = <String>[
        if (roleKeyFromLabel(primary) != null) roleKeyFromLabel(primary)!,
        if (roleKeyFromLabel(second) != null) roleKeyFromLabel(second)!,
      ];
      final draft = _staffFromCells(
        (aliases) => _at(row, _idx(header, aliases)),
        loc,
        skipped,
        extraRoles: roles,
      );
      if (draft != null) out.add(draft);
    }
  }

  static void _parseStaffForm(
    List<List<String>> table,
    String sheetName,
    List<EnrolmentStaffDraft> out,
    List<String> skipped,
  ) {
    final fields = _formFields(table);
    if (fields.isEmpty) return;
    if (_blank(fields, const ['full name', 'name']) &&
        _blank(fields, const ['phone number login', 'phone login', 'phone']) &&
        _blank(fields, const ['email for password reset', 'email'])) {
      return;
    }
    final roleYes = <String>[];
    for (final entry in fields.entries) {
      if (!entry.key.startsWith('role ')) continue;
      if (!_isYes(entry.value)) continue;
      final key = roleKeyFromLabel(entry.key.substring(5));
      if (key != null) roleYes.add(key);
    }
    final custom = _formGet(fields, const [
      'other custom school role',
      'other custom role',
    ]);
    final customKey = roleKeyFromLabel(custom);
    final draft = _staffFromCells(
      (aliases) => _formGet(fields, aliases),
      sheetName,
      skipped,
      extraRoles: [
        ...roleYes,
        if (customKey != null) customKey,
      ],
    );
    if (draft != null) out.add(draft);
  }

  static EnrolmentStudentDraft? _studentFromCells(
    String Function(List<String> aliases) get,
    String loc,
    List<String> skipped,
  ) {
    final name = get(const ['full name', 'name']);
    if (name.isEmpty) {
      skipped.add('$loc: missing full name');
      return null;
    }
    final dobRaw = get(const ['date of birth', 'dob', 'birth date']);
    final dob = parseDate(dobRaw);
    if (dob == null) {
      skipped.add('$name ($loc): missing date of birth');
      return null;
    }
    final grade = _normalizeGrade(get(const ['grade', 'year']));
    final section = get(const ['section']);
    final className = grade.isEmpty && section.isEmpty
        ? unassigned
        : StudentRegistryService.buildClassName(
            grade.isEmpty ? unassigned : grade,
            section,
          );
    final medicalDetails = _emptyToNull(
      get(const ['specify medical condition', 'medical details']),
    );
    final medicalFlag = get(const [
      'has a medical condition',
      'medical condition',
    ]);
    final hasMedical = _isYes(medicalFlag) ||
        (medicalDetails != null && medicalDetails.isNotEmpty);
    final transport = _isYes(
      get(const ['school bus transport enabled', 'transport']),
    );
    return EnrolmentStudentDraft(
      fullName: name,
      grade: grade.isEmpty ? unassigned : grade,
      className: className,
      dateOfBirth: dob,
      gender: _emptyToNull(_normalizeGender(get(const ['gender']))),
      fatherName: _emptyToNull(get(const ['fathers name', 'father name'])),
      fatherPhone: _emptyToNull(get(const ['father phone'])),
      motherName: _emptyToNull(get(const ['mothers name', 'mother name'])),
      motherPhone: _emptyToNull(get(const ['mother phone'])),
      guardianName: _emptyToNull(get(const ['guardian name'])),
      guardianPhone: _emptyToNull(get(const ['guardian phone'])),
      emergencyContact1Name: _emptyToNull(
        get(const ['emergency contact 1 name', 'emergency 1 name']),
      ),
      emergencyPhone1: _emptyToNull(get(const ['emergency phone 1'])),
      emergencyContact2Name: _emptyToNull(
        get(const ['emergency contact 2 name', 'emergency 2 name']),
      ),
      emergencyPhone2: _emptyToNull(get(const ['emergency phone 2'])),
      campus: _emptyToNull(get(const ['campus'])),
      house: _emptyToNull(
        get(const ['house gojo colour', 'house']),
      ),
      fundingType: _funding(get(const ['student type', 'funding'])),
      homeroomTeacherId: _emptyToNull(get(const ['homeroom teacher id'])),
      transportEnabled: transport,
      transportId: _emptyToNull(get(const ['bus link id'])),
      hasMedicalCondition: hasMedical,
      medicalConditionDetails: hasMedical ? medicalDetails : null,
      otherMedicalInfo: _emptyToNull(
        get(const ['other medical information', 'other medical info']),
      ),
      academicYear: _emptyToNull(
        get(const [
          'academic year g.c.',
          'academic year gc',
          'academic year e.c.',
          'academic year ec',
          'academic year',
        ]),
      ),
      source: loc,
    );
  }

  static EnrolmentTeacherDraft? _teacherFromCells(
    String Function(List<String> aliases) get,
    String loc,
    List<String> skipped,
  ) {
    final name = get(const ['full name', 'name']);
    final email = EmailUtils.userFacing(
      get(const ['email for password reset', 'email']),
    );
    final phone = get(const [
      'phone number login',
      'phone login',
      'phone',
    ]);
    if (name.isEmpty) {
      skipped.add('$loc: missing full name');
      return null;
    }
    if (email == null) {
      skipped.add('$name ($loc): need a real email');
      return null;
    }
    if (!PhoneUtils.isValidLoginPhone(phone)) {
      skipped.add('$name ($loc): need a valid login phone');
      return null;
    }
    final mainSubject = get(const ['main subject']);
    final other = get(const ['other subjects']);
    final subjects = <String>[
      if (mainSubject.trim().isNotEmpty) mainSubject.trim(),
      ...other
          .split(RegExp(r'[,;]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty),
    ];
    final classes = get(const ['assigned classes', 'assigned class'])
        .split(RegExp(r'[,;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final roles = _teachRoles(get(const ['teaching role']));
    final assignmentRole = roles.contains(TeacherStaffRole.homeroomTeacher)
        ? TeacherStaffRole.homeroomTeacher
        : TeacherStaffRole.subjectTeacher;
    return EnrolmentTeacherDraft(
      fullName: name,
      email: email,
      phone: phone,
      employeeId: _emptyToNull(
        get(const [
          'teacher hr id already in use',
          'staff hr id already in use',
          'existing hr id',
        ]),
      ),
      campus: _emptyToNull(get(const ['campus'])),
      roles: roles,
      subjects: subjects,
      assignedClass: classes.isEmpty ? '' : classes.join(', '),
      classAssignments: [
        for (final className in classes)
          TeacherClassAssignment(className: className, role: assignmentRole),
      ],
      source: loc,
    );
  }

  static EnrolmentStaffDraft? _staffFromCells(
    String Function(List<String> aliases) get,
    String loc,
    List<String> skipped, {
    List<String> extraRoles = const [],
  }) {
    final name = get(const ['full name', 'name']);
    final email = EmailUtils.userFacing(
      get(const ['email for password reset', 'email']),
    );
    final phone = get(const [
      'phone number login',
      'phone login',
      'phone',
    ]);
    if (name.isEmpty) {
      skipped.add('$loc: missing full name');
      return null;
    }
    if (email == null) {
      skipped.add('$name ($loc): need a real email');
      return null;
    }
    if (!PhoneUtils.isValidLoginPhone(phone)) {
      skipped.add('$name ($loc): need a valid login phone');
      return null;
    }
    final roles = <String>[];
    for (final key in extraRoles) {
      if (!roles.contains(key)) roles.add(key);
    }
    if (roles.isEmpty) roles.add(StaffRoles.staffs);
    return EnrolmentStaffDraft(
      fullName: name,
      email: email,
      phone: phone,
      staffRoles: roles,
      employeeId: _emptyToNull(
        get(const [
          'staff hr id already in use',
          'teacher hr id already in use',
          'existing hr id',
        ]),
      ),
      campus: _emptyToNull(get(const ['campus'])),
      source: loc,
    );
  }

  static ({List<String> header, int dataStart})? _headerMap(
    List<List<String>> table,
  ) {
    for (var i = 0; i < table.length && i < 6; i++) {
      final header = table[i].map(_norm).toList();
      if (_idx(header, const ['full name', 'name']) != null) {
        return (header: header, dataStart: i + 1);
      }
    }
    return null;
  }

  /// Form sheets: column A = label, column B = value. Stop at office-use.
  static Map<String, String> _formFields(List<List<String>> table) {
    final out = <String, String>{};
    for (final row in table) {
      if (row.isEmpty) continue;
      final labelRaw = row.first.trim();
      if (labelRaw.toUpperCase().contains('OFFICE USE ONLY')) break;
      final label = _norm(labelRaw);
      if (label.isEmpty || _isOfficeHeader(label)) continue;
      if (RegExp(r'^\d+\.').hasMatch(labelRaw.trim())) continue;
      final value = row.length > 1 ? row[1].trim() : '';
      if (label.isEmpty) continue;
      out[label] = value;
    }
    return out;
  }

  static bool _formHasAnyValue(Map<String, String> fields) =>
      fields.values.any((v) => v.trim().isNotEmpty);

  static bool _blank(Map<String, String> fields, List<String> aliases) =>
      _formGet(fields, aliases).isEmpty;

  static String _formGet(Map<String, String> fields, List<String> aliases) {
    for (final alias in aliases) {
      final want = _norm(alias);
      final direct = fields[want];
      if (direct != null && direct.trim().isNotEmpty) return direct.trim();
      for (final entry in fields.entries) {
        if (entry.key == want || entry.key.startsWith(want)) {
          if (entry.value.trim().isNotEmpty) return entry.value.trim();
        }
      }
    }
    return '';
  }

  static bool _rowEmpty(List<String> row, List<String> header) {
    for (var i = 0; i < header.length; i++) {
      if (_isOfficeHeader(header[i])) continue;
      if (i < row.length && row[i].trim().isNotEmpty) return false;
    }
    return true;
  }

  static bool _isOfficeHeader(String norm) {
    if (norm == 'class name') return true;
    if (norm.startsWith('student id')) return true;
    if (norm.startsWith('teacher id')) return true;
    if (norm == 'staff id' || norm.startsWith('staff id issued')) return true;
    if (norm.startsWith('portal')) return true;
    if (norm == 'login username') return true;
    if (norm.contains('temp password') ||
        norm.contains('temporary password')) {
      return true;
    }
    if (norm == 'parent invite phone' ||
        norm == 'parent invite sent to phone' ||
        norm == 'invite channel') {
      return true;
    }
    if (norm == 'date entered' ||
        norm == 'entered by' ||
        norm == 'entered by registrar' ||
        norm == 'checked by') {
      return true;
    }
    if (norm == 'roles granted') return true;
    if (norm.startsWith('must change') || norm == 'account active') {
      return true;
    }
    if (norm.contains('photo uploaded') ||
        norm.contains('module rights') ||
        norm.contains('classes assigned in software')) {
      return true;
    }
    return false;
  }

  static int? _idx(List<String> header, List<String> aliases) {
    final wants = aliases.map(_norm).toList();
    for (var i = 0; i < header.length; i++) {
      if (_isOfficeHeader(header[i])) continue;
      if (wants.contains(header[i])) return i;
    }
    for (var i = 0; i < header.length; i++) {
      if (_isOfficeHeader(header[i])) continue;
      for (final want in wants) {
        if (header[i] == want || header[i].startsWith(want)) return i;
      }
    }
    return null;
  }

  static String _at(List<String> row, int? idx) {
    if (idx == null || idx < 0 || idx >= row.length) return '';
    return row[idx].trim();
  }

  static String _norm(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('*', ' ')
      .replaceAll("'", '')
      .replaceAll('’', '')
      .replaceAll('_', ' ')
      .replaceAll('/', ' ')
      .replaceAll('(', ' ')
      .replaceAll(')', ' ')
      .replaceAll(':', ' ')
      .replaceAll('?', ' ')
      .replaceAll('-', ' ')
      .replaceAll('.', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String? _emptyToNull(String value) {
    final t = value.trim();
    return t.isEmpty ? null : t;
  }

  static bool _isYes(String raw) {
    final t = raw.trim().toLowerCase();
    return t == 'yes' || t == 'y' || t == 'true' || t == '1';
  }

  static String _normalizeGrade(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    if (RegExp(r'^\d{1,2}$').hasMatch(t)) return 'Grade $t';
    return t;
  }

  static String _normalizeGender(String raw) {
    final t = raw.trim().toLowerCase();
    if (t == 'm' || t == 'male') return 'Male';
    if (t == 'f' || t == 'female') return 'Female';
    return raw.trim();
  }

  static StudentFundingType _funding(String raw) {
    final t = raw.trim().toLowerCase();
    if (t.contains('scholar')) return StudentFundingType.scholarship;
    return StudentFundingType.regular;
  }

  static List<TeacherStaffRole> _teachRoles(String raw) {
    final t = raw.trim().toLowerCase();
    if (t.isEmpty) return const [];
    if (t.contains('both')) {
      return const [
        TeacherStaffRole.homeroomTeacher,
        TeacherStaffRole.subjectTeacher,
      ];
    }
    if (t.contains('homeroom')) return const [TeacherStaffRole.homeroomTeacher];
    if (t.contains('subject')) return const [TeacherStaffRole.subjectTeacher];
    return const [];
  }

  /// Maps workbook labels such as "Quality Assurance" to [StaffRoles] keys.
  static String? roleKeyFromLabel(String raw) {
    var n = _norm(raw);
    if (n.isEmpty) return null;
    if (n.startsWith('role ')) n = n.substring(5).trim();
    for (final role in StaffRoles.templates) {
      if (_norm(role.labelEn) == n) return role.key;
    }
    final snake = n.replaceAll(' ', '_');
    final canonical = StaffRoles.canonicalize(snake);
    if (StaffRoles.lookup(canonical) != null) return canonical;
    return null;
  }

  static DateTime? parseDate(String raw) {
    final fromStudent = StudentExcelImport.parseDate(raw);
    if (fromStudent != null) return fromStudent;
    return null;
  }

  static String _cellText(Object? value) {
    if (value == null) return '';
    if (value is DateTime) {
      return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
          '${value.day.toString().padLeft(2, '0')}';
    }
    if (value is DateCellValue) {
      return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
          '${value.day.toString().padLeft(2, '0')}';
    }
    if (value is DateTimeCellValue) {
      return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
          '${value.day.toString().padLeft(2, '0')}';
    }
    if (value is TextCellValue) {
      return value.value.toString().trim();
    }
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) {
      final serial = _excelSerialDate(value.value);
      if (serial != null) {
        return '${serial.year}-${serial.month.toString().padLeft(2, '0')}-'
            '${serial.day.toString().padLeft(2, '0')}';
      }
      if (value.value == value.value.roundToDouble()) {
        return value.value.round().toString();
      }
      return value.value.toString();
    }
    if (value is BoolCellValue) return value.value ? 'Yes' : 'No';
    if (value is FormulaCellValue) {
      return (value.cachedValue ?? value.formula).trim();
    }
    return value.toString().trim();
  }

  static DateTime? _excelSerialDate(double n) {
    if (n < 20000 || n > 80000) return null;
    return DateTime.utc(1899, 12, 30).add(Duration(days: n.round()));
  }

  /// openpyxl writes Target="/xl/worksheets/sheetN.xml"; excel_plus looks up
  /// `xl/$target`. Rewrite those targets so Fenote workbooks open.
  static List<int> _normalizeXlsx(List<int> bytes) {
    try {
      final incoming = ZipDecoder().decodeBytes(bytes);
      final outgoing = Archive();
      var changed = false;
      for (final file in incoming.files) {
        if (file.name == 'xl/_rels/workbook.xml.rels') {
          final text = utf8.decode(file.content);
          if (text.contains('Target="/xl/worksheets/')) {
            outgoing.addFile(
              ArchiveFile.bytes(
                file.name,
                utf8.encode(
                  text.replaceAll(
                    'Target="/xl/worksheets/',
                    'Target="worksheets/',
                  ),
                ),
              ),
            );
            changed = true;
            continue;
          }
        }
        outgoing.addFile(file);
      }
      if (!changed) return bytes;
      return ZipEncoder().encode(outgoing) ?? bytes;
    } catch (_) {
      return bytes;
    }
  }
}
