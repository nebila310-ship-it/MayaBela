import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/services/announcement_attachment_service.dart';
import 'package:mayabela/utils/attachment_path_utils.dart';
import 'package:mayabela/widgets/attachment_share_actions.dart';
import 'package:mayabela/widgets/platform_path_image.dart';

/// Shows homework file/image attachments with optional parent share/download.
class HomeworkAttachmentsPanel extends StatelessWidget {
  const HomeworkAttachmentsPanel({
    super.key,
    required this.attachmentPaths,
    this.compact = false,
    this.allowShareDownload = false,
    this.sectionTitle,
    this.onRemovePath,
  });

  final List<String> attachmentPaths;
  final bool compact;
  final bool allowShareDownload;
  final String? sectionTitle;
  final ValueChanged<String>? onRemovePath;

  AnnouncementAttachment _attachmentFor(String path) {
    return AnnouncementAttachment(
      id: path,
      fileName: attachmentFileName(path),
      filePath: path,
    );
  }

  Future<void> _open(BuildContext context, String path) async {
    final s = AppLocale.instance.strings;
    final result = await AnnouncementAttachmentService.instance
        .openAttachment(_attachmentFor(path));
    if (!context.mounted) return;
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.announcementAttachmentOpenFailed)),
      );
    }
  }

  void _previewImage(BuildContext context, String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttachmentImagePreviewScreen(
          path: path,
          allowShareDownload: allowShareDownload,
          image: PlatformPathImage(
            path: path,
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }

  void _onFileTap(BuildContext context, String path) {
    if (allowShareDownload) {
      showAttachmentActionSheet(context, path: path);
      return;
    }
    _open(context, path);
  }

  @override
  Widget build(BuildContext context) {
    if (attachmentPaths.isEmpty) return const SizedBox.shrink();

    final s = AppLocale.instance.strings;
    final service = AnnouncementAttachmentService.instance;
    final images = attachmentPaths.where(attachmentPathIsImage).toList();
    final files =
        attachmentPaths.where((path) => !attachmentPathIsImage(path)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sectionTitle ?? s.announcementAttachments,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: compact ? 13 : 14,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        if (images.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: images.map((path) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: () => _previewImage(context, path),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: PlatformPathImage(
                        path: path,
                        width: compact ? 72 : 96,
                        height: compact ? 72 : 96,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  if (onRemovePath != null)
                    Positioned(
                      top: -8,
                      right: -8,
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.cancel, size: 20),
                        onPressed: () => onRemovePath!(path),
                      ),
                    ),
                ],
              );
            }).toList(),
          ),
        if (files.isNotEmpty) ...[
          if (images.isNotEmpty) const SizedBox(height: 8),
          ...files.map((path) {
            final attachment = _attachmentFor(path);
            final hint = service.iconHintForFileName(attachment.fileName);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: compact,
              leading: Icon(_iconFor(hint)),
              title: Text(
                attachment.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: onRemovePath != null
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => onRemovePath!(path),
                    )
                  : null,
              onTap: () => _onFileTap(context, path),
            );
          }),
        ],
      ],
    );
  }

  IconData _iconFor(IconHint hint) {
    return switch (hint) {
      IconHint.pdf => Icons.picture_as_pdf_outlined,
      IconHint.document => Icons.description_outlined,
      IconHint.spreadsheet => Icons.table_chart_outlined,
      IconHint.image => Icons.image_outlined,
      IconHint.video => Icons.videocam_outlined,
      IconHint.audio => Icons.audiotrack_outlined,
      IconHint.archive => Icons.folder_zip_outlined,
      IconHint.generic => Icons.attach_file,
    };
  }
}
