import 'package:flutter/material.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/theme/teacher_theme.dart';

/// Visual theme for the login screen — mirrors each role dashboard palette.
class LoginRoleTheme {
  const LoginRoleTheme({
    required this.primary,
    required this.primaryLight,
    required this.gradientColors,
    required this.icon,
  });

  final Color primary;
  final Color primaryLight;
  final List<Color> gradientColors;
  final IconData icon;

  Color get surfaceTint => primary.withValues(alpha: 0.08);
  Color get borderTint => primary.withValues(alpha: 0.22);
  Color get shadowTint => primary.withValues(alpha: 0.28);
  Color get onPrimary => Colors.white;
  Color get taglineColor => Color.lerp(primary, Colors.black, 0.35)!;

  static LoginRoleTheme forRole(String roleKey) {
    return switch (roleKey) {
      AuthService.roleTeacher => const LoginRoleTheme(
          primary: TeacherTheme.primaryDark,
          primaryLight: TeacherTheme.primary,
          gradientColors: TeacherTheme.gradient,
          icon: Icons.school_outlined,
        ),
      AuthService.roleStaff => const LoginRoleTheme(
          primary: Color(0xFF1B4F72),
          primaryLight: Color(0xFF2874A6),
          gradientColors: [
            Color(0xFF1B4F72),
            Color(0xFF2874A6),
            Color(0xFF5DADE2),
          ],
          icon: Icons.badge_outlined,
        ),
      AuthService.roleParent => const LoginRoleTheme(
          primary: Color(0xFF00695C),
          primaryLight: Color(0xFF00897B),
          gradientColors: [
            Color(0xFF00695C),
            Color(0xFF00897B),
            Color(0xFF26A69A),
          ],
          icon: Icons.family_restroom_outlined,
        ),
      AuthService.roleAdmin => const LoginRoleTheme(
          primary: Color(0xFF4527A0),
          primaryLight: Color(0xFF5E35B1),
          gradientColors: [
            Color(0xFF4527A0),
            Color(0xFF5E35B1),
            Color(0xFF7E57C2),
          ],
          icon: Icons.admin_panel_settings_outlined,
        ),
      AuthService.roleDriver => const LoginRoleTheme(
          primary: Color(0xFFE65100),
          primaryLight: Color(0xFFF57C00),
          gradientColors: [
            Color(0xFFE65100),
            Color(0xFFF57C00),
            Color(0xFFFFB74D),
          ],
          icon: Icons.directions_bus_outlined,
        ),
      AuthService.roleStudent => const LoginRoleTheme(
          primary: Color(0xFF1565C0),
          primaryLight: Color(0xFF1976D2),
          gradientColors: [
            Color(0xFF1565C0),
            Color(0xFF1976D2),
            Color(0xFF42A5F5),
          ],
          icon: Icons.school_outlined,
        ),
      _ => const LoginRoleTheme(
          primary: Color(0xFF1976D2),
          primaryLight: Color(0xFF42A5F5),
          gradientColors: [
            Color(0xFF1976D2),
            Color(0xFF42A5F5),
            Color(0xFFBBDEFB),
          ],
          icon: Icons.login_outlined,
        ),
    };
  }
}
