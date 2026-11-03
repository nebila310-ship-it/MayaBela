import 'package:flutter/material.dart';

import 'package:mayabela/models/remembered_school_brand.dart';
import 'package:mayabela/models/school_logo_style.dart';
import 'package:mayabela/platform/login_chrome_brand.dart';
import 'package:mayabela/services/school_logo_service.dart';
import 'package:mayabela/widgets/education_splash_loader.dart';
import 'package:mayabela/widgets/maya_brand_logo.dart';

/// First Flutter frame while critical bootstrap runs. Mirrors the web splash
/// in `web/index.html`: the school mark, or the platform mark, sits in a
/// gold medallion with the milestone orbit around it.
class LaunchSchoolSplash extends StatelessWidget {
  const LaunchSchoolSplash({super.key, this.brand});

  final RememberedSchoolBrand? brand;

  @override
  Widget build(BuildContext context) {
    final remembered = brand;
    final title = remembered?.name ?? LoginChromeBrand.productTitle;
    final screen = MediaQuery.sizeOf(context);
    final ring = [
      screen.width * 0.8,
      screen.height * 0.54,
      420.0,
    ].reduce((a, b) => a < b ? a : b).clamp(180.0, 420.0);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F33),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.16),
            radius: 1.1,
            colors: [Color(0xFF26337F), Color(0xFF141C55), Color(0xFF0A0F33)],
            stops: [0, 0.52, 1],
          ),
        ),
        child: Stack(
          children: [
            const _Aurora(
              alignment: Alignment(-1.1, -1.1),
              color: Color(0xFF7B1FA2),
              factor: 0.9,
            ),
            const _Aurora(
              alignment: Alignment(1.1, 1.1),
              color: Color(0xFF00838F),
              factor: 0.8,
            ),
            const _Aurora(
              alignment: Alignment(0.7, -1.2),
              color: Color(0xFFFF8F00),
              factor: 0.5,
              opacity: 0.22,
            ),
            SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          EducationSplashLoader(
                            key: const ValueKey('splash-loading-ring'),
                            size: ring,
                            showLabel: false,
                            center: _SplashMark(brand: remembered),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Color(0x59000000),
                                  blurRadius: 14,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          const _GoldDivider(),
                          const SizedBox(height: 10),
                          const EducationSplashLoader(
                            key: ValueKey('splash-loading-caption'),
                            size: 0,
                            showLabel: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: Text(
                        'MAJO BRIDGE · SCHOOL OS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.6,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Aurora extends StatelessWidget {
  const _Aurora({
    required this.alignment,
    required this.color,
    required this.factor,
    this.opacity = 0.45,
  });

  final Alignment alignment;
  final Color color;
  final double factor;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final side = MediaQuery.sizeOf(context).longestSide * 0.5 * factor;
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: opacity),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoldDivider extends StatelessWidget {
  const _GoldDivider();

  @override
  Widget build(BuildContext context) {
    Widget line(bool flip) => Container(
      width: 42,
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: flip
              ? const [EducationSplashLoader.gold, Color(0x00FFD54F)]
              : const [Color(0x00FFD54F), EducationSplashLoader.gold],
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        line(false),
        const SizedBox(width: 8),
        Transform.rotate(
          angle: 0.785398,
          child: Container(
            width: 7,
            height: 7,
            color: EducationSplashLoader.gold,
          ),
        ),
        const SizedBox(width: 8),
        line(true),
      ],
    );
  }
}

class _SplashMark extends StatelessWidget {
  const _SplashMark({required this.brand});

  final RememberedSchoolBrand? brand;

  @override
  Widget build(BuildContext context) {
    final remembered = brand;
    final url = remembered == null
        ? null
        : SchoolLogoService.displayUrlFor(
            remembered.schoolId,
            storedUrl: remembered.logoUrl,
            style: remembered.logoStyle,
          );
    final platform = Transform.scale(
      scale: 1.18,
      child: Image.asset(
        MayaBrandLogo.assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
    if (url == null ||
        !(url.startsWith('http://') || url.startsWith('https://'))) {
      return platform;
    }
    final image = Image.network(
      url,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => platform,
    );
    return remembered?.logoStyle == SchoolLogoStyle.circular
        ? ClipOval(child: image)
        : image;
  }
}
