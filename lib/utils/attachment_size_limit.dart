import 'package:mayabela/utils/attachment_path_utils.dart';

/// Upload caps for gallery and other file attachments.
abstract final class AttachmentSizeLimit {
  static const imageBytes = 8 * 1024 * 1024;
  static const videoBytes = 25 * 1024 * 1024;
  static const fileBytes = 10 * 1024 * 1024;

  static int forFileName(String fileName) {
    if (attachmentPathIsVideo(fileName)) return videoBytes;
    if (attachmentPathIsImage(fileName)) return imageBytes;
    return fileBytes;
  }

  static int maxMbForFileName(String fileName) =>
      (forFileName(fileName) / (1024 * 1024)).round();

  static bool exceeds(String fileName, int byteCount) =>
      byteCount > forFileName(fileName);
}
