import 'package:mayabela/platform/web_attachment_cache.dart';

Future<List<int>?> readInventoryFileBytes(String? path) async {
  if (path == null || path.isEmpty) return null;
  if (!WebAttachmentCache.instance.isWebPath(path)) return null;
  return WebAttachmentCache.instance.read(path)?.toList();
}
