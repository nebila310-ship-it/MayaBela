import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/exam_models.dart';
import 'package:mayabela/models/lesson_plan_models.dart';
import 'package:mayabela/services/announcement_attachment_service.dart';
import 'package:mayabela/services/curriculum_service.dart';
import 'package:mayabela/services/exam_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/utils/attachment_path_utils.dart';
import 'package:mayabela/widgets/attachment_share_actions.dart';
import 'package:mayabela/widgets/online_class_link_button.dart';

/// Expandable weekly plan card used by admin, teacher, parent, and student.
class LessonPlanViewCard extends StatefulWidget {
  const LessonPlanViewCard({
    super.key,
    required this.plan,
    this.accent = const Color(0xFF5D4037),
    this.initiallyExpanded = false,
    this.actions = const [],
    this.allowShareDownload = true,
  });

  final LessonPlan plan;
  final Color accent;
  final bool initiallyExpanded;
  final List<Widget> actions;
  final bool allowShareDownload;

  @override
  State<LessonPlanViewCard> createState() => _LessonPlanViewCardState();
}

class _LessonPlanViewCardState extends State<LessonPlanViewCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  void didUpdateWidget(covariant LessonPlanViewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initiallyExpanded != widget.initiallyExpanded &&
        oldWidget.plan.id != widget.plan.id) {
      _expanded = widget.initiallyExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final accent = widget.accent;
    final homework = SchoolDataService.instance
        .getHomeworkForClass(plan.className)
        .where((h) => plan.homeworkIds.contains(h.id))
        .toList();
    final papers = <ExamPaper>[
      for (final id in plan.examPaperIds)
        if (ExamService.instance.paperById(id) != null)
          ExamService.instance.paperById(id)!,
    ];
    final materials = SchoolDataService.instance
        .learningMaterialsSnapshot()
        .where((m) => plan.learningMaterialIds.contains(m.id))
        .toList();
    final unit = plan.curriculumUnitId == null
        ? null
        : CurriculumService.instance.unitById(plan.curriculumUnitId!);
    final meta = [
      plan.className,
      plan.subject,
      'Week ${plan.weekLabel}',
      if (plan.periodLabel.trim().isNotEmpty) plan.periodLabel.trim(),
      if (plan.durationMinutes != null) '${plan.durationMinutes} min',
      plan.isPublished ? 'Published' : 'Draft',
      if (plan.reviewLabel.isNotEmpty) plan.reviewLabel,
      if (plan.hasAchievement) plan.achievementLabel,
    ].where((part) => part.trim().isNotEmpty).join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('lp-expand-${plan.id}'),
          initiallyExpanded: _expanded,
          maintainState: true,
          onExpansionChanged: (value) {
            if (!mounted) return;
            setState(() => _expanded = value);
          },
          leading: Icon(Icons.menu_book_outlined, color: accent),
          title: Text(
            plan.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(meta, style: TextStyle(color: Colors.grey.shade800)),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const _LessonPlanGuide(),
            _achievementSection(plan),
            if (unit != null)
              _section(
                context,
                'Curriculum unit',
                unit.title,
              ),
            _section(
              context,
              'Learning objectives',
              plan.objectives,
              hint: 'What learners will know or be able to do by the end of the week.',
            ),
            _section(
              context,
              'Success criteria',
              plan.successCriteria,
              hint: 'How learners and the teacher will know the lesson went well.',
            ),
            _section(context, 'Key vocabulary', plan.keyVocabulary),
            _section(context, 'Prior knowledge', plan.priorKnowledge),
            _section(
              context,
              'Starter / hook',
              plan.starter,
              hint: 'Opening activity that settles the class and sets the aim.',
            ),
            _section(
              context,
              'Main teaching & learning',
              plan.activities,
              hint: 'Core sequence: modelling, guided practice, independent work.',
            ),
            _section(
              context,
              'Plenary',
              plan.plenary,
              hint: 'Close the lesson and check understanding.',
            ),
            _section(
              context,
              'Differentiation',
              plan.differentiation,
              hint: 'Support, core, and challenge so every learner can access the aim.',
            ),
            _section(
              context,
              'Inclusion / SEN',
              plan.inclusionNotes,
            ),
            _section(
              context,
              'Assessment for learning',
              plan.assessment,
            ),
            _section(
              context,
              'Home learning',
              plan.homeLearning,
            ),
            if (plan.hasOnlineSession) ...[
              const SizedBox(height: 8),
              OnlineClassLinkButton(plan: plan),
            ],
            if (homework.isNotEmpty)
              _chips(context, 'Linked homework', [
                for (final item in homework)
                  item.description.trim().isEmpty
                      ? item.subject
                      : item.description,
              ]),
            if (papers.isNotEmpty)
              _chips(context, 'Linked assessments', [
                for (final paper in papers) paper.title,
              ]),
            if (materials.isNotEmpty)
              _chips(context, 'Linked resources', [
                for (final item in materials)
                  item.bookName.trim().isEmpty
                      ? item.materialName
                      : item.bookName,
              ]),
            if (plan.attachmentPaths.isNotEmpty) ...[
              const SizedBox(height: 12),
              LessonPlanAttachmentList(
                paths: plan.attachmentPaths,
                allowShareDownload: widget.allowShareDownload,
              ),
            ],
            if (widget.actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(spacing: 8, children: widget.actions),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _achievementSection(LessonPlan plan) {
    final value = plan.achievementPercent;
    final color = value == null
        ? Colors.grey.shade600
        : value >= 80
            ? const Color(0xFF15803D)
            : value >= 60
                ? const Color(0xFFB45309)
                : const Color(0xFFB91C1C);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Achievement',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: widget.accent,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value == null
                  ? 'Management has not evaluated this weekly plan yet.'
                  : 'Management evaluation of how well this plan met its aims.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            if (value == null)
              const Text('Not evaluated')
            else ...[
              Text(
                '$value%',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: value / 100,
                  minHeight: 8,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
              ),
              if (plan.achievementNotes.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(plan.achievementNotes.trim(), style: const TextStyle(height: 1.35)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    String body, {
    String? hint,
  }) {
    final text = body.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: widget.accent,
                fontSize: 13,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: 2),
              Text(
                hint,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 4),
            Text(text, style: const TextStyle(height: 1.35)),
          ],
        ),
      ),
    );
  }

  Widget _chips(BuildContext context, String title, List<String> labels) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: widget.accent,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final label in labels)
                  Chip(
                    label: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonPlanGuide extends StatelessWidget {
  const _LessonPlanGuide();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'How this weekly plan is organised: learning objectives say what '
            'students will know or do. Success criteria show how they will '
            'know they got there. The sequence is starter → main teaching → '
            'plenary. Differentiation and inclusion notes say how every '
            'learner is supported. Tap a file to open it — the plan stays open.',
            style: TextStyle(height: 1.35, fontSize: 12.5),
          ),
        ),
      ),
    );
  }
}

/// Opens lesson-plan files from signed-in storage. Does not preview with a
/// widget that can consume cached bytes or collapse the plan card.
class LessonPlanAttachmentList extends StatelessWidget {
  const LessonPlanAttachmentList({
    super.key,
    required this.paths,
    this.onRemove,
    this.allowShareDownload = true,
  });

  final List<String> paths;
  final ValueChanged<String>? onRemove;
  final bool allowShareDownload;

  @override
  Widget build(BuildContext context) {
    final files = paths.where((path) => path.trim().isNotEmpty).toList();
    if (files.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resources & worksheets',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 6),
        for (final path in files)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  leading: Icon(
                    attachmentPathIsImage(path)
                        ? Icons.image_outlined
                        : Icons.attach_file,
                  ),
                  title: Text(
                    attachmentFileName(path),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: onRemove == null
                      ? const Icon(Icons.open_in_new, size: 18)
                      : IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => onRemove!(path),
                        ),
                  onTap: () => openAttachmentWithFeedback(context, path: path),
                ),
                if (allowShareDownload)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: AttachmentShareDownloadRow(path: path, compact: true),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Add / remove lesson-plan files without image thumbnails that eat the cache.
class LessonPlanAttachmentPicker extends StatefulWidget {
  const LessonPlanAttachmentPicker({
    super.key,
    required this.paths,
    required this.onChanged,
  });

  final List<String> paths;
  final ValueChanged<List<String>> onChanged;

  @override
  State<LessonPlanAttachmentPicker> createState() =>
      _LessonPlanAttachmentPickerState();
}

class _LessonPlanAttachmentPickerState
    extends State<LessonPlanAttachmentPicker> {
  var _picking = false;

  Future<void> _add() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picked = await AnnouncementAttachmentService.instance
          .pickAndSaveFiles(subdir: 'lesson_plan_attachments');
      if (!mounted) return;
      final s = AppLocale.instance.strings;
      final maxMb = AnnouncementAttachmentService.instance.lastRejectedMaxMb;
      if (picked.isEmpty) {
        if (maxMb != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.galleryFileTooLarge(maxMb))),
          );
        }
        return;
      }
      widget.onChanged([...widget.paths, ...picked.map((a) => a.filePath)]);
      if (maxMb != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.galleryFileTooLarge(maxMb))),
        );
      }
    } catch (_) {
      if (!mounted) return;
      final s = AppLocale.instance.strings;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.galleryMediaPickFailed)),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _picking ? null : _add,
            icon: _picking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.attach_file),
            label: Text(s.announcementAddAttachment),
          ),
        ),
        if (widget.paths.isNotEmpty) ...[
          const SizedBox(height: 8),
          LessonPlanAttachmentList(
            paths: widget.paths,
            allowShareDownload: false,
            onRemove: (path) =>
                widget.onChanged([...widget.paths]..remove(path)),
          ),
        ],
      ],
    );
  }
}
