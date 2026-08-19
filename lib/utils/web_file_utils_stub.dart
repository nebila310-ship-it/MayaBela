import 'package:flutter/foundation.dart';

import 'package:mayabela/platform/web_attachment_cache.dart';

Future<void> downloadBytes({
  required String fileName,
  required List<int> bytes,
}) async {
  // No-op on IO platforms — callers use share_plus / open_file.
}

Future<void> openOrDownload({
  required String filePath,
  required String fileName,
  List<int>? bytes,
}) async {
  if (kIsWeb) {
    final data = bytes ?? WebAttachmentCache.instance.read(filePath);
    if (data != null) {
      await downloadBytes(fileName: fileName, bytes: data);
    }
  }
}
