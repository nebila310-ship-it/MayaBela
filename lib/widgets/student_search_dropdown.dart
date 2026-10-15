import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';

/// One row in a searchable student picker.
class StudentSearchOption {
  const StudentSearchOption({
    required this.id,
    required this.name,
    this.studentId,
  });

  /// Stable selection id. Prefer the student record id when the class has
  /// two students with the same name.
  final String id;
  final String name;
  final String? studentId;
}

/// Closed field that opens a scrollable, searchable student list.
class StudentSearchDropdown extends StatelessWidget {
  const StudentSearchDropdown({
    super.key,
    required this.options,
    required this.selectedId,
    required this.onSelected,
    this.accent = const Color(0xFF0D47A1),
  });

  final List<StudentSearchOption> options;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final Color accent;

  StudentSearchOption? get _selected {
    for (final option in options) {
      if (option.id == selectedId) return option;
    }
    return options.isEmpty ? null : options.first;
  }

  Future<void> _open(BuildContext context) async {
    if (options.length <= 1) return;
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => _StudentSearchDialog(
        options: options,
        selectedId: _selected?.id,
        accent: accent,
      ),
    );
    if (picked != null) onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final canOpen = options.length > 1;
    return Material(
      color: Colors.white.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: canOpen ? () => _open(context) : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 20, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  selected?.name ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
              if (canOpen) ...[
                const SizedBox(width: 8),
                Icon(Icons.search, size: 18, color: accent.withValues(alpha: 0.8)),
                Icon(Icons.arrow_drop_down, color: accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentSearchDialog extends StatefulWidget {
  const _StudentSearchDialog({
    required this.options,
    required this.selectedId,
    required this.accent,
  });

  final List<StudentSearchOption> options;
  final String? selectedId;
  final Color accent;

  @override
  State<_StudentSearchDialog> createState() => _StudentSearchDialogState();
}

class _StudentSearchDialogState extends State<_StudentSearchDialog> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<StudentSearchOption> get _filtered {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options.where((option) {
      final name = option.name.toLowerCase();
      final id = (option.studentId ?? '').toLowerCase();
      return name.contains(q) || id.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final filtered = _filtered;
    final height = MediaQuery.sizeOf(context).height;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: height * 0.72,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.studentsAudience,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _query,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: s.searchStudentsHint,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          s.noMatchingStudents,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final option = filtered[index];
                          final selected = option.id == widget.selectedId;
                          final id = option.studentId?.trim();
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            selected: selected,
                            selectedTileColor:
                                widget.accent.withValues(alpha: 0.1),
                            title: Text(
                              option.name,
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: selected ? widget.accent : null,
                              ),
                            ),
                            subtitle: id == null || id.isEmpty
                                ? null
                                : Text(id),
                            trailing: selected
                                ? Icon(Icons.check, color: widget.accent)
                                : null,
                            onTap: () => Navigator.pop(context, option.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
