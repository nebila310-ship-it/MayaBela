import 'package:flutter/material.dart';

import 'package:mayabela/models/remembered_school_brand.dart';
import 'package:mayabela/platform/login_chrome_brand.dart';
import 'package:mayabela/services/school_logo_service.dart';
import 'package:mayabela/widgets/education_splash_loader.dart';
import 'package:mayabela/widgets/maya_brand_logo.dart';
import 'package:mayabela/widgets/school_logo_display.dart';

/// First Flutter frame while critical bootstrap runs.
/// Uses the remembered school when one exists; otherwise Maya.
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
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const EducationSplashLoader(
                          key: ValueKey('splash-loading-ring'),
                          size: 240,
                          showLabel: false,
                        ),
                        if (remembered == null)
                          const MayaBrandLogo(height: 112)
                        else
                          SchoolLogoDisplay(
                            schoolId: remembered.schoolId,
                            imagePath: remembered.logoPath,
                            networkUrl: SchoolLogoService.displayUrlFor(
                              remembered.schoolId,
                              storedUrl: remembered.logoUrl,
                              style: remembered.logoStyle,
                            ),
                            style: remembered.logoStyle,
                            height: 112,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
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
          ),
        ),
      ),
    );
  }
}
