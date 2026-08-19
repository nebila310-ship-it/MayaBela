import 'package:flutter/material.dart';

import 'package:mayabela/constants/school_subjects.dart';

/// Multi-select subject picker with preset list + custom add.
class SubjectMultiPicker extends StatefulWidget {
  const SubjectMultiPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.accent = Colors.indigo,
    this.label = 'Subjects',
  });

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final Color accent;
  final String label;

  @override
  State<SubjectMultiPicker> createState() => _SubjectMultiPickerState();
}

class _SubjectMultiPickerState extends State<SubjectMultiPicker> {
  Future<void> _addCustomSubject() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add subject'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Subject name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    final next = [...widget.selected];
    if (!next.contains(value)) next.add(value);
    widget.onChanged(next);
    setState(() {});
  }

  Future<void> _openPicker() async {
    final temp = {...widget.selected};
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          ...SchoolSubjects.all.map(
                            (subject) => CheckboxListTile(
                              value: temp.contains(subject),
                              title: Text(subject),
                              onChanged: (checked) {
                                setSheetState(() {
                                  if (checked == true) {
                                    temp.add(subject);
                                  } else {
                                    temp.remove(subject);
                                  }
                                });
                              },
                            ),
                          ),
                          for (final custom in temp.where(
                            (s) => !SchoolSubjects.all.contains(s),
                          ))
                            CheckboxListTile(
                              value: true,
                              title: Text(custom),
                              onChanged: (_) {
                                setSheetState(() => temp.remove(custom));
                              },
                            ),
                          ListTile(
                            leading: Icon(Icons.add, color: widget.accent),
                            title: const Text('Add subject'),
                            onTap: () async {
                              Navigator.pop(context);
                              await _addCustomSubject();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () {
                        widget.onChanged(temp.toList()..sort());
                        Navigator.pop(context);
                        setState(() {});
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _openPicker,
          icon: const Icon(Icons.menu_book_outlined),
          label: Text(
            widget.selected.isEmpty
                ? 'Select subjects'
                : '${widget.selected.length} selected',
          ),
        ),
        if (widget.selected.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: widget.selected
                .map(
                  (subject) => InputChip(
                    label: Text(subject),
                    onDeleted: () {
                      final next = [...widget.selected]..remove(subject);
                      widget.onChanged(next);
                      setState(() {});
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}
