import 'dart:io';

Future<List<int>?> readInventoryFileBytes(String? path) async {
  if (path == null || path.isEmpty) return null;
  try {
    final file = File(path);
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  } catch (_) {
    return null;
  }
}
