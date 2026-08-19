import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mayabela/platform/web_attachment_cache.dart';
import 'package:mayabela/widgets/platform_path_image_io.dart'
    if (dart.library.html) 'package:mayabela/widgets/platform_path_image_stub.dart'
    as io_image;

/// Renders a local attachment path on mobile or cached web bytes.
class PlatformPathImage extends StatelessWidget {
  const PlatformPathImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
  });

  final String? path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    final value = path?.trim();
    if (value == null || value.isEmpty) {
      return _fallback(context, Exception('empty path'));
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Image.network(
        value,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: errorBuilder,
      );
    }

    if (value.startsWith('asset:')) {
      return Image.asset(
        value.substring('asset:'.length),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: errorBuilder,
      );
    }

    if (kIsWeb || WebAttachmentCache.instance.isWebPath(value)) {
      final bytes = WebAttachmentCache.instance.read(value);
      if (bytes != null) {
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: errorBuilder,
        );
      }
      return _fallback(context, Exception('missing web cache'));
    }

    return _IoPathImage(
      path: value,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: errorBuilder,
    );
  }

  Widget _fallback(BuildContext context, Object error) {
    if (errorBuilder != null) {
      return errorBuilder!(context, error, StackTrace.current);
    }
    return Icon(Icons.broken_image_outlined, size: width ?? height ?? 40);
  }
}

class _IoPathImage extends StatelessWidget {
  const _IoPathImage({
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return _buildIo();
  }

  Widget _buildIo() {
    // Isolated in io-specific file via conditional export.
    return io_image.buildIoPathImage(
      path: path,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: errorBuilder,
    );
  }
}
