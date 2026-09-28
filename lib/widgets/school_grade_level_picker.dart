import 'package:flutter/material.dart';

/// KG / Primary / Middle / High School bands used across Academic Management.
enum SchoolLevel { kindergarten, primary, middle, highSchool, other }

/// Standard grade catalog for school onboarding / profile.
abstract final class SchoolGradeCatalog {
  static const kindergarten = ['PreKG', 'LKG', 'UKG'];
  static const primary = [
    'Grade 1',
    'Grade 2',
    'Grade 3',
    'Grade 4',
    'Grade 5',
    'Grade 6',
  ];
  static const middle = ['Grade 7', 'Grade 8'];
  static const highSchool = ['Grade 9', 'Grade 10', 'Grade 11', 'Grade 12'];

  static const primarySecondary = [...primary, ...middle, ...highSchool];

  static const all = [...kindergarten, ...primarySecondary];

  static const levelOrder = [
    SchoolLevel.kindergarten,
    SchoolLevel.primary,
    SchoolLevel.middle,
    SchoolLevel.highSchool,
    SchoolLevel.other,
  ];

  static String labelFor(SchoolLevel level) {
    return switch (level) {
      SchoolLevel.kindergarten => 'Kindergarten',
      SchoolLevel.primary => 'Primary',
      SchoolLevel.middle => 'Middle School',
      SchoolLevel.highSchool => 'High School',
      SchoolLevel.other => 'Other levels',
    };
  }

  static List<String> gradesFor(SchoolLevel level) {
    return switch (level) {
      SchoolLevel.kindergarten => kindergarten,
      SchoolLevel.primary => primary,
      SchoolLevel.middle => middle,
      SchoolLevel.highSchool => highSchool,
      SchoolLevel.other => const [],
    };
  }

  static SchoolLevel levelForGrade(String raw) {
    final compact = raw.toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');
    if (compact.contains('kg') ||
        compact.contains('kindergarten') ||
        compact == 'prekg' ||
        compact == 'lkg' ||
        compact == 'ukg') {
      return SchoolLevel.kindergarten;
    }
    final number = _gradeNumber(raw);
    if (number == null) return SchoolLevel.other;
    if (number <= 6) return SchoolLevel.primary;
    if (number <= 8) return SchoolLevel.middle;
    return SchoolLevel.highSchool;
  }

  static Map<SchoolLevel, List<String>> group(Iterable<String> grades) {
    final grouped = {for (final level in levelOrder) level: <String>[]};
    for (final grade in grades) {
      grouped[levelForGrade(grade)]!.add(grade);
    }
    return grouped;
  }

  static int? _gradeNumber(String raw) {
    final match = RegExp(r'(\d{1,2})').firstMatch(raw);
    if (match == null) return null;
    final value = int.tryParse(match.group(1)!);
    if (value == null || value < 1 || value > 12) return null;
    return value;
  }
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
          for (final level in [
            SchoolLevel.kindergarten,
            SchoolLevel.primary,
            SchoolLevel.middle,
            SchoolLevel.highSchool,
          ]) ...[
            _groupHeader(
              title: SchoolGradeCatalog.labelFor(level),
              grades: SchoolGradeCatalog.gradesFor(level),
              color: hintColor,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SchoolGradeCatalog.gradesFor(
                level,
              ).map((g) => _chip(g)).toList(),
            ),
            const SizedBox(height: 14),
          ],
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
          child: Text(
            allOn ? 'Clear' : 'Select all',
            style: const TextStyle(fontSize: 12),
          ),
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
            : (dark ? Colors.white24 : Colors.black26),
      ),
      backgroundColor: dark
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.white,
    );
  }
}
