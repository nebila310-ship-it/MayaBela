import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/theme/classroom_palette.dart';

/// Picks a due date, then a clock. Empty time becomes 16:00 the same day.
Future<DateTime?> pickHomeworkDue(
  BuildContext context, {
  DateTime? current,
}) async {
  final now = DateTime.now();
  final initial = current ?? now.add(const Duration(days: 2));
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: now.subtract(const Duration(days: 1)),
    lastDate: now.add(const Duration(days: 365)),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(
      current ?? DateTime(date.year, date.month, date.day, 16),
    ),
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
  final clock = time ?? const TimeOfDay(hour: 16, minute: 0);
  return DateTime(date.year, date.month, date.day, clock.hour, clock.minute);
}

/// Date and clock for a homework due moment. Midnight means the date only.
String formatHomeworkDue(DateTime due) {
  final date = '${due.day}/${due.month}/${due.year}';
  if (due.hour == 0 && due.minute == 0) return date;
  final clock =
      '${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')}';
  return '$date · $clock';
}

Color homeworkSubjectColor(String subject) =>
    ClassroomPalette.forKey(subject.trim().isEmpty ? 'homework' : subject);

Color homeworkTaskColor(String code) {
  switch (code) {
    case HomeworkTaskTypes.practice:
      return ClassroomPalette.blue;
    case HomeworkTaskTypes.preparation:
      return ClassroomPalette.purple;
    case HomeworkTaskTypes.consolidation:
      return ClassroomPalette.teal;
    case HomeworkTaskTypes.inquiry:
      return ClassroomPalette.cyan;
    case HomeworkTaskTypes.project:
      return ClassroomPalette.orange;
    case HomeworkTaskTypes.revision:
      return ClassroomPalette.pink;
    case HomeworkTaskTypes.reading:
      return ClassroomPalette.green;
    default:
      return ClassroomPalette.navy;
  }
}

/// Colored chips and labelled blocks for a posted homework brief.
class HomeworkBriefSections extends StatelessWidget {
  const HomeworkBriefSections({
    super.key,
    required this.item,
    this.showTitle = true,
  });

  final HomeworkItem item;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final ink = ClassroomPalette.inkOf(context);
    final muted = ClassroomPalette.mutedOf(context);
    final blocks = <Widget>[];

    if (showTitle) {
      blocks.add(
        Text(
          item.displayTitle,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: ink,
            height: 1.25,
          ),
        ),
      );
    }

    final due = item.dueDate;
    final dueLabel = due == null
        ? ''
        : item.isOverdue
            ? '${s.homeworkOverdue} · ${formatHomeworkDue(due)}'
            : s.homeworkDueOn(formatHomeworkDue(due));
    final chips = <Widget>[
      if (item.taskType.trim().isNotEmpty)
        _pill(
          s.homeworkTaskTypeLabel(item.taskType),
          homeworkTaskColor(item.taskType),
        ),
      if (item.estimatedMinutes != null)
        _pill(
          s.homeworkMinutes(item.estimatedMinutes!),
          ClassroomPalette.navy,
        ),
      if (item.submissionMethod.trim().isNotEmpty)
        _pill(
          s.homeworkSubmitLabel(item.submissionMethod),
          ClassroomPalette.teal,
        ),
      if (due != null)
        _pill(
          dueLabel,
          item.isOverdue
              ? ClassroomPalette.red
              : item.isDueSoon
                  ? ClassroomPalette.orange
                  : ClassroomPalette.green,
        ),
    ];

    if (chips.isNotEmpty) {
      blocks.add(const SizedBox(height: 8));
      blocks.add(Wrap(spacing: 6, runSpacing: 6, children: chips));
    }

    void addBlock(String label, String body, Color color, IconData icon) {
      final text = body.trim();
      if (text.isEmpty) return;
      blocks.add(const SizedBox(height: 10));
      blocks.add(_labelled(label, text, color, icon, ink));
    }

    final instructions = item.description.trim();
    final titleLine = item.title.trim();
    if (instructions.isNotEmpty &&
        (titleLine.isEmpty || instructions != titleLine)) {
      addBlock(
        s.homeworkInstructions,
        instructions,
        ClassroomPalette.blue,
        Icons.menu_book_outlined,
      );
    }
    addBlock(
      s.homeworkLearningObjective,
      item.learningObjective,
      ClassroomPalette.purple,
      Icons.flag_outlined,
    );
    addBlock(
      s.homeworkSuccessCriteria,
      item.successCriteria,
      ClassroomPalette.green,
      Icons.check_circle_outline,
    );
    addBlock(
      s.homeworkResources,
      item.resources,
      ClassroomPalette.cyan,
      Icons.link,
    );
    addBlock(
      s.homeworkSupport,
      item.supportNote,
      ClassroomPalette.orange,
      Icons.accessibility_new,
    );
    addBlock(
      s.homeworkExtension,
      item.extensionNote,
      ClassroomPalette.pink,
      Icons.auto_awesome_outlined,
    );

    if (item.maxScore != 100) {
      blocks.add(const SizedBox(height: 8));
      blocks.add(
        Text(
          '${s.homeworkMaxScore}: ${item.maxScore.toStringAsFixed(item.maxScore == item.maxScore.roundToDouble() ? 0 : 1)}',
          style: TextStyle(color: muted, fontWeight: FontWeight.w600),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _labelled(
    String label,
    String body,
    Color color,
    IconData icon,
    Color ink,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(body, style: TextStyle(color: ink, height: 1.35, fontSize: 14)),
        ],
      ),
    );
  }
}

/// Fields a teacher fills when posting homework for an international brief.
class HomeworkPostFields extends StatelessWidget {
  const HomeworkPostFields({
    super.key,
    required this.title,
    required this.instructions,
    required this.objective,
    required this.criteria,
    required this.resources,
    required this.supportNote,
    required this.extensionNote,
    required this.maxScore,
    required this.taskType,
    required this.submissionMethod,
    required this.estimatedMinutes,
    required this.dueDate,
    required this.onTaskType,
    required this.onSubmission,
    required this.onMinutes,
    required this.onPickDue,
    this.leading,
    this.trailing,
  });

  final TextEditingController title;
  final TextEditingController instructions;
  final TextEditingController objective;
  final TextEditingController criteria;
  final TextEditingController resources;
  final TextEditingController supportNote;
  final TextEditingController extensionNote;
  final TextEditingController maxScore;
  final String taskType;
  final String submissionMethod;
  final int? estimatedMinutes;
  final DateTime? dueDate;
  final ValueChanged<String> onTaskType;
  final ValueChanged<String> onSubmission;
  final ValueChanged<int?> onMinutes;
  final VoidCallback onPickDue;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?leading,
        TextField(
          controller: title,
          textCapitalization: TextCapitalization.sentences,
          decoration: _field(s.homeworkAssignmentTitle, Icons.title),
        ),
        const SizedBox(height: 12),
        Text(
          s.homeworkTaskType,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Wrap(
          children: [
            for (final code in HomeworkTaskTypes.values)
              _choice(
                label: s.homeworkTaskTypeLabel(code),
                selected: taskType == code,
                color: homeworkTaskColor(code),
                onTap: () => onTaskType(taskType == code ? '' : code),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: objective,
          maxLines: 2,
          decoration: _field(
            s.homeworkLearningObjective,
            Icons.flag_outlined,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: criteria,
          maxLines: 2,
          decoration: _field(
            s.homeworkSuccessCriteria,
            Icons.check_circle_outline,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: instructions,
          maxLines: 4,
          decoration: _field(s.homeworkInstructions, Icons.notes_outlined),
        ),
        const SizedBox(height: 12),
        Text(
          s.homeworkEstimatedTime,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Wrap(
          children: [
            for (final minutes in const [10, 15, 20, 30, 45, 60])
              _choice(
                label: s.homeworkMinutes(minutes),
                selected: estimatedMinutes == minutes,
                color: ClassroomPalette.navy,
                onTap: () => onMinutes(
                  estimatedMinutes == minutes ? null : minutes,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          s.homeworkHowToSubmit,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Wrap(
          children: [
            for (final code in HomeworkSubmissionMethods.values)
              _choice(
                label: s.homeworkSubmitLabel(code),
                selected: submissionMethod == code,
                color: ClassroomPalette.teal,
                onTap: () =>
                    onSubmission(submissionMethod == code ? '' : code),
              ),
          ],
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.event_available,
            color: dueDate == null
                ? ClassroomPalette.muted
                : ClassroomPalette.orange,
          ),
          title: Text(
            dueDate == null ? s.homeworkNoDue : formatHomeworkDue(dueDate!),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          trailing: TextButton(
            onPressed: onPickDue,
            child: Text(s.homeworkSetDue),
          ),
        ),
        TextField(
          controller: resources,
          maxLines: 2,
          decoration: _field(s.homeworkResources, Icons.link),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: supportNote,
          maxLines: 2,
          decoration: _field(s.homeworkSupport, Icons.accessibility_new),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: extensionNote,
          maxLines: 2,
          decoration: _field(
            s.homeworkExtension,
            Icons.auto_awesome_outlined,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: maxScore,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: _field(s.homeworkMaxScore, Icons.grade_outlined),
        ),
        if (trailing != null) ...[
          const SizedBox(height: 12),
          trailing!,
        ],
      ],
    );
  }

  InputDecoration _field(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: const OutlineInputBorder(),
      alignLabelWithHint: true,
    );
  }

  Widget _choice({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: Material(
        color: selected ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
