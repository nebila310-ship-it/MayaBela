import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'package:mayabela/platform/web_attachment_cache.dart';
import 'package:mayabela/services/profile_photo_codec.dart';

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

Future<bool> openOrDownload({
  required String filePath,
  required String fileName,
  List<int>? bytes,
}) async {
  final data = bytes ?? WebAttachmentCache.instance.read(filePath);
  if (data != null && data.isNotEmpty) {
    await _openBytes(fileName: fileName, bytes: data);
    return true;
  }
  // Private school-files public URLs 404 in a new tab. Only open http
  // when the object is actually public (branding) or already hydrated.
  if ((filePath.startsWith('http://') || filePath.startsWith('https://')) &&
      !ProfilePhotoCodec.isPrivateSchoolFilesUrl(filePath)) {
    web.window.open(filePath, '_blank');
    return true;
  }
  return false;
}

Future<void> _openBytes({
  required String fileName,
  required List<int> bytes,
}) async {
  final blob = web.Blob(
    [Uint8List.fromList(bytes).toJS].toJS,
  );
  final url = web.URL.createObjectURL(blob);
  final opened = web.window.open(url, '_blank');
  if (opened == null) {
    await downloadBytes(fileName: fileName, bytes: bytes);
  }
}
