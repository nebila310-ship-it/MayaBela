import 'package:flutter/foundation.dart';
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

Widget studentQrViewerBody(
  BuildContext context,
  StudentQrProfile profile, {
  double size = 200,
}) {
  final s = AppLocale.instance.strings;
  return Column(
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
      StudentQrCard(profile: profile, size: size),
      const SizedBox(height: 8),
    ],
  );
}

void _showStudentQrViewer(
  BuildContext context,
  StudentQrProfile profile,
) {
  final body = studentQrViewerBody(context, profile);
  if (kIsWeb) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(child: body),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocale.instance.strings.done),
          ),
        ],
      ),
    );
    return;
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: listPagePadding(ctx),
        child: body,
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
  _showStudentQrViewer(context, profile);
}

void showAdminStudentQrSheet(
  BuildContext context, {
  required AdminStudentRecord student,
}) {
  _showStudentQrViewer(context, qrProfileForStudent(student));
}

/// Printable grid of student QR cards for bus check-in/out and class attendance.
Future<void> showStudentQrPrintPreview(
  BuildContext context, {
  required List<AdminStudentRecord> students,
}) {
  final s = AppLocale.instance.strings;
  final profiles = students.map(qrProfileForStudent).toList(growable: false);
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 720),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.studentQrCodes,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                '${s.studentQrUsageHint} Press Ctrl+P to print this page.',
                style: TextStyle(color: Colors.grey.shade700, height: 1.35),
              ),
            ),
            Expanded(
              child: profiles.isEmpty
                  ? const Center(child: Text('No students to print.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final profile in profiles)
                            SizedBox(
                              width: 260,
                              child: StudentQrCard(profile: profile, size: 160),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
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
