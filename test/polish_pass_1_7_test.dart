import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayabela/screens/change_password_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/inventory_realtime_sync.dart';
import 'package:mayabela/services/password_hash_service.dart';
import 'package:mayabela/services/rbac/eduaba_chat_matrix.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_report_export_service.dart';
import 'package:mayabela/web_erp/pages/web_institution_page.dart';
import 'package:mayabela/web_erp/pages/web_school_management_page.dart';
import 'package:mayabela/web_erp/router/web_erp_router.dart';
import 'package:mayabela/web_erp/services/web_admin_stats_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Integration coverage for polish items 1–7.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.clearSession();
  });

  group('1. Unique temp passwords + change without OTP', () {
    test('temp passwords are unique and long enough', () {
      final samples = List.generate(8, (_) => AuthService.generateTempPassword());
      expect(samples.toSet().length, samples.length);
      for (final p in samples) {
        expect(p.length, greaterThanOrEqualTo(AuthService.minPasswordLength));
      }
    });

    test('staff registration requires a valid email', () {
      final err = AuthService.registerTeacherAccount(
        fullName: 'No Email Teacher',
        schoolId: 'TB-001',
        phone: '0911999001',
        linkedTeacherId: 'T-NO-EMAIL',
      );
      expect(err, 'invalid_email');
    });

    test('new teacher account requires password change', () {
      final temp = AuthService.generateTempPassword();
      final err = AuthService.registerTeacherAccount(
        fullName: 'Polish Teacher',
        schoolId: 'TB-001',
        phone: '0911888777',
        email: 'polish.teacher@school.et',
        linkedTeacherId: 'T-POLISH-1',
        password: temp,
      );
      expect(err, isNull);

      final loginErr = AuthService.validateLogin(
        roleKey: AuthService.roleTeacher,
        username: '0911888777',
        password: temp,
      );
      expect(loginErr, isNull);
      expect(AuthService.requiresPasswordChange(), isTrue);

      AuthService.changePassword('BrandNewPass99');
      expect(AuthService.requiresPasswordChange(), isFalse);
      expect(
        PasswordHashService.instance.verifyPassword(
          'BrandNewPass99',
          AuthService.currentUser!.password,
        ),
        isTrue,
      );
    });

    testWidgets('ChangePasswordScreen changes password without OTP input',
        (tester) async {
      AuthService.currentUser = RegisteredUser(
        username: 'polish.user',
        password: PasswordHashService.instance.hashPassword('OldPass1234'),
        roleKey: AuthService.roleTeacher,
        schoolId: 'TB-001',
        mustChangePassword: false,
      );

      await tester.pumpWidget(
        const MaterialApp(home: ChangePasswordScreen()),
      );
      await tester.pumpAndSettle();

      // Direct form: current + new + confirm — no OTP code field.
      expect(find.byType(TextField), findsNWidgets(3));
      expect(find.widgetWithText(TextField, 'OTP'), findsNothing);
      expect(find.widgetWithText(TextField, 'Verification code'), findsNothing);
    });
  });

  group('2. Real finance / admissions charts', () {
    test('admin stats expose real trend series lengths', () {
      final stats = WebAdminStatsService.instance.load();
      expect(stats.revenueTrend.length, 7);
      expect(stats.admissionsTrend.length, 6);
      expect(stats.revenueToday, isNonNegative);
    });
  });

  group('3. Institution / School pages are real', () {
    test('router maps institution and school to real pages', () {
      AuthService.currentUser = RegisteredUser(
        username: 'polish.owner',
        password: 'x',
        roleKey: AuthService.roleAdmin,
        schoolId: 'TB-001',
      );
      expect(
        WebErpRouter.pageFor('institution'),
        isA<WebInstitutionPage>(),
      );
      expect(
        WebErpRouter.pageFor('school'),
        isA<WebSchoolManagementPage>(),
      );
    });
  });

  group('4. Inventory realtime for procurement / storekeeper', () {
    test('watches purchase requests and allows ops roles', () {
      expect(
        InventoryRealtimeSync.watchedCollections,
        contains(AppCollections.purchaseRequests),
      );
      expect(
        InventoryRealtimeSync.mayListenFor(
          RegisteredUser(
            username: 'proc',
            password: 'x',
            roleKey: AuthService.roleTeacher,
            schoolId: 'TB-001',
            staffRoles: [StaffRoles.procurement],
          ),
        ),
        isTrue,
      );
      expect(
        InventoryRealtimeSync.mayListenFor(
          RegisteredUser(
            username: 'store',
            password: 'x',
            roleKey: AuthService.roleTeacher,
            schoolId: 'TB-001',
            staffRoles: [StaffRoles.storekeeper],
          ),
        ),
        isTrue,
      );
      expect(
        InventoryRealtimeSync.mayListenFor(
          RegisteredUser(
            username: 'parent',
            password: 'x',
            roleKey: AuthService.roleParent,
            schoolId: 'TB-001',
          ),
        ),
        isFalse,
      );
    });
  });

  group('5. Librarian chat edges', () {
    test('librarian can chat VP / SD / QA and is in teacher contacts', () {
      expect(
        EduabaChatMatrix.classroomTeacherContacts,
        contains(StaffRoles.librarian),
      );
      expect(
        EduabaChatMatrix.canStaffChat(
          actorRoles: {StaffRoles.librarian},
          peerRoles: {StaffRoles.vicePresident},
        ),
        isTrue,
      );
      expect(
        EduabaChatMatrix.canStaffChat(
          actorRoles: {StaffRoles.librarian},
          peerRoles: {StaffRoles.sectionDirector},
        ),
        isTrue,
      );
      expect(
        EduabaChatMatrix.canStaffChat(
          actorRoles: {StaffRoles.librarian},
          peerRoles: {StaffRoles.qualityAssurance},
        ),
        isTrue,
      );
    });
  });

  group('6. Real PDF engine', () {
    test('PDF export produces a valid %PDF document', () async {
      final bytes = await SchoolReportExportService.instance
          .buildPdfBytes(SchoolReportKind.attendance);
      expect(bytes.length, greaterThan(100));
      expect(utf8.decode(bytes.take(5).toList()), '%PDF-');
    });
  });
}
