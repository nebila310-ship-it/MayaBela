import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';

/// Stable QR payload for a teacher subject teaching assignment.
String teachingSlotQrPayload({
  required SubjectTeachingSlot slot,
  required String className,
  required String teacherId,
  required String teacherName,
  required String schoolId,
}) {
  return 'TEACH:${slot.slotId}|${slot.subjectId}|${className.trim()}|$teacherId.trim()|$schoolId.trim()';
}

/// Shows subject + class assignment details with scannable QR.
class TeachingSlotQrCard extends StatelessWidget {
  const TeachingSlotQrCard({
    super.key,
    required this.slot,
    required this.className,
    required this.teacherName,
    required this.qrData,
    this.size = 160,
  });

  final SubjectTeachingSlot slot;
  final String className;
  final String teacherName;
  final String qrData;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            slot.subjectName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(className, style: TextStyle(color: Colors.grey.shade700)),
          Text(
            teacherName,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _idLine(s.teachingSlotIdLabel, slot.slotId),
          _idLine(s.subjectIdLabel, slot.subjectId),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: size,
                backgroundColor: Colors.white,
                gapless: true,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            qrData,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _idLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

void showTeachingSlotQrSheet(
  BuildContext context, {
  required SubjectTeachingSlot slot,
  required String className,
  required String teacherId,
  required String teacherName,
  required String schoolId,
}) {
  final s = AppLocale.instance.strings;
  final qrData = teachingSlotQrPayload(
    slot: slot,
    className: className,
    teacherId: teacherId,
    teacherName: teacherName,
    schoolId: schoolId,
  );

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
              s.teachingAssignmentQrTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              s.teachingAssignmentQrHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, height: 1.35),
            ),
            const SizedBox(height: 12),
            TeachingSlotQrCard(
              slot: slot,
              className: className,
              teacherName: teacherName,
              qrData: qrData,
              size: 200,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}
