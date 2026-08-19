import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/utils/text_input_formatters.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';

/// Shared child link + medical info block for parent signup and add-child flows.
class ParentChildRegistrationCard extends StatefulWidget {
  const ParentChildRegistrationCard({
    super.key,
    required this.index,
    required this.entry,
    required this.schoolId,
    required this.onVerify,
    this.onRemove,
    this.onStudentContactChanged,
    this.accent = const Color(0xFF00695C),
  });

  final int index;
  final ParentChildFormEntry entry;
  final String schoolId;
  final VoidCallback onVerify;
  final VoidCallback? onRemove;
  final ValueChanged<ParentChildFormEntry>? onStudentContactChanged;
  final Color accent;

  @override
  State<ParentChildRegistrationCard> createState() =>
      _ParentChildRegistrationCardState();
}

class ParentChildFormEntry {
  ParentChildFormEntry();

  final studentIdController = TextEditingController();
  final dobController = TextEditingController();
  final medicalDetailsController = TextEditingController();
  final otherMedicalController = TextEditingController();
  ParentRelationship relationship = ParentRelationship.father;
  bool? hasMedicalCondition;
  AdminStudentRecord? record;

  void dispose() {
    studentIdController.dispose();
    dobController.dispose();
    medicalDetailsController.dispose();
    otherMedicalController.dispose();
  }
}

class _ParentChildRegistrationCardState extends State<ParentChildRegistrationCard> {
  AppStrings get s => AppLocale.instance.strings;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final record = entry.record;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: widget.accent.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            decoration: BoxDecoration(
              color: widget.accent.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: widget.accent.withValues(alpha: 0.15),
                  child: Text(
                    '${widget.index + 1}',
                    style: TextStyle(
                      color: widget.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${s.myChildren} ${widget.index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (widget.onRemove != null)
                  IconButton(
                    onPressed: widget.onRemove,
                    icon: const Icon(Icons.close_rounded, color: Colors.red),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.parentChildLinkStep,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: entry.studentIdController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: adminFieldDecoration(
                          label: s.studentId,
                          icon: Icons.badge_outlined,
                          accent: widget.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: widget.onVerify,
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 16,
                        ),
                      ),
                      icon: const Icon(Icons.verified_user_outlined, size: 18),
                      label: Text(s.verifyChild),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: entry.dobController,
                  keyboardType: TextInputType.number,
                  inputFormatters: dateSlashFormatters,
                  decoration: adminFieldDecoration(
                    label: s.childDateOfBirth,
                    hint: s.dateFormatHint,
                    icon: Icons.cake_outlined,
                    accent: widget.accent,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ParentRelationship>(
                  key: ValueKey(entry.relationship),
                  initialValue: entry.relationship,
                  decoration: adminFieldDecoration(
                    label: s.relationship,
                    icon: Icons.family_restroom_outlined,
                    accent: widget.accent,
                  ),
                  items: ParentRelationship.values
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(s.relationshipLabel(r)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => entry.relationship = v);
                      widget.onStudentContactChanged?.call(entry);
                    }
                  },
                ),
                if (record != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('${s.grade}: ${record.grade} · ${record.className}'),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  s.studentMedicalSection,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.accent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  s.studentMedicalQuestion,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MedicalChoiceTile(
                        label: s.yes,
                        selected: entry.hasMedicalCondition == true,
                        accent: widget.accent,
                        onTap: () => setState(() {
                          entry.hasMedicalCondition = true;
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MedicalChoiceTile(
                        label: s.no,
                        selected: entry.hasMedicalCondition == false,
                        accent: widget.accent,
                        onTap: () => setState(() {
                          entry.hasMedicalCondition = false;
                          entry.medicalDetailsController.clear();
                        }),
                      ),
                    ),
                  ],
                ),
                if (entry.hasMedicalCondition == true) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: entry.medicalDetailsController,
                    maxLines: 2,
                    decoration: adminFieldDecoration(
                      label: s.studentMedicalSpecify,
                      icon: Icons.medical_information_outlined,
                      accent: widget.accent,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: entry.otherMedicalController,
                  maxLines: 3,
                  decoration: adminFieldDecoration(
                    label: s.studentMedicalOtherInfo,
                    icon: Icons.health_and_safety_outlined,
                    accent: widget.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicalChoiceTile extends StatelessWidget {
  const _MedicalChoiceTile({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accent.withValues(alpha: 0.12) : Colors.grey.shade50,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accent : Colors.grey.shade300,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? accent : Colors.grey.shade500,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? accent : Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

ParentChildRegistration parentRegistrationFromEntry(
  ParentChildFormEntry entry, {
  required DateTime dateOfBirth,
}) {
  return ParentChildRegistration(
    studentId: entry.record!.studentId,
    dateOfBirth: dateOfBirth,
    relationship: entry.relationship,
    hasMedicalCondition: entry.hasMedicalCondition ?? false,
    medicalConditionDetails: entry.hasMedicalCondition == true
        ? entry.medicalDetailsController.text.trim()
        : null,
    otherMedicalInfo: entry.otherMedicalController.text.trim().isEmpty
        ? null
        : entry.otherMedicalController.text.trim(),
  );
}

/// Fills parent phone (and optionally name) from the verified student record.
void applyStudentContactSuggestion({
  required ParentChildFormEntry entry,
  required TextEditingController phoneController,
  TextEditingController? nameController,
}) {
  final record = entry.record;
  if (record == null) return;

  final phone = record.phoneForRelationship(entry.relationship);
  if (phone != null) {
    phoneController.text = phone;
  }

  if (nameController != null) {
    final name = record.nameForRelationship(entry.relationship);
    if (name != null && nameController.text.trim().isEmpty) {
      nameController.text = name;
    }
  }
}
