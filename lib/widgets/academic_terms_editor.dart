import 'package:flutter/material.dart';

import 'package:mayabela/models/academic_term.dart';

/// Add / edit academic term windows (start, end, optional exam dates).
class AcademicTermsEditor extends StatelessWidget {
  const AcademicTermsEditor({
    super.key,
    required this.terms,
    required this.onChanged,
    this.enabled = true,
  });

  final List<AcademicTerm> terms;
  final ValueChanged<List<AcademicTerm>> onChanged;
  final bool enabled;

  Future<void> _edit(BuildContext context, {AcademicTerm? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    var start = existing?.startDate ?? DateTime.now();
    var end = existing?.endDate ?? DateTime.now().add(const Duration(days: 90));
    var examStart = existing?.examStart;
    var examEnd = existing?.examEnd;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> pick(
              DateTime current,
              ValueChanged<DateTime> apply,
            ) async {
              final next = await showDatePicker(
                context: ctx,
                initialDate: current,
                firstDate: DateTime(2020),
                lastDate: DateTime(2040),
              );
              if (next != null) setDialogState(() => apply(next));
            }

            String label(DateTime? date) {
              if (date == null) return 'Not set';
              return '${date.day}/${date.month}/${date.year}';
            }

            return AlertDialog(
              title: Text(existing == null ? 'Add academic term' : 'Edit term'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Term name',
                        hintText: 'Term 1',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Starts'),
                      trailing: Text(label(start)),
                      onTap: () => pick(start, (d) => start = d),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Ends'),
                      trailing: Text(label(end)),
                      onTap: () => pick(end, (d) => end = d),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Exam window start'),
                      trailing: Text(label(examStart)),
                      onTap: () => pick(
                        examStart ?? end.subtract(const Duration(days: 14)),
                        (d) => examStart = d,
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Exam window end'),
                      trailing: Text(label(examEnd)),
                      onTap: () => pick(examEnd ?? end, (d) => examEnd = d),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: name.text.trim().isEmpty
                      ? null
                      : () => Navigator.pop(ctx, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    final termName = name.text.trim();
    name.dispose();
    if (saved != true || termName.isEmpty) return;
    final next = AcademicTerm(
      id: existing?.id ?? 'term-${DateTime.now().millisecondsSinceEpoch}',
      name: termName,
      startDate: start,
      endDate: end.isBefore(start) ? start : end,
      examStart: examStart,
      examEnd: examEnd,
    );
    final list = [...terms];
    if (existing == null) {
      list.add(next);
    } else {
      final index = list.indexWhere((t) => t.id == existing.id);
      if (index >= 0) list[index] = next;
    }
    onChanged(list);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Academic terms',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            if (enabled)
              TextButton.icon(
                onPressed: () => _edit(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add term'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Set term and exam windows for the academic calendar.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (terms.isEmpty)
          Text(
            'No terms yet. Add Term 1 / Term 2 or semesters.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          for (final term in terms)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_note_outlined),
              title: Text(term.name),
              subtitle: Text(
                '${term.startDate.day}/${term.startDate.month}/${term.startDate.year}'
                ' – ${term.endDate.day}/${term.endDate.month}/${term.endDate.year}'
                '${term.hasExamWindow ? ' · Exams ${term.examStart!.day}/${term.examStart!.month}–${term.examEnd!.day}/${term.examEnd!.month}' : ''}',
              ),
              trailing: enabled
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _edit(context, existing: term),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => onChanged(
                            terms.where((t) => t.id != term.id).toList(),
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
      ],
    );
  }
}
