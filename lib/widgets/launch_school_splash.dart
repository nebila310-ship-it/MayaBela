import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:mayabela/models/remembered_school_brand.dart';
import 'package:mayabela/platform/login_chrome_brand.dart';
import 'package:mayabela/services/school_logo_service.dart';
import 'package:mayabela/widgets/education_splash_loader.dart';
import 'package:mayabela/widgets/maya_brand_logo.dart';

/// First Flutter frame while critical bootstrap runs.
/// The school mark, or the platform mark, sits behind as a wide watermark.
class LaunchSchoolSplash extends StatelessWidget {
  const LaunchSchoolSplash({super.key, this.brand});

  final RememberedSchoolBrand? brand;

  @override
  Widget build(BuildContext context) {
    final remembered = brand;
    final title = remembered?.name ?? LoginChromeBrand.productTitle;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF8E1),
              Color(0xFFE3F2FD),
              Color(0xFFF3E5F5),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            alignment: Alignment.center,
            children: [
              _SplashWatermark(brand: remembered),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const EducationSplashLoader(
                      key: ValueKey('splash-loading-ring'),
                      size: 300,
                      showLabel: false,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.indigo.shade900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const EducationSplashLoader(
                      key: ValueKey('splash-loading-caption'),
                      size: 0,
                      showLabel: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashWatermark extends StatelessWidget {
  const _SplashWatermark({required this.brand});

  final RememberedSchoolBrand? brand;

  @override
  Widget build(BuildContext context) {
    final width = math.min(MediaQuery.sizeOf(context).width * 0.96, 1000.0);
    final remembered = brand;
    final url = remembered == null
        ? null
        : SchoolLogoService.displayUrlFor(
            remembered.schoolId,
            storedUrl: remembered.logoUrl,
            style: remembered.logoStyle,
          );
    final fallback = Image.asset(
      MayaBrandLogo.assetPath,
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
    final Widget image;
    if (url != null &&
        (url.startsWith('http://') || url.startsWith('https://'))) {
      image = Image.network(
        url,
        width: width,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => fallback,
      );
    } else {
      image = fallback;
    }
    final schoolLogo = url != null &&
        (url.startsWith('http://') || url.startsWith('https://'));
    // School photos often sit on white. Knock that field out and darken the mark.
    // The platform steps mark is already transparent, so it is left as drawn.
    final shown = schoolLogo
        ? ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.78, 0, 0, 0, 0,
              0, 0.78, 0, 0, 0,
              0, 0, 0.78, 0, 0,
              -1.15, -1.15, -1.15, 0, 800,
            ]),
            child: image,
          )
        : image;
    return IgnorePointer(child: shown);
  }
}
