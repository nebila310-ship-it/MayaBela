import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/calendar_event.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/transport_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/professional_qr_scanner.dart';
import 'package:mayabela/widgets/student_qr_card.dart';

/// Ensures the student has a synced QR profile and returns it for display.
StudentQrProfile qrProfileForStudent(AdminStudentRecord student) {
  TransportService.instance.syncStudentQrProfile(student);
  return StudentQrProfile(
    id: student.studentId.toLowerCase(),
    name: student.fullName,
    className: student.className,
    qrCode: TransportService.qrCodeForStudentId(student.studentId),
  );
}

StudentQrProfile qrProfileForStudentId({
  required String studentId,
  required String studentName,
  required String className,
}) {
  final record = StudentRegistryService.instance.lookupById(studentId);
  if (record != null) return qrProfileForStudent(record);

  final profile = StudentQrProfile(
    id: studentId.toLowerCase(),
    name: studentName,
    className: className,
    qrCode: TransportService.qrCodeForStudentId(studentId),
  );
  SchoolDataService.instance.upsertStudentQrProfile(profile);
  return profile;
}

void _showStudentQrBottomSheet(
  BuildContext context,
  StudentQrProfile profile,
) {
  final s = AppLocale.instance.strings;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: listPagePadding(ctx),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              s.generateStudentQr,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              s.studentQrUsageHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, height: 1.35),
            ),
            const SizedBox(height: 12),
            StudentQrCard(profile: profile, size: 200),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

/// Shows the same student identification QR used by admin (`STUDENT:STU-XXXX`).
void showStudentIdentificationQrSheet(
  BuildContext context, {
  required String studentId,
  required String studentName,
  required String className,
}) {
  final profile = qrProfileForStudentId(
    studentId: studentId,
    studentName: studentName,
    className: className,
  );
  _showStudentQrBottomSheet(context, profile);
}

void showAdminStudentQrSheet(
  BuildContext context, {
  required AdminStudentRecord student,
}) {
  _showStudentQrBottomSheet(context, qrProfileForStudent(student));
}

Future<String?> showAdminScanStudentQrDialog(BuildContext context) async {
  final s = AppLocale.instance.strings;
  var handled = false;
  String? result;

  await showProfessionalQrScanDialog(
    context: context,
    title: s.scanStudentQr,
    subtitle: s.qrScannerAlignHint,
    cancelLabel: s.cancel,
    unavailableMessage: s.cameraScannerAvailable,
    errorMessage: s.qrScannerStartError,
    permissionDeniedMessage: s.cameraPermissionRequired,
    startingMessage: s.cameraStarting,
    retryLabel: s.tryAgain,
    onCode: (code) {
      if (handled) return false;
      handled = true;

      final studentId = TransportService.instance.resolveStudentIdFromQr(code);
      if (studentId == null) {
        handled = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.invalidStudentQr)),
        );
        return false;
      }

      result = studentId;
      return true;
    },
  );

  return result;
}
