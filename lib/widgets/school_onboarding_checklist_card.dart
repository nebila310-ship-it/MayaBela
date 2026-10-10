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
      key: const Key('school-lifecycle-scorecard'),
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
                  'School score · ${checklist.scorePercent}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _bandColor(checklist).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  checklist.scoreBand,
                  style: TextStyle(
                    color: _bandColor(checklist),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${checklist.completedCount}/${checklist.totalCount} parameters · '
            'create school to go-live',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
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
          if (checklist.phases.isEmpty)
            ...checklist.steps.map(_stepRow)
          else
            ...checklist.phases.map(_phaseBlock),
        ],
      ),
    );
  }

  Color _bandColor(SchoolOnboardingChecklist checklist) {
    return switch (checklist.scoreBand) {
      'Ready' => Colors.greenAccent,
      'Operating' => Colors.lightGreenAccent,
      'Building' => Colors.amber,
      _ => Colors.orangeAccent,
    };
  }

  Widget _phaseBlock(SchoolScorePhase phase) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${phase.title}  ·  ${phase.completedCount}/${phase.totalCount}  ·  ${phase.percent}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            phase.summary,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 8),
          ...phase.steps.map(_stepRow),
        ],
      ),
    );
  }

  Widget _stepRow(SchoolOnboardingStep step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            step.done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: step.done ? Colors.greenAccent : Colors.white38,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.label,
                  style: TextStyle(
                    color: step.done ? Colors.white70 : Colors.white54,
                    fontSize: 13,
                  ),
                ),
                if (step.parameter.isNotEmpty)
                  Text(
                    step.parameter,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactChip(SchoolOnboardingChecklist checklist) {
    final color = checklist.scorePercent >= 85 ? Colors.green : Colors.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Score ${checklist.scorePercent}% · ${checklist.completedCount}/${checklist.totalCount}',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
