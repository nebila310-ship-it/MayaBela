import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/library_rental_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/module_id_aliases.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/student_sis_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String read(String path) => File(path).readAsStringSync();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LibraryRentalService.instance.resetForTests();
    AuthService.currentUser = RegisteredUser(
      username: 'lib.p4',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
      fullName: 'Librarian',
    );
  });

  tearDown(() {
    LibraryRentalService.instance.resetForTests();
    AuthService.currentUser = null;
  });

  test('checkout requires an available copy and return frees it', () async {
    final copies = await LibraryRentalService.instance.addCopies(
      materialId: 'book-p4',
      bookTitle: 'Amharic reader',
      count: 1,
    );
    expect(copies.single.copyCode, isNotEmpty);
    expect(LibraryRentalService.instance.copyCounts('book-p4').available, 1);

    final loan = await LibraryRentalService.instance.checkout(
      copyId: copies.single.id,
      studentId: 'STU-P4',
      studentName: 'Phase Four Child',
      dueDate: DateTime(2026, 10, 20),
    );
    expect(loan.copyCode, copies.single.copyCode);
    expect(LibraryRentalService.instance.copyCounts('book-p4').available, 0);
    expect(LibraryRentalService.instance.copyCounts('book-p4').checkedOut, 1);

    await expectLater(
      LibraryRentalService.instance.checkout(
        copyId: copies.single.id,
        studentId: 'STU-P4B',
        studentName: 'Someone Else',
      ),
      throwsA(isA<StateError>()),
    );

    await LibraryRentalService.instance.markReturned(loan.id);
    expect(LibraryRentalService.instance.copyCounts('book-p4').available, 1);
    expect(
      LibraryRentalService.instance.all.single.isActive,
      isFalse,
    );
  });

  test('overdue report and CSV list only past-due active loans', () async {
    final copies = await LibraryRentalService.instance.addCopies(
      materialId: 'book-p4-due',
      bookTitle: 'Science atlas',
      count: 2,
    );
    await LibraryRentalService.instance.checkout(
      copyId: copies.first.id,
      studentId: 'STU-LATE',
      studentName: 'Late Returner',
      dueDate: DateTime(2026, 9, 1),
    );
    await LibraryRentalService.instance.checkout(
      copyId: copies.last.id,
      studentId: 'STU-OK',
      studentName: 'On Time',
      dueDate: DateTime(2026, 12, 1),
    );

    final asOf = DateTime(2026, 10, 4);
    final overdue = LibraryRentalService.instance.overdue(asOf: asOf);
    expect(overdue, hasLength(1));
    expect(overdue.single.studentId, 'STU-LATE');
    expect(overdue.single.daysOverdue(asOf), 33);

    final csv = LibraryRentalService.instance.overdueCsv(asOf: asOf);
    expect(csv, contains('Copy,Title,Student ID,Name,Due,Days overdue'));
    expect(csv, contains('STU-LATE'));
    expect(csv, contains('Science atlas'));
    expect(csv, isNot(contains('STU-OK')));
  });

  test('SIS page assembles attendance and library loans from live stores', () {
    final student = StudentRegistryService.instance.addStudent(
      schoolId: 'TB-001',
      fullName: 'SIS Phase Four',
      grade: 'Grade 5',
      className: 'Grade 5P4',
      dateOfBirth: DateTime(2015, 4, 4),
    );
    SchoolDataService.instance.applyPersistedAttendance([
      AttendanceSession(
        className: student.className,
        date: DateTime(2026, 10, 1),
        conductedBy: 'Ms Hana',
        entries: [
          StudentAttendanceEntry(
            studentName: student.fullName,
            studentId: student.studentId,
            status: AttendanceStatus.present,
          ),
        ],
      ),
      AttendanceSession(
        className: student.className,
        date: DateTime(2026, 10, 2),
        conductedBy: 'Ms Hana',
        entries: [
          StudentAttendanceEntry(
            studentName: student.fullName,
            studentId: student.studentId,
            status: AttendanceStatus.absent,
          ),
        ],
      ),
    ]);
    LibraryRentalService.instance.applyPersisted([
      LibraryRental(
        id: 'loan-sis-p4',
        materialId: 'book-sis',
        bookTitle: 'Atlas',
        studentId: student.studentId,
        studentName: student.fullName,
        isPaid: false,
        rentedAt: DateTime(2026, 9, 20),
        copyId: 'copy-1',
        copyCode: 'ATLA-001',
        dueDate: DateTime(2026, 10, 1),
      ),
    ], merge: false);

    final sis = StudentSisProfile.load(student.studentId);
    expect(sis, isNotNull);
    expect(sis!.attendance.present, 1);
    expect(sis.attendance.absent, 1);
    expect(sis.libraryLoans.single.copyCode, 'ATLA-001');
    expect(sis.libraryLoans.single.isOverdue(DateTime(2026, 10, 4)), isTrue);
  });

  test('SIS route reuses students rights and leftover copies stay 30s', () {
    expect(normalizeModuleId('sis'), 'students');
    expect(ModuleAccess.canView('sis'), isTrue);
    expect(CloudSyncEngine.standardPriority, contains(AppCollections.libraryCopies));
    expect(CloudSyncEngine.highPriority, isNot(contains(AppCollections.libraryCopies)));
  });

  test('library circulation and SIS page are wired on the desks', () {
    final library = read('lib/web_erp/pages/web_library_page.dart');
    expect(library, contains('Circulation'));
    expect(library, contains('Add copies'));
    expect(library, contains('Checkout copy'));
    expect(library, contains('Export overdue CSV'));

    final sis = read('lib/web_erp/pages/web_sis_page.dart');
    expect(sis, contains('Student information'));
    expect(sis, contains('StudentSisRecordView'));
    expect(sis, contains('This is not a second roster'));

    final students = read('lib/web_erp/pages/web_students_table_page.dart');
    expect(students, contains('Student SIS'));
    expect(students, contains("onNavigate?.call('sis')"));

    final router = read('lib/web_erp/router/web_erp_router.dart');
    expect(router, contains("case 'sis':"));
  });
}
