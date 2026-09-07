import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/announcement_attachment_service.dart';
import 'package:mayabela/widgets/homework_attachments_panel.dart';

/// Shared file picker for lesson plans, curriculum units, exams, and gallery.
class CourseAttachmentPicker extends StatefulWidget {
  const CourseAttachmentPicker({
    super.key,
    required this.paths,
    required this.subdir,
    this.onChanged,
    this.canEdit = true,
    this.allowShareDownload = false,
    this.sectionTitle,
  });

  final List<String> paths;
  final String subdir;
  final ValueChanged<List<String>>? onChanged;
  final bool canEdit;
  final bool allowShareDownload;
  final String? sectionTitle;

  @override
  State<CourseAttachmentPicker> createState() => _CourseAttachmentPickerState();
}

class _CourseAttachmentPickerState extends State<CourseAttachmentPicker> {
  var _picking = false;

  Future<void> _add() async {
    final onChanged = widget.onChanged;
    if (onChanged == null || _picking) return;
    setState(() => _picking = true);
    try {
      final picked = await AnnouncementAttachmentService.instance
          .pickAndSaveFiles(subdir: widget.subdir);
      if (!mounted) return;
      if (picked.isEmpty) return;
      onChanged([...widget.paths, ...picked.map((a) => a.filePath)]);
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
        if (widget.canEdit)
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
          if (widget.canEdit) const SizedBox(height: 8),
          HomeworkAttachmentsPanel(
            attachmentPaths: widget.paths,
            sectionTitle: widget.sectionTitle ?? s.announcementAttachments,
            allowShareDownload: widget.allowShareDownload,
            onRemovePath: widget.canEdit && widget.onChanged != null
                ? (path) => widget.onChanged!([...widget.paths]..remove(path))
                : null,
          ),
        ],
      ],
    );
  }
}
