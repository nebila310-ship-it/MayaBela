import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/platform/web_attachment_cache.dart';

Future<AnnouncementAttachment?> saveAttachmentBytes({
  required String fileName,
  required List<int> bytes,
  required String subdir,
  int? size,
}) async {
  final id = DateTime.now().millisecondsSinceEpoch.toString();
  final path = WebAttachmentCache.instance.store(fileName, bytes);
  return AnnouncementAttachment(
    id: id,
    fileName: fileName,
    filePath: path,
    fileSizeBytes: size ?? bytes.length,
  );
}

Future<AnnouncementAttachment?> copyAttachmentFromPath({
  required String fileName,
  required String sourcePath,
  required String subdir,
  int? size,
}) async {
  return null;
}

Future<bool> attachmentPathExists(String path) async =>
    WebAttachmentCache.instance.isWebPath(path);
