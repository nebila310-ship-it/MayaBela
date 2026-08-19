import 'package:flutter/foundation.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/services/auth_service.dart';

class MayaChatMessage {
  const MayaChatMessage({
    required this.id,
    required this.text,
    required this.fromUser,
    required this.at,
  });

  final String id;
  final String text;
  final bool fromUser;
  final DateTime at;
}

/// Role-branded Maya assistant: titles, suggestions, cloud AI + local fallback.
class MayaAssistantService {
  MayaAssistantService._();
  static final instance = MayaAssistantService._();

  static const rolePlatformOwner = 'platform_owner';

  bool get isCloudAvailable => SupabaseBootstrap.isInitialized;

  /// One brand for every role — always "Maya Assistant".
  static String titleForRole(String? roleKey) => 'Maya Assistant';

  static String subtitleForRole(String? roleKey) {
    return switch (roleKey) {
      AuthService.roleAdmin =>
        'Ask about school operations, staff, students, and reports.',
      AuthService.roleTeacher =>
        'Get help with classes, grades, attendance, and parent messaging.',
      AuthService.roleStudent =>
        'Study tips, homework help, and how to use your student portal.',
      AuthService.roleParent =>
        'Questions about your children, fees, bus, and school updates.',
      AuthService.roleDriver =>
        'Guidance for routes, passenger check-in, and live map tools.',
      rolePlatformOwner =>
        'Platform schools, billing insights, and console workflows.',
      _ => 'Your MaJo e-School Bridge assistant.',
    };
  }

  static List<String> suggestionsForRole(String? roleKey) {
    return switch (roleKey) {
      AuthService.roleAdmin => const [
          'How do I approve a parent link?',
          'Where do I add a teacher?',
          'How do grade approvals work?',
        ],
      AuthService.roleTeacher => const [
          'How do I enter grades?',
          'How do I take attendance?',
          'How do I message parents?',
        ],
      AuthService.roleStudent => const [
          'Where are my homework tasks?',
          'How do I see my grades?',
          'How do I change my password?',
        ],
      AuthService.roleParent => const [
          'How do I track the school bus?',
          'Where can I see fees?',
          'How do I link another child?',
        ],
      AuthService.roleDriver => const [
          'How do I scan passengers on board?',
          'Where is the live map?',
          'How do I report a route issue?',
        ],
      rolePlatformOwner => const [
          'How do I create a new school?',
          'Where is the audit log?',
          'How do enrollment metrics work?',
        ],
      _ => const [
          'What can you help me with?',
          'How do I open settings?',
        ],
    };
  }

  String welcomeMessage(String? roleKey) {
    final title = titleForRole(roleKey);
    return 'Hi — I am $title. Ask me about using MaJo e-School Bridge, '
        'or tap a suggestion below to get started.';
  }

  Future<String> reply({
    required String roleKey,
    required String userMessage,
    List<MayaChatMessage> history = const [],
  }) async {
    final trimmed = userMessage.trim();
    if (trimmed.isEmpty) {
      return 'Send a short question and I will help.';
    }

    final cloud = await _tryCloudReply(
      roleKey: roleKey,
      userMessage: trimmed,
      history: history,
    );
    if (cloud != null && cloud.trim().isNotEmpty) return cloud.trim();

    return _localReply(roleKey: roleKey, userMessage: trimmed);
  }

  Future<String?> _tryCloudReply({
    required String roleKey,
    required String userMessage,
    required List<MayaChatMessage> history,
  }) async {
    if (!isCloudAvailable) return null;
    try {
      final result = await SupabaseBootstrap.client.functions.invoke(
        'maya-assistant-chat',
        body: {
          'roleKey': roleKey,
          'message': userMessage,
          'history': history
              .take(12)
              .map(
                (m) => {
                  'role': m.fromUser ? 'user' : 'model',
                  'text': m.text,
                },
              )
              .toList(),
        },
      );
      final data = result.data is Map
          ? Map<String, dynamic>.from(result.data as Map)
          : null;
      final text = data?['reply'] as String?;
      if (text == null || text.trim().isEmpty) return null;
      return text;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MayaAssistantService cloud failed: $e');
      }
      return null;
    }
  }

  String _localReply({
    required String roleKey,
    required String userMessage,
  }) {
    final q = userMessage.toLowerCase();

    if (_matches(q, ['hello', 'hi', 'hey', 'selam', 'ሰላም'])) {
      return welcomeMessage(roleKey);
    }
    if (_matches(q, ['who are you', 'what are you', 'your name'])) {
      return 'I am ${titleForRole(roleKey)}, your in-app guide for '
          'MaJo e-School Bridge.';
    }
    if (_matches(q, ['help', 'what can you', 'capabilities'])) {
      return '${subtitleForRole(roleKey)}\n\n'
          'Try one of the suggested questions, or ask about a screen '
          'you see on your dashboard.';
    }

    return switch (roleKey) {
      AuthService.roleAdmin => _adminLocal(q, roleKey),
      AuthService.roleTeacher => _teacherLocal(q, roleKey),
      AuthService.roleStudent => _studentLocal(q, roleKey),
      AuthService.roleParent => _parentLocal(q, roleKey),
      AuthService.roleDriver => _driverLocal(q, roleKey),
      rolePlatformOwner => _ownerLocal(q, roleKey),
      _ => _genericLocal(q, roleKey: roleKey),
    };
  }

  String _adminLocal(String q, String roleKey) {
    if (_matches(q, ['parent', 'approv', 'link'])) {
      return 'Open Parent Approvals from Quick actions. Review pending '
          'link requests, then Approve or Reject. Approved parents can see '
          'only their linked children.';
    }
    if (_matches(q, ['add teacher', 'teacher'])) {
      return 'Use Add Teacher to register staff, assign classes, and create '
          'their login. They appear under Staff after save and cloud sync.';
    }
    if (_matches(q, ['add student', 'student'])) {
      return 'Use Add Student to enroll a learner with class, guardians, and '
          'IDs. Parents can then request a link using the student ID.';
    }
    if (_matches(q, ['grade', 'approval', 'workflow'])) {
      return 'Teachers submit grades; Admins review them in Grade Approvals. '
          'Grade workflow settings control whether approval is required '
          'before parents see published scores.';
    }
    if (_matches(q, ['finance', 'fee'])) {
      return 'Finance shows fee records for the school. Live payment providers '
          'are still being connected — parents can view due amounts in Fees.';
    }
    if (_matches(q, ['transport', 'bus'])) {
      return 'Transport lets you manage buses, drivers, and assignments. '
          'Drivers use Scan QR for boarding; parents track via Bus Tracking.';
    }
    return _genericLocal(q, roleKey: roleKey);
  }

  String _teacherLocal(String q, String roleKey) {
    if (_matches(q, ['grade', 'mark', 'score'])) {
      return 'Open Grades, pick an assigned class and subject, enter marks, '
          'then submit for approval if your school requires it.';
    }
    if (_matches(q, ['attendance'])) {
      return 'Open Attendance, choose your class, mark present/absent, and '
          'save the session. Homeroom teachers see their classes first.';
    }
    if (_matches(q, ['message', 'parent', 'chat'])) {
      return 'Open Messages to chat with parents linked to your classes. '
          'Keep conversations about the specific student when possible.';
    }
    if (_matches(q, ['homework'])) {
      return 'Open Homework, select a class you teach, post the task with '
          'subject and due details. Parents and students see it for that class.';
    }
    if (_matches(q, ['approv', 'parent link'])) {
      return 'If you are a homeroom teacher, Parent Approvals lists link '
          'requests for your classes so you can verify the child.';
    }
    return _genericLocal(q, roleKey: roleKey);
  }

  String _studentLocal(String q, String roleKey) {
    if (_matches(q, ['homework', 'assignment'])) {
      return 'Open Homework to see assignments for your class. Complete work '
          'offline if needed, then check Announcements for teacher updates.';
    }
    if (_matches(q, ['grade', 'result', 'score'])) {
      return 'Open Grade Reports to view published scores. Draft grades may '
          'stay hidden until school admin approval.';
    }
    if (_matches(q, ['password', 'login'])) {
      return 'Open Settings → Change password. Use a password with at least '
          '10 characters. Ask admin if you need a reset.';
    }
    if (_matches(q, ['timetable', 'schedule'])) {
      return 'Open Timetable to see your class schedule for the week.';
    }
    if (_matches(q, ['study', 'exam', 'tutor', 'learn'])) {
      return 'Try this study loop: review today\'s homework, check Learning '
          'Materials for notes, then quiz yourself from Grade Reports topics. '
          'Ask your teacher in Messages if something is unclear.';
    }
    return _genericLocal(q, roleKey: roleKey);
  }

  String _parentLocal(String q, String roleKey) {
    if (_matches(q, ['bus', 'track', 'transport'])) {
      return 'Open Bus Tracking to follow your child\'s assigned bus when the '
          'driver shares a live position. Make sure your parent link is approved.';
    }
    if (_matches(q, ['fee', 'payment', 'pay'])) {
      return 'Open Fees & Payments to see amounts due for your linked children. '
          'Online payment providers are rolling out — pay at school if offline.';
    }
    if (_matches(q, ['link', 'child', 'kids', 'children'])) {
      return 'Use My Children / link child flow with the school Student ID and '
          'date of birth. Admin or homeroom teacher must approve before full access.';
    }
    if (_matches(q, ['grade', 'homework', 'attendance'])) {
      return 'After approval, open Grades, Homework, or Attendance for each '
          'linked child. Switch children from the child picker when you have more than one.';
    }
    return _genericLocal(q, roleKey: roleKey);
  }

  String _driverLocal(String q, String roleKey) {
    if (_matches(q, ['scan', 'qr', 'board', 'onboard'])) {
      return 'Open Scan QR (or Pick-up / Drop-off) and scan each student card. '
          'Onboard marks them on the bus; discharge marks drop-off.';
    }
    if (_matches(q, ['map', 'live', 'gps', 'location'])) {
      return 'Open Live Map to share your bus position with the school and '
          'parents. Location permission must stay enabled while driving.';
    }
    if (_matches(q, ['passenger', 'list', 'route'])) {
      return 'Open Passenger List for today\'s assigned students, and My Route '
          'for route details. Report problems with Report Issue.';
    }
    if (_matches(q, ['issue', 'problem', 'break', 'late'])) {
      return 'Use Report Issue to notify school admin about delays, vehicle, '
          'or passenger problems. Also send a short note in Messages if urgent.';
    }
    return _genericLocal(q, roleKey: roleKey);
  }

  String _ownerLocal(String q, String roleKey) {
    if (_matches(q, ['create', 'new school', 'add school'])) {
      return 'Tap New school, fill school ID/name/admin contact, then send '
          'admin credentials. Track onboarding from the school detail checklist.';
    }
    if (_matches(q, ['audit'])) {
      return 'Open Audit log from the menu to review platform actions such as '
          'school creates, blocks, and credential sends.';
    }
    if (_matches(q, ['billing', 'revenue', 'enrollment', 'student'])) {
      return 'The header chips show active schools, billable students, and '
          'estimated monthly revenue. Open a school for enrollment metrics.';
    }
    if (_matches(q, ['export', 'backup'])) {
      return 'Use Export backup (JSON) or Export schools (CSV) from the menu '
          'for offline records. Keep PIN access private.';
    }
    if (_matches(q, ['sms', 'expir'])) {
      return 'Bulk SMS · expiring helps notify schools nearing subscription '
          'expiry. Confirm phone numbers before sending.';
    }
    return _genericLocal(q, roleKey: roleKey);
  }

  String _genericLocal(String q, {String? roleKey}) {
    if (_matches(q, ['setting', 'language', 'theme'])) {
      return 'Open Settings from your dashboard Account section to change '
          'language, password, and notification preferences.';
    }
    if (_matches(q, ['message', 'chat'])) {
      return 'School Messages is for people (teachers, parents, staff). '
          'This Maya chat is for product guidance and quick how-to answers.';
    }
    return 'I can help with common ${titleForRole(roleKey)} '
        'tasks in MaJo e-School Bridge. Ask about a feature by name '
        '(for example grades, attendance, bus, or settings), or tap a suggestion.';
  }

  bool _matches(String q, List<String> keys) {
    for (final key in keys) {
      if (q.contains(key)) return true;
    }
    return false;
  }
}
