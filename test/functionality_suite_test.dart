import 'package:mayabela/database/seed/registry_seed_builder.dart';
import 'package:mayabela/database/school_database_service.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/password_hash_service.dart';
import 'package:mayabela/services/platform_owner_service.dart';
import 'package:mayabela/utils/phone_utils.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';
import 'package:mayabela/web_erp/router/web_erp_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Executable functionality suite used by the PDF functionality report.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    AuthService.ensureRegistryLoginAccounts();
    await SchoolDatabaseService.instance.initialize();
  });

  group('Auth & credentials', () {
    test('debug demo admin login succeeds locally', () {
      final error = AuthService.validateLogin(
        roleKey: AuthService.roleAdmin,
        username: 'admin',
        password: AuthService.demoPassword,
      );
      expect(error, isNull);
      expect(AuthService.currentUser?.roleKey, AuthService.roleAdmin);
      AuthService.clearSession();
    });

    test('debug demo student login succeeds locally', () {
      final error = AuthService.validateLogin(
        roleKey: AuthService.roleStudent,
        username: 'student',
        password: AuthService.demoPassword,
      );
      expect(error, isNull);
      expect(AuthService.currentUser?.roleKey, AuthService.roleStudent);
      expect(AuthService.currentUser?.linkedStudentId, 'STU-1001');
      AuthService.clearSession();
    });

    test('wrong password rejected', () {
      final error = AuthService.validateLogin(
        roleKey: AuthService.roleTeacher,
        username: 'teacher',
        password: 'wrong-password-xx',
      );
      expect(error, 'invalid');
    });

    test('role mismatch rejected', () {
      final error = AuthService.validateLogin(
        roleKey: AuthService.roleParent,
        username: 'admin',
        password: AuthService.demoPassword,
      );
      expect(error, anyOf('invalid', 'role_mismatch'));
    });

    test('password policy minimum is 10', () {
      expect(AuthService.minPasswordLength, 10);
      expect(AuthService.tempPassword.length >= AuthService.minPasswordLength, isTrue);
    });

    test('password hash verify round-trip', () {
      final hash = PasswordHashService.instance.hashPassword('SecurePass1!');
      expect(PasswordHashService.instance.isHashed(hash), isTrue);
      expect(
        PasswordHashService.instance.verifyPassword('SecurePass1!', hash),
        isTrue,
      );
      expect(
        PasswordHashService.instance.verifyPassword('other', hash),
        isFalse,
      );
    });
  });

  group('Phone utilities', () {
    test('normalizes Ethiopian local login key', () {
      expect(PhoneUtils.normalizeLocal('911234567'), '0911234567');
      expect(PhoneUtils.loginKey('0911234567'), isNotEmpty);
      expect(PhoneUtils.isValidLoginPhone('0911234567'), isTrue);
    });

    test('builds E.164 for Ethiopia', () {
      final e164 = PhoneUtils.toE164Ethiopian('0911234567');
      expect(e164.startsWith('+251'), isTrue);
    });
  });

  group('School data / access', () {
    test('seed builds students, classes, parent links', () {
      final snapshot = RegistrySeedBuilder.buildFromRegistries();
      expect(snapshot.students.any((s) => s.studentId == 'STU-1001'), isTrue);
      expect(snapshot.classes.any((c) => c.classId == 'C001'), isTrue);
      expect(
        snapshot.parentLinks.any((l) => l.studentId == 'STU-1001'),
        isTrue,
      );
    });

    test('parent resolver reaches child and teachers', () {
      final db = SchoolDatabaseService.instance;
      final parent = db.parentForUsername('parent');
      expect(parent, isNotNull);
      final children = db.resolver.studentsForParent(parent!.parentId);
      expect(children.map((s) => s.studentId), contains('STU-1001'));
      final teachers = db.resolver.teachersForParent(parent.parentId);
      expect(teachers, isNotEmpty);
    });

    test('teacher class access boundaries', () {
      final db = SchoolDatabaseService.instance;
      expect(
        db.canTeacherAccessClass(teacherId: 'TCH-1001', classId: 'C001'),
        isTrue,
      );
      expect(
        db.canTeacherAccessClass(teacherId: 'TCH-1002', classId: 'C001'),
        isFalse,
      );
    });

    test('driver student access boundaries', () {
      final db = SchoolDatabaseService.instance;
      expect(
        db.canDriverAccessStudent(
          driverId: 'DRV-1001',
          studentId: 'STU-1001',
        ),
        isTrue,
      );
      expect(
        db.canDriverAccessStudent(
          driverId: 'DRV-1002',
          studentId: 'STU-1001',
        ),
        isFalse,
      );
    });
  });

  group('Platform owner PIN', () {
    test('PIN min length is 6', () {
      expect(PlatformOwnerService.minPinLength, 6);
    });

    test('set and verify hashed PIN', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = PlatformOwnerService.instance;
      await svc.setPin('654321');
      expect(await svc.verifyPin('654321'), isTrue);
      expect(await svc.verifyPin('000000'), isFalse);
    });
  });

  group('Web ERP surface', () {
    setUp(() {
      AuthService.currentUser = RegisteredUser(
        username: 'erp.admin',
        password: 'x',
        roleKey: AuthService.roleAdmin,
        schoolId: 'TB-001',
      );
    });

    tearDown(() {
      AuthService.currentUser = null;
    });

    test('admin nav includes core modules', () {
      final ids = webErpNavItemsForCurrentUser().map((e) => e.id).toSet();
      expect(ids.contains('dashboard'), isTrue);
      expect(ids.contains('students'), isTrue);
      expect(ids.contains('teachers'), isTrue);
      expect(ids.contains('finance'), isTrue);
      expect(ids.contains('transport'), isTrue);
      expect(ids.contains('inventory'), isTrue);
      expect(ids.contains('settings'), isTrue);
    });

    test('router resolves key admin pages to widgets', () {
      for (final id in [
        'dashboard',
        'students',
        'teachers',
        'finance',
        'transport',
        'inventory',
        'settings',
        'audit_log',
      ]) {
        final page = WebErpRouter.pageFor(id);
        expect(page, isA<Widget>(), reason: 'route $id');
      }
    });
  });
}
