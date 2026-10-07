import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:mayabela/models/announcement.dart';

Future<AnnouncementAttachment?> saveAttachmentBytes({
  required String fileName,
  required List<int> bytes,
  required String subdir,
  int? size,
}) async {
  try {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$subdir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final dest = File('${dir.path}/${id}_$safeName');
    await dest.writeAsBytes(bytes, flush: true);
    return AnnouncementAttachment(
      id: id,
      fileName: fileName,
      filePath: dest.path,
      fileSizeBytes: size ?? bytes.length,
    );
  } catch (_) {
    return null;
  }
}

Future<AnnouncementAttachment?> copyAttachmentFromPath({
  required String fileName,
  required String sourcePath,
  required String subdir,
  int? size,
}) async {
  try {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$subdir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final dest = File('${dir.path}/${id}_$safeName');
    await File(sourcePath).copy(dest.path);
    return AnnouncementAttachment(
      id: id,
      fileName: fileName,
      filePath: dest.path,
      fileSizeBytes: size ?? await dest.length(),
    );
  } catch (_) {
    return null;
  }
}

Future<bool> attachmentPathExists(String path) async {
  if (path.isEmpty) return false;
  return File(path).exists();
}

Future<List<int>?> readAttachmentBytes(String path) async {
  final value = path.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return null;
  }
  try {
    final file = File(value);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    return bytes.isEmpty ? null : bytes;
  } catch (_) {
    return null;
  }
}

Future<String?> writeTempAttachment({
  required String fileName,
  required List<int> bytes,
}) async {
  if (bytes.isEmpty) return null;
  try {
    final dir = await getTemporaryDirectory();
    final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${dir.path}/$safeName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  } catch (_) {
    return null;
  }
}
