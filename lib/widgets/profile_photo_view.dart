import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mayabela/platform/web_attachment_cache.dart';

/// Resolves a person photo from in-memory bytes, web cache, network, or file.
ImageProvider? profilePhotoProvider({
  Uint8List? bytes,
  String? path,
}) {
  if (bytes != null && bytes.isNotEmpty) return MemoryImage(bytes);
  if (path == null || path.trim().isEmpty) return null;
  final cached = WebAttachmentCache.instance.read(path);
  if (cached != null && cached.isNotEmpty) return MemoryImage(cached);
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return NetworkImage(path);
  }
  if (WebAttachmentCache.instance.isWebPath(path)) return null;
  if (!kIsWeb && File(path).existsSync()) return FileImage(File(path));
  return null;
}

class ProfilePhotoImage extends StatelessWidget {
  const ProfilePhotoImage({
    super.key,
    this.bytes,
    this.path,
    required this.size,
    this.fit = BoxFit.cover,
  });

  final Uint8List? bytes;
  final String? path;
  final double size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final provider = profilePhotoProvider(bytes: bytes, path: path);
    if (provider == null) return const SizedBox.shrink();
    return Image(
      image: provider,
      width: size,
      height: size,
      fit: fit,
      gaplessPlayback: true,
    );
  }
}
