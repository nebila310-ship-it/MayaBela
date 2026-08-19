import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mayabela/models/school_logo_style.dart';
import 'package:mayabela/platform/web_attachment_cache.dart';
import 'package:mayabela/widgets/platform_path_image.dart';

/// Edge-to-edge school logo — saved files are pre-fitted to the frame aspect ratio.
class SchoolLogoDisplay extends StatelessWidget {
  const SchoolLogoDisplay({
    super.key,
    this.imagePath,
    required this.style,
    this.height = 140,
    this.width,
    this.networkUrl,
    this.imageBytes,
  });

  final String? imagePath;
  final String? networkUrl;
  final Uint8List? imageBytes;
  final SchoolLogoStyle style;
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      SchoolLogoStyle.rectangular => _rectangular(),
      SchoolLogoStyle.circular => _circular(),
    };
  }

  Widget _imageFill() {
    final bytes = imageBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }

    final dataBytes = _bytesFromDataUrl(networkUrl);
    if (dataBytes != null) {
      return Image.memory(
        dataBytes,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }

    if (networkUrl != null &&
        networkUrl!.isNotEmpty &&
        (networkUrl!.startsWith('http://') ||
            networkUrl!.startsWith('https://'))) {
      return Image.network(
        networkUrl!,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => _fileFill(),
      );
    }
    return _fileFill();
  }

  Uint8List? _bytesFromDataUrl(String? url) {
    if (url == null || !url.startsWith('data:image')) return null;
    final comma = url.indexOf(',');
    if (comma < 0) return null;
    try {
      return Uint8List.fromList(base64Decode(url.substring(comma + 1)));
    } catch (_) {
      return null;
    }
  }

  Widget _fileFill() {
    final path = imagePath;
    if (path == null || path.isEmpty || path.startsWith('web-logo:')) {
      return _placeholder();
    }
    if (WebAttachmentCache.instance.isWebPath(path) ||
        path.startsWith('http') ||
        !kIsWeb) {
      return PlatformPathImage(
        path: path,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Icon(
          Icons.account_balance,
          size: height * 0.35,
          color: Colors.indigo.shade200,
        ),
      ),
    );
  }

  BoxDecoration _frameDecoration({required bool circular}) {
    return BoxDecoration(
      borderRadius: circular ? null : BorderRadius.circular(20),
      shape: circular ? BoxShape.circle : BoxShape.rectangle,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
      color: Colors.white,
    );
  }

  Widget _rectangular() {
    final w = width;
    if (w != null && w != double.infinity) {
      return SizedBox(
        width: w,
        height: height,
        child: _framedLogo(circular: false),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: height,
      child: _framedLogo(circular: false),
    );
  }

  Widget _circular() {
    final size = height;
    return SizedBox(
      width: width ?? size,
      height: size,
      child: _framedLogo(circular: true),
    );
  }

  Widget _framedLogo({required bool circular}) {
    return Container(
      decoration: _frameDecoration(circular: circular),
      clipBehavior: Clip.antiAlias,
      child: _imageFill(),
    );
  }
}
