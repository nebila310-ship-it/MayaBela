import 'dart:typed_data';

/// In-memory attachment bytes for Flutter Web (`web://` paths).
class WebAttachmentCache {
  WebAttachmentCache._();
  static final instance = WebAttachmentCache._();

  final Map<String, Uint8List> _bytes = {};

  static const pathPrefix = 'web://';

  String store(String fileName, List<int> bytes) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final safe = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final path = '$pathPrefix$id/$safe';
    _bytes[path] = Uint8List.fromList(bytes);
    return path;
  }

  bool isWebPath(String? path) =>
      path != null && path.startsWith(pathPrefix);

  Uint8List? read(String? path) {
    if (path == null) return null;
    return _bytes[path];
  }

  void remove(String path) => _bytes.remove(path);
}
