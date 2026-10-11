import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/otp_delivery_service.dart';
import 'package:mayabela/services/parent_invite_link.dart';
import 'package:mayabela/services/school_auth_cloud_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/utils/phone_utils.dart';

enum ParentInviteOutcome { sent, noEmail, failed }

class ParentContactLine {
  const ParentContactLine({required this.label, required this.phone});

  final String label;
  final String phone;
}

class BulkInviteResult {
  const BulkInviteResult({
    required this.sent,
    required this.skipped,
    required this.total,
  });

  final int sent;
  final int skipped;
  final int total;

  int get missingPhone => skipped;
}

class ParentInviteService {
  ParentInviteService._();
  static final instance = ParentInviteService._();

  static const appName = 'Maya School';
  static const appLink = ParentInviteLink.liveOrigin;

  static const _genericSchoolNames = {
    'maya school',
    'maya school management',
    'majo e-school bridge',
    'majo bridge',
    'mayabela',
  };

  static String formatDob(DateTime dob) {
    final day = dob.day.toString().padLeft(2, '0');
    final month = dob.month.toString().padLeft(2, '0');
    return '$day/$month/${dob.year}';
  }

  /// The campus name on the invite — never the MaJo Bridge product brand.
  static String schoolNameFor(String schoolId, [String? override]) {
    final named = (override ?? '').trim();
    if (named.isNotEmpty && !_isGenericSchoolName(named)) return named;
    final registry =
        SchoolRegistryService.instance.lookup(schoolId)?.name.trim() ?? '';
    if (registry.isNotEmpty && !_isGenericSchoolName(registry)) return registry;
    final display = AuthService.schoolDisplayName.trim();
    if (display.isNotEmpty && !_isGenericSchoolName(display)) return display;
    return registry.isNotEmpty ? registry : 'our school';
  }

  static bool _isGenericSchoolName(String name) {
    final lower = name.trim().toLowerCase();
    return _genericSchoolNames.contains(lower);
  }

  String inviteUrlFor({
    required String schoolId,
    required String studentId,
    DateTime? dateOfBirth,
  }) {
    return ParentInviteLink.build(
      schoolId: schoolId,
      studentId: studentId,
      dateOfBirth: dateOfBirth,
    );
  }

  String inviteUrlForRecord(AdminStudentRecord student) {
    return inviteUrlFor(
      schoolId: student.schoolId,
      studentId: student.studentId,
      dateOfBirth: student.dateOfBirth,
    );
  }

  String welcomeSubject(String schoolId, [String? schoolName]) {
    return 'Welcome to ${schoolNameFor(schoolId, schoolName)}';
  }

  String buildMessage({
    required String schoolId,
    required String studentId,
    required String childName,
    String? schoolName,
    DateTime? childDateOfBirth,
    bool transportEnabled = false,
    String? transportId,
  }) {
    final name = schoolNameFor(schoolId, schoolName);
    final inviteUrl = inviteUrlFor(
      schoolId: schoolId,
      studentId: studentId,
      dateOfBirth: childDateOfBirth,
    );
    final dobLine = childDateOfBirth != null
        ? 'Student date of birth: ${formatDob(childDateOfBirth)}'
        : 'Use the student\'s date of birth (DD/MM/YYYY) when registering.';

    final buffer = StringBuffer()
      ..writeln('Welcome to $name!')
      ..writeln()
      ..writeln('Dear parent,')
      ..writeln()
      ..writeln(
        'We are so happy to welcome $childName into the $name family. '
        'Please tap the link below to register as a parent and stay close to '
        '$childName\'s classes, homework, and school life:',
      )
      ..writeln()
      ..writeln(inviteUrl)
      ..writeln()
      ..writeln(
        'The form is already filled with the School ID, Student ID, and date of birth.',
      )
      ..writeln()
      ..writeln('School ID: $schoolId')
      ..writeln('Student ID: $studentId')
      ..writeln('Student name: $childName')
      ..writeln(dobLine);

    if (transportEnabled) {
      buffer
        ..writeln()
        ..writeln('--- School Transport ---')
        ..writeln(
          '$childName is enrolled in our school transport system.',
        );

      final driver = transportId != null && transportId.trim().isNotEmpty
          ? DriverRegistryService.instance.resolveTransportReference(
              transportId.trim(),
            )
          : null;

      if (driver != null) {
        buffer
          ..writeln()
          ..writeln('Please confirm these details match your child\'s bus:')
          ..writeln('Route: ${driver.routeName}')
          ..writeln('Driver: ${driver.fullName}');
        if (driver.phone != null && driver.phone!.trim().isNotEmpty) {
          buffer.writeln('Driver phone: ${driver.phone!.trim()}');
        }
        if (driver.plateNumber.trim().isNotEmpty && driver.plateNumber != '—') {
          buffer.writeln('Plate number: ${driver.plateNumber.trim()}');
        }
        if (driver.busNumber.trim().isNotEmpty && driver.busNumber != '—') {
          buffer.writeln('Bus: ${driver.busNumber}');
        }
        buffer.writeln('Bus Link ID: ${driver.busId}');
      } else if (transportId != null && transportId.trim().isNotEmpty) {
        buffer.writeln(
          'School Transport ID: ${transportId.trim().toUpperCase()}',
        );
        buffer.writeln(
          'Route and driver details are not on file yet — please contact the school office to confirm.',
        );
      }

      buffer.writeln();
      if (transportId != null && transportId.trim().isNotEmpty) {
        buffer.writeln(
          'After you register in the app, open your child\'s profile and enter the Transport ID above to connect live bus tracking to your parent account.',
        );
      } else {
        buffer.writeln(
          'Your school will share the route, driver, and Transport ID soon. Once you receive them, open your child\'s profile in the app and add the Transport ID to connect bus tracking.',
        );
      }
      buffer.writeln(
        'If you already registered before, please update the student profile with the Transport ID when you have it.',
      );
    }

    buffer
      ..writeln()
      ..writeln(
        'If the link does not open, go to $appLink, tap Register as Parent, and enter the School ID, Student ID, and date of birth above.',
      )
      ..writeln()
      ..writeln('Thank you for choosing $name.');

    return buffer.toString().trim();
  }

  String buildHtmlMessage({
    required String schoolId,
    required String studentId,
    required String childName,
    String? schoolName,
    DateTime? childDateOfBirth,
    bool transportEnabled = false,
    String? transportId,
  }) {
    final name = schoolNameFor(schoolId, schoolName);
    return htmlFromInviteText(
      text: buildMessage(
        schoolId: schoolId,
        studentId: studentId,
        childName: childName,
        schoolName: name,
        childDateOfBirth: childDateOfBirth,
        transportEnabled: transportEnabled,
        transportId: transportId,
      ),
      inviteUrl: inviteUrlFor(
        schoolId: schoolId,
        studentId: studentId,
        dateOfBirth: childDateOfBirth,
      ),
      schoolName: name,
    );
  }

  static String htmlFromInviteText({
    required String text,
    required String inviteUrl,
    required String schoolName,
  }) {
    final escaped = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    final linked = escaped.replaceAllMapped(
      RegExp(r'https?:\/\/[^\s<]+'),
      (match) => '<a href="${match[0]}">${match[0]}</a>',
    );
    return '<p style="font-size:18px;font-weight:700">Welcome to $schoolName!</p>'
        '<p><a href="$inviteUrl" style="display:inline-block;padding:10px 16px;'
        'background:#1d4ed8;color:#ffffff;text-decoration:none;border-radius:8px">'
        'Register as a parent</a></p>'
        '<p>${linked.replaceAll('\n', '<br/>')}</p>';
  }

  String buildMessageForRecord(AdminStudentRecord student) {
    return buildMessage(
      schoolId: student.schoolId,
      studentId: student.studentId,
      childName: student.fullName,
      schoolName: schoolNameFor(student.schoolId),
      childDateOfBirth: student.dateOfBirth,
      transportEnabled: student.transportEnabled,
      transportId: student.transportId,
    );
  }

  String buildHtmlMessageForRecord(AdminStudentRecord student) {
    return buildHtmlMessage(
      schoolId: student.schoolId,
      studentId: student.studentId,
      childName: student.fullName,
      schoolName: schoolNameFor(student.schoolId),
      childDateOfBirth: student.dateOfBirth,
      transportEnabled: student.transportEnabled,
      transportId: student.transportId,
    );
  }

  List<ParentContactLine> contactLinesForRecord(AdminStudentRecord student) {
    final lines = <ParentContactLine>[];
    void add(String label, String? phone) {
      if (phone == null || phone.trim().isEmpty) return;
      final trimmed = phone.trim();
      final key = PhoneUtils.whatsAppInternationalDigits(trimmed);
      if (key.isEmpty) return;
      if (lines.any((l) => PhoneUtils.whatsAppInternationalDigits(l.phone) == key)) {
        return;
      }
      lines.add(ParentContactLine(label: label, phone: trimmed));
    }

    add('Father', student.fatherPhone);
    add('Mother', student.motherPhone);
    add('Guardian', student.guardianPhone);
    add(
      student.emergencyContact1Name ?? 'Emergency contact 1',
      student.emergencyPhone1,
    );
    add(
      student.emergencyContact2Name ?? 'Emergency contact 2',
      student.emergencyPhone2,
    );
    return lines;
  }

  /// Sends to each contact one at a time. [confirmBefore] is called before
  /// every contact after the first so the user can send each message when the
  /// external app opens, then continue to the next number.
  Future<BulkInviteResult> inviteAllContactsSequentially({
    required AdminStudentRecord student,
    required Future<bool> Function(ParentContactLine contact, int index) sendTo,
    Future<bool> Function(ParentContactLine contact, int index)? confirmBefore,
  }) async {
    final contacts = contactLinesForRecord(student);
    var sent = 0;
    var skipped = 0;
    for (var i = 0; i < contacts.length; i++) {
      final contact = contacts[i];
      if (i > 0 && confirmBefore != null) {
        final proceed = await confirmBefore(contact, i);
        if (!proceed) {
          skipped += contacts.length - i;
          break;
        }
      }
      final ok = await sendTo(contact, i);
      if (ok) {
        sent++;
      } else {
        skipped++;
      }
    }
    return BulkInviteResult(
      sent: sent,
      skipped: skipped,
      total: contacts.length,
    );
  }

  Future<bool> sendSms({required String phone, required String message}) async {
    final normalized = PhoneUtils.smsUriPhone(phone);
    if (normalized.isEmpty) return false;
    final uri = Uri(
      scheme: 'sms',
      path: normalized,
      queryParameters: {'body': message},
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<bool> sendViaChannel({
    required String phone,
    required String message,
    required OtpDeliveryChannel channel,
  }) {
    return OtpDeliveryService.instance.deliver(
      phone: phone,
      otp: '',
      channel: channel,
      messageOverride: message,
    );
  }

  Future<void> shareMessage(
    String message, {
    String? subject,
    String? inviteUrl,
  }) async {
    final body = inviteUrl != null &&
            inviteUrl.isNotEmpty &&
            !message.contains(inviteUrl)
        ? '$message\n\n$inviteUrl'
        : message;
    await Share.share(
      body,
      subject: subject ?? welcomeSubject(AuthService.activeSchoolId ?? ''),
    );
  }

  Future<void> shareInviteForRecord(AdminStudentRecord student) {
    return shareMessage(
      buildMessageForRecord(student),
      subject: welcomeSubject(student.schoolId),
      inviteUrl: inviteUrlForRecord(student),
    );
  }

  Future<bool> invitePrimaryViaChannel(
    AdminStudentRecord student,
    OtpDeliveryChannel channel,
  ) async {
    final phone = student.primaryContactPhone;
    if (phone == null || phone.trim().isEmpty) return false;
    return sendViaChannel(
      phone: phone,
      message: buildMessageForRecord(student),
      channel: channel,
    );
  }

  Future<bool> inviteStudent(AdminStudentRecord student) async {
    final message = buildMessageForRecord(student);
    final phone = student.primaryContactPhone;
    if (phone != null && phone.isNotEmpty) {
      return sendSms(phone: phone, message: message);
    }
    await shareInviteForRecord(student);
    return true;
  }

  Future<BulkInviteResult> inviteAllContactsViaSms(
    AdminStudentRecord student, {
    Future<bool> Function(ParentContactLine contact, int index)? confirmBefore,
  }) async {
    final message = buildMessageForRecord(student);
    return inviteAllContactsSequentially(
      student: student,
      confirmBefore: confirmBefore,
      sendTo: (contact, _) => sendSms(phone: contact.phone, message: message),
    );
  }

  Future<BulkInviteResult> inviteAllContactsViaChannel(
    AdminStudentRecord student,
    OtpDeliveryChannel channel, {
    Future<bool> Function(ParentContactLine contact, int index)? confirmBefore,
  }) async {
    final message = buildMessageForRecord(student);
    return inviteAllContactsSequentially(
      student: student,
      confirmBefore: confirmBefore,
      sendTo: (contact, _) => sendViaChannel(
        phone: contact.phone,
        message: message,
        channel: channel,
      ),
    );
  }

  /// Opens the SMS app once per parent (device sends one message at a time).
  Future<BulkInviteResult> inviteBulkViaSms(
    List<AdminStudentRecord> students,
  ) async {
    var sent = 0;
    var skipped = 0;
    for (final student in students) {
      if (student.allContactPhones.isEmpty) {
        skipped++;
        continue;
      }
      final result = await inviteAllContactsViaSms(student);
      sent += result.sent;
      if (result.sent == 0) skipped++;
    }
    return BulkInviteResult(
      sent: sent,
      skipped: skipped,
      total: students.length,
    );
  }

  AdminStudentRecord? recordForStudentRef({
    required String name,
    String? registryStudentId,
  }) {
    if (registryStudentId != null) {
      final byId = StudentRegistryService.instance.lookupById(registryStudentId);
      if (byId != null) return byId;
    }
    try {
      return StudentRegistryService.instance
          .getAllStudents()
          .firstWhere((s) => s.fullName == name);
    } catch (_) {
      return null;
    }
  }

  /// Email the parent invite after enroll. No SMS.
  Future<ParentInviteOutcome> inviteParentForEnrollment({
    required AdminStudentRecord student,
    required String guardianEmail,
  }) async {
    final email = guardianEmail.trim();
    if (email.isEmpty || !email.contains('@')) {
      return ParentInviteOutcome.noEmail;
    }
    final message = buildMessageForRecord(student);
    final html = buildHtmlMessageForRecord(student);
    NotificationService.instance.push(
      title: 'Parent invite — ${student.fullName}',
      body: 'Register with Student ID ${student.studentId} and the date of birth.',
      type: NotificationType.announcement,
      fromRole: AuthService.roleTeacher,
      fromName: AuthService.currentUser?.fullName ??
          AuthService.currentUser?.username ??
          'Admissions',
      recipientRole: AuthService.roleParent,
      targetStudentId: student.studentId,
      targetClassName: student.className,
    );
    if (!SchoolAuthCloudService.instance.isAvailable) {
      return ParentInviteOutcome.sent;
    }
    final result = await SchoolAuthCloudService.instance.inviteParentEmail(
      schoolId: student.schoolId,
      email: email,
      studentId: student.studentId,
      studentName: student.fullName,
      schoolName: schoolNameFor(student.schoolId),
      dateOfBirth: student.dateOfBirth,
      message: message,
      html: html,
    );
    return result.ok ? ParentInviteOutcome.sent : ParentInviteOutcome.failed;
  }

  String? validateTransportId(String? raw, {String? schoolId}) {
    final id = raw?.trim().toUpperCase();
    if (id == null || id.isEmpty) return null;
    final driver = DriverRegistryService.instance.resolveTransportReference(id);
    if (driver == null) {
      return 'not_found';
    }
    if (schoolId != null &&
        driver.schoolId.toUpperCase() != schoolId.trim().toUpperCase()) {
      return 'wrong_school';
    }
    return null;
  }
}
