import 'package:flutter/material.dart';
import 'package:mayabela/models/school_logo_style.dart';
import 'package:mayabela/services/school_logo_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/widgets/school_logo_display.dart';

/// School name above logo cover — used on dashboards after sign-in.
class SchoolBrandingHeader extends StatefulWidget {
  const SchoolBrandingHeader({
    super.key,
    this.schoolId,
    this.onSecretTap,
    this.compact = false,
    this.fallbackTitle,
    this.tagline,
  });

  final String? schoolId;
  final VoidCallback? onSecretTap;
  final bool compact;
  final String? fallbackTitle;
  final String? tagline;

  @override
  State<SchoolBrandingHeader> createState() => _SchoolBrandingHeaderState();
}

class _SchoolBrandingHeaderState extends State<SchoolBrandingHeader> {
  String? _logoPath;
  String? _logoUrl;

  @override
  void initState() {
    super.initState();
    _loadLogo();
  }

  @override
  void didUpdateWidget(SchoolBrandingHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId) {
      _loadLogo();
    }
  }

  Future<void> _loadLogo() async {
    final id = widget.schoolId?.trim();
    if (id == null || id.isEmpty) {
      if (mounted) {
        setState(() {
          _logoPath = null;
          _logoUrl = null;
        });
      }
      return;
    }
    final record = SchoolRegistryService.instance.lookup(id);
    final path = await SchoolLogoService.instance.resolvedLogoPath(
      id,
      storedPath: record?.logoPath,
    );
    if (mounted) {
      setState(() {
        _logoPath = path;
        _logoUrl = record?.logoUrl;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.schoolId?.trim();
    final record = id != null && id.isNotEmpty
        ? SchoolRegistryService.instance.lookup(id)
        : null;
    final hasSchool = record != null;
    final schoolName = hasSchool ? record.name : null;

    if (widget.compact) {
      if (!hasSchool || schoolName == null) return const SizedBox.shrink();
      return Column(
        children: [
          Text(
            schoolName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          _logoWidget(height: 120, width: double.infinity),
        ],
      );
    }

    if (hasSchool && schoolName != null) {
      return Column(
        children: [
          Text(
            schoolName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.indigo.shade900,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: widget.onSecretTap,
            child: _logoWidget(height: 140, width: double.infinity),
          ),
          if (widget.tagline != null) ...[
            const SizedBox(height: 10),
            Text(
              widget.tagline!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.indigo.shade700.withValues(alpha: 0.85),
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      children: [
        GestureDetector(
          onTap: widget.onSecretTap,
          child: const Icon(Icons.school, size: 70, color: Colors.indigo),
        ),
        const SizedBox(height: 14),
        Text(
          widget.fallbackTitle ?? 'Maya School',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Colors.indigo.shade900,
          ),
        ),
        if (widget.tagline != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.tagline!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.indigo.shade700.withValues(alpha: 0.85),
            ),
          ),
        ],
      ],
    );
  }

  Widget _logoWidget({required double height, required double width}) {
    final record = SchoolRegistryService.instance.lookup(widget.schoolId?.trim());
    final style = record?.logoStyle ?? SchoolLogoStyle.rectangular;

    if (style == SchoolLogoStyle.circular) {
      return Center(
        child: SchoolLogoDisplay(
          imagePath: _logoPath,
          networkUrl: _logoUrl,
          style: style,
          height: height,
        ),
      );
    }

    return SchoolLogoDisplay(
      imagePath: _logoPath,
      networkUrl: _logoUrl,
      style: style,
      height: height,
      width: width,
    );
  }
}
