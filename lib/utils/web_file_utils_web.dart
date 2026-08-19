import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'package:mayabela/platform/web_attachment_cache.dart';

Future<void> downloadBytes({
  required String fileName,
  required List<int> bytes,
}) async {
  final blob = web.Blob(
    [Uint8List.fromList(bytes).toJS].toJS,
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

Future<void> openOrDownload({
  required String filePath,
  required String fileName,
  List<int>? bytes,
}) async {
  final data = bytes ?? WebAttachmentCache.instance.read(filePath);
  if (data == null) return;
  await downloadBytes(fileName: fileName, bytes: data);
}
