import 'package:flutter/material.dart';
import 'package:mayabela/models/school_logo_style.dart';
import 'package:mayabela/services/school_logo_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/widgets/maya_brand_logo.dart';
import 'package:mayabela/widgets/school_logo_display.dart';

/// Login top brand: Maya logo until a valid School ID with a saved logo is entered.
class LoginBrandHeader extends StatefulWidget {
  const LoginBrandHeader({
    super.key,
    required this.schoolId,
    this.onSecretTap,
    this.height = 140,
    this.accentColor,
  });

  final String schoolId;
  final VoidCallback? onSecretTap;
  final double height;
  final Color? accentColor;

  @override
  State<LoginBrandHeader> createState() => _LoginBrandHeaderState();
}

class _LoginBrandHeaderState extends State<LoginBrandHeader> {
  String? _logoPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(LoginBrandHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId) _load();
  }

  Future<void> _load() async {
    final id = widget.schoolId.trim();
    if (id.isEmpty) {
      if (mounted) setState(() => _logoPath = null);
      return;
    }
    final record = SchoolRegistryService.instance.lookup(id);
    if (record == null) {
      if (mounted) setState(() => _logoPath = null);
      return;
    }
    final path = await SchoolLogoService.instance.resolvedLogoPath(
      id,
      storedPath: record.logoPath,
    );
    if (mounted) setState(() => _logoPath = path);
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.schoolId.trim();
    final record = id.isEmpty ? null : SchoolRegistryService.instance.lookup(id);
    final hasSavedLogo = record != null &&
        ((_logoPath != null && _logoPath!.isNotEmpty) ||
            (record.logoUrl?.isNotEmpty == true) ||
            (record.logoPath?.isNotEmpty == true));

    final accent = widget.accentColor ?? Colors.indigo.shade900;

    if (record == null || !hasSavedLogo) {
      return MayaBrandLogo(onSecretTap: widget.onSecretTap, height: widget.height);
    }

    final style = record.logoStyle;
    final name = record.name;

    return GestureDetector(
      onTap: widget.onSecretTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 10),
          if (style == SchoolLogoStyle.circular)
            Center(
              child: SchoolLogoDisplay(
                imagePath: _logoPath,
                networkUrl: record.logoUrl,
                style: style,
                height: widget.height,
              ),
            )
          else
            SchoolLogoDisplay(
              imagePath: _logoPath,
              networkUrl: record.logoUrl,
              style: style,
              height: widget.height,
            ),
        ],
      ),
    );
  }
}
