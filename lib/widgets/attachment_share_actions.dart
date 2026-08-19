import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/services/announcement_attachment_service.dart';
import 'package:mayabela/services/file_attachment_share_service.dart';

/// Share / download controls for parent-facing file attachments.
class AttachmentShareDownloadRow extends StatelessWidget {
  const AttachmentShareDownloadRow({
    super.key,
    required this.path,
    this.compact = false,
  });

  final String path;
  final bool compact;

  Future<void> _share(BuildContext context) async {
    final s = AppLocale.instance.strings;
    final result = await FileAttachmentShareService.instance.sharePath(
      path,
      subject: FileAttachmentShareService.instance.displayName(path),
    );
    if (!context.mounted) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.attachmentNotFound)),
      );
    }
  }

  Future<void> _download(BuildContext context) async {
    final s = AppLocale.instance.strings;
    final result =
        await FileAttachmentShareService.instance.downloadPath(path);
    if (!context.mounted) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.attachmentDownloadFailed)),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          s.attachmentDownloaded(
            FileAttachmentShareService.instance.displayName(path),
          ),
        ),
        backgroundColor: const Color(0xFF15803D),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final padding = compact ? 4.0 : 0.0;

    return Padding(
      padding: EdgeInsets.only(top: padding),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _share(context),
              icon: Icon(Icons.share_outlined, size: compact ? 16 : 18),
              label: Text(s.share),
              style: OutlinedButton.styleFrom(
                visualDensity:
                    compact ? VisualDensity.compact : VisualDensity.standard,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _download(context),
              icon: Icon(Icons.download_outlined, size: compact ? 16 : 18),
              label: Text(s.download),
              style: ElevatedButton.styleFrom(
                visualDensity:
                    compact ? VisualDensity.compact : VisualDensity.standard,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showAttachmentActionSheet(
  BuildContext context, {
  required String path,
}) async {
  final s = AppLocale.instance.strings;
  final shareService = FileAttachmentShareService.instance;
  final fileName = shareService.displayName(path);

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              fileName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: Text(s.open),
            onTap: () async {
              Navigator.pop(ctx);
              if (shareService.isAssetPath(path)) {
                if (!context.mounted) return;
                _previewAssetImage(context, path);
                return;
              }
              final result = await AnnouncementAttachmentService.instance
                  .openAttachment(
                AnnouncementAttachment(
                  id: path,
                  fileName: fileName,
                  filePath: path,
                ),
              );
              if (!context.mounted) return;
              if (result.type != ResultType.done) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(s.announcementAttachmentOpenFailed)),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: Text(s.share),
            onTap: () async {
              Navigator.pop(ctx);
              final result = await shareService.sharePath(
                path,
                subject: fileName,
              );
              if (!context.mounted) return;
              if (!result.success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(s.attachmentNotFound)),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(s.download),
            onTap: () async {
              Navigator.pop(ctx);
              final result = await shareService.downloadPath(path);
              if (!context.mounted) return;
              if (!result.success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(s.attachmentDownloadFailed)),
                );
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(s.attachmentDownloaded(fileName)),
                  backgroundColor: const Color(0xFF15803D),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

void _previewAssetImage(BuildContext context, String path) {
  final assetKey = path.substring(FileAttachmentShareService.assetPrefix.length);
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => _AttachmentImagePreview(
        path: path,
        allowShareDownload: true,
        image: Image.asset(assetKey),
      ),
    ),
  );
}

class AttachmentImagePreviewScreen extends StatelessWidget {
  const AttachmentImagePreviewScreen({
    super.key,
    required this.path,
    required this.image,
    this.allowShareDownload = false,
  });

  final String path;
  final Widget image;
  final bool allowShareDownload;

  @override
  Widget build(BuildContext context) {
    return _AttachmentImagePreview(
      path: path,
      allowShareDownload: allowShareDownload,
      image: image,
    );
  }
}

class _AttachmentImagePreview extends StatelessWidget {
  const _AttachmentImagePreview({
    required this.path,
    required this.image,
    required this.allowShareDownload,
  });

  final String path;
  final Widget image;
  final bool allowShareDownload;

  Future<void> _share(BuildContext context) async {
    final s = AppLocale.instance.strings;
    final result = await FileAttachmentShareService.instance.sharePath(path);
    if (!context.mounted) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.attachmentNotFound)),
      );
    }
  }

  Future<void> _download(BuildContext context) async {
    final s = AppLocale.instance.strings;
    final result =
        await FileAttachmentShareService.instance.downloadPath(path);
    if (!context.mounted) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.attachmentDownloadFailed)),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          s.attachmentDownloaded(
            FileAttachmentShareService.instance.displayName(path),
          ),
        ),
        backgroundColor: const Color(0xFF15803D),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: allowShareDownload
            ? [
                IconButton(
                  tooltip: AppLocale.instance.strings.share,
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () => _share(context),
                ),
                IconButton(
                  tooltip: AppLocale.instance.strings.download,
                  icon: const Icon(Icons.download_outlined),
                  onPressed: () => _download(context),
                ),
              ]
            : null,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: InteractiveViewer(child: image),
      ),
    );
  }
}
