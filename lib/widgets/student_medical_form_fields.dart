import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';

/// Shared medical fields for add / edit student. Same store as parent signup.
class StudentMedicalFormFields extends StatelessWidget {
  const StudentMedicalFormFields({
    super.key,
    required this.hasMedicalCondition,
    required this.onHasMedicalChanged,
    required this.detailsController,
    required this.otherController,
    required this.accent,
  });

  final bool hasMedicalCondition;
  final ValueChanged<bool> onHasMedicalChanged;
  final TextEditingController detailsController;
  final TextEditingController otherController;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.studentMedicalQuestion,
          style: TextStyle(color: Colors.grey.shade700, height: 1.35),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: Text(s.yes),
                selected: hasMedicalCondition,
                onSelected: (_) => onHasMedicalChanged(true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ChoiceChip(
                label: Text(s.no),
                selected: !hasMedicalCondition,
                onSelected: (_) {
                  detailsController.clear();
                  onHasMedicalChanged(false);
                },
              ),
            ),
          ],
        ),
        if (hasMedicalCondition) ...[
          const SizedBox(height: 12),
          TextField(
            controller: detailsController,
            maxLines: 2,
            decoration: adminFieldDecoration(
              label: s.studentMedicalSpecify,
              icon: Icons.medical_information_outlined,
              accent: accent,
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: otherController,
          maxLines: 2,
          decoration: adminFieldDecoration(
            label: s.studentMedicalOtherInfo,
            icon: Icons.health_and_safety_outlined,
            accent: accent,
          ),
        ),
      ],
    );
  }
}
