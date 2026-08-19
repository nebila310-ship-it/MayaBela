import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/database/supabase/supabase_storage_bootstrap.dart';
import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/platform/platform_file_storage.dart';
import 'package:mayabela/platform/web_attachment_cache.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/utils/web_file_utils.dart';

class AnnouncementAttachmentService {
  AnnouncementAttachmentService._();
  static final instance = AnnouncementAttachmentService._();

  Future<List<AnnouncementAttachment>> pickAndSaveFiles({
    String subdir = 'announcement_attachments',
    FileType type = FileType.any,
    List<String>? allowedExtensions,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: type,
      allowedExtensions:
          type == FileType.custom ? allowedExtensions : null,
      // Web needs bytes in-memory; native can read from path for large files.
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return [];

    final saved = <AnnouncementAttachment>[];
    for (final file in result.files) {
      final attachment = await _savePlatformFile(file, subdir: subdir);
      if (attachment != null) saved.add(attachment);
    }
    return saved;
  }

  Future<List<AnnouncementAttachment>> pickAndSaveMessageAttachments() {
    return pickAndSaveFiles(subdir: 'message_attachments');
  }

  Future<AnnouncementAttachment?> _savePlatformFile(
    PlatformFile file, {
    required String subdir,
  }) async {
    List<int>? bytes = file.bytes;
    AnnouncementAttachment? local;
    if (bytes != null) {
      local = await saveAttachmentBytes(
        fileName: file.name,
        bytes: bytes,
        subdir: subdir,
        size: file.size,
      );
    } else if (!kIsWeb && file.path != null) {
      local = await copyAttachmentFromPath(
        fileName: file.name,
        sourcePath: file.path!,
        subdir: subdir,
        size: file.size,
      );
    }
    if (local == null) return null;

    // Prefer a cloud URL so other roles / devices can open the file.
    final cloud = await _uploadToCloud(
      fileName: file.name,
      bytes: bytes,
      localPath: local.filePath,
      subdir: subdir,
      attachmentId: local.id,
    );
    if (cloud != null) {
      return AnnouncementAttachment(
        id: local.id,
        fileName: local.fileName,
        filePath: cloud,
        fileSizeBytes: local.fileSizeBytes,
      );
    }
    return local;
  }

  Future<String?> _uploadToCloud({
    required String fileName,
    required List<int>? bytes,
    required String localPath,
    required String subdir,
    required String attachmentId,
  }) async {
    if (!SupabaseBootstrap.isInitialized) return null;
    if (SupabaseStorageBootstrap.deferred) return null;
    final ready = await SupabaseStorageBootstrap.ensureReady();
    if (!ready) return null;

    try {
      var payload = bytes;
      if ((payload == null || payload.isEmpty) &&
          WebAttachmentCache.instance.isWebPath(localPath)) {
        payload = WebAttachmentCache.instance.read(localPath);
      }
      if (payload == null || payload.isEmpty) return null;

      final schoolId = (AuthService.activeSchoolId ??
              AuthService.currentUser?.schoolId ??
              'unknown')
          .trim()
          .toUpperCase();
      final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final storagePath =
          'schools/$schoolId/$subdir/${attachmentId}_$safeName';
      await SupabaseBootstrap.client.storage.from('school-files').uploadBinary(
            storagePath,
            Uint8List.fromList(payload),
            fileOptions: FileOptions(
              contentType: _contentTypeFor(fileName),
              upsert: true,
            ),
          );
      return SupabaseBootstrap.client.storage
          .from('school-files')
          .getPublicUrl(storagePath);
    } catch (e) {
      SupabaseStorageBootstrap.reset();
      if (kDebugMode) {
        debugPrint('AnnouncementAttachmentService cloud upload failed: $e');
      }
      return null;
    }
  }

  String _contentTypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    if (lower.endsWith('.tif') || lower.endsWith('.tiff')) return 'image/tiff';
    if (lower.endsWith('.svg')) return 'image/svg+xml';
    if (lower.endsWith('.txt') || lower.endsWith('.csv') || lower.endsWith('.log')) {
      return 'text/plain';
    }
    if (lower.endsWith('.rtf')) return 'application/rtf';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
    if (lower.endsWith('.pptx')) {
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    }
    if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (lower.endsWith('.odt')) {
      return 'application/vnd.oasis.opendocument.text';
    }
    if (lower.endsWith('.ods')) {
      return 'application/vnd.oasis.opendocument.spreadsheet';
    }
    if (lower.endsWith('.zip')) return 'application/zip';
    if (lower.endsWith('.rar')) return 'application/vnd.rar';
    if (lower.endsWith('.7z')) return 'application/x-7z-compressed';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    if (lower.endsWith('.avi')) return 'video/x-msvideo';
    return 'application/octet-stream';
  }

  Future<OpenResult> openAttachment(AnnouncementAttachment attachment) async {
    if (isVoiceAttachment(attachment)) {
      return OpenResult(type: ResultType.done);
    }
    final path = attachment.filePath;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      await WebFileUtils.openOrDownload(
        filePath: path,
        fileName: attachment.fileName,
      );
      return OpenResult(type: ResultType.done);
    }
    if (kIsWeb || WebAttachmentCache.instance.isWebPath(path)) {
      await WebFileUtils.openOrDownload(
        filePath: path,
        fileName: attachment.fileName,
      );
      return OpenResult(type: ResultType.done);
    }
    return OpenFile.open(path);
  }

  bool isVoiceAttachment(AnnouncementAttachment attachment) {
    final lower = attachment.fileName.toLowerCase();
    return lower.endsWith('.m4a') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.wav') ||
        lower.startsWith('voice_') ||
        lower == 'voice_message.m4a';
  }

  String formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconHint iconHintForFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return IconHint.pdf;
    if (lower.endsWith('.doc') ||
        lower.endsWith('.docx') ||
        lower.endsWith('.txt') ||
        lower.endsWith('.rtf')) {
      return IconHint.document;
    }
    if (lower.endsWith('.xls') ||
        lower.endsWith('.xlsx') ||
        lower.endsWith('.csv')) {
      return IconHint.spreadsheet;
    }
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp')) {
      return IconHint.image;
    }
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv')) {
      return IconHint.video;
    }
    if (lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.m4a')) {
      return IconHint.audio;
    }
    if (lower.endsWith('.zip') ||
        lower.endsWith('.rar') ||
        lower.endsWith('.7z')) {
      return IconHint.archive;
    }
    return IconHint.generic;
  }
}

enum IconHint {
  pdf,
  document,
  spreadsheet,
  image,
  video,
  audio,
  archive,
  generic,
}
