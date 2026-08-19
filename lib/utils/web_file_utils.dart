import 'package:mayabela/utils/web_file_utils_stub.dart'
    if (dart.library.html) 'package:mayabela/utils/web_file_utils_web.dart'
    as impl;

abstract final class WebFileUtils {
  static Future<void> downloadBytes({
    required String fileName,
    required List<int> bytes,
  }) =>
      impl.downloadBytes(fileName: fileName, bytes: bytes);

  static Future<void> openOrDownload({
    required String filePath,
    required String fileName,
    List<int>? bytes,
  }) =>
      impl.openOrDownload(
        filePath: filePath,
        fileName: fileName,
        bytes: bytes,
      );
}
