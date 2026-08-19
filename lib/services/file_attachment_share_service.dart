import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import 'package:mayabela/platform/web_attachment_cache.dart';
import 'package:mayabela/utils/web_file_utils.dart';

import 'file_attachment_share_service_io.dart'
    if (dart.library.html) 'file_attachment_share_service_stub.dart'
    as io_share;

class AttachmentShareResult {
  const AttachmentShareResult({
    required this.success,
    this.message,
  });

  final bool success;
  final String? message;
}

/// Share or save homework / grade attachments stored on device or as bundled assets.
class FileAttachmentShareService {
  FileAttachmentShareService._();
  static final instance = FileAttachmentShareService._();

  static const assetPrefix = 'asset:';

  bool isAssetPath(String path) => path.startsWith(assetPrefix);

  String displayName(String path) {
    if (isAssetPath(path)) {
      return path.substring(assetPrefix.length).split('/').last;
    }
    if (WebAttachmentCache.instance.isWebPath(path)) {
      return path.split('/').last;
    }
    return p.basename(path);
  }

  Future<AttachmentShareResult> sharePath(
    String path, {
    String? subject,
  }) async {
    if (kIsWeb || WebAttachmentCache.instance.isWebPath(path)) {
      final bytes = WebAttachmentCache.instance.read(path);
      if (bytes == null) {
        return const AttachmentShareResult(success: false, message: 'not_found');
      }
      final name = displayName(path);
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: name, mimeType: mimeTypeFor(name))],
        subject: subject ?? name,
      );
      return const AttachmentShareResult(success: true);
    }

    return io_share.sharePath(path, subject: subject);
  }

  Future<AttachmentShareResult> downloadPath(String path) async {
    if (kIsWeb || WebAttachmentCache.instance.isWebPath(path)) {
      final bytes = WebAttachmentCache.instance.read(path);
      if (bytes == null) {
        return const AttachmentShareResult(success: false, message: 'not_found');
      }
      await WebFileUtils.downloadBytes(
        fileName: displayName(path),
        bytes: bytes,
      );
      return const AttachmentShareResult(success: true);
    }

    return io_share.downloadPath(path);
  }

  String? mimeTypeFor(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    return switch (ext) {
      '.png' => 'image/png',
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.pdf' => 'application/pdf',
      '.doc' => 'application/msword',
      '.docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xls' => 'application/vnd.ms-excel',
      '.xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.csv' => 'text/csv',
      '.txt' => 'text/plain',
      '.mp4' => 'video/mp4',
      '.mov' => 'video/quicktime',
      '.mp3' => 'audio/mpeg',
      '.wav' => 'audio/wav',
      '.m4a' => 'audio/mp4',
      '.zip' => 'application/zip',
      _ => null,
    };
  }
}
