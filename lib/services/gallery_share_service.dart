import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:mayabela/models/teacher_features.dart';

class GalleryShareResult {
  const GalleryShareResult({
    required this.success,
    this.file,
    this.message,
  });

  final bool success;
  final File? file;
  final String? message;
}

/// Resolves gallery media paths (device files + bundled assets) for share/download.
class GalleryShareService {
  GalleryShareService._();
  static final instance = GalleryShareService._();

  static const _assetPrefix = 'asset:';

  bool hasShareableMedia(GalleryPost post) {
    if (post.type == GalleryPostType.note) return false;
    final path = post.mediaPath;
    if (path == null || path.trim().isEmpty) return false;
    if (path.startsWith(_assetPrefix)) return true;
    return File(path).existsSync();
  }

  Future<File?> resolveMediaFile(GalleryPost post) async {
    final path = post.mediaPath?.trim();
    if (path == null || path.isEmpty) return null;

    if (path.startsWith(_assetPrefix)) {
      final assetKey = path.substring(_assetPrefix.length);
      final bytes = await rootBundle.load(assetKey);
      final ext = p.extension(assetKey).replaceFirst('.', '');
      final dir = await getTemporaryDirectory();
      final file = File(
        p.join(dir.path, 'gallery_${post.id}.${ext.isEmpty ? 'jpg' : ext}'),
      );
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      return file;
    }

    final file = File(path);
    if (await file.exists()) return file;
    return null;
  }

  String shareCaption(GalleryPost post) {
    return '${post.title}\n${post.caption}\n'
        'Class: ${post.className} · By ${post.authorName}';
  }

  String fileNameFor(GalleryPost post, File file) {
    if (post.mediaLabel != null && post.mediaLabel!.contains('.')) {
      return post.mediaLabel!;
    }
    final ext = p.extension(file.path);
    final safeTitle = post.title
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return '${safeTitle.isEmpty ? post.id : safeTitle}$ext';
  }

  String? mimeTypeFor(GalleryPost post, File file) {
    switch (post.type) {
      case GalleryPostType.photo:
        final ext = p.extension(file.path).toLowerCase();
        return switch (ext) {
          '.png' => 'image/png',
          '.webp' => 'image/webp',
          '.gif' => 'image/gif',
          _ => 'image/jpeg',
        };
      case GalleryPostType.video:
        return 'video/mp4';
      case GalleryPostType.note:
        return null;
    }
  }

  Future<GalleryShareResult> sharePost(GalleryPost post) async {
    final caption = shareCaption(post);
    if (post.type == GalleryPostType.note || !hasShareableMedia(post)) {
      await Share.share(caption, subject: post.title);
      return const GalleryShareResult(success: true);
    }

    final file = await resolveMediaFile(post);
    if (file == null) {
      await Share.share(caption, subject: post.title);
      return GalleryShareResult(
        success: false,
        message: 'Media file not found — shared description only.',
      );
    }

    await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType: mimeTypeFor(post, file),
          name: fileNameFor(post, file),
        ),
      ],
      text: caption,
      subject: post.title,
    );
    return GalleryShareResult(success: true, file: file);
  }

  Future<GalleryShareResult> downloadPost(GalleryPost post) async {
    if (post.type == GalleryPostType.note || !hasShareableMedia(post)) {
      return GalleryShareResult(
        success: false,
        message: 'No photo or video attached to this post.',
      );
    }

    final source = await resolveMediaFile(post);
    if (source == null) {
      return GalleryShareResult(
        success: false,
        message: 'Media file not found on this device.',
      );
    }

    final dir = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final target = File(p.join(dir.path, fileNameFor(post, source)));
    if (await target.exists()) {
      await target.delete();
    }
    final saved = await source.copy(target.path);
    return GalleryShareResult(success: true, file: saved);
  }
}
