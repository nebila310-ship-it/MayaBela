import 'package:flutter/material.dart';

/// Standard grade catalog for school onboarding / profile.
abstract final class SchoolGradeCatalog {
  static const kindergarten = ['PreKG', 'LKG', 'UKG'];
  static const primarySecondary = [
    'Grade 1',
    'Grade 2',
    'Grade 3',
    'Grade 4',
    'Grade 5',
    'Grade 6',
    'Grade 7',
    'Grade 8',
    'Grade 9',
    'Grade 10',
    'Grade 11',
    'Grade 12',
  ];

  static const all = [...kindergarten, ...primarySecondary];
}

/// Tick-box grade selection (Kindergarten + Grade 1–12).
class SchoolGradeLevelPicker extends StatelessWidget {
  const SchoolGradeLevelPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.dark = true,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool enabled;
  final bool dark;

  void _toggle(String grade) {
    if (!enabled) return;
    final next = Set<String>.from(selected);
    if (next.contains(grade)) {
      next.remove(grade);
    } else {
      next.add(grade);
    }
    onChanged(next);
  }

  void _selectGroup(List<String> grades, {required bool select}) {
    if (!enabled) return;
    final next = Set<String>.from(selected);
    if (select) {
      next.addAll(grades);
    } else {
      next.removeAll(grades);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final labelColor = dark ? Colors.white70 : null;
    final hintColor = dark ? Colors.white54 : Colors.black54;
    final border = dark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.12);
    final fill = dark ? const Color(0xFF1E293B) : Colors.grey.shade50;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Grade levels',
            style: TextStyle(
              color: labelColor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tick every level this school offers',
            style: TextStyle(color: hintColor, fontSize: 11),
          ),
          const SizedBox(height: 12),
          _groupHeader(
            title: 'Kindergarten',
            grades: SchoolGradeCatalog.kindergarten,
            color: hintColor,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SchoolGradeCatalog.kindergarten
                .map((g) => _chip(g))
                .toList(),
          ),
          const SizedBox(height: 14),
          _groupHeader(
            title: 'Grade 1 – 12',
            grades: SchoolGradeCatalog.primarySecondary,
            color: hintColor,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SchoolGradeCatalog.primarySecondary
                .map((g) => _chip(g))
                .toList(),
          ),
          if (selected.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${selected.length} selected: ${_orderedSelected().join(', ')}',
              style: TextStyle(color: hintColor, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  List<String> _orderedSelected() {
    return SchoolGradeCatalog.all.where(selected.contains).toList();
  }

  Widget _groupHeader({
    required String title,
    required List<String> grades,
    required Color color,
  }) {
    final allOn = grades.every(selected.contains);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        TextButton(
          onPressed: enabled
              ? () => _selectGroup(grades, select: !allOn)
              : null,
          style: TextButton.styleFrom(
            foregroundColor: dark ? Colors.tealAccent : Colors.teal.shade700,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: Text(allOn ? 'Clear' : 'Select all', style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _chip(String grade) {
    final on = selected.contains(grade);
    return FilterChip(
      label: Text(grade),
      selected: on,
      showCheckmark: true,
      onSelected: enabled ? (_) => _toggle(grade) : null,
      selectedColor: Colors.teal.withValues(alpha: dark ? 0.35 : 0.25),
      checkmarkColor: dark ? Colors.white : Colors.teal.shade900,
      labelStyle: TextStyle(
        color: dark
            ? (on ? Colors.white : Colors.white70)
            : (on ? Colors.teal.shade900 : Colors.black87),
        fontWeight: on ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12.5,
      ),
      side: BorderSide(
        color: on
            ? Colors.tealAccent.withValues(alpha: 0.7)
            : (dark
                ? Colors.white24
                : Colors.black26),
      ),
      backgroundColor: dark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
    );
  }
}
