import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/announcement_attachment_service.dart';
import 'package:mayabela/widgets/homework_attachments_panel.dart';

/// Shared file picker for lesson plans, curriculum units, and exam papers.
class CourseAttachmentPicker extends StatelessWidget {
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

  Future<void> _add(BuildContext context) async {
    final onChanged = this.onChanged;
    if (onChanged == null) return;
    final picked = await AnnouncementAttachmentService.instance
        .pickAndSaveFiles(subdir: subdir);
    if (picked.isEmpty) return;
    onChanged([...paths, ...picked.map((a) => a.filePath)]);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canEdit)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _add(context),
              icon: const Icon(Icons.attach_file),
              label: Text(s.announcementAddAttachment),
            ),
          ),
        if (paths.isNotEmpty) ...[
          if (canEdit) const SizedBox(height: 8),
          HomeworkAttachmentsPanel(
            attachmentPaths: paths,
            sectionTitle: sectionTitle ?? s.announcementAttachments,
            allowShareDownload: allowShareDownload,
            onRemovePath: canEdit && onChanged != null
                ? (path) => onChanged!([...paths]..remove(path))
                : null,
          ),
        ],
      ],
    );
  }
}
