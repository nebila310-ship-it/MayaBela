import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/material_purchase_models.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/announcement_attachment_service.dart';
import 'package:mayabela/services/material_access_service.dart';
import 'package:mayabela/services/material_purchase_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_content_sync_service.dart';
import 'package:mayabela/services/student_portal_sync_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/theme/teacher_theme.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/admin_edit_dialog.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';
import 'package:mayabela/widgets/class_picker_bar.dart';
import 'package:mayabela/widgets/homework_attachments_panel.dart';
import 'package:mayabela/widgets/material_access_dialog.dart';
import 'package:mayabela/widgets/material_payment_sheet.dart';
import 'package:mayabela/widgets/material_purchase_queue_panel.dart';

enum LearningMaterialsViewMode { teacher, parent, student }

class LearningMaterialsScreen extends StatefulWidget {
  const LearningMaterialsScreen({
    super.key,
    this.mode = LearningMaterialsViewMode.teacher,
    this.initialClass,
  });

  final LearningMaterialsViewMode mode;
  final String? initialClass;

  @override
  State<LearningMaterialsScreen> createState() =>
      _LearningMaterialsScreenState();
}

class _LearningMaterialsScreenState extends State<LearningMaterialsScreen> {
  final _data = SchoolDataService.instance;
  final _access = TeacherAccessService.instance;
  final _materialAccess = MaterialAccessService.instance;
  final _purchases = MaterialPurchaseService.instance;
  String? _selectedClass;

  bool get _isReadOnly =>
      widget.mode == LearningMaterialsViewMode.parent ||
      widget.mode == LearningMaterialsViewMode.student;

  List<String> get _viewerStudentIds => _data
      .getChildren()
      .map((child) => child.studentId)
      .whereType<String>()
      .toList();

  List<String> get _classOptions {
    if (_isReadOnly) {
      return _data
          .getChildren()
          .map((child) => child.className)
          .toSet()
          .toList();
    }
    return _access.myClasses.map((assignment) => assignment.className).toList();
  }

  List<LearningMaterialItem> get _items {
    if (_isReadOnly) {
      final className = _selectedClass;
      if (className != null) {
        return _data.getLearningMaterialsForClass(className);
      }
      return _data.getLearningMaterialsForParent();
    }
    final className = _selectedClass ?? _classOptions.firstOrNull;
    if (className == null) return [];
    return _data.getLearningMaterialsForClass(className);
  }

  @override
  void initState() {
    super.initState();
    if (_classOptions.isNotEmpty) {
      _selectedClass = widget.initialClass ?? _classOptions.first;
    }
    unawaited(_materialAccess.ensureLoaded());
    unawaited(_purchases.load());
  }

  String? _studentIdForMaterial(LearningMaterialItem item) {
    final ids = _viewerStudentIds.map((e) => e.toUpperCase()).toList();
    if (ids.isEmpty) return null;
    if (ids.length == 1) return ids.first;
    for (final child in _data.getChildren()) {
      final sid = child.studentId?.trim().toUpperCase();
      if (sid == null || !ids.contains(sid)) continue;
      if (child.className == item.className) return sid;
    }
    return ids.first;
  }

  Future<void> _requestUnlock(LearningMaterialItem item) async {
    final sid = _studentIdForMaterial(item);
    if (sid == null) return;
    final err = await _purchases.requestByStudent(
      material: item,
      studentId: sid,
    );
    if (!mounted) return;
    final s = AppLocale.instance.strings;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? s.bookRequestSentToast)),
    );
  }

  Future<void> _parentBuy(LearningMaterialItem item) async {
    final sid = _studentIdForMaterial(item);
    if (sid == null) return;
    final err = await _purchases.startParentDirectPurchase(
      material: item,
      studentId: sid,
    );
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    final req = _purchases.findOpenFor(materialId: item.id, studentId: sid);
    if (req == null) return;
    await showMaterialPaymentSheet(context: context, request: req);
  }

  Future<void> _showMaterialDialog({
    required String className,
    LearningMaterialItem? existing,
  }) async {
    final s = AppLocale.instance.strings;
    final subjects = _access.teachableSubjects(className);
    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.noSubjectsAssigned)),
      );
      return;
    }

    final bookController =
        TextEditingController(text: existing?.bookName ?? '');
    final materialController =
        TextEditingController(text: existing?.materialName ?? '');
    final priceController = TextEditingController(
      text: existing?.price?.toStringAsFixed(0) ?? '',
    );
    var subject = existing?.subject ??
        _access.defaultHomeworkSubject(className) ??
        subjects.first;
    var isFree = existing?.isFree ?? true;
    String? filePath = existing?.filePath;

    final saved = await showAdminFormDialog(
      context: context,
      title: existing == null ? s.addLearningMaterial : s.editLearningMaterial,
      subtitle: className,
      accent: const Color(0xFF4527A0),
      icon: Icons.menu_book_outlined,
      saveLabel: existing == null ? s.upload : s.save,
      builder: (context, setDialogState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          adminDialogField(
            DropdownButtonFormField<String>(
              key: ValueKey(subject),
              initialValue: subject,
              decoration: adminFieldDecoration(
                label: s.chooseSubjectYouTeach,
                icon: Icons.menu_book_outlined,
                accent: const Color(0xFF4527A0),
              ),
              items: subjects
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(item),
                    ),
                  )
                  .toList(),
              onChanged: existing == null
                  ? (value) {
                      if (value != null) {
                        setDialogState(() => subject = value);
                      }
                    }
                  : null,
            ),
          ),
          adminDialogField(
            TextField(
              controller: bookController,
              decoration: adminFieldDecoration(
                label: s.bookNameLabel,
                icon: Icons.auto_stories_outlined,
                accent: const Color(0xFF4527A0),
              ),
            ),
          ),
          adminDialogField(
            TextField(
              controller: materialController,
              decoration: adminFieldDecoration(
                label: s.materialNameLabel,
                icon: Icons.description_outlined,
                accent: const Color(0xFF4527A0),
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: !isFree,
            title: Text(
              s.paidMaterialToggle,
              style: const TextStyle(fontSize: 14),
            ),
            onChanged: (value) => setDialogState(() => isFree = !value),
          ),
          if (!isFree)
            adminDialogField(
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: adminFieldDecoration(
                  label: s.priceEtbLabel,
                  icon: Icons.payments_outlined,
                  accent: const Color(0xFF4527A0),
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await AnnouncementAttachmentService.instance
                  .pickAndSaveFiles(subdir: 'learning_materials');
              if (picked.isEmpty) return;
              setDialogState(() => filePath = picked.first.filePath);
            },
            icon: const Icon(Icons.attach_file),
            label: Text(
              filePath == null ? s.pickLearningMaterialFile : s.replaceFile,
            ),
          ),
          if (filePath != null) ...[
            const SizedBox(height: 8),
            InputChip(
              label: Text(
                filePath!.split(Platform.pathSeparator).last,
                overflow: TextOverflow.ellipsis,
              ),
              onDeleted: () => setDialogState(() => filePath = null),
            ),
          ],
        ],
      ),
    );

    if (saved == true) {
      final bookName = bookController.text.trim();
      final materialName = materialController.text.trim();
      final price = double.tryParse(priceController.text.trim());
      if (bookName.isEmpty || materialName.isEmpty) {
        bookController.dispose();
        materialController.dispose();
        priceController.dispose();
        return;
      }
      if (filePath == null || filePath!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.pickLearningMaterialFile)),
          );
        }
        bookController.dispose();
        materialController.dispose();
        priceController.dispose();
        return;
      }

      if (existing == null) {
        final slot = _access.teachingSlotFor(className, subject);
        _data.addLearningMaterial(
          className: className,
          subject: subject,
          bookName: bookName,
          materialName: materialName,
          filePath: filePath!,
          teacherName: _access.teacherName,
          teacherId: _access.teacherId,
          subjectId: slot?.subjectId,
          teachingSlotId: slot?.slotId,
          isFree: isFree,
          price: price,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(s.learningMaterialUploaded),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        _data.updateLearningMaterial(
          id: existing.id,
          bookName: bookName,
          materialName: materialName,
          filePath: filePath,
          isFree: isFree,
          price: price,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(s.learningMaterialUpdated),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      setState(() {});
    }

    bookController.dispose();
    materialController.dispose();
    priceController.dispose();
  }

  Future<void> _confirmDelete(LearningMaterialItem item) async {
    final s = AppLocale.instance.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.deleteLearningMaterial),
        content: Text(s.deleteLearningMaterialConfirm(item.bookName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _data.deleteLearningMaterial(item.id);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.learningMaterialDeleted)),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final suffix = time.hour >= 12 ? 'PM' : 'AM';
    return '${time.day}/${time.month}/${time.year} · $hour:${time.minute.toString().padLeft(2, '0')} $suffix';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppLocale.instance,
        SchoolContentSyncService.instance,
        MaterialAccessService.instance,
        MaterialPurchaseService.instance,
        if (widget.mode == LearningMaterialsViewMode.student)
          StudentPortalSyncService.instance,
      ]),
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final className = _selectedClass;
        final canUpload = !_isReadOnly &&
            className != null &&
            _access.canAddLearningMaterial(className);

        final accent = _isReadOnly
            ? const Color(0xFF00695C)
            : TeacherTheme.primaryDark;

        return Scaffold(
          backgroundColor: const Color(0xFFCFDBEA),
          appBar: AppBar(
            backgroundColor: accent,
            title: Text(s.booksAndLearningMaterialTitle),
          ),
          floatingActionButton: canUpload
              ? FloatingActionButton.extended(
                  onPressed: () => _showMaterialDialog(className: className),
                  icon: const Icon(Icons.upload_file),
                  label: Text(s.addLearningMaterial),
                  backgroundColor: accent,
                )
              : null,
          body: WarmScreenBody(
            accentColor: accent,
            child: Column(
              children: [
                if (_classOptions.isNotEmpty)
                  ClassPickerBar(
                    label: s.className,
                    options: _classOptions,
                    selected: _selectedClass,
                    accent: accent,
                    onSelected: (value) => setState(() => _selectedClass = value),
                  )
                else if (!_isReadOnly)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          s.noClassesAssigned,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: _classOptions.isEmpty && !_isReadOnly
                      ? const SizedBox.shrink()
                      : ListView(
                              padding: listPagePadding(context),
                              children: [
                                if (widget.mode ==
                                    LearningMaterialsViewMode.parent) ...[
                                  const MaterialPurchaseQueuePanel(
                                    mode: MaterialPurchaseQueueMode
                                        .parentApprovals,
                                  ),
                                  const MaterialPurchaseQueuePanel(
                                    mode: MaterialPurchaseQueueMode.parentPay,
                                  ),
                                ],
                                if (!_isReadOnly)
                                  const MaterialPurchaseQueuePanel(
                                    mode: MaterialPurchaseQueueMode
                                        .adminConfirm,
                                  ),
                                if (_items.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Center(
                                      child: Text(s.noLearningMaterials),
                                    ),
                                  )
                                else
                                  ..._items.map((item) {
                                final canEdit = !_isReadOnly &&
                                    _access.canEditLearningMaterial(item);
                                final unlocked = !_isReadOnly ||
                                    _materialAccess.hasAccess(
                                      item,
                                      studentIds: _viewerStudentIds,
                                    );
                                final openReq = () {
                                  final sid = _studentIdForMaterial(item);
                                  if (sid == null) return null;
                                  return _purchases.findOpenFor(
                                    materialId: item.id,
                                    studentId: sid,
                                  );
                                }();
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.bookName,
                                                    style: const TextStyle(
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    item.materialName,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      color:
                                                          Colors.grey.shade800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (canEdit)
                                              PopupMenuButton<String>(
                                                onSelected: (value) {
                                                  if (value == 'edit') {
                                                    _showMaterialDialog(
                                                      className: item.className,
                                                      existing: item,
                                                    );
                                                  } else if (value ==
                                                      'access') {
                                                    showMaterialAccessDialog(
                                                      context: context,
                                                      material: item,
                                                      accent: accent,
                                                    );
                                                  } else if (value ==
                                                      'delete') {
                                                    _confirmDelete(item);
                                                  }
                                                },
                                                itemBuilder: (context) => [
                                                  PopupMenuItem(
                                                    value: 'edit',
                                                    child: Text(s.edit),
                                                  ),
                                                  if (!item.isFree)
                                                    PopupMenuItem(
                                                      value: 'access',
                                                      child:
                                                          Text(s.manageAccess),
                                                    ),
                                                  PopupMenuItem(
                                                    value: 'delete',
                                                    child: Text(s.delete),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            if (item.subject.isNotEmpty)
                                              Chip(
                                                label: Text(item.subject),
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                            Chip(
                                              label: Text(item.className),
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                            Chip(
                                              avatar: Icon(
                                                item.isFree
                                                    ? Icons.lock_open
                                                    : Icons.lock_outline,
                                                size: 16,
                                                color: item.isFree
                                                    ? Colors.green.shade800
                                                    : Colors.orange.shade900,
                                              ),
                                              label: Text(
                                                item.isFree
                                                    ? s.freeBadge
                                                    : item.price != null
                                                        ? '${s.paidBadge} · ${item.price!.toStringAsFixed(0)} ETB'
                                                        : s.paidBadge,
                                              ),
                                              backgroundColor: item.isFree
                                                  ? Colors.green.shade50
                                                  : Colors.orange.shade50,
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          ],
                                        ),
                                        if (unlocked &&
                                            !item.isFree &&
                                            _isReadOnly) ...[
                                          const SizedBox(height: 10),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.green.shade200,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.lock_open,
                                                  color: Colors.green.shade800,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        s.bookUnlockedTitle,
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Colors
                                                              .green.shade900,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                          height: 2),
                                                      Text(
                                                        s.bookReleasedHint,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: Colors
                                                              .grey.shade800,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        if (item.filePath.isNotEmpty &&
                                            unlocked) ...[
                                          const SizedBox(height: 10),
                                          HomeworkAttachmentsPanel(
                                            attachmentPaths: [item.filePath],
                                            compact: _isReadOnly,
                                            allowShareDownload: true,
                                            sectionTitle: s.learningMaterialFile,
                                          ),
                                        ] else if (!unlocked) ...[
                                          const SizedBox(height: 10),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.orange.shade200,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.lock_outline,
                                                  color:
                                                      Colors.orange.shade900,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        s.lockedMaterialTitle,
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Colors
                                                              .orange.shade900,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                          height: 2),
                                                      Text(
                                                        openReq != null
                                                            ? _statusHint(
                                                                s, openReq)
                                                            : s.lockedMaterialHint,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: Colors
                                                              .grey.shade800,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (_isReadOnly) ...[
                                            const SizedBox(height: 10),
                                            if (widget.mode ==
                                                    LearningMaterialsViewMode
                                                        .student &&
                                                openReq == null)
                                              Align(
                                                alignment:
                                                    Alignment.centerLeft,
                                                child: FilledButton.tonal(
                                                  onPressed: () =>
                                                      _requestUnlock(item),
                                                  child: Text(
                                                    s.requestBookUnlock,
                                                  ),
                                                ),
                                              )
                                            else if (widget.mode ==
                                                LearningMaterialsViewMode
                                                    .parent)
                                              Align(
                                                alignment:
                                                    Alignment.centerLeft,
                                                child: FilledButton.tonal(
                                                  onPressed: openReq?.status ==
                                                          MaterialPurchaseStatus
                                                              .awaitingPayment
                                                      ? () =>
                                                          showMaterialPaymentSheet(
                                                            context: context,
                                                            request: openReq!,
                                                          )
                                                      : openReq == null
                                                          ? () =>
                                                              _parentBuy(item)
                                                          : null,
                                                  child: Text(
                                                    openReq?.status ==
                                                            MaterialPurchaseStatus
                                                                .awaitingPayment
                                                        ? s.payNow
                                                        : openReq?.status ==
                                                                MaterialPurchaseStatus
                                                                    .paymentSubmitted
                                                            ? s.paymentSubmittedStatus
                                                            : openReq == null
                                                                ? s.buyBookUnlock
                                                                : s.bookRequestPendingStatus,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ],
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            const Icon(Icons.person, size: 16),
                                            const SizedBox(width: 4),
                                            Text(
                                              item.teacherName,
                                              style:
                                                  const TextStyle(fontSize: 13),
                                            ),
                                            const Spacer(),
                                            Text(
                                              _formatTime(item.postedAt),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  ),
                                );
                                  }),
                              ],
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _statusHint(AppStrings s, MaterialPurchaseRequest req) {
    return switch (req.status) {
      MaterialPurchaseStatus.pendingParentApproval => s.awaitingParentApproval,
      MaterialPurchaseStatus.awaitingPayment => s.awaitingPayment,
      MaterialPurchaseStatus.paymentSubmitted => s.paymentSubmittedStatus,
      _ => s.bookRequestPendingStatus,
    };
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
