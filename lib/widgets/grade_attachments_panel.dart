import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/services/announcement_attachment_service.dart';
import 'package:mayabela/services/file_attachment_share_service.dart';
import 'package:mayabela/utils/attachment_path_utils.dart';
import 'package:mayabela/widgets/attachment_share_actions.dart';
import 'package:mayabela/widgets/platform_path_image.dart';

/// Read-only grade mark sheets and file attachments (parent + teacher views).
class GradeAttachmentsPanel extends StatelessWidget {
  const GradeAttachmentsPanel({
    super.key,
    required this.markPhotoPaths,
    this.attachmentPaths = const [],
    this.compact = false,
    this.allowShareDownload = false,
  });

  final List<String> markPhotoPaths;
  final List<String> attachmentPaths;
  final bool compact;
  final bool allowShareDownload;

  List<String> get _allPaths => [
        ...markPhotoPaths,
        ...attachmentPaths,
      ];

  bool _isAssetPath(String path) =>
      FileAttachmentShareService.instance.isAssetPath(path);

  String _assetKey(String path) => path.substring('asset:'.length);

  bool _isImagePath(String path) {
    if (_isAssetPath(path)) return true;
    return attachmentPathIsImage(path);
  }

  String _displayName(String path) {
    return FileAttachmentShareService.instance.displayName(path);
  }

  AnnouncementAttachment _attachmentFor(String path) {
    return AnnouncementAttachment(
      id: path,
      fileName: _displayName(path),
      filePath: path,
    );
  }

  Future<void> _openFile(BuildContext context, String path) async {
    if (_isAssetPath(path)) {
      _previewImage(context, path);
      return;
    }
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
          image: _isAssetPath(path)
              ? Image.asset(
                  _assetKey(path),
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 64,
                  ),
                )
              : PlatformPathImage(
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
    _openFile(context, path);
  }

  Widget _thumbnail(String path, {required double size}) {
    if (_isAssetPath(path)) {
      return Image.asset(
        _assetKey(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _brokenThumb(size),
      );
    }
    return PlatformPathImage(
      path: path,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _brokenThumb(size),
    );
  }

  Widget _brokenThumb(double size) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey.shade200,
      child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade500),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paths = _allPaths;
    if (paths.isEmpty) return const SizedBox.shrink();

    final s = AppLocale.instance.strings;
    final service = AnnouncementAttachmentService.instance;
    final images = paths.where(_isImagePath).toList();
    final files = paths.where((path) => !_isImagePath(path)).toList();
    final thumbSize = compact ? 72.0 : 88.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.markPhotosLabel,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: compact ? 13 : 14,
            color: Colors.grey.shade800,
          ),
        ),
        if (images.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: thumbSize,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final path = images[index];
                return InkWell(
                  onTap: () => _previewImage(context, path),
                  borderRadius: BorderRadius.circular(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _thumbnail(path, size: thumbSize),
                  ),
                );
              },
            ),
          ),
          if (allowShareDownload && images.length == 1) ...[
            const SizedBox(height: 8),
            AttachmentShareDownloadRow(path: images.first, compact: compact),
          ] else if (allowShareDownload) ...[
            const SizedBox(height: 6),
            Text(
              s.attachmentTapImageHint,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
        if (files.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...files.map((path) {
            final attachment = _attachmentFor(path);
            final hint = service.iconHintForFileName(attachment.fileName);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ActionChip(
                    avatar: Icon(_iconForHint(hint), size: 16),
                    label: Text(
                      attachment.fileName,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _onFileTap(context, path),
                  ),
                  if (allowShareDownload)
                    AttachmentShareDownloadRow(path: path, compact: compact),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  IconData _iconForHint(IconHint hint) {
    return switch (hint) {
      IconHint.pdf => Icons.picture_as_pdf,
      IconHint.document => Icons.description,
      IconHint.spreadsheet => Icons.table_chart,
      IconHint.image => Icons.image,
      IconHint.video => Icons.videocam,
      IconHint.audio => Icons.audiotrack,
      IconHint.archive => Icons.folder_zip,
      IconHint.generic => Icons.attach_file,
    };
  }
}
