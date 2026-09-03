import 'package:flutter_test/flutter_test.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';

void main() {
  tearDown(() {
    AuthService.currentUser = null;
  });

  RegisteredUser signIn(String roleKey, List<String> staffRoles) {
    final user = RegisteredUser(
      username: 'module.test',
      password: 'x',
      roleKey: roleKey,
      schoolId: 'TB-001',
      staffRoles: staffRoles,
    );
    AuthService.currentUser = user;
    return user;
  }

  group('ModuleAccess catalog', () {
    test('every module rule references known permissions', () {
      for (final entry in ModuleAccess.rules.entries) {
        for (final perm in [...entry.value.view, ...entry.value.manage]) {
          expect(
            SchoolPermissions.all.contains(perm),
            isTrue,
            reason: 'Module ${entry.key} references unknown permission $perm',
          );
        }
      }
    });

    test('every sidebar item has a module rule', () {
      signIn(AuthService.roleAdmin, const []);
      for (final item in webErpNavItemsForCurrentUser()) {
        if (item.isLogout) continue;
        expect(
          ModuleAccess.ruleFor(item.id),
          isNotNull,
          reason: 'Nav item ${item.id} has no ModuleAccess rule',
        );
      }
    });
  });

  group('Owner (admin)', () {
    test('sees and manages everything', () {
      signIn(AuthService.roleAdmin, const []);
      for (final id in ModuleAccess.rules.keys) {
        expect(ModuleAccess.canView(id), isTrue, reason: id);
        expect(ModuleAccess.canManage(id), isTrue, reason: id);
      }
      expect(ModuleAccess.hasErpAccess, isTrue);
    });
  });

  group('Multi-role staff (Procurement + Storekeeper + Transport Admin)', () {
    setUp(() => signIn(AuthService.roleTeacher, [
          StaffRoles.procurement,
          StaffRoles.storekeeper,
          StaffRoles.transportAdmin,
        ]));

    test('sees only role modules plus chrome (not full ERP baseline)', () {
      expect(ModuleAccess.canView('inventory'), isTrue);
      expect(ModuleAccess.canView('transport'), isTrue);
      // EDUABA allocation: Students is Registrar/SD/VP/Student Affairs only.
      expect(ModuleAccess.canView('students'), isFalse);
      // Chrome only — plus Maya, which is allocated to every role.
      expect(ModuleAccess.canView('dashboard'), isTrue);
      expect(ModuleAccess.canView('profile'), isTrue);
      expect(ModuleAccess.canView('settings'), isTrue);
      expect(ModuleAccess.canView('maya_assistant'), isTrue);
      expect(ModuleAccess.canView('reports'), isFalse);
      // Messages (support) and announcements are wired to all roles.
      expect(ModuleAccess.canView('support'), isTrue);
      expect(ModuleAccess.canView('announcements'), isTrue);
      expect(ModuleAccess.canView('system_health'), isFalse);
      expect(ModuleAccess.canView('audit_log'), isFalse);
      // Not granted by any of the three roles:
      expect(ModuleAccess.canView('finance'), isFalse);
      expect(ModuleAccess.canView('examinations'), isFalse);
      expect(ModuleAccess.canView('institution'), isFalse);
      expect(ModuleAccess.canView('staff_roles'), isFalse);
    });

    test('can manage inventory and transport, but not students', () {
      expect(ModuleAccess.canManage('inventory'), isTrue);
      expect(ModuleAccess.canManage('transport'), isTrue);
      expect(ModuleAccess.canManage('students'), isFalse);
      // Hidden module — not even read-only.
      expect(ModuleAccess.canView('students'), isFalse);
    });

    test('lands in the web ERP shell', () {
      expect(ModuleAccess.hasErpAccess, isTrue);
    });

    test('sidebar lists only granted modules plus chrome', () {
      final ids = webErpNavItemsForCurrentUser().map((e) => e.id).toSet();
      expect(ids, contains('inventory'));
      expect(ids, contains('transport'));
      expect(ids, contains('support'));
      expect(ids, contains('announcements'));
      expect(ids, contains('maya_assistant'));
      expect(ids, isNot(contains('system_health')));
      expect(ids, isNot(contains('audit_log')));
      expect(ids, isNot(contains('reports')));
      expect(ids, isNot(contains('finance')));
      expect(ids, isNot(contains('students')));
      expect(ids, isNot(contains('staff_roles')));
      expect(ids, contains('dashboard'));
      expect(ids, contains('profile'));
      expect(ids, contains('settings'));
      expect(ids, contains('logout'));
    });
  });

  group('Vice President (oversight)', () {
    setUp(() => signIn(AuthService.roleTeacher, [StaffRoles.vicePresident]));

    test('sees the modules allocated to VP', () {
      for (final id in [
        'students',
        'teachers',
        'employees',
        'hr',
        'classroom_teachers',
        'academic',
        'finance',
        'transport',
        'inventory',
        'examinations',
        'attendance',
        'transfers',
        'parents',
        'announcements',
        'learning_materials',
        'library',
        'quality_assurance',
        'student_affairs',
        'admissions',
        'alumni',
        'markbook',
        'report_cards',
        'exam_bank',
        'lesson_plans',
        'curriculum',
        'at_risk',
        'student_support',
        'safeguarding',
        'student_programs',
      ]) {
        expect(ModuleAccess.canView(id), isTrue, reason: id);
      }
      // EDUABA allocation: events/calendar belong to Section Director
      // (executives also see them read-only; VP does not operate them).
      expect(ModuleAccess.canView('calendar'), isFalse);
      expect(ModuleAccess.canView('events'), isFalse);
      // Reports opened for VP oversight (export read-only).
      expect(ModuleAccess.canView('reports'), isTrue);
      expect(ModuleAccess.canManage('reports'), isFalse);
      expect(ModuleAccess.canView('audit_log'), isFalse);
    });

    test('does not see owner-only system chrome', () {
      expect(ModuleAccess.canView('system_health'), isFalse);
      // Maya is allocated to every role.
      expect(ModuleAccess.canView('maya_assistant'), isTrue);
      expect(ModuleAccess.canView('institution'), isFalse);
      expect(ModuleAccess.canView('staff_roles'), isFalse);
    });

    test('can manage approvals, communications, library, and support', () {
      expect(ModuleAccess.canManage('examinations'), isTrue);
      expect(ModuleAccess.canManage('transfers'), isTrue);
      expect(ModuleAccess.canManage('inventory'), isTrue);
      expect(ModuleAccess.canManage('announcements'), isTrue);
      expect(ModuleAccess.canManage('learning_materials'), isTrue);
      expect(ModuleAccess.canManage('library'), isTrue);
      // Allocated to VP with full duty per the matrix.
      expect(ModuleAccess.canManage('finance'), isTrue);
      expect(ModuleAccess.canManage('transport'), isTrue);
      expect(ModuleAccess.canManage('quality_assurance'), isTrue);
      expect(ModuleAccess.canView('support'), isTrue);
      expect(ModuleAccess.canManage('support'), isTrue);
    });

    test('stays read-only on students and attendance oversight works', () {
      // Item 4: VP is read-only on Students (Registrar/SD manage).
      expect(ModuleAccess.canManage('students'), isFalse);
      expect(ModuleAccess.isReadOnly('students'), isTrue);
      // Attendance is manageable per item 10.
      expect(ModuleAccess.canManage('attendance'), isTrue);
      // Campus has no allocation and VP lacks manage_campuses.
      expect(ModuleAccess.canManage('campus'), isFalse);
    });
  });

  group('Human Resource', () {
    setUp(() => signIn(AuthService.roleTeacher, [StaffRoles.humanResource]));

    test('hires via HR hub but does not touch academics', () {
      expect(ModuleAccess.canHireStaff, isTrue);
      expect(ModuleAccess.canAssignTeachers, isFalse);
      expect(ModuleAccess.canManage('hr'), isTrue);
      expect(ModuleAccess.canManage('add_teacher'), isTrue);
      // Item 6: the administration directory belongs to VP + HR.
      expect(ModuleAccess.canManage('teachers'), isTrue);
      expect(ModuleAccess.canView('classroom_teachers'), isTrue);
      expect(ModuleAccess.canManage('transport'), isTrue);
      expect(ModuleAccess.canLinkStudentTransport, isTrue);
      expect(ModuleAccess.canView('support'), isTrue);
      // Not allocated to HR:
      expect(ModuleAccess.canView('academic'), isFalse);
      expect(ModuleAccess.canView('examinations'), isFalse);
      expect(ModuleAccess.canView('finance'), isFalse);
      expect(ModuleAccess.canView('students'), isFalse);
    });
  });

  group('Section Director', () {
    setUp(() => signIn(AuthService.roleTeacher, [StaffRoles.sectionDirector]));

    test('assigns classes but does not hire staff', () {
      expect(ModuleAccess.canAssignTeachers, isTrue);
      expect(ModuleAccess.canHireStaff, isFalse);
      expect(ModuleAccess.canManage('academic'), isTrue);
      // Item 6: HR hub and admin directory are VP + HR only.
      expect(ModuleAccess.canView('hr'), isFalse);
      expect(ModuleAccess.canView('teachers'), isFalse);
      // Item 7: SD sees classroom teachers.
      expect(ModuleAccess.canView('classroom_teachers'), isTrue);
      // Items 4/5: SD manages students (assignment) and requests transfers.
      expect(ModuleAccess.canManage('students'), isTrue);
      expect(ModuleAccess.canManage('transfers'), isTrue);
      // Item 16: events & calendar belong to SD on the staff side.
      expect(ModuleAccess.canView('events'), isTrue);
      expect(ModuleAccess.canManage('calendar'), isTrue);
      expect(ModuleAccess.canLinkStudentTransport, isTrue);
      expect(ModuleAccess.canManage('parents'), isTrue);
      expect(ModuleAccess.canManage('examinations'), isTrue);
      expect(ModuleAccess.canManage('grade_approvals'), isTrue);
      expect(ModuleAccess.canView('support'), isTrue);
      // Child-protection files are not a classroom or department-head desk.
      expect(ModuleAccess.canView('safeguarding'), isFalse);
    });
  });

  group('Plain teacher', () {
    setUp(() => signIn(AuthService.roleTeacher, const []));

    test('has no ERP access and no staff modules', () {
      expect(ModuleAccess.hasErpAccess, isFalse);
      expect(ModuleAccess.canView('students'), isFalse);
      expect(ModuleAccess.canView('inventory'), isFalse);
      expect(ModuleAccess.canView('transport'), isFalse);
    });
  });

  group('Route aliases', () {
    test('mutation and alias routes resolve to their parent module', () {
      signIn(AuthService.roleTeacher, [StaffRoles.registrar]);
      // Registrar manages students, so student creation is allowed.
      expect(ModuleAccess.canManage('add_student'), isTrue);
      // But not teacher accounts.
      expect(ModuleAccess.canManage('add_teacher'), isFalse);
      expect(ModuleAccess.normalize('staff'), 'hr');
      expect(ModuleAccess.normalize('employees'), 'hr');
      // Classroom teachers is its own module now (item 7 allocation).
      expect(ModuleAccess.normalize('classroom_teachers'), 'classroom_teachers');
      expect(ModuleAccess.normalize('add_teacher'), 'hr');
      expect(ModuleAccess.normalize('add_staff'), 'teachers');
      expect(ModuleAccess.normalize('grade_approvals'), 'examinations');
      expect(ModuleAccess.normalize('markbook'), 'examinations');
      expect(ModuleAccess.normalize('report_cards'), 'examinations');
      expect(ModuleAccess.normalize('exam_bank'), 'examinations');
      expect(ModuleAccess.normalize('exam_papers'), 'examinations');
      expect(ModuleAccess.normalize('exam_desk'), 'examinations');
      expect(ModuleAccess.normalize('lesson_plans'), 'academic');
      expect(ModuleAccess.normalize('lessons'), 'academic');
      expect(ModuleAccess.normalize('curriculum'), 'academic');
      expect(ModuleAccess.normalize('academic_meetings'), 'academic');
      expect(ModuleAccess.normalize('at_risk'), 'attendance');
      expect(ModuleAccess.normalize('attendance_insights'), 'attendance');
      expect(ModuleAccess.normalize('health'), 'student_affairs');
      expect(ModuleAccess.normalize('counseling'), 'student_affairs');
      expect(ModuleAccess.normalize('iep'), 'student_affairs');
      expect(ModuleAccess.normalize('special_needs'), 'student_affairs');
      expect(ModuleAccess.normalize('college_guidance'), 'student_affairs');
      expect(ModuleAccess.normalize('student_support'), 'student_affairs');
      expect(ModuleAccess.normalize('safeguarding'), 'safeguarding');
      expect(ModuleAccess.normalize('clubs'), 'student_affairs');
      expect(ModuleAccess.normalize('gojo'), 'student_affairs');
      expect(ModuleAccess.normalize('scholarships'), 'student_affairs');
      expect(ModuleAccess.normalize('grievances'), 'student_affairs');
      expect(ModuleAccess.normalize('internships'), 'student_affairs');
      expect(ModuleAccess.normalize('leadership_meetings'), 'student_affairs');
      expect(ModuleAccess.normalize('student_programs'), 'student_affairs');
      expect(ModuleAccess.normalize('dosa'), 'student_affairs');
      expect(ModuleAccess.normalize('surveys'), 'quality_assurance');
      expect(ModuleAccess.normalize('qa_surveys'), 'quality_assurance');
      expect(ModuleAccess.normalize('observations'), 'quality_assurance');
      expect(ModuleAccess.normalize('academic_audits'), 'quality_assurance');
      expect(ModuleAccess.normalize('action_research'), 'quality_assurance');
      expect(ModuleAccess.normalize('academic_monitoring'), 'quality_assurance');
      expect(ModuleAccess.normalize('transport_buses'), 'transport');
      expect(ModuleAccess.normalize('transport_live_gps'), 'transport');
      expect(ModuleAccess.normalize('add_driver'), 'transport');
    });
  });
}
