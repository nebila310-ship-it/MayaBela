import 'package:flutter/material.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/screens/homeroom_student_profile_screen.dart';
import 'package:mayabela/screens/teacher_enter_grades_screen.dart';
import 'package:mayabela/services/announcement_attachment_service.dart';
import 'package:mayabela/services/file_attachment_share_service.dart';
import 'package:mayabela/services/grade_analytics_service.dart';
import 'package:mayabela/services/grade_mark_photo_service.dart';
import 'package:mayabela/services/grade_report_export_service.dart';
import 'package:mayabela/models/grade_workflow.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/grade_workflow_service.dart';
import 'package:mayabela/services/persistence/cloud_save_honesty.dart';
import 'package:mayabela/services/persistence/grade_persistence_service.dart';
import 'package:mayabela/services/school_content_sync_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/theme/teacher_theme.dart';
import 'package:mayabela/utils/attachment_path_utils.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/grade_attachments_panel.dart';
import 'package:mayabela/widgets/class_rankings_list.dart';
import 'package:mayabela/widgets/class_picker_bar.dart';
import 'package:mayabela/widgets/admin_edit_dialog.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';
import 'package:mayabela/widgets/platform_path_image.dart';
import 'package:mayabela/widgets/term_report_card_view.dart';
import 'package:mayabela/services/school_registry_service.dart';

enum GradeReportView { teacher, parent, student, admin }

const _gradeTeacherAccent = TeacherTheme.primaryDark;
const _gradeHomeroomAccent = TeacherTheme.homeroomAccent;

class GradeReportsScreen extends StatefulWidget {
  const GradeReportsScreen({
    super.key,
    required this.view,
    this.initialClass,
    this.initialStudentName,
  });

  final GradeReportView view;
  final String? initialClass;
  final String? initialStudentName;

  @override
  State<GradeReportsScreen> createState() => _GradeReportsScreenState();
}

class _GradeReportsScreenState extends State<GradeReportsScreen>
    with SingleTickerProviderStateMixin {
  final _data = SchoolDataService.instance;
  final _access = TeacherAccessService.instance;
  final _analytics = GradeAnalyticsService.instance;
  TabController? _homeroomTabs;
  String? _selectedClass;
  String? _selectedStudent;

  List<StudentGradeReport> get _reports {
    switch (widget.view) {
      case GradeReportView.parent:
      case GradeReportView.student:
        var reports = _data.getGradeReportsForParent();
        final classFilter = _selectedClass ?? widget.initialClass;
        if (classFilter != null && classFilter.isNotEmpty) {
          reports =
              reports
                  .where(
                    (r) => StudentRegistryService.classNamesMatch(
                      r.className,
                      classFilter,
                    ),
                  )
                  .toList();
        }
        final studentFilter = widget.initialStudentName;
        if (studentFilter != null && studentFilter.isNotEmpty) {
          reports =
              reports.where((r) => r.studentName == studentFilter).toList();
        }
        return reports;
      case GradeReportView.admin:
        return _data.getAllGradeReports();
      case GradeReportView.teacher:
        final className = _selectedClass ?? _classOptions.firstOrNull;
        if (className == null) return [];
        return _data.getGradeReportsForClass(className);
    }
  }

  bool get _isStudentPortalView =>
      widget.view == GradeReportView.parent ||
      widget.view == GradeReportView.student;

  List<String> get _classOptions {
    if (_isStudentPortalView) {
      return _data
          .getChildren()
          .map((child) => child.className)
          .toSet()
          .toList();
    }
    return _access.myClasses.map((assignment) => assignment.className).toList();
  }

  bool get _canEnterClassGrades {
    if (widget.view != GradeReportView.teacher) return false;
    final className = _selectedClass;
    if (className == null || className.isEmpty) return false;
    return _access.teachableSubjects(className).isNotEmpty;
  }

  Future<void> _openBulkGradeEntry(String className) async {
    final subjects = _access.teachableSubjects(className);
    if (subjects.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocale.instance.strings.noSubjectsAssigned)),
      );
      return;
    }

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherEnterGradesScreen(className: className),
      ),
    );
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _submitGradeForApproval(
    SubjectGrade subject,
    StudentGradeReport report,
  ) async {
    final s = AppLocale.instance.strings;
    if (!_access.canEditSubject(
      report.className,
      subject.subject,
      enteredByTeacherId: subject.enteredByTeacherId,
    )) {
      return;
    }
    if (!subject.canTeacherEdit) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            subject.reviewComment?.trim().isNotEmpty == true
                ? subject.reviewComment!.trim()
                : 'This grade is locked pending approval.',
          ),
        ),
      );
      return;
    }

    final requireApproval =
        GradeWorkflowService.requireApproval(AuthService.activeSchoolId);
    final ok = requireApproval
        ? _data.submitSubjectGradeForApproval(
            studentName: report.studentName,
            className: report.className,
            subject: subject.subject,
            teacherId: _access.teacherId,
          )
        : _data.publishSubjectGrade(
            studentName: report.studentName,
            className: report.className,
            subject: subject.subject,
            teacherId: _access.teacherId,
          );
    if (!mounted) return;
    setState(() {});
    SchoolContentSyncService.instance.markDataChanged();
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.gradePublishFailed),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }
    final outcome = await CloudSaveHonesty.settle(
      persist: GradePersistenceService.instance.saveFromService(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      CloudSaveHonesty.snackBar(
        savedOk: requireApproval
            ? 'Submitted for approval'
            : s.gradePublishedSuccess,
        outcome: outcome,
        strings: s,
      ),
    );
  }

  Future<void> _editGrade(SubjectGrade subject, StudentGradeReport report) async {
    final s = AppLocale.instance.strings;
    if (widget.view != GradeReportView.teacher) return;
    if (!_access.canEditSubject(
      report.className,
      subject.subject,
      enteredByTeacherId: subject.enteredByTeacherId,
    )) {
      return;
    }
    if (!subject.canTeacherEdit) return;

    final scoreController = TextEditingController(
      text: subject.score.toInt().toString(),
    );
    final commentController = TextEditingController(
      text: subject.comment ?? '',
    );
    var markPhotoPaths = List<String>.from(subject.markPhotoPaths);
    var attachmentPaths = List<String>.from(subject.attachmentPaths);

    final saved = await showAdminFormDialog(
      context: context,
      title: s.editSubjectTitle(subject.subject),
      accent: _gradeTeacherAccent,
      icon: Icons.grade_outlined,
      builder: (context, setDialogState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          adminDialogField(
            TextField(
              controller: scoreController,
              keyboardType: TextInputType.number,
              decoration: adminFieldDecoration(
                label: s.scoreOutOf(subject.maxScore),
                icon: Icons.numbers_rounded,
                accent: _gradeTeacherAccent,
              ),
            ),
          ),
          adminDialogField(
            TextField(
              controller: commentController,
              maxLines: 3,
              decoration: adminFieldDecoration(
                label: s.commentLabel,
                icon: Icons.comment_outlined,
                accent: _gradeTeacherAccent,
              ),
            ),
          ),
          Text(
            s.markPhotosLabel,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final picked =
                  await GradeMarkPhotoService.instance.pickFromGallery();
              if (picked.isEmpty) return;
              setDialogState(() => markPhotoPaths.addAll(picked));
            },
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(s.addMarkPhotos),
          ),
          if (markPhotoPaths.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: markPhotoPaths.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final path = markPhotoPaths[index];
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
                                      child: const Icon(
                                        Icons.insert_drive_file_outlined,
                                      ),
                                    ),
                                  )
                                : ColoredBox(
                                    color: Colors.grey.shade200,
                                    child: const Icon(
                                      Icons.insert_drive_file_outlined,
                                    ),
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
                            onPressed: () {
                              setDialogState(
                                () => markPhotoPaths.removeAt(index),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            s.announcementAttachments,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await AnnouncementAttachmentService.instance
                  .pickAndSaveFiles(subdir: 'grade_attachments');
              if (picked.isEmpty) return;
              setDialogState(
                () => attachmentPaths.addAll(picked.map((a) => a.filePath)),
              );
            },
            icon: const Icon(Icons.attach_file),
            label: Text(s.announcementAddAttachment),
          ),
          if (attachmentPaths.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: attachmentPaths.map((path) {
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
                    setDialogState(() => attachmentPaths.remove(path));
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );

    if (saved != true) {
      scoreController.dispose();
      commentController.dispose();
      return;
    }

    final score = double.tryParse(scoreController.text.trim());
    final commentText = commentController.text.trim();
    scoreController.dispose();
    commentController.dispose();
    if (score == null) return;

    _data.updateSubjectGrade(
      studentName: report.studentName,
      className: report.className,
      subject: subject.subject,
      score: score.clamp(0, subject.maxScore),
      comment: commentText.isEmpty ? null : commentText,
      markPhotoPaths: markPhotoPaths,
      attachmentPaths: attachmentPaths,
      enteredByTeacherId: _access.teacherId,
      subjectId: subject.subjectId ??
          _access.teachingSlotFor(report.className, subject.subject)?.subjectId,
      teachingSlotId: subject.teachingSlotId ??
          _access.teachingSlotFor(report.className, subject.subject)?.slotId,
    );
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    if (widget.view == GradeReportView.teacher) {
      _homeroomTabs = TabController(length: 2, vsync: this)
        ..addListener(() {
          if (mounted) setState(() {});
        });
    }
    if (_classOptions.isNotEmpty) {
      _selectedClass = widget.initialClass ?? _classOptions.first;
    }
    final reports = _reports;
    if (widget.initialStudentName != null &&
        reports.any((r) => r.studentName == widget.initialStudentName)) {
      _selectedStudent = widget.initialStudentName;
    } else if (reports.isNotEmpty) {
      _selectedStudent = reports.first.studentName;
    }
  }

  @override
  void dispose() {
    _homeroomTabs?.dispose();
    super.dispose();
  }

  Future<void> _exportClassReport(String className) async {
    final s = AppLocale.instance.strings;
    try {
      final export = await GradeReportExportService.instance.buildExcelExport(
        labels: GradeReportExportLabels.fromStrings(s),
        classNames: [className],
      );
      await GradeReportExportService.instance.shareExport(export);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.exportGradeReportSuccess),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.exportGradeReportFailed),
          backgroundColor: Colors.orange.shade800,
        ),
      );
    }
  }

  Future<void> _exportAllHomeroomReports() async {
    final s = AppLocale.instance.strings;
    final classes = _access.homeroomClassNames;
    if (classes.isEmpty) return;
    try {
      final export = await GradeReportExportService.instance.buildExcelExport(
        labels: GradeReportExportLabels.fromStrings(s),
        classNames: classes,
      );
      await GradeReportExportService.instance.shareExport(export);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.exportGradeReportSuccess),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.exportGradeReportFailed),
          backgroundColor: Colors.orange.shade800,
        ),
      );
    }
  }

  Color _gradeColor(double percentage) {
    if (percentage >= 90) return Colors.green;
    if (percentage >= 80) return Colors.lightGreen;
    if (percentage >= 70) return Colors.orange;
    return Colors.red;
  }

  Widget _buildClassPicker(AppStrings s) {
    final showTeacher = widget.view == GradeReportView.teacher &&
        _classOptions.isNotEmpty &&
        widget.initialClass == null &&
        _classOptions.length > 1;
    final showParent = _isStudentPortalView &&
        _classOptions.length > 1;

    if (!showTeacher && !showParent) {
      if (widget.view == GradeReportView.teacher &&
          _selectedClass != null &&
          widget.initialClass != null) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _gradeTeacherAccent.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.class_outlined,
                    size: 18, color: _gradeTeacherAccent),
                const SizedBox(width: 8),
                Text(
                  _selectedClass!,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _gradeTeacherAccent,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    final accent = _isStudentPortalView
        ? const Color(0xFF00695C)
        : _gradeTeacherAccent;

    return ClassPickerBar(
      label: s.className,
      options: _classOptions,
      selected: _selectedClass,
      accent: accent,
      onSelected: (value) {
        setState(() {
          _selectedClass = value;
          final updated = _reports;
          _selectedStudent =
              updated.isNotEmpty ? updated.first.studentName : null;
        });
      },
    );
  }

  Color _appBarColor({required bool homeroom}) {
    if (widget.view == GradeReportView.admin) return Colors.deepOrange;
    if (_isStudentPortalView) return const Color(0xFF00695C);
    return homeroom ? _gradeHomeroomAccent : _gradeTeacherAccent;
  }

  Widget _wrapTeacherBody(Widget child, {required bool homeroom}) {
    if (widget.view != GradeReportView.teacher &&
        widget.view != GradeReportView.parent &&
        widget.view != GradeReportView.student) {
      return child;
    }
    final accent = _isStudentPortalView
        ? const Color(0xFF00695C)
        : (homeroom ? _gradeHomeroomAccent : _gradeTeacherAccent);
    return WarmScreenBody(accentColor: accent, child: child);
  }

  List<Widget> _buildExportActions(
    AppStrings s, {
    required bool canExportHomeroom,
    required List<String> homeroomClasses,
  }) {
    if (!canExportHomeroom) return const [];
    if (homeroomClasses.length > 1) {
      return [
        PopupMenuButton<String>(
          icon: const Icon(Icons.download_outlined),
          tooltip: s.exportGradeReport,
          onSelected: (value) {
            if (value == 'all') {
              _exportAllHomeroomReports();
            } else {
              _exportClassReport(_selectedClass!);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'class',
              child: Text(s.exportCurrentClassReport),
            ),
            PopupMenuItem(
              value: 'all',
              child: Text(s.exportAllHomeroomReports),
            ),
          ],
        ),
      ];
    }
    return [
      IconButton(
        icon: const Icon(Icons.download_outlined),
        tooltip: s.exportGradeReport,
        onPressed: () => _exportClassReport(_selectedClass!),
      ),
    ];
  }

  Widget _buildGradesDetailBody(
    AppStrings s, {
    required List<StudentGradeReport> reports,
    required StudentGradeReport? activeReport,
    required bool showSubjectHint,
    required bool showHomeroomHint,
    bool hideStudentPicker = false,
  }) {
    if (reports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _isStudentPortalView
                ? s.noPublishedGradeReports
                : s.noGradeReports,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
          ),
        ),
      );
    }
    return Column(
      children: [
        if (showHomeroomHint)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              s.homeroomGradesViewOnlyHint,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ),
        if (showSubjectHint)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              s.subjectGradesOnlyHint,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ),
        if (!hideStudentPicker)
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: reports.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
              final report = reports[index];
              final selected = report.studentName == _selectedStudent;
              return Material(
                color: selected
                    ? _gradeTeacherAccent
                    : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () =>
                      setState(() => _selectedStudent = report.studentName),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: selected
                            ? _gradeTeacherAccent
                            : _gradeTeacherAccent.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      report.studentName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : _gradeTeacherAccent,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: activeReport == null
              ? const SizedBox.shrink()
              : _ReportDetail(
                  report: activeReport,
                  gradeColor: _gradeColor,
                  publishedOnly: _isStudentPortalView,
                  allowShareDownload: _isStudentPortalView,
                  filterSubjects: widget.view == GradeReportView.teacher &&
                      !_access.isHomeroomFor(activeReport.className),
                  canEditSubject: widget.view == GradeReportView.teacher
                      ? (subjectGrade) =>
                          subjectGrade.canTeacherEdit &&
                          _access.canEditSubject(
                            activeReport.className,
                            subjectGrade.subject,
                            enteredByTeacherId:
                                subjectGrade.enteredByTeacherId,
                          )
                      : null,
                  onEditSubject: widget.view == GradeReportView.teacher
                      ? (subject) => _editGrade(subject, activeReport)
                      : null,
                  onPublishSubject: widget.view == GradeReportView.teacher
                      ? (subject) =>
                          _submitGradeForApproval(subject, activeReport)
                      : null,
                ),
        ),
      ],
    );
  }

  void _openHomeroomStudent(RankedStudentReport entry) {
    final className = _selectedClass;
    if (className == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HomeroomStudentProfileScreen(
          className: className,
          entry: entry,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final reports = _reports;
    final activeReport = reports.cast<StudentGradeReport?>().firstWhere(
          (r) => r!.studentName == _selectedStudent,
          orElse: () => reports.isNotEmpty ? reports.first : null,
        );
    final showSubjectHint = widget.view == GradeReportView.teacher &&
        _selectedClass != null &&
        !_access.isHomeroomFor(_selectedClass!);
    final showHomeroomHint = widget.view == GradeReportView.teacher &&
        _selectedClass != null &&
        _access.isHomeroomFor(_selectedClass!);
    final canExportHomeroom = widget.view == GradeReportView.teacher &&
        _selectedClass != null &&
        _access.canExportGradesForClass(_selectedClass!);
    final homeroomClasses = _access.homeroomClassNames;
    final classRankings = showHomeroomHint && _selectedClass != null
        ? _analytics.rankingsForClass(_selectedClass!)
        : const <RankedStudentReport>[];
    final hideStudentPicker = _isStudentPortalView &&
        (widget.initialStudentName != null || reports.length <= 1);

    return ListenableBuilder(
      listenable: Listenable.merge([
        AppLocale.instance,
        if (widget.view == GradeReportView.teacher)
          SchoolContentSyncService.instance,
      ]),
      builder: (context, _) {
        final s = AppLocale.instance.strings;

        if (showHomeroomHint &&
            _homeroomTabs != null &&
            _selectedClass != null) {
          return Scaffold(
            backgroundColor: const Color(0xFFCFDBEA),
            appBar: AppBar(
              backgroundColor: _appBarColor(homeroom: true),
              foregroundColor: Colors.white,
              title: Text(s.gradeReports),
              actions: _buildExportActions(
                s,
                canExportHomeroom: canExportHomeroom,
                homeroomClasses: homeroomClasses,
              ),
              bottom: TabBar(
                controller: _homeroomTabs,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(
                    text: s.classRankingsTab,
                    icon: const Icon(Icons.leaderboard_outlined),
                  ),
                  Tab(
                    text: s.gradesDetailTab,
                    icon: const Icon(Icons.bar_chart_outlined),
                  ),
                ],
              ),
            ),
            floatingActionButton: _homeroomTabs!.index == 1 &&
                    _canEnterClassGrades &&
                    _selectedClass != null
                ? FloatingActionButton.extended(
                    onPressed: () => _openBulkGradeEntry(_selectedClass!),
                    icon: const Icon(Icons.edit_note),
                    label: Text(s.enterClassGrades),
                  )
                : null,
            body: _wrapTeacherBody(
              Column(
                children: [
                  _buildClassPicker(s),
                  Expanded(
                    child: _homeroomTabs!.index == 0
                        ? (classRankings.isEmpty
                            ? Center(child: Text(s.noGradeReports))
                            : ClassRankingsList(
                                className: _selectedClass!,
                                rankings: classRankings,
                                onOpenStudent: _openHomeroomStudent,
                              ))
                        : _buildGradesDetailBody(
                            s,
                            reports: reports,
                            activeReport: activeReport,
                            showSubjectHint: false,
                            showHomeroomHint: true,
                            hideStudentPicker: hideStudentPicker,
                          ),
                  ),
                ],
              ),
              homeroom: true,
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFCFDBEA),
          appBar: AppBar(
            backgroundColor: _appBarColor(homeroom: showHomeroomHint),
            foregroundColor: Colors.white,
            title: Text(s.gradeReports),
            actions: _buildExportActions(
              s,
              canExportHomeroom: canExportHomeroom,
              homeroomClasses: homeroomClasses,
            ),
          ),
          floatingActionButton: _canEnterClassGrades && _selectedClass != null
              ? FloatingActionButton.extended(
                  onPressed: () => _openBulkGradeEntry(_selectedClass!),
                  icon: const Icon(Icons.edit_note),
                  label: Text(s.enterClassGrades),
                )
              : null,
          body: _wrapTeacherBody(
            Column(
              children: [
                _buildClassPicker(s),
                if (showSubjectHint)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      s.teacherGradeReportHint,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                  ),
                if (_isStudentPortalView)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      s.parentGradeReportsHint,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                  ),
                Expanded(
                  child: _buildGradesDetailBody(
                    s,
                    reports: reports,
                    activeReport: activeReport,
                    showSubjectHint: false,
                    showHomeroomHint: false,
                    hideStudentPicker: hideStudentPicker,
                  ),
                ),
              ],
            ),
            homeroom: showHomeroomHint,
          ),
        );
      },
    );
  }
}

Color _statusColor(SubjectGradeStatus status) {
  return switch (status) {
    SubjectGradeStatus.draft => Colors.grey.shade200,
    SubjectGradeStatus.pendingApproval => Colors.orange.shade100,
    SubjectGradeStatus.changesRequested => Colors.amber.shade100,
    SubjectGradeStatus.approved => Colors.green.shade100,
    SubjectGradeStatus.rejected => Colors.red.shade100,
  };
}

class _ReportDetail extends StatelessWidget {
  const _ReportDetail({
    required this.report,
    required this.gradeColor,
    this.publishedOnly = false,
    this.allowShareDownload = false,
    this.filterSubjects = false,
    this.canEditSubject,
    this.onEditSubject,
    this.onPublishSubject,
  });

  final StudentGradeReport report;
  final Color Function(double) gradeColor;
  final bool publishedOnly;
  final bool allowShareDownload;
  final bool filterSubjects;
  final bool Function(SubjectGrade subject)? canEditSubject;
  final void Function(SubjectGrade subject)? onEditSubject;
  final void Function(SubjectGrade subject)? onPublishSubject;

  List<SubjectGrade> get _visibleSubjects {
    var subjects = report.subjects;
    if (publishedOnly) {
      subjects = subjects.where((subject) => subject.isVisibleToParent).toList();
    }
    if (!filterSubjects) return subjects;
    return subjects
        .where(
          (subject) => TeacherAccessService.instance.canViewSubjectGrade(
            report.className,
            subject.subject,
          ),
        )
        .toList();
  }

  double get _visibleAverage {
    final subjects = _visibleSubjects;
    if (subjects.isEmpty) return 0;
    return subjects.map((s) => s.percentage).reduce((a, b) => a + b) /
        subjects.length;
  }

  @override
  Widget build(BuildContext context) {
    final subjects = _visibleSubjects;
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        if (subjects.isEmpty) {
          return Center(
            child: Padding(
              padding: listPagePadding(context),
              child: Text(
                publishedOnly ? s.noPublishedGradeReports : s.noGradeReports,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
              ),
            ),
          );
        }
        return ListView(
          padding: listPagePadding(context),
          children: [
            Card(
              color: Colors.white.withValues(alpha: 0.95),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: _gradeTeacherAccent.withValues(alpha: 0.15),
                ),
              ),
                child: Padding(
                padding: const EdgeInsets.all(20),
                child: report.reportCardPublished
                    ? TermReportCardView(
                        report: report,
                        schoolName: SchoolRegistryService.instance
                            .lookup(AuthService.activeSchoolId ?? '')
                            ?.name,
                        compact: true,
                      )
                    : Column(
                  children: [
                    Text(
                      report.studentName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _gradeTeacherAccent,
                      ),
                    ),
                    Text('${report.className} · ${report.term}'),
                    const SizedBox(height: 12),
                    Text(
                      filterSubjects || publishedOnly
                          ? s.averageLabel(_visibleAverage)
                          : s.averageLabel(report.average),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: gradeColor(
                          filterSubjects || publishedOnly
                              ? _visibleAverage
                              : report.average,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'GPA ${report.gpa.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              s.subjectBreakdown,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...subjects.map((subject) {
              final editable = canEditSubject?.call(subject) ?? false;
              final published = subject.isVisibleToParent;
              final statusLabel =
                  GradeWorkflowService.statusLabel(subject.status);
              return Material(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.subject,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!publishedOnly &&
                          (subject.subjectId != null ||
                              subject.teachingSlotId != null))
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            [
                              if (subject.subjectId != null)
                                '${s.subjectIdLabel}: ${subject.subjectId}',
                              if (subject.teachingSlotId != null)
                                '${s.teachingSlotIdLabel}: ${subject.teachingSlotId}',
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (!publishedOnly)
                            Chip(
                              label: Text(statusLabel),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: _statusColor(subject.status),
                            ),
                          if (editable)
                            ActionChip(
                              avatar: const Icon(Icons.edit, size: 16),
                              label: Text(s.editGradeTooltip),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => onEditSubject?.call(subject),
                            )
                          else if (canEditSubject != null)
                            Chip(
                              label: Text(s.readOnly),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: Colors.grey.shade100,
                            ),
                          if (onPublishSubject != null && editable) ...[
                            if (!published &&
                                subject.status !=
                                    SubjectGradeStatus.pendingApproval)
                              ActionChip(
                                avatar:
                                    const Icon(Icons.send_outlined, size: 16),
                                label: Text(
                                  subject.status ==
                                              SubjectGradeStatus.rejected ||
                                          subject.status ==
                                              SubjectGradeStatus
                                                  .changesRequested
                                      ? s.gradeResubmitForApproval
                                      : GradeWorkflowService.requireApproval(
                                          AuthService.activeSchoolId,
                                        )
                                          ? s.submitGradesForApproval
                                          : s.publishToParents,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    onPublishSubject?.call(subject),
                              )
                            else if (subject.status ==
                                SubjectGradeStatus.pendingApproval)
                              Chip(
                                label: Text(s.gradePendingApprovalLabel),
                                backgroundColor: Colors.orange.shade100,
                                visualDensity: VisualDensity.compact,
                              )
                            else if (subject.status ==
                                SubjectGradeStatus.approved)
                              Chip(
                                label: Text(s.gradeApprovedLockedLabel),
                                visualDensity: VisualDensity.compact,
                                backgroundColor:
                                    Colors.green.withValues(alpha: 0.12),
                              )
                            else
                              Chip(
                                label: Text(s.gradeReportPublished),
                                visualDensity: VisualDensity.compact,
                                backgroundColor:
                                    Colors.green.withValues(alpha: 0.12),
                              ),
                          ] else if (publishedOnly && published)
                            Chip(
                              label: Text(s.gradeReportPublished),
                              visualDensity: VisualDensity.compact,
                              backgroundColor:
                                  Colors.green.withValues(alpha: 0.12),
                            )
                          else if (onPublishSubject != null &&
                              editable &&
                              !published)
                            Chip(
                              label: Text(s.gradeReportDraft),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: Colors.orange.shade50,
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: gradeColor(subject.percentage)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${subject.score.toInt()}/${subject.maxScore.toInt()} (${subject.letterGrade})',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: gradeColor(subject.percentage),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: subject.percentage / 100,
                        backgroundColor: Colors.grey.shade200,
                        color: gradeColor(subject.percentage),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      if (subject.hasMarkbook) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final mark in subject.assessments.where((m) => m.isEntered))
                              Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text(
                                  '${mark.label} ${mark.score!.toStringAsFixed(0)} (${mark.weightPercent.toStringAsFixed(0)}%)',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (!publishedOnly &&
                          (subject.status == SubjectGradeStatus.rejected ||
                              subject.status ==
                                  SubjectGradeStatus.changesRequested)) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: subject.status ==
                                    SubjectGradeStatus.rejected
                                ? Colors.red.shade50
                                : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: subject.status ==
                                      SubjectGradeStatus.rejected
                                  ? Colors.red.shade200
                                  : Colors.amber.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subject.status == SubjectGradeStatus.rejected
                                    ? s.gradeRejectedByAdmin
                                    : s.gradeReturnedForCorrection,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: subject.status ==
                                          SubjectGradeStatus.rejected
                                      ? Colors.red.shade900
                                      : Colors.amber.shade900,
                                ),
                              ),
                              if (subject.reviewComment?.trim().isNotEmpty ==
                                  true) ...[
                                const SizedBox(height: 6),
                                Text(
                                  s.adminFeedbackLabel(
                                    subject.reviewComment!.trim(),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                s.gradeResubmitHint,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (subject.comment != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          subject.comment!,
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                      if (subject.markPhotoPaths.isNotEmpty ||
                          subject.attachmentPaths.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        GradeAttachmentsPanel(
                          markPhotoPaths: subject.markPhotoPaths,
                          attachmentPaths: subject.attachmentPaths,
                          compact: true,
                          allowShareDownload: allowShareDownload,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
