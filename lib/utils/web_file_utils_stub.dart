import 'package:mayabela/platform/web_attachment_cache.dart';
import 'package:mayabela/services/profile_photo_codec.dart';

Future<void> downloadBytes({
  required String fileName,
  required List<int> bytes,
}) async {
  // No-op on IO platforms — callers use share_plus / open_file.
}

Future<bool> openOrDownload({
  required String filePath,
  required String fileName,
  List<int>? bytes,
}) async {
  final data = bytes ?? WebAttachmentCache.instance.read(filePath);
  if (data != null && data.isNotEmpty) {
    await downloadBytes(fileName: fileName, bytes: data);
    return true;
  }
  if ((filePath.startsWith('http://') || filePath.startsWith('https://')) &&
      ProfilePhotoCodec.isPrivateSchoolFilesUrl(filePath)) {
    return false;
  }
  return false;
}
