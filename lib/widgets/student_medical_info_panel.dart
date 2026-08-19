import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';

/// Read-only medical summary for admin / teacher student views.
class StudentMedicalInfoPanel extends StatelessWidget {
  const StudentMedicalInfoPanel({
    super.key,
    required this.hasMedicalCondition,
    this.medicalConditionDetails,
    this.otherMedicalInfo,
    this.accent = const Color(0xFF00695C),
    this.compact = false,
  });

  final bool hasMedicalCondition;
  final String? medicalConditionDetails;
  final String? otherMedicalInfo;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final details = medicalConditionDetails?.trim();
    final other = otherMedicalInfo?.trim();

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: hasMedicalCondition
            ? Colors.orange.shade50
            : accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasMedicalCondition
              ? Colors.orange.shade200
              : accent.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasMedicalCondition
                    ? Icons.medical_information_outlined
                    : Icons.health_and_safety_outlined,
                size: 18,
                color: hasMedicalCondition ? Colors.orange.shade800 : accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasMedicalCondition
                      ? s.studentMedicalYes
                      : s.studentMedicalNone,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: hasMedicalCondition
                        ? Colors.orange.shade900
                        : accent,
                  ),
                ),
              ),
            ],
          ),
          if (hasMedicalCondition && details != null && details.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${s.studentMedicalSpecify}: $details',
              style: TextStyle(height: 1.35, color: Colors.grey.shade800),
            ),
          ],
          if (other != null && other.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${s.studentMedicalOtherInfo}: $other',
              style: TextStyle(height: 1.35, color: Colors.grey.shade800),
            ),
          ],
        ],
      ),
    );
  }
}
