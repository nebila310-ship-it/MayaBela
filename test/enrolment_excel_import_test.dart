import 'dart:io';

import 'package:excel_plus/excel_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/enrolment_excel_import.dart';
import 'package:mayabela/services/enrolment_import_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = RegisteredUser(
      username: 'admin.fenote',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'FEN101',
    );
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  test('empty Fenote workbook is recognised and imports nothing', () {
    final bytes = File(
      'docs/fenote-raey/enrolment-forms/Fenote_Raey_Enrolment_Forms.xlsx',
    ).readAsBytesSync();
    expect(EnrolmentExcelImport.looksLikeFenote(bytes), isTrue);
    final draft = EnrolmentExcelImport.parseBytes(bytes);
    expect(draft.isFenote, isTrue);
    expect(draft.students, isEmpty);
    expect(draft.teachers, isEmpty);
    expect(draft.staff, isEmpty);
  });

  test('reads Fenote register sheets including partial rows', () {
    final draft = EnrolmentExcelImport.parseBytes(_filledFenoteWorkbook());
    expect(draft.students, hasLength(2));
    expect(draft.students[0].fullName, 'Abebe Kebede');
    expect(draft.students[0].grade, 'Grade 2');
    expect(draft.students[0].className, 'Grade 2A');
    expect(draft.students[0].fatherPhone, '0911222333');
    expect(draft.students[0].fundingType, StudentFundingType.scholarship);
    expect(draft.students[0].transportEnabled, isTrue);
    expect(draft.students[0].house, 'Blue');

    final partial = draft.students[1];
    expect(partial.fullName, 'Partial Only');
    expect(partial.grade, EnrolmentExcelImport.unassigned);
    expect(partial.className, EnrolmentExcelImport.unassigned);

    expect(
      draft.skipped.any((line) => line.contains('No Dob Kid')),
      isTrue,
    );

    expect(draft.teachers, hasLength(1));
    expect(draft.teachers.first.fullName, 'Sara Teacher');
    expect(draft.teachers.first.email, 'sara.teacher@school.et');
    expect(draft.staff, hasLength(1));
    expect(draft.staff.first.staffRoles, contains(StaffRoles.qualityAssurance));
    expect(
      draft.skipped.any((line) => line.contains('Incomplete Teacher')),
      isTrue,
    );
  });

  test('writes filled Fenote register into generated workbook bytes', () {
    final raw = File(
      'docs/fenote-raey/enrolment-forms/Fenote_Raey_Enrolment_Forms.xlsx',
    ).readAsBytesSync();
    final excel = Excel.decodeBytes(raw);
    final sheet = excel['Student register'];
    void set(int col, String value) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 2))
          .value = TextCellValue(value);
    }

    set(0, 'Liya From Template');
    set(1, 'Female');
    set(2, '12/03/2018');
    set(16, 'Grade 3');
    set(17, 'B');
    set(25, 'STU-9999');

    final draft = EnrolmentExcelImport.parseBytes(excel.encode()!);
    expect(draft.students, hasLength(1));
    expect(draft.students.first.fullName, 'Liya From Template');
    expect(draft.students.first.className, 'Grade 3B');
  });

  test('import places students, teachers, and staff and skips incomplete',
      () async {
    final draft = EnrolmentExcelImport.parseBytes(_filledFenoteWorkbook());
    final result = await EnrolmentImportService.instance.importDraft(draft);
    expect(result.createdStudentIds, hasLength(2));
    expect(result.createdStudentIds.first, startsWith('STU-'));
    expect(result.createdStudentIds.first, isNot('STU-9999'));

    final abebe = StudentRegistryService.instance
        .lookupAnyById(result.createdStudentIds.first);
    expect(abebe?.fullName, 'Abebe Kebede');
    expect(abebe?.className, 'Grade 2A');
    expect(abebe?.fatherPhone, isNotNull);
    expect(abebe?.house, 'Blue');
    expect(abebe?.fundingType.isScholarship, isTrue);
    expect(abebe?.transportEnabled, isTrue);

    final partial = StudentRegistryService.instance
        .lookupAnyById(result.createdStudentIds.last);
    expect(partial?.fullName, 'Partial Only');
    expect(partial?.grade, EnrolmentExcelImport.unassigned);

    expect(result.createdTeacherIds, hasLength(1));
    expect(result.createdTeacherIds.first, startsWith('TCH-'));
    final teacher = TeacherRegistryService.instance
        .lookupAnyById(result.createdTeacherIds.first);
    expect(teacher?.email, 'sara.teacher@school.et');
    expect(AuthService.findUser('0911444555'), isNotNull);

    expect(result.createdStaffIds, hasLength(1));
    expect(result.createdStaffIds.first, startsWith('QA-'));
    final staff = TeacherRegistryService.instance
        .lookupAnyById(result.createdStaffIds.first);
    expect(staff?.staffRoles, contains(StaffRoles.qualityAssurance));

    expect(result.skipped, isNotEmpty);

    final again = await EnrolmentImportService.instance.importDraft(draft);
    expect(again.createdStudentIds, isEmpty);
    expect(again.skipped.any((line) => line.contains('same name + class')),
        isTrue);
  });

  test('student form sheet one person maps into Add Student fields', () {
    final excel = Excel.createExcel();
    final sheet = excel['Student form'];
    const fields = [
      ['Full name *', 'Hana Form'],
      ['Date of birth *', '01/02/2017'],
      ['Gender *', 'Female'],
      ["Father's name", 'Alem'],
      ['Grade *', 'Grade 1'],
      ['Section *', 'C'],
      ['OFFICE USE ONLY — copy from MayaBela AFTER save.', ''],
      ['Student ID', 'STU-0000'],
    ];
    for (var i = 0; i < fields.length; i++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 2))
          .value = TextCellValue(fields[i][0]);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 2))
          .value = TextCellValue(fields[i][1]);
    }
    final draft = EnrolmentExcelImport.parseBytes(excel.encode()!);
    expect(draft.students, hasLength(1));
    expect(draft.students.first.fullName, 'Hana Form');
    expect(draft.students.first.className, 'Grade 1C');
    expect(draft.students.first.fatherName, 'Alem');
  });
}

List<int> _filledFenoteWorkbook() {
  final excel = Excel.createExcel();
  _writeRegister(
    excel,
    'Student register',
    const [
      'Full name *',
      'Gender *',
      'Date of birth *',
      "Father's name",
      'Father phone',
      "Mother's name",
      'Mother phone',
      'Guardian name',
      'Guardian phone',
      'Emergency 1 name',
      'Emergency phone 1',
      'Emergency 2 name',
      'Emergency phone 2',
      'Campus',
      'House',
      'Student type',
      'Grade *',
      'Section *',
      'Homeroom teacher ID',
      'Transport',
      'Bus link ID',
      'Medical condition',
      'Medical details',
      'Other medical info',
      'Photo on file',
      'Student ID STU-',
      'Class name',
    ],
    const [
      [
        'Abebe Kebede',
        'Male',
        '15/01/2016',
        'Kebede',
        '0911222333',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        'Main Campus',
        'Blue',
        'Scholarship student',
        'Grade 2',
        'A',
        '',
        'Yes',
        'BUS-1001',
        'No',
        '',
        '',
        '',
        'STU-9999',
        'IGNORE',
      ],
      [
        'Partial Only',
        '',
        '2017-06-01',
      ],
      [
        'No Dob Kid',
        'Female',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        'Grade 4',
        'A',
      ],
    ],
  );
  _writeRegister(
    excel,
    'Teacher register',
    const [
      'Full name *',
      'Email *',
      'Phone (login) *',
      'Existing HR ID',
      'Campus',
      'Teaching role',
      'Main subject',
      'Other subjects',
      'Assigned class(es)',
      'Emergency phone',
      'National ID',
      'Notes',
      'Teacher ID TCH-',
    ],
    const [
      [
        'Sara Teacher',
        'sara.teacher@school.et',
        '0911444555',
        '',
        'Main Campus',
        'Homeroom teacher',
        'Mathematics',
        'English',
        'Grade 2A',
      ],
      [
        'Incomplete Teacher',
        '',
        '0911666777',
      ],
    ],
  );
  _writeRegister(
    excel,
    'Staff register',
    const [
      'Full name *',
      'Email *',
      'Phone (login) *',
      'Existing HR ID',
      'Campus',
      'Job title',
      'Primary role *',
      'Second role',
      'Also teaches?',
      'Duties / notes',
      'Staff ID',
    ],
    const [
      [
        'Marta QA',
        'marta.qa@school.et',
        '0911888999',
        '',
        'Main Campus',
        'QA officer',
        'Quality Assurance',
        '',
        'No',
      ],
    ],
  );
  return excel.encode()!;
}

void _writeRegister(
  Excel excel,
  String sheetName,
  List<String> headers,
  List<List<String>> rows,
) {
  final sheet = excel[sheetName];
  sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
      TextCellValue('Fenote Raey Academy · $sheetName');
  for (var c = 0; c < headers.length; c++) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1))
        .value = TextCellValue(headers[c]);
  }
  for (var r = 0; r < rows.length; r++) {
    for (var c = 0; c < rows[r].length; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 2))
          .value = TextCellValue(rows[r][c]);
    }
  }
}
