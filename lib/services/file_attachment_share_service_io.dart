import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'file_attachment_share_service.dart';

Future<AttachmentShareResult> sharePath(
  String path, {
  String? subject,
}) async {
  final file = await _resolveFile(path);
  if (file == null) {
    return const AttachmentShareResult(success: false, message: 'not_found');
  }

  final name = FileAttachmentShareService.instance.displayName(path);
  await Share.shareXFiles(
    [
      XFile(
        file.path,
        name: name,
        mimeType: FileAttachmentShareService.instance.mimeTypeFor(name),
      ),
    ],
    subject: subject ?? name,
  );
  return const AttachmentShareResult(success: true);
}

Future<AttachmentShareResult> downloadPath(String path) async {
  final source = await _resolveFile(path);
  if (source == null) {
    return const AttachmentShareResult(success: false, message: 'not_found');
  }

  final dir =
      await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final name = FileAttachmentShareService.instance.displayName(path);
  var target = File(p.join(dir.path, name));
  if (await target.exists()) {
    final stem = p.basenameWithoutExtension(name);
    final ext = p.extension(name);
    var counter = 1;
    while (await target.exists()) {
      target = File(p.join(dir.path, '${stem}_$counter$ext'));
      counter++;
    }
  }
  await source.copy(target.path);
  return const AttachmentShareResult(success: true);
}

Future<File?> _resolveFile(String path) async {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return null;

  if (FileAttachmentShareService.instance.isAssetPath(trimmed)) {
    final assetKey = trimmed.substring(
      FileAttachmentShareService.assetPrefix.length,
    );
    try {
      final bytes = await rootBundle.load(assetKey);
      final ext = p.extension(assetKey);
      final dir = await getTemporaryDirectory();
      final safeName = FileAttachmentShareService.instance
          .displayName(trimmed)
          .replaceAll(RegExp(r'[^\w.\-]'), '_');
      final file = File(
        p.join(dir.path, 'attachment_$safeName${ext.isEmpty ? '' : ext}'),
      );
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      return file;
    } catch (_) {
      return null;
    }
  }

  final file = File(trimmed);
  if (await file.exists()) return file;
  return null;
}
