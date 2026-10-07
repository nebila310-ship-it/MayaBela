import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mayabela/models/school_logo_style.dart';
import 'package:mayabela/platform/login_chrome_brand.dart';
import 'package:mayabela/platform/school_splash_brand.dart';
import 'package:mayabela/services/login_prefs_service.dart';
import 'package:mayabela/services/school_logo_service.dart';
import 'package:mayabela/services/school_public_brand_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/widgets/maya_brand_logo.dart';
import 'package:mayabela/widgets/school_logo_display.dart';

/// Login top brand: typed School ID name + logo, else MaJo Bridge OS.
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
  Uint8List? _logoBytes;

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
    final typed = widget.schoolId.trim();
    if (typed.isEmpty) return null;
    final splash = SchoolSplashBrand.readMeta(schoolId: typed);
    final id = typed;

    final record = SchoolRegistryService.instance.lookup(id);
    final name = LoginChromeBrand.resolvedSchoolName(id) ?? '';
    if (record != null && name.isNotEmpty) {
      return _BrandSnapshot(
        schoolId: record.id,
        name: name,
        logoUrl: SchoolLogoService.displayUrlFor(
          record.id,
          storedUrl: record.displayLogoUrl,
          style: record.logoStyle,
        ),
        logoPath: _logoPath ?? record.displayLogoPath,
        logoStyle: record.logoStyle,
        logoBytes: _logoBytes,
      );
    }
    final remembered = LoginPrefsService.instance.brandForSchool(id);
    if (remembered != null && name.isNotEmpty) {
      return _BrandSnapshot(
        schoolId: remembered.schoolId,
        name: name,
        logoUrl: SchoolLogoService.displayUrlFor(
          remembered.schoolId,
          storedUrl: remembered.logoUrl,
          style: remembered.logoStyle,
        ),
        logoPath: remembered.logoPath,
        logoStyle: remembered.logoStyle,
        logoBytes: _logoBytes,
      );
    }
    if (splash != null && splash.schoolId == id.toUpperCase()) {
      return _BrandSnapshot(
        schoolId: splash.schoolId,
        name: name,
        logoUrl:
            splash.logoUrl ??
            SchoolLogoService.publicUrl(
              splash.schoolId,
              style: splash.logoStyle,
            ),
        logoStyle: splash.logoStyle,
        logoBytes: _logoBytes,
      );
    }
    if (id.length >= 3) {
      return _BrandSnapshot(
        schoolId: id,
        name: name,
        logoUrl: SchoolLogoService.publicUrl(id),
        logoStyle: splash?.logoStyle ?? SchoolLogoStyle.rectangular,
        logoBytes: _logoBytes,
      );
    }
    return null;
  }

  Future<void> _load() async {
    final typed = widget.schoolId.trim();
    if (typed.isEmpty) {
      if (mounted) {
        setState(() {
          _logoPath = null;
          _logoBytes = null;
        });
      }
      return;
    }
    final splash = SchoolSplashBrand.readMeta(schoolId: typed);
    final id = typed;
    final record = SchoolRegistryService.instance.lookup(id);
    final style =
        record?.logoStyle ?? splash?.logoStyle ?? SchoolLogoStyle.rectangular;
    final bytes = SchoolSplashBrand.readBytes(schoolId: id, style: style);
    String? path;
    if (record != null) {
      path = await SchoolLogoService.instance.resolvedLogoPath(
        record.id,
        storedPath: record.displayLogoPath,
      );
      await LoginPrefsService.instance.rememberSchoolBrand(
        schoolId: record.id,
        name: record.name,
        logoUrl: SchoolLogoService.displayUrlFor(
          record.id,
          storedUrl: record.displayLogoUrl,
          style: record.logoStyle,
        ),
        logoPath: path ?? record.displayLogoPath,
        logoStyle: record.logoStyle,
      );
    }
    if (!mounted) return;
    if (widget.schoolId.trim() != id) return;
    setState(() {
      _logoPath = path;
      _logoBytes = bytes;
    });
    LoginChromeBrand.apply(schoolId: id);
    if (LoginChromeBrand.resolvedSchoolName(id) == null) {
      unawaited(_loadPublicName(id));
    }
  }

  Future<void> _loadPublicName(String id) async {
    final brand = await SchoolPublicBrandService.instance.loadAndRemember(id);
    if (!mounted) return;
    if (widget.schoolId.trim().toUpperCase() != id.toUpperCase()) return;
    if (brand == null) return;
    LoginChromeBrand.apply(schoolId: id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LoginChromeBrand.tabTitle,
      builder: (context, _, __) => _buildHeader(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final brand = _snapshot;
    final accent = widget.accentColor ?? Colors.indigo.shade900;

    if (brand == null) {
      return Column(
        children: [
          Text(
            LoginChromeBrand.productTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 10),
          MayaBrandLogo(onSecretTap: widget.onSecretTap, height: widget.height),
        ],
      );
    }

    final logo = SchoolLogoDisplay(
      schoolId: brand.schoolId,
      imagePath: brand.logoPath,
      imageBytes: brand.logoBytes,
      networkUrl: brand.logoUrl,
      style: brand.logoStyle,
      height: widget.height,
    );

    return GestureDetector(
      onTap: widget.onSecretTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(
            brand.name.isNotEmpty ? brand.name : LoginChromeBrand.productTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 10),
          if (brand.logoStyle == SchoolLogoStyle.circular)
            Center(child: logo)
          else
            logo,
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
    this.logoBytes,
    this.logoStyle = SchoolLogoStyle.rectangular,
  });

  final String schoolId;
  final String name;
  final String? logoUrl;
  final String? logoPath;
  final Uint8List? logoBytes;
  final SchoolLogoStyle logoStyle;
}
