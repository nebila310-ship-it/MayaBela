import 'package:flutter/material.dart';
import 'package:mayabela/models/school_onboarding_checklist.dart';
import 'package:mayabela/services/school_onboarding_service.dart';
import 'package:mayabela/services/school_registry_service.dart';

class SchoolOnboardingChecklistCard extends StatelessWidget {
  const SchoolOnboardingChecklistCard({
    super.key,
    required this.school,
    this.compact = false,
  });

  final SchoolRecord school;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final checklist = SchoolOnboardingService.instance.forSchool(school);

    if (compact) {
      return _compactChip(checklist);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: checklist.isComplete
              ? Colors.green.withValues(alpha: 0.35)
              : Colors.amber.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Onboarding · ${checklist.completedCount}/${checklist.totalCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (checklist.isComplete)
                Icon(Icons.check_circle, color: Colors.green.shade400, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: checklist.progress,
              minHeight: 6,
              backgroundColor: Colors.white12,
              color: checklist.isComplete ? Colors.green : Colors.amber,
            ),
          ),
          const SizedBox(height: 10),
          ...checklist.steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    step.done ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 18,
                    color: step.done ? Colors.greenAccent : Colors.white38,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step.label,
                      style: TextStyle(
                        color: step.done ? Colors.white70 : Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactChip(SchoolOnboardingChecklist checklist) {
    final color = checklist.isComplete ? Colors.green : Colors.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        checklist.isComplete
            ? 'Onboarded'
            : 'Setup ${checklist.completedCount}/${checklist.totalCount}',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
