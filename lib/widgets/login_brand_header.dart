import 'package:flutter/material.dart';
import 'package:mayabela/models/remembered_school_brand.dart';
import 'package:mayabela/models/school_logo_style.dart';
import 'package:mayabela/services/login_prefs_service.dart';
import 'package:mayabela/services/school_logo_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/widgets/maya_brand_logo.dart';
import 'package:mayabela/widgets/school_logo_display.dart';

/// Login top brand: remembered or registry school name + logo, else Maya.
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

  _BrandSnapshot? get _snapshot {
    final id = widget.schoolId.trim();
    if (id.isEmpty) return null;
    final record = SchoolRegistryService.instance.lookup(id);
    if (record != null && record.name.trim().isNotEmpty) {
      return _BrandSnapshot(
        schoolId: record.id,
        name: record.name,
        logoUrl: record.logoUrl,
        logoPath: _logoPath ?? record.logoPath,
        logoStyle: record.logoStyle,
      );
    }
    final remembered = LoginPrefsService.instance.brandForSchool(id);
    if (remembered != null) {
      return _BrandSnapshot.fromRemembered(remembered);
    }
    return null;
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
    await LoginPrefsService.instance.rememberSchoolBrand(
      schoolId: record.id,
      name: record.name,
      logoUrl: record.logoUrl,
      logoPath: path ?? record.logoPath,
      logoStyle: record.logoStyle,
    );
    if (mounted) setState(() => _logoPath = path);
  }

  @override
  Widget build(BuildContext context) {
    final brand = _snapshot;
    final accent = widget.accentColor ?? Colors.indigo.shade900;

    if (brand == null) {
      return MayaBrandLogo(onSecretTap: widget.onSecretTap, height: widget.height);
    }

    return GestureDetector(
      onTap: widget.onSecretTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(
            brand.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 10),
          if (brand.logoStyle == SchoolLogoStyle.circular)
            Center(
              child: SchoolLogoDisplay(
                imagePath: brand.logoPath,
                networkUrl: brand.logoUrl,
                style: brand.logoStyle,
                height: widget.height,
              ),
            )
          else
            SchoolLogoDisplay(
              imagePath: brand.logoPath,
              networkUrl: brand.logoUrl,
              style: brand.logoStyle,
              height: widget.height,
            ),
        ],
      ),
    );
  }
}

class _BrandSnapshot {
  const _BrandSnapshot({
    required this.schoolId,
    required this.name,
    this.logoUrl,
    this.logoPath,
    this.logoStyle = SchoolLogoStyle.rectangular,
  });

  factory _BrandSnapshot.fromRemembered(RememberedSchoolBrand brand) {
    return _BrandSnapshot(
      schoolId: brand.schoolId,
      name: brand.name,
      logoUrl: brand.logoUrl,
      logoPath: brand.logoPath,
      logoStyle: brand.logoStyle,
    );
  }

  final String schoolId;
  final String name;
  final String? logoUrl;
  final String? logoPath;
  final SchoolLogoStyle logoStyle;
}
