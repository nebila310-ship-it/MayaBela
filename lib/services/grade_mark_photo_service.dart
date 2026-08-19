import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'package:mayabela/services/announcement_attachment_service.dart';

/// Saves grade mark sheet photos (and scanned sheets) for a student grade.
///
/// Uses [FilePicker] so web and mobile both work without leaving a grey
/// overlay or relying on dart:io [ImagePicker] paths.
class GradeMarkPhotoService {
  GradeMarkPhotoService._();
  static final instance = GradeMarkPhotoService._();

  /// Picks mark-sheet images / PDFs / common scan formats.
  Future<List<String>> pickFromGallery() async {
    final attachments = await AnnouncementAttachmentService.instance
        .pickAndSaveFiles(
      subdir: 'grade_mark_photos',
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
        'pdf',
        'tif',
        'tiff',
      ],
    );
    if (attachments.isEmpty && !kIsWeb) {
      // Fallback: some devices only expose gallery via image picker type.
      final fallback = await AnnouncementAttachmentService.instance
          .pickAndSaveFiles(
        subdir: 'grade_mark_photos',
        type: FileType.image,
      );
      return fallback.map((a) => a.filePath).toList();
    }
    return attachments.map((a) => a.filePath).toList();
  }
}
