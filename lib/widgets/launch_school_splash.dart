import 'package:flutter/material.dart';

import 'package:mayabela/models/remembered_school_brand.dart';
import 'package:mayabela/models/school_logo_style.dart';
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (remembered == null) ...[
                  const MayaBrandLogo(height: 128),
                ] else ...[
                  Text(
                    remembered.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.indigo.shade900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (remembered.logoStyle == SchoolLogoStyle.circular)
                    Center(
                      child: SchoolLogoDisplay(
                        imagePath: remembered.logoPath,
                        networkUrl: remembered.logoUrl,
                        style: remembered.logoStyle,
                        height: 128,
                      ),
                    )
                  else
                    SchoolLogoDisplay(
                      imagePath: remembered.logoPath,
                      networkUrl: remembered.logoUrl,
                      style: remembered.logoStyle,
                      height: 128,
                    ),
                ],
                const SizedBox(height: 28),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
