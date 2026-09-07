import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/utils/attachment_path_utils.dart';

class GalleryComposeResult {
  const GalleryComposeResult({
    required this.title,
    required this.caption,
    required this.type,
    this.mediaPath,
    this.mediaLabel,
  });

  final String title;
  final String caption;
  final GalleryPostType type;
  final String? mediaPath;
  final String? mediaLabel;
}

/// Fills missing gallery fields so Upload still creates a visible post.
class GalleryCompose {
  static const defaultTitleFallback = 'Gallery post';

  static GalleryComposeResult resolve({
    required String title,
    required String caption,
    required GalleryPostType type,
    String? mediaPath,
    String? mediaLabel,
    List<String> attachments = const [],
  }) {
    var resolvedType = type;
    var resolvedMedia = mediaPath?.trim();
    if (resolvedMedia != null && resolvedMedia.isEmpty) resolvedMedia = null;
    var resolvedLabel = mediaLabel?.trim();
    if (resolvedLabel != null && resolvedLabel.isEmpty) resolvedLabel = null;

    if (resolvedMedia == null) {
      final image = attachments.where(attachmentPathIsImage).firstOrNull;
      final video = attachments.where(attachmentPathIsVideo).firstOrNull;
      if (image != null &&
          (resolvedType != GalleryPostType.video || video == null)) {
        resolvedMedia = image;
        resolvedLabel ??= attachmentFileName(image);
        resolvedType = GalleryPostType.photo;
      } else if (video != null) {
        resolvedMedia = video;
        resolvedLabel ??= attachmentFileName(video);
        resolvedType = GalleryPostType.video;
      }
    }

    final resolvedTitle = title.trim().isEmpty
        ? (resolvedLabel ??
            (attachments.isNotEmpty
                ? attachmentFileName(attachments.first)
                : defaultTitleFallback))
        : title.trim();

    return GalleryComposeResult(
      title: resolvedTitle,
      caption: caption.trim(),
      type: resolvedType,
      mediaPath: resolvedMedia,
      mediaLabel: resolvedLabel,
    );
  }

  static bool hasPublishableContent({
    required String title,
    String? mediaPath,
    List<String> attachments = const [],
  }) {
    return title.trim().isNotEmpty ||
        (mediaPath != null && mediaPath.trim().isNotEmpty) ||
        attachments.isNotEmpty;
  }
}
