import 'package:flutter/material.dart';

import 'package:mayabela/models/remembered_school_brand.dart';
import 'package:mayabela/platform/login_chrome_brand.dart';
import 'package:mayabela/services/school_logo_service.dart';
import 'package:mayabela/widgets/fancy_loading_ring.dart';
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const FancyLoadingRing(
                        key: ValueKey('splash-loading-ring'),
                        size: 200,
                        showLabel: false,
                      ),
                      if (remembered == null)
                        const MayaBrandLogo(height: 128)
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
                          height: 128,
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
                const FancyLoadingRing(
                  key: ValueKey('splash-loading-caption'),
                  size: 0,
                  showLabel: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
