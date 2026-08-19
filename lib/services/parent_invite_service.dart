import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/otp_delivery_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/utils/phone_utils.dart';

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
  static const appLink = 'https://mayaschool.et/app';

  static String formatDob(DateTime dob) {
    final day = dob.day.toString().padLeft(2, '0');
    final month = dob.month.toString().padLeft(2, '0');
    return '$day/$month/${dob.year}';
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
    final name = schoolName ?? AuthService.schoolDisplayName;
    final dobLine = childDateOfBirth != null
        ? 'Student DOB (use when registering): ${formatDob(childDateOfBirth)}'
        : 'Use the student\'s date of birth (DD/MM/YYYY) when registering.';

    final buffer = StringBuffer()
      ..writeln('Welcome to Maya School!')
      ..writeln()
      ..writeln('We are delighted that $childName is enrolled at $name.')
      ..writeln()
      ..writeln('School ID: $schoolId')
      ..writeln('Student ID: $studentId')
      ..writeln('Student Name: $childName')
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
        'Download the $appName app ($appLink) and register as Parent using the Student ID and date of birth above.',
      )
      ..writeln()
      ..writeln('Thank you for choosing $name.');

    return buffer.toString().trim();
  }

  String buildMessageForRecord(AdminStudentRecord student) {
    return buildMessage(
      schoolId: student.schoolId,
      studentId: student.studentId,
      childName: student.fullName,
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

  Future<void> shareMessage(String message) async {
    await Share.share(message, subject: '$appName — Parent registration');
  }

  Future<bool> inviteStudent(AdminStudentRecord student) async {
    final message = buildMessageForRecord(student);
    final phone = student.primaryContactPhone;
    if (phone != null && phone.isNotEmpty) {
      return sendSms(phone: phone, message: message);
    }
    await shareMessage(message);
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
