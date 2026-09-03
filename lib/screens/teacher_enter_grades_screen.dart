import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/markbook.dart';
import 'package:mayabela/services/announcement_attachment_service.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/file_attachment_share_service.dart';
import 'package:mayabela/services/grade_mark_photo_service.dart';
import 'package:mayabela/services/grade_workflow_service.dart';
import 'package:mayabela/services/markbook_service.dart';
import 'package:mayabela/services/school_content_sync_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/theme/teacher_theme.dart';
import 'package:mayabela/utils/attachment_path_utils.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';
import 'package:mayabela/widgets/class_picker_bar.dart';
import 'package:mayabela/widgets/platform_path_image.dart';

class _StudentGradeDraft {
  _StudentGradeDraft({
    required String scoreText,
    String commentText = '',
    List<String>? markPhotoPaths,
    List<String>? attachmentPaths,
    Map<String, String>? categoryScores,
  })  : scoreController = TextEditingController(text: scoreText),
        commentController = TextEditingController(text: commentText),
        markPhotoPaths = List<String>.from(markPhotoPaths ?? []),
        attachmentPaths = List<String>.from(attachmentPaths ?? []) {
    for (final entry in (categoryScores ?? const <String, String>{}).entries) {
      categoryControllers[entry.key] = TextEditingController(text: entry.value);
    }
  }

  final TextEditingController scoreController;
  final TextEditingController commentController;
  final Map<String, TextEditingController> categoryControllers = {};
  List<String> markPhotoPaths;
  List<String> attachmentPaths;

  int get attachmentCount => markPhotoPaths.length + attachmentPaths.length;

  TextEditingController categoryController(String id, [String text = '']) {
    return categoryControllers.putIfAbsent(
      id,
      () => TextEditingController(text: text),
    );
  }

  void dispose() {
    scoreController.dispose();
    commentController.dispose();
    for (final controller in categoryControllers.values) {
      controller.dispose();
    }
  }
}

/// Teacher enters grades for one subject across an entire class section.
class TeacherEnterGradesScreen extends StatefulWidget {
  const TeacherEnterGradesScreen({
    super.key,
    required this.className,
    this.initialSubject,
  });

  final String className;
  final String? initialSubject;

  @override
  State<TeacherEnterGradesScreen> createState() =>
      _TeacherEnterGradesScreenState();
}

class _TeacherEnterGradesScreenState extends State<TeacherEnterGradesScreen> {
  final _data = SchoolDataService.instance;
  final _access = TeacherAccessService.instance;
  final _drafts = <String, _StudentGradeDraft>{};
  final _expandedStudents = <String>{};
  var _selectedSubject = '';
  var _submitForApproval = false;
  var _saving = false;

  bool get _requireApproval =>
      GradeWorkflowService.requireApproval(AuthService.activeSchoolId);

  List<String> get _subjects => _access.teachableSubjects(widget.className);

  List<AssessmentCategory> get _categories =>
      MarkbookService.instance.settingsForSchool().categories;

  List<String> get _studentNames {
    return _data
        .getStudentsForClass(widget.className)
        .map((student) => student.name)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _submitForApproval =
        GradeWorkflowService.requireApproval(AuthService.activeSchoolId);
    final subjects = _subjects;
    _selectedSubject = widget.initialSubject ??
        (subjects.isNotEmpty ? subjects.first : '');
    _loadDraftsForSubject();
  }

  @override
  void dispose() {
    for (final draft in _drafts.values) {
      draft.dispose();
    }
    super.dispose();
  }

  InputDecoration _compactScoreDecoration(AppStrings s) {
    return InputDecoration(
      hintText: s.scoreLabel,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: TeacherTheme.primaryDark.withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: TeacherTheme.primaryDark.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: TeacherTheme.primaryDark, width: 1.5),
      ),
    );
  }

  void _loadDraftsForSubject() {
    for (final draft in _drafts.values) {
      draft.dispose();
    }
    _drafts.clear();

    final reports = _data.getGradeReportsForClass(widget.className);
    for (final name in _studentNames) {
      StudentGradeReport? report;
      for (final item in reports) {
        if (item.studentName == name) {
          report = item;
          break;
        }
      }

      var scoreText = '';
      var commentText = '';
      List<String> markPhotoPaths = [];
      List<String> attachmentPaths = [];
      final categoryScores = <String, String>{};
      if (report != null) {
        for (final grade in report.subjects) {
          if (grade.subject == _selectedSubject) {
            scoreText = grade.score.toInt().toString();
            commentText = grade.comment ?? '';
            markPhotoPaths = List<String>.from(grade.markPhotoPaths);
            attachmentPaths = List<String>.from(grade.attachmentPaths);
            for (final mark in MarkbookService.instance.marksForSubject(grade)) {
              if (mark.score != null) {
                categoryScores[mark.categoryId] = mark.score!.toInt().toString();
              }
            }
            break;
          }
        }
      }

      _drafts[name] = _StudentGradeDraft(
        scoreText: scoreText,
        commentText: commentText,
        markPhotoPaths: markPhotoPaths,
        attachmentPaths: attachmentPaths,
        categoryScores: categoryScores,
      );
    }
  }

  _StudentGradeDraft _draftFor(String studentName) {
    return _drafts.putIfAbsent(
      studentName,
      () => _StudentGradeDraft(scoreText: ''),
    );
  }

  String _draftFinalLabel(_StudentGradeDraft draft) {
    final marks = [
      for (final cat in _categories)
        AssessmentMark(
          categoryId: cat.id,
          label: cat.label,
          weightPercent: cat.weightPercent,
          score: double.tryParse(draft.categoryController(cat.id).text.trim()),
        ),
    ];
    if (!marks.any((m) => m.isEntered)) return '—';
    final pct = MarkbookMath.weightedPercentage(
      marks,
      missingCountsAsZero:
          MarkbookService.instance.settingsForSchool().missingCountsAsZero,
    );
    return '${pct.toStringAsFixed(1)} ${MarkbookMath.letterFromPercentage(pct)}';
  }

  Future<void> _pickMarkPhotos(_StudentGradeDraft draft, String studentName) async {
    final picked = await GradeMarkPhotoService.instance.pickFromGallery();
    if (!mounted) return;
    if (picked.isEmpty) return;
    setState(() {
      draft.markPhotoPaths.addAll(picked);
      _expandedStudents.add(studentName);
    });
  }

  Future<void> _pickAttachments(_StudentGradeDraft draft, String studentName) async {
    final picked = await AnnouncementAttachmentService.instance
        .pickAndSaveFiles(subdir: 'grade_attachments');
    if (!mounted) return;
    if (picked.isEmpty) return;
    setState(() {
      draft.attachmentPaths.addAll(picked.map((a) => a.filePath));
      _expandedStudents.add(studentName);
    });
  }

  Widget _attachmentThumb(String path, {required VoidCallback onRemove}) {
    final isImage = attachmentPathIsImage(path);
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: isImage
                  ? PlatformPathImage(
                      path: path,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.insert_drive_file_outlined),
                      ),
                    )
                  : ColoredBox(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.insert_drive_file_outlined),
                    ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                minimumSize: const Size(24, 24),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.close, size: 14),
              onPressed: onRemove,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_saving || _selectedSubject.isEmpty) return;
    final s = AppLocale.instance.strings;

    final scores = <String, double>{};
    final comments = <String, String>{};
    final markPhotos = <String, List<String>>{};
    final attachments = <String, List<String>>{};
    final assessmentsByStudent = <String, List<AssessmentMark>>{};
    final cats = _categories;
    final missingAsZero =
        MarkbookService.instance.settingsForSchool().missingCountsAsZero;

    for (final entry in _drafts.entries) {
      final comment = entry.value.commentController.text.trim();
      if (comment.isNotEmpty) {
        comments[entry.key] = comment;
      }
      if (entry.value.markPhotoPaths.isNotEmpty) {
        markPhotos[entry.key] = List<String>.from(entry.value.markPhotoPaths);
      }
      if (entry.value.attachmentPaths.isNotEmpty) {
        attachments[entry.key] = List<String>.from(entry.value.attachmentPaths);
      }

      var usedCategories = false;
      if (cats.isNotEmpty) {
        final marks = <AssessmentMark>[];
        var any = false;
        for (final cat in cats) {
          final raw = entry.value.categoryController(cat.id).text.trim();
          double? score;
          if (raw.isNotEmpty) {
            score = double.tryParse(raw);
            if (score == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(s.invalidScoreFor(entry.key))),
              );
              return;
            }
            score = score.clamp(0, 100);
            any = true;
          }
          marks.add(
            AssessmentMark(
              categoryId: cat.id,
              label: cat.label,
              weightPercent: cat.weightPercent,
              score: score,
              enteredAt: score == null ? null : DateTime.now(),
            ),
          );
        }
        if (any) {
          usedCategories = true;
          assessmentsByStudent[entry.key] = marks;
          scores[entry.key] = MarkbookMath.weightedPercentage(
            marks,
            missingCountsAsZero: missingAsZero,
          );
        }
      }

      if (!usedCategories) {
        final raw = entry.value.scoreController.text.trim();
        if (raw.isEmpty) continue;
        final score = double.tryParse(raw);
        if (score == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.invalidScoreFor(entry.key))),
          );
          return;
        }
        scores[entry.key] = score.clamp(0, 100);
      }
    }

    if (scores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.enterAtLeastOneGrade)),
      );
      return;
    }

    setState(() => _saving = true);

    final slot = _access.teachingSlotFor(widget.className, _selectedSubject);
    final shouldSubmit = _requireApproval || _submitForApproval;
    final result = _data.enterSubjectGradesForClass(
      className: widget.className,
      subject: _selectedSubject,
      teacherId: _access.teacherId,
      scoresByStudentName: scores,
      subjectId: slot?.subjectId,
      teachingSlotId: slot?.slotId,
      publishToParents: shouldSubmit,
      commentsByStudentName: comments.isEmpty ? null : comments,
      markPhotoPathsByStudentName: markPhotos.isEmpty ? null : markPhotos,
      attachmentPathsByStudentName: attachments.isEmpty ? null : attachments,
      assessmentsByStudentName:
          assessmentsByStudent.isEmpty ? null : assessmentsByStudent,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result.saved == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.skippedLocked > 0
                ? 'Could not save: ${result.skippedLocked} grade(s) are locked (pending approval or already approved).'
                : s.gradePublishFailed,
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    SchoolContentSyncService.instance.markDataChanged();
    final skippedNote = result.skippedLocked > 0
        ? ' (${result.skippedLocked} locked grade(s) skipped)'
        : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          shouldSubmit && _requireApproval
              ? 'Submitted ${result.saved} grade(s) for approval$skippedNote'
              : '${s.gradesSavedForClass(result.saved, widget.className)}$skippedNote',
        ),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context, true);
  }

  Widget _buildMarkPhotosSection(
    AppStrings s,
    _StudentGradeDraft draft,
    String studentName,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          s.markPhotosLabel,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _pickMarkPhotos(draft, studentName),
          icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
          label: Text(s.addMarkPhotos),
        ),
        if (draft.markPhotoPaths.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: draft.markPhotoPaths.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final path = draft.markPhotoPaths[index];
                return _attachmentThumb(
                  path,
                  onRemove: () {
                    setState(() => draft.markPhotoPaths.removeAt(index));
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAttachmentsSection(
    AppStrings s,
    _StudentGradeDraft draft,
    String studentName,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          s.announcementAttachments,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _pickAttachments(draft, studentName),
          icon: const Icon(Icons.attach_file, size: 18),
          label: Text(s.announcementAddAttachment),
        ),
        if (draft.attachmentPaths.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: draft.attachmentPaths.map((path) {
              final name =
                  FileAttachmentShareService.instance.displayName(path);
              return InputChip(
                avatar: Icon(
                  attachmentPathIsImage(path)
                      ? Icons.image_outlined
                      : Icons.insert_drive_file_outlined,
                  size: 16,
                ),
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(name, overflow: TextOverflow.ellipsis),
                ),
                onDeleted: () {
                  setState(() {
                    draft.attachmentPaths.remove(path);
                  });
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildSubjectPicker(AppStrings s, List<String> subjects) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.chooseSubjectYouTeach,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: TeacherTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: subjects.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final subject = subjects[index];
                final selected = subject == _selectedSubject;
                return FilterChip(
                  label: Text(
                    subject,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  selected: selected,
                  showCheckmark: true,
                  selectedColor:
                      TeacherTheme.primaryDark.withValues(alpha: 0.14),
                  checkmarkColor: TeacherTheme.primaryDark,
                  onSelected: (_) {
                    setState(() {
                      _selectedSubject = subject;
                      _loadDraftsForSubject();
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentRow(AppStrings s, String name) {
    final draft = _draftFor(name);
    final fileCount = draft.attachmentCount;
    final expanded = _expandedStudents.contains(name);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                if (fileCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Badge(
                      label: Text('$fileCount'),
                      child: Icon(
                        Icons.attach_file,
                        size: 18,
                        color: TeacherTheme.primaryDark,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                if (_categories.isEmpty)
                  SizedBox(
                    width: 56,
                    child: TextField(
                      controller: draft.scoreController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15),
                      decoration: _compactScoreDecoration(s),
                    ),
                  )
                else
                  Text(
                    _draftFinalLabel(draft),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
              ],
            ),
          ),
          if (_categories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final cat in _categories)
                    SizedBox(
                      width: 88,
                      child: TextField(
                        controller: draft.categoryController(cat.id),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: '${cat.label} ${cat.weightPercent.toStringAsFixed(0)}%',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: s.addMarkPhotos,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 22),
                  color: TeacherTheme.primaryDark,
                  onPressed: () => _pickMarkPhotos(draft, name),
                ),
                IconButton(
                  tooltip: s.announcementAddAttachment,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.attach_file, size: 22),
                  color: TeacherTheme.primaryDark,
                  onPressed: () => _pickAttachments(draft, name),
                ),
                IconButton(
                  tooltip: expanded ? 'Hide details' : 'Show comment & files',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                  ),
                  onPressed: () {
                    setState(() {
                      if (expanded) {
                        _expandedStudents.remove(name);
                      } else {
                        _expandedStudents.add(name);
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: draft.commentController,
                    maxLines: 2,
                    decoration: adminFieldDecoration(
                      label: s.commentLabel,
                      icon: Icons.comment_outlined,
                      accent: TeacherTheme.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMarkPhotosSection(s, draft, name),
                  const SizedBox(height: 12),
                  _buildAttachmentsSection(s, draft, name),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final subjects = _subjects;
        final students = _studentNames;

        return Scaffold(
          backgroundColor: const Color(0xFFCFDBEA),
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            backgroundColor: TeacherTheme.primaryDark,
            foregroundColor: Colors.white,
            title: Text(s.enterClassGrades),
          ),
          body: WarmScreenBody(
            accentColor: TeacherTheme.primaryDark,
            child: subjects.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        s.noSubjectsAssigned,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: ListView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: listPagePadding(context),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.className,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                      color: TeacherTheme.primaryDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    s.gradesVisibleToParentsHint,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 13,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildSubjectPicker(s, subjects),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                              child: _requireApproval
                                  ? ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(
                                        Icons.fact_check_outlined,
                                        color: TeacherTheme.primaryDark,
                                      ),
                                      title: const Text(
                                        'Grades will be submitted for admin approval',
                                      ),
                                      subtitle: const Text(
                                        'After saving, they appear in the admin Grade approvals queue.',
                                      ),
                                    )
                                  : SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      value: _submitForApproval,
                                      activeThumbColor: TeacherTheme.primaryDark,
                                      title: Text(s.publishGradesToParents),
                                      subtitle: Text(s.publishGradesToParentsHint),
                                      onChanged: (value) => setState(
                                        () => _submitForApproval = value,
                                      ),
                                    ),
                            ),
                            if (students.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text(s.noStudentsInClass),
                                ),
                              )
                            else
                              ...students.expand(
                                (name) => [
                                  _buildStudentRow(s, name),
                                  const SizedBox(height: 10),
                                ],
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          8 + MediaQuery.viewInsetsOf(context).bottom,
                        ),
                        child: adminPrimaryButton(
                          label: s.saveGrades,
                          color: TeacherTheme.primaryDark,
                          loading: _saving,
                          onPressed: _saving ? null : _save,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
