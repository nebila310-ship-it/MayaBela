import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mayabela/platform/web_attachment_cache.dart';
import 'package:mayabela/services/profile_photo_codec.dart';
import 'package:mayabela/supabase_options.dart';
import 'package:mayabela/widgets/platform_path_image_io.dart'
    if (dart.library.html) 'package:mayabela/widgets/platform_path_image_stub.dart'
    as io_image;

/// Renders a local attachment path, cached web bytes, or a private school-files URL.
class PlatformPathImage extends StatefulWidget {
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
  State<PlatformPathImage> createState() => _PlatformPathImageState();
}

class _PlatformPathImageState extends State<PlatformPathImage> {
  Uint8List? _remoteBytes;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  @override
  void didUpdateWidget(PlatformPathImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _remoteBytes = null;
      _hydrate();
    }
  }

  Future<void> _hydrate() async {
    final value = widget.path?.trim();
    if (value == null || value.isEmpty) return;
    if (WebAttachmentCache.instance.read(value) != null) return;
    if (!ProfilePhotoCodec.isPrivateSchoolFilesUrl(value)) return;
    final bytes = await ProfilePhotoCodec.fetchRemoteBytes(value);
    if (!mounted) return;
    if (widget.path?.trim() != value) return;
    if (bytes == null || bytes.isEmpty) return;
    setState(() => _remoteBytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.path?.trim();
    if (value == null || value.isEmpty) {
      return _fallback(context, Exception('empty path'));
    }

    final cached = WebAttachmentCache.instance.read(value) ?? _remoteBytes;
    if (cached != null) {
      return Image.memory(
        cached,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: widget.errorBuilder,
      );
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      if (ProfilePhotoCodec.isPrivateSchoolFilesUrl(value)) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white54),
          ),
        );
      }
      final viewable = schoolBrandingViewableUrl(value);
      return Image.network(
        viewable,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        headers: schoolBrandingImageHeaders(viewable),
        errorBuilder: widget.errorBuilder,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            ),
          );
        },
      );
    }

    if (value.startsWith('asset:')) {
      return Image.asset(
        value.substring('asset:'.length),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: widget.errorBuilder,
      );
    }

    if (kIsWeb || WebAttachmentCache.instance.isWebPath(value)) {
      return _fallback(context, Exception('missing web cache'));
    }

    return _IoPathImage(
      path: value,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: widget.errorBuilder,
    );
  }

  Widget _fallback(BuildContext context, Object error) {
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(context, error, StackTrace.current);
    }
    return Icon(
      Icons.broken_image_outlined,
      size: widget.width ?? widget.height ?? 40,
    );
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
    return io_image.buildIoPathImage(
      path: path,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: errorBuilder,
    );
  }
}
