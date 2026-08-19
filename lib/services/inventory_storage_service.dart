import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/database/supabase/supabase_storage_bootstrap.dart';
import 'package:mayabela/platform/platform_file_storage.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/inventory_file_bytes.dart';

enum InventoryStorageKind {
  itemImage('items'),
  assetPhoto('assets'),
  invoiceAttachment('invoices');

  const InventoryStorageKind(this.folder);
  final String folder;
}

class InventoryPickResult {
  const InventoryPickResult({
    required this.fileName,
    this.bytes,
    this.localPath,
    this.size,
  });

  final String fileName;
  final List<int>? bytes;
  final String? localPath;
  final int? size;
}

class InventoryUploadResult {
  const InventoryUploadResult({
    required this.path,
    required this.usedCloud,
    this.message,
  });

  final String? path;
  final bool usedCloud;
  final String? message;
}

/// Local file pick + Supabase Storage upload for inventory attachments.
class InventoryStorageService {
  InventoryStorageService._();
  static final instance = InventoryStorageService._();

  bool get cloudAvailable =>
      SupabaseBootstrap.isInitialized && SupabaseStorageBootstrap.isReady;

  String? get lastCloudError => SupabaseStorageBootstrap.lastError;

  String get storageSetupHint => SupabaseStorageBootstrap.setupHint;

  String get _schoolId => AuthService.activeSchoolId ?? 'default';

  Future<InventoryPickResult?> pickImage() => _pickFile(imagesOnly: true);

  Future<InventoryPickResult?> pickInvoiceFile() =>
      _pickFile(imagesOnly: false);

  Future<InventoryPickResult?> _pickFile({required bool imagesOnly}) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: imagesOnly ? FileType.image : FileType.custom,
      allowedExtensions:
          imagesOnly ? null : const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    return InventoryPickResult(
      fileName: file.name,
      bytes: file.bytes,
      localPath: file.path,
      size: file.size,
    );
  }

  Future<InventoryUploadResult> uploadForEntity({
    required InventoryPickResult pick,
    required InventoryStorageKind kind,
    required String entityId,
  }) async {
    final localPath = await _saveLocal(pick, kind);
    if (!SupabaseBootstrap.isInitialized) {
      return InventoryUploadResult(
        path: localPath,
        usedCloud: false,
      );
    }

    if (SupabaseStorageBootstrap.deferred) {
      return InventoryUploadResult(
        path: localPath,
        usedCloud: false,
        message: SupabaseStorageBootstrap.setupHint,
      );
    }

    final storageReady = await SupabaseStorageBootstrap.ensureReady();
    if (!storageReady) {
      return InventoryUploadResult(
        path: localPath,
        usedCloud: false,
        message: SupabaseStorageBootstrap.lastError,
      );
    }

    try {
      final bytes = pick.bytes ??
          await readInventoryFileBytes(localPath) ??
          await readInventoryFileBytes(pick.localPath);
      if (bytes == null || bytes.isEmpty) {
        return InventoryUploadResult(
          path: localPath,
          usedCloud: false,
          message: 'Saved locally (no file bytes)',
        );
      }

      final safeName = pick.fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final storagePath =
          'schools/$_schoolId/inventory/${kind.folder}/$entityId/$safeName';
      await SupabaseBootstrap.client.storage.from('school-files').uploadBinary(
            storagePath,
            Uint8List.fromList(bytes),
            fileOptions: FileOptions(
              contentType: _contentTypeFor(pick.fileName),
              upsert: true,
            ),
          );
      final url = SupabaseBootstrap.client.storage
          .from('school-files')
          .getPublicUrl(storagePath);
      return InventoryUploadResult(path: url, usedCloud: true);
    } catch (e) {
      SupabaseStorageBootstrap.reset();
      if (kDebugMode) {
        debugPrint('InventoryStorageService upload failed: $e');
      }
      return InventoryUploadResult(
        path: localPath,
        usedCloud: false,
        message: e.toString(),
      );
    }
  }

  Future<String?> _saveLocal(
    InventoryPickResult pick,
    InventoryStorageKind kind,
  ) async {
    if (pick.bytes != null) {
      final saved = await saveAttachmentBytes(
        fileName: pick.fileName,
        bytes: pick.bytes!,
        subdir: 'inventory_${kind.folder}',
        size: pick.size,
      );
      return saved?.filePath;
    }
    if (pick.localPath != null && !kIsWeb) {
      final saved = await copyAttachmentFromPath(
        fileName: pick.fileName,
        sourcePath: pick.localPath!,
        subdir: 'inventory_${kind.folder}',
        size: pick.size,
      );
      return saved?.filePath;
    }
    return null;
  }

  String? _contentTypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return null;
  }

  bool isCloudUrl(String? path) =>
      path != null &&
      (path.startsWith('http://') || path.startsWith('https://'));

  String displayLabel(String? path) {
    if (path == null || path.isEmpty) return 'No file attached';
    if (isCloudUrl(path)) {
      return 'Cloud: ${path.split('/').last.split('?').first}';
    }
    final parts = path.split('/');
    return parts.isNotEmpty ? parts.last : path;
  }
}
