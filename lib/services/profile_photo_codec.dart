import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/platform/platform_file_storage.dart';
import 'package:mayabela/platform/web_attachment_cache.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/utils/attachment_size_limit.dart';

/// Shared pick / normalize / save for student, teacher, staff, and driver photos.
class ProfilePhotoCodec {
  ProfilePhotoCodec._();

  static String? lastError;

  static final Map<String, Future<Uint8List?>> _inflightDownloads = {};

  static bool isRemoteUrl(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  /// `web://`, `data:`, or a native file path — not reachable from another device.
  static bool isDeviceLocalPath(String? path) {
    if (path == null) return true;
    final trimmed = path.trim();
    if (trimmed.isEmpty) return true;
    if (WebAttachmentCache.instance.isWebPath(trimmed)) return true;
    if (trimmed.startsWith('data:')) return true;
    if (isRemoteUrl(trimmed)) return false;
    if (trimmed.startsWith('schools/')) return false;
    return true;
  }

  /// Student/staff photos live in a private bucket. Only branding files are public.
  static bool isPrivateSchoolFilesUrl(String path) {
    if (!isRemoteUrl(path) && !path.trim().startsWith('schools/')) {
      return false;
    }
    final objectPath = schoolFilesObjectPath(path);
    if (objectPath == null) return false;
    return !objectPath.contains('/branding/');
  }

  /// Turns a Supabase public/sign/authenticated URL into a storage object path.
  static String? schoolFilesObjectPath(String url) {
    final trimmed = url.trim();
    if (trimmed.startsWith('schools/') && !trimmed.contains('://')) {
      return Uri.decodeComponent(trimmed);
    }
    const markers = [
      '/object/public/school-files/',
      '/object/sign/school-files/',
      '/object/authenticated/school-files/',
    ];
    for (final marker in markers) {
      final i = url.indexOf(marker);
      if (i < 0) continue;
      var rest = url.substring(i + marker.length);
      final q = rest.indexOf('?');
      if (q >= 0) rest = rest.substring(0, q);
      if (rest.isEmpty) return null;
      return Uri.decodeComponent(rest);
    }
    return null;
  }

  /// Stable school-files object for a person photo.
  static String cloudObjectPath({
    required String schoolId,
    required String folder,
    required String personId,
  }) {
    final school = schoolId.trim().toUpperCase();
    final id = personId.trim().toUpperCase();
    final safeFolder = folder.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return 'schools/$school/$safeFolder/${id}_$id.jpg';
  }

  /// Drop laptop-only photo paths so they are not written into cloud registry rows.
  static Map<String, dynamic> withoutDeviceLocalPhoto(
    Map<String, dynamic> record,
  ) {
    final photo = record['photoPath'];
    if (photo is String && isDeviceLocalPath(photo)) {
      final copy = Map<String, dynamic>.from(record);
      copy.remove('photoPath');
      return copy;
    }
    return record;
  }

  /// File picker first (web + “choose file”), then gallery on native.
  static Future<Uint8List?> pickBytes() async {
    lastError = null;
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'gif',
          'bmp',
          'heic',
          'heif',
        ],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return null;
      return _bytesFromPlatformFile(result.files.first);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProfilePhotoCodec FilePicker: $e');
      }
    }

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) return null;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        lastError = 'Could not read the selected image.';
        return null;
      }
      if (AttachmentSizeLimit.exceeds(picked.name, bytes.length)) {
        lastError =
            'That photo is too large. Use an image under ${AttachmentSizeLimit.maxMbForFileName(picked.name)} MB.';
        return null;
      }
      return bytes;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProfilePhotoCodec ImagePicker: $e');
      }
      lastError = 'Could not open the photo picker. Try another image.';
      return null;
    }
  }

  static Uint8List? _bytesFromPlatformFile(PlatformFile file) {
    List<int>? bytes = file.bytes;
    if ((bytes == null || bytes.isEmpty) &&
        !kIsWeb &&
        file.path != null &&
        file.path!.isNotEmpty) {
      try {
        bytes = File(file.path!).readAsBytesSync();
      } catch (_) {
        bytes = null;
      }
    }
    if (bytes == null || bytes.isEmpty) {
      lastError = 'Could not read the selected image.';
      return null;
    }
    if (AttachmentSizeLimit.exceeds(file.name, bytes.length)) {
      lastError =
          'That photo is too large. Use an image under ${AttachmentSizeLimit.maxMbForFileName(file.name)} MB.';
      return null;
    }
    return Uint8List.fromList(bytes);
  }

  /// JPEG 512×512. Already-square bytes (aligned crop) are not re-centered.
  static Uint8List squareJpegOrOriginal(Uint8List bytes) {
    if (bytes.isEmpty) return bytes;
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;

      img.Image square;
      if (decoded.width == decoded.height) {
        square = decoded;
      } else {
        final size = decoded.width < decoded.height
            ? decoded.width
            : decoded.height;
        if (size <= 0) return bytes;
        final left = (decoded.width - size) ~/ 2;
        final top = (decoded.height - size) ~/ 2;
        square = img.copyCrop(
          decoded,
          x: left,
          y: top,
          width: size,
          height: size,
        );
      }
      final resized = img.copyResize(square, width: 512, height: 512);
      return Uint8List.fromList(img.encodeJpg(resized, quality: 88));
    } catch (_) {
      return bytes;
    }
  }

  static Future<String?> saveBytes({
    required String personId,
    required Uint8List sourceBytes,
    required String folder,
    required Map<String, Uint8List> byteCache,
    required Map<String, String> pathCache,
  }) async {
    lastError = null;
    final id = personId.trim().toUpperCase();
    if (id.isEmpty || sourceBytes.isEmpty) {
      lastError = 'Missing photo data.';
      return null;
    }

    final encoded = squareJpegOrOriginal(sourceBytes);
    if (encoded.isEmpty) {
      lastError = 'Could not process that image. Try JPG or PNG.';
      return null;
    }

    byteCache[id] = encoded;
    var path = kIsWeb
        ? WebAttachmentCache.instance.store('$id.jpg', encoded)
        : await _writeNativeFile(id: id, folder: folder, bytes: encoded);
    if (path == null || path.isEmpty) {
      path = WebAttachmentCache.instance.store('$id.jpg', encoded);
    }
    pathCache[id] = path;
    WebAttachmentCache.instance.remember(path, encoded);

    final cloud = await uploadBytesToSchoolFiles(
      personId: id,
      folder: folder,
      bytes: encoded,
    );
    if (cloud != null && cloud.isNotEmpty) {
      pathCache[id] = cloud;
      WebAttachmentCache.instance.remember(cloud, encoded);
      return cloud;
    }
    return path;
  }

  /// Uploads JPEG bytes to private `school-files`. Skips the Storage probe
  /// that previously blocked every person photo and left a laptop-only path.
  static Future<String?> uploadBytesToSchoolFiles({
    required String personId,
    required String folder,
    required Uint8List bytes,
    bool reportError = true,
  }) async {
    final id = personId.trim().toUpperCase();
    if (id.isEmpty || bytes.isEmpty || folder.trim().isEmpty) return null;

    if (!SupabaseBootstrap.isInitialized) {
      if (reportError) {
        lastError =
            'Cloud is not connected. The photo is only on this device until you save again.';
      }
      return null;
    }

    try {
      await SupabaseBootstrap.ensureReadyForFirestore();
    } catch (_) {}

    final schoolId =
        (AuthService.activeSchoolId ?? AuthService.currentUser?.schoolId ?? '')
            .trim()
            .toUpperCase();
    if (schoolId.isEmpty) {
      if (reportError) {
        lastError =
            'No school is signed in. The photo is only on this device until you save again.';
      }
      return null;
    }

    final storagePath = cloudObjectPath(
      schoolId: schoolId,
      folder: folder,
      personId: id,
    );

    Future<String?> attempt() async {
      await SupabaseBootstrap.client.storage
          .from('school-files')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          )
          .timeout(const Duration(seconds: 25));
      final url = SupabaseBootstrap.client.storage
          .from('school-files')
          .getPublicUrl(storagePath);
      WebAttachmentCache.instance.remember(url, bytes);
      WebAttachmentCache.instance.remember(storagePath, bytes);
      return url;
    }

    try {
      return await attempt();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProfilePhotoCodec cloud upload retry: $e');
      }
      try {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        return await attempt();
      } catch (e2) {
        if (kDebugMode) {
          debugPrint('ProfilePhotoCodec cloud upload failed: $e2');
        }
        if (reportError) {
          lastError =
              'Could not save the photo to the school cloud. It is only on this device until you try again.';
        }
        return null;
      }
    }
  }

  static Future<String?> _writeNativeFile({
    required String id,
    required String folder,
    required Uint8List bytes,
  }) async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${dir.path}/$folder');
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }
      final file = File('${photosDir.path}/$id.jpg');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProfilePhotoCodec native save: $e');
      }
      return null;
    }
  }

  static Uint8List? lookupBytes({
    required String? personId,
    required Map<String, Uint8List> byteCache,
    required Map<String, String> pathCache,
    String? storedPath,
  }) {
    if (personId != null && personId.trim().isNotEmpty) {
      final id = personId.trim().toUpperCase();
      final cached = byteCache[id];
      if (cached != null && cached.isNotEmpty) return cached;
      final path = pathCache[id] ?? storedPath;
      final fromCache = WebAttachmentCache.instance.read(path);
      if (fromCache != null && fromCache.isNotEmpty) return fromCache;
    }
    return WebAttachmentCache.instance.read(storedPath);
  }

  /// Downloads a private school-files photo with the signed-in Storage client.
  /// Local cache, native file, or authenticated school-files download.
  static Future<Uint8List?> bytesFromStoredPath(String? path) async {
    if (path == null) return null;
    final trimmed = path.trim();
    if (trimmed.isEmpty) return null;
    final cached = WebAttachmentCache.instance.read(trimmed);
    if (cached != null && cached.isNotEmpty) return cached;
    if (isRemoteUrl(trimmed)) return fetchRemoteBytes(trimmed);
    final local = await readAttachmentBytes(trimmed);
    if (local == null || local.isEmpty) return null;
    return Uint8List.fromList(local);
  }

  static Future<Uint8List?> fetchRemoteBytes(String? path) async {
    if (path == null || path.trim().isEmpty) return null;
    final cached = WebAttachmentCache.instance.read(path);
    if (cached != null && cached.isNotEmpty) return cached;
    final objectPath = schoolFilesObjectPath(path);
    if (objectPath == null) return null;
    if (!SupabaseBootstrap.isInitialized) return null;

    final inflight = _inflightDownloads[path];
    if (inflight != null) return inflight;

    final future = _downloadSchoolFile(path, objectPath);
    _inflightDownloads[path] = future;
    try {
      return await future;
    } finally {
      _inflightDownloads.remove(path);
    }
  }

  static Future<Uint8List?> _downloadSchoolFile(
    String url,
    String objectPath,
  ) async {
    try {
      final bytes = await SupabaseBootstrap.client.storage
          .from('school-files')
          .download(objectPath)
          .timeout(const Duration(seconds: 12));
      if (bytes.isNotEmpty) {
        WebAttachmentCache.instance.remember(url, bytes);
        WebAttachmentCache.instance.remember(objectPath, bytes);
        return bytes;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProfilePhotoCodec download failed: $e');
      }
    }
    return null;
  }

  /// Local cache first, then authenticated Storage download for private URLs.
  static Future<Uint8List?> hydrateBytes({
    required String? personId,
    required Map<String, Uint8List> byteCache,
    required Map<String, String> pathCache,
    String? storedPath,
    String? folder,
  }) async {
    final existing = lookupBytes(
      personId: personId,
      byteCache: byteCache,
      pathCache: pathCache,
      storedPath: storedPath,
    );
    if (existing != null && existing.isNotEmpty) {
      if (personId != null && personId.trim().isNotEmpty) {
        byteCache[personId.trim().toUpperCase()] = existing;
      }
      return existing;
    }

    String? path;
    if (personId != null && personId.trim().isNotEmpty) {
      path = pathCache[personId.trim().toUpperCase()] ?? storedPath;
    } else {
      path = storedPath;
    }

    if (path != null && path.trim().isNotEmpty) {
      final remote = await fetchRemoteBytes(path);
      if (remote != null && remote.isNotEmpty) {
        _rememberHydrated(
          personId: personId,
          byteCache: byteCache,
          pathCache: pathCache,
          path: path,
          bytes: remote,
        );
        return remote;
      }
    }

    if (folder != null && personId != null && personId.trim().isNotEmpty) {
      final known = await fetchKnownSchoolPhoto(
        personId: personId,
        folder: folder,
      );
      if (known != null && known.bytes.isNotEmpty) {
        _rememberHydrated(
          personId: personId,
          byteCache: byteCache,
          pathCache: pathCache,
          path: known.url,
          bytes: known.bytes,
        );
        return known.bytes;
      }
    }
    return null;
  }

  static void _rememberHydrated({
    required String? personId,
    required Map<String, Uint8List> byteCache,
    required Map<String, String> pathCache,
    required String path,
    required Uint8List bytes,
  }) {
    if (personId == null || personId.trim().isEmpty) return;
    final id = personId.trim().toUpperCase();
    byteCache[id] = bytes;
    if (!isDeviceLocalPath(path)) {
      pathCache[id] = path;
    }
  }

  /// Downloads the deterministic school-files object even if the registry
  /// still stores a laptop-only `web://` path.
  static Future<({String url, Uint8List bytes})?> fetchKnownSchoolPhoto({
    required String personId,
    required String folder,
  }) async {
    final schoolId =
        (AuthService.activeSchoolId ?? AuthService.currentUser?.schoolId ?? '')
            .trim()
            .toUpperCase();
    if (schoolId.isEmpty) return null;
    if (!SupabaseBootstrap.isInitialized) return null;
    final objectPath = cloudObjectPath(
      schoolId: schoolId,
      folder: folder,
      personId: personId,
    );
    final url = SupabaseBootstrap.client.storage
        .from('school-files')
        .getPublicUrl(objectPath);
    final cached =
        WebAttachmentCache.instance.read(url) ??
        WebAttachmentCache.instance.read(objectPath);
    if (cached != null && cached.isNotEmpty) {
      return (url: url, bytes: cached);
    }
    final bytes = await _downloadSchoolFile(url, objectPath);
    if (bytes == null || bytes.isEmpty) return null;
    return (url: url, bytes: bytes);
  }

  static Future<String?> resolvePath({
    required String? personId,
    required String folder,
    required Map<String, String> pathCache,
    String? storedPath,
  }) async {
    if (personId == null || personId.trim().isEmpty) return storedPath;
    final id = personId.trim().toUpperCase();
    final cached = pathCache[id] ?? storedPath;
    if (cached != null && cached.isNotEmpty) {
      if (WebAttachmentCache.instance.isWebPath(cached)) return cached;
      if (cached.startsWith('http://') || cached.startsWith('https://')) {
        return cached;
      }
      if (!kIsWeb && File(cached).existsSync()) return cached;
    }
    if (kIsWeb) return cached;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$folder/$id.jpg');
      if (await file.exists()) {
        pathCache[id] = file.path;
        return file.path;
      }
    } catch (_) {}
    return cached;
  }
}
