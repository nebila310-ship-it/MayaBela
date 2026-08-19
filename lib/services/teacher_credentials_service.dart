import 'package:share_plus/share_plus.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/otp_delivery_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/utils/phone_utils.dart';

class TeacherCredentialsService {
  TeacherCredentialsService._();
  static final instance = TeacherCredentialsService._();

  static const appName = 'Maya School';
  static const appLink = 'https://mayaschool.et/app';

  AdminTeacherRecord? recordForCurrentUser() {
    final user = AuthService.currentUser;
    if (user == null || user.roleKey != AuthService.roleTeacher) return null;
    return TeacherRegistryService.instance.resolveForAuthUser(
      linkedTeacherId: user.linkedTeacherId,
      username: user.username,
      phone: user.phone,
      schoolId: AuthService.activeSchoolId ?? user.schoolId,
    );
  }

  String loginFor(AdminTeacherRecord teacher) {
    final phone = teacher.phone?.trim();
    if (phone != null && phone.isNotEmpty) {
      return PhoneUtils.loginKey(phone);
    }
    return teacher.loginUsername ?? '—';
  }

  String passwordFor(AdminTeacherRecord teacher) {
    final stored = teacher.initialPassword?.trim();
    // Never hand out the old demo PIN (1234) — cloud login rejects it.
    if (stored != null &&
        stored.isNotEmpty &&
        stored.length >= AuthService.minPasswordLength &&
        stored != AuthService.demoPassword) {
      return stored;
    }
    return AuthService.tempPassword;
  }

  String buildMessage(AdminTeacherRecord teacher) {
    final schoolName =
        SchoolRegistryService.instance.displayName(teacher.schoolId);
    final login = loginFor(teacher);
    final password = passwordFor(teacher);

    return '''Welcome to $appName!

Your administration staff account is ready:

Name: ${teacher.fullName}
School: $schoolName
School ID: ${teacher.schoolId}
Staff ID: ${teacher.employeeId ?? teacher.teacherId}
Login phone: $login
Temp password: $password

Sign in as Administration Staff.
Download: $appLink
Please change your password after first login.''';
  }

  Future<bool> sendViaChannel({
    required AdminTeacherRecord teacher,
    required OtpDeliveryChannel channel,
  }) async {
    final phone = teacher.phone?.trim();
    if (phone == null || phone.isEmpty) return false;
    return OtpDeliveryService.instance.deliver(
      phone: phone,
      otp: '',
      channel: channel,
      messageOverride: buildMessage(teacher),
    );
  }

  Future<void> share(AdminTeacherRecord teacher) async {
    await Share.share(
      buildMessage(teacher),
      subject: '$appName — Teacher login for ${teacher.fullName}',
    );
  }
}
