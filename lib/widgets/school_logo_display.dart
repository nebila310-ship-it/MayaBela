import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mayabela/models/school_logo_style.dart';
import 'package:mayabela/platform/school_splash_brand.dart';
import 'package:mayabela/platform/web_attachment_cache.dart';
import 'package:mayabela/services/school_logo_service.dart';
import 'package:mayabela/widgets/platform_path_image.dart';

/// Edge-to-edge school logo — saved files are pre-fitted to the frame aspect ratio.
class SchoolLogoDisplay extends StatefulWidget {
  const SchoolLogoDisplay({
    super.key,
    this.imagePath,
    required this.style,
    this.height = 140,
    this.width,
    this.networkUrl,
    this.imageBytes,
    this.schoolId,
  });

  final String? imagePath;
  final String? networkUrl;
  final Uint8List? imageBytes;
  final SchoolLogoStyle style;
  final double height;
  final double? width;
  final String? schoolId;

  @override
  State<SchoolLogoDisplay> createState() => _SchoolLogoDisplayState();
}

class _SchoolLogoDisplayState extends State<SchoolLogoDisplay> {
  Uint8List? _downloaded;
  bool _downloadStarted = false;

  @override
  void initState() {
    super.initState();
    _primeFromCache();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchFromStorage();
    });
  }

  @override
  void didUpdateWidget(SchoolLogoDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId ||
        oldWidget.style != widget.style ||
        oldWidget.networkUrl != widget.networkUrl ||
        oldWidget.imagePath != widget.imagePath ||
        oldWidget.imageBytes != widget.imageBytes) {
      _downloaded = null;
      _downloadStarted = false;
      _primeFromCache();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchFromStorage();
      });
    }
  }

  void _primeFromCache() {
    final id = widget.schoolId?.trim();
    if (id == null || id.isEmpty) return;
    final cached = SchoolSplashBrand.readBytes(
          schoolId: id,
          style: widget.style,
        ) ??
        WebAttachmentCache.instance.read(
          SchoolLogoService.cacheKey(id, widget.style),
        );
    if (cached != null && cached.isNotEmpty) {
      _downloaded = cached;
    }
  }

  bool get _canFetchStorage {
    final id = widget.schoolId?.trim();
    if (id == null || id.isEmpty) return false;
    final url = widget.networkUrl?.trim() ?? '';
    if (url.isEmpty) return true;
    return url.contains('/storage/v1/object/');
  }

  void _fetchFromStorage() {
    if (_downloadStarted || !_canFetchStorage) return;
    final id = widget.schoolId?.trim();
    if (id == null || id.isEmpty) return;
    _downloadStarted = true;
    SchoolLogoService.instance
        .downloadBrandingBytes(schoolId: id, style: widget.style)
        .then((bytes) {
      if (!mounted || bytes == null || bytes.isEmpty) return;
      setState(() => _downloaded = bytes);
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.style) {
      SchoolLogoStyle.rectangular => _rectangular(),
      SchoolLogoStyle.circular => _circular(),
    };
  }

  Widget _imageFill() {
    final bytes = widget.imageBytes ?? _downloaded;
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

    final pathCached = WebAttachmentCache.instance.read(widget.imagePath);
    if (pathCached != null && pathCached.isNotEmpty) {
      return Image.memory(
        pathCached,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => _networkOrFile(),
      );
    }

    return _networkOrFile();
  }

  Widget _networkOrFile() {
    final dataBytes = _bytesFromDataUrl(widget.networkUrl);
    if (dataBytes != null) {
      return Image.memory(
        dataBytes,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => _fileFill(),
      );
    }

    final networkUrl = SchoolLogoService.viewableUrl(
      widget.networkUrl?.trim().isNotEmpty == true
          ? widget.networkUrl
          : (widget.schoolId != null && widget.schoolId!.trim().isNotEmpty)
              ? SchoolLogoService.publicUrl(
                  widget.schoolId!,
                  style: widget.style,
                )
              : null,
    );
    if (networkUrl != null &&
        (networkUrl.startsWith('http://') ||
            networkUrl.startsWith('https://'))) {
      return Image.network(
        networkUrl,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        headers: SchoolLogoService.imageHeadersFor(networkUrl),
        errorBuilder: (_, _, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fetchFromStorage();
          });
          return _fileFill();
        },
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchFromStorage();
    });
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
    final path = widget.imagePath;
    if (path == null || path.isEmpty) {
      return _placeholder();
    }
    if (path.startsWith('web-logo:') &&
        WebAttachmentCache.instance.read(path) == null) {
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
          size: widget.height * 0.35,
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
    final w = widget.width;
    if (w != null && w != double.infinity) {
      return SizedBox(
        width: w,
        height: widget.height,
        child: _framedLogo(circular: false),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: _framedLogo(circular: false),
    );
  }

  Widget _circular() {
    final size = widget.height;
    return SizedBox(
      width: widget.width ?? size,
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
