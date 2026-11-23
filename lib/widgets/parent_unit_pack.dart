import 'package:flutter/material.dart';

import 'package:mayabela/models/curriculum_models.dart';
import 'package:mayabela/services/curriculum_service.dart';

/// Parent-facing unit pack on the lesson-plan desk (goals, assessment, help at home).
class ParentUnitPackList extends StatelessWidget {
  const ParentUnitPackList({
    super.key,
    required this.className,
    required this.accent,
    this.canEdit = false,
    this.subjects = const [],
    this.onEdit,
  });

  final String className;
  final Color accent;
  final bool canEdit;
  final List<String> subjects;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final units = canEdit
        ? CurriculumService.instance.unitsForSchool().where((u) {
            final unitClass = u.className;
            if (unitClass == null || unitClass.isEmpty) {
              return subjects.isEmpty ||
                  subjects.any(
                    (s) => s.trim().toLowerCase() == u.subject.trim().toLowerCase(),
                  );
            }
            return unitClass.trim().toLowerCase() == className.trim().toLowerCase();
          }).toList()
        : CurriculumService.instance.publishedForClass(className);
    if (units.isEmpty && !canEdit) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'This unit for families',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ),
            if (canEdit)
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.family_restroom, size: 18),
                label: const Text('Write pack'),
              ),
          ],
        ),
        if (units.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'No parent-facing unit yet. Write goals, the coming assessment, and how families can help at home.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ),
        for (final unit in units.take(6))
          ParentUnitPackCard(unit: unit, accent: accent),
      ],
    );
  }
}

class ParentUnitPackCard extends StatelessWidget {
  const ParentUnitPackCard({
    super.key,
    required this.unit,
    required this.accent,
  });

  final CurriculumUnit unit;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                unit.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                [
                  unit.subject,
                  if (unit.isPublished) 'Published',
                  if (!unit.isPublished) 'Draft',
                ].join(' · '),
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
              if (unit.objectives.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                _block('Goals', unit.objectives, accent),
              ],
              if (unit.assessmentSummary.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                _block('Coming assessment', unit.assessmentSummary, accent),
              ],
              if (unit.homeLearning.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                _block('Learning at home', unit.homeLearning, accent),
              ],
              if (unit.helpAtHome.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                _block('How you can help', unit.helpAtHome, accent),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _block(String label, String body, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: accent,
            letterSpacing: 0.2,
          ),
        ),
        Text(body, style: const TextStyle(height: 1.4)),
      ],
    );
  }
}

Future<void> showParentPackEditor({
  required BuildContext context,
  required String className,
  required List<String> subjects,
  CurriculumUnit? existing,
}) async {
  final title = TextEditingController(text: existing?.title ?? '');
  final goals = TextEditingController(text: existing?.objectives ?? '');
  final assessment = TextEditingController(
    text: existing?.assessmentSummary ?? '',
  );
  final home = TextEditingController(text: existing?.homeLearning ?? '');
  final help = TextEditingController(text: existing?.helpAtHome ?? '');
  var subject = existing?.subject ??
      (subjects.isNotEmpty ? subjects.first : 'General');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('Parent-facing unit'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (subjects.length > 1)
                  DropdownButtonFormField<String>(
                    initialValue: subjects.contains(subject) ? subject : subjects.first,
                    decoration: const InputDecoration(labelText: 'Subject'),
                    items: [
                      for (final name in subjects)
                        DropdownMenuItem(value: name, child: Text(name)),
                    ],
                    onChanged: (v) => setLocal(() => subject = v ?? subject),
                  ),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Unit title'),
                ),
                TextField(
                  controller: goals,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Goals this week'),
                ),
                TextField(
                  controller: assessment,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Coming assessment',
                  ),
                ),
                TextField(
                  controller: home,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Learning at home'),
                ),
                TextField(
                  controller: help,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'How families can help',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Publish to families'),
          ),
        ],
      ),
    ),
  );
  final titleText = title.text;
  final goalsText = goals.text;
  final assessmentText = assessment.text;
  final homeText = home.text;
  final helpText = help.text;
  title.dispose();
  goals.dispose();
  assessment.dispose();
  home.dispose();
  help.dispose();
  if (ok != true) return;
  await CurriculumService.instance.upsertParentPack(
    className: className,
    subject: subject,
    title: titleText.trim().isEmpty ? '$subject unit' : titleText.trim(),
    objectives: goalsText,
    assessmentSummary: assessmentText,
    homeLearning: homeText,
    helpAtHome: helpText,
    existingId: existing?.id,
  );
}
