import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/grade_workflow.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/grade_workflow_service.dart';
import 'package:mayabela/services/school_content_sync_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/admin_edit_dialog.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';

class GradeApprovalQueueScreen extends StatefulWidget {
  const GradeApprovalQueueScreen({super.key});

  @override
  State<GradeApprovalQueueScreen> createState() =>
      _GradeApprovalQueueScreenState();
}

class _GradeApprovalQueueScreenState extends State<GradeApprovalQueueScreen> {
  final _data = SchoolDataService.instance;

  List<SubjectGradePendingItem> get _items =>
      _data.adminGradeReviewItems(schoolId: AuthService.activeSchoolId);

  String _teacherName(SubjectGradePendingItem item) {
    final teacherId = item.subjectGrade.submittedByTeacherId ??
        item.subjectGrade.enteredByTeacherId;
    if (teacherId == null || teacherId.isEmpty) return 'Teacher';
    return TeacherRegistryService.instance.lookupById(teacherId)?.fullName ??
        teacherId;
  }

  Color _statusColor(SubjectGradeStatus status) {
    return switch (status) {
      SubjectGradeStatus.pendingApproval => Colors.orange.shade100,
      SubjectGradeStatus.approved => Colors.green.shade100,
      SubjectGradeStatus.rejected => Colors.red.shade100,
      SubjectGradeStatus.changesRequested => Colors.blue.shade100,
      SubjectGradeStatus.draft => Colors.grey.shade100,
    };
  }

  Color _statusTextColor(SubjectGradeStatus status) {
    return switch (status) {
      SubjectGradeStatus.pendingApproval => Colors.orange.shade900,
      SubjectGradeStatus.approved => Colors.green.shade900,
      SubjectGradeStatus.rejected => Colors.red.shade900,
      SubjectGradeStatus.changesRequested => Colors.blue.shade900,
      SubjectGradeStatus.draft => Colors.grey.shade800,
    };
  }

  Future<void> _review(
    SubjectGradePendingItem item, {
    required _ApprovalAction action,
  }) async {
    final s = AppLocale.instance.strings;
    final commentController = TextEditingController();
    final saved = await showAdminFormDialog(
      context: context,
      title: switch (action) {
        _ApprovalAction.approve => s.approveGrades,
        _ApprovalAction.reject => s.rejectGrades,
        _ApprovalAction.adjustment => s.requestGradeAdjustment,
      },
      subtitle: '${item.report.studentName} · ${item.subject}',
      accent: const Color(0xFF4527A0),
      icon: Icons.fact_check_outlined,
      canSave: (_) => action == _ApprovalAction.approve
          ? true
          : commentController.text.trim().isNotEmpty,
      builder: (context, setDialogState) => adminDialogField(
        TextField(
          controller: commentController,
          onChanged: (_) => setDialogState(() {}),
          maxLines: 4,
          decoration: adminFieldDecoration(
            label: switch (action) {
              _ApprovalAction.approve => s.approvalCommentOptional,
              _ApprovalAction.reject => s.rejectionReasonRequired,
              _ApprovalAction.adjustment => s.adjustmentReasonRequired,
            },
            icon: Icons.comment_outlined,
            accent: const Color(0xFF4527A0),
          ),
        ),
      ),
    );
    if (saved != true || !mounted) {
      commentController.dispose();
      return;
    }

    final user = AuthService.currentUser;
    final comment = commentController.text.trim();
    commentController.dispose();
    bool ok = false;
    switch (action) {
      case _ApprovalAction.approve:
        ok = _data.approveSubjectGrade(
          studentName: item.report.studentName,
          className: item.report.className,
          subject: item.subject,
          reviewerId: user?.linkedTeacherId ?? user?.username,
          reviewerName: AuthService.displayNameForRole(user?.roleKey ?? ''),
          reviewerRole: user?.roleKey,
          comment: comment.isEmpty ? null : comment,
        );
      case _ApprovalAction.reject:
        ok = _data.rejectSubjectGrade(
          studentName: item.report.studentName,
          className: item.report.className,
          subject: item.subject,
          reason: comment,
          reviewerId: user?.linkedTeacherId ?? user?.username,
          reviewerName: AuthService.displayNameForRole(user?.roleKey ?? ''),
          reviewerRole: user?.roleKey,
        );
      case _ApprovalAction.adjustment:
        ok = _data.requestSubjectGradeChanges(
          studentName: item.report.studentName,
          className: item.report.className,
          subject: item.subject,
          comment: comment,
          reviewerId: user?.linkedTeacherId ?? user?.username,
          reviewerName: AuthService.displayNameForRole(user?.roleKey ?? ''),
          reviewerRole: user?.roleKey,
        );
    }

    if (!mounted) return;
    setState(() {});
    SchoolContentSyncService.instance.markDataChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? s.gradeApprovalActionSuccess(action.name) : s.gradeApprovalActionFailed,
        ),
        backgroundColor: ok ? Colors.green : Colors.orange.shade800,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SchoolContentSyncService.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        const accent = Color(0xFF4527A0);
        final items = _items;

        return Scaffold(
          backgroundColor: const Color(0xFFF3E5F5),
          appBar: AppBar(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            title: Text(s.gradeApprovalsTitle),
          ),
          body: items.isEmpty
              ? Center(child: Text(s.noGradeApprovalsPending))
              : ListView.separated(
                  padding: listPagePadding(context),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final grade = item.subjectGrade;
                    final status = grade.status;
                    final statusLabel =
                        GradeWorkflowService.statusLabel(status);
                    final canAct = status == SubjectGradeStatus.pendingApproval &&
                        GradeWorkflowService.canUserApprove(
                          grade: grade,
                          className: item.report.className,
                          schoolId: AuthService.activeSchoolId,
                        );

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.report.studentName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item.report.className} · ${item.subject}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      color: _statusTextColor(status),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: _statusColor(status),
                                  side: BorderSide.none,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              s.gradeApprovalScoreLine(
                                grade.score.toInt(),
                                grade.maxScore.toInt(),
                                grade.letterGrade,
                              ),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              s.submittedByTeacher(_teacherName(item)),
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                            if (grade.lastReviewedBy?.trim().isNotEmpty ==
                                    true &&
                                status != SubjectGradeStatus.pendingApproval) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Reviewed by ${grade.lastReviewedBy}',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            if (grade.comment?.trim().isNotEmpty == true) ...[
                              const SizedBox(height: 8),
                              Text(
                                s.gradeTeacherNoteLine(grade.comment!.trim()),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                            if (grade.reviewComment?.trim().isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Admin note: ${grade.reviewComment!.trim()}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade800,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                            if (canAct) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.icon(
                                    onPressed: () => _review(
                                      item,
                                      action: _ApprovalAction.approve,
                                    ),
                                    icon: const Icon(Icons.check),
                                    label: Text(s.approveGrades),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _review(
                                      item,
                                      action: _ApprovalAction.reject,
                                    ),
                                    icon: const Icon(Icons.close),
                                    label: Text(s.rejectGrades),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _review(
                                      item,
                                      action: _ApprovalAction.adjustment,
                                    ),
                                    icon: const Icon(Icons.edit_note),
                                    label: Text(s.requestGradeAdjustment),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

enum _ApprovalAction { approve, reject, adjustment }

extension on _ApprovalAction {
  String get name => switch (this) {
        _ApprovalAction.approve => 'approve',
        _ApprovalAction.reject => 'reject',
        _ApprovalAction.adjustment => 'adjustment',
      };
}
