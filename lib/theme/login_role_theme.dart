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
          primary: Color(0xFF1A73E8),
          primaryLight: Color(0xFF8E24AA),
          gradientColors: [
            Color(0xFF1A73E8),
            Color(0xFF00897B),
            Color(0xFF8E24AA),
          ],
          icon: Icons.badge_outlined,
        ),
      AuthService.roleParent => const LoginRoleTheme(
          primary: Color(0xFF00897B),
          primaryLight: Color(0xFF1E8E3E),
          gradientColors: [
            Color(0xFF00897B),
            Color(0xFF12B5CB),
            Color(0xFF1E8E3E),
          ],
          icon: Icons.family_restroom_outlined,
        ),
      AuthService.roleAdmin => const LoginRoleTheme(
          primary: Color(0xFF00897B),
          primaryLight: Color(0xFF1A73E8),
          gradientColors: [
            Color(0xFF00897B),
            Color(0xFF1A73E8),
            Color(0xFF8E24AA),
          ],
          icon: Icons.admin_panel_settings_outlined,
        ),
      AuthService.roleDriver => const LoginRoleTheme(
          primary: Color(0xFFE37400),
          primaryLight: Color(0xFFF9AB00),
          gradientColors: [
            Color(0xFFE37400),
            Color(0xFFF9AB00),
            Color(0xFFD93025),
          ],
          icon: Icons.directions_bus_outlined,
        ),
      AuthService.roleStudent => const LoginRoleTheme(
          primary: Color(0xFF1A73E8),
          primaryLight: Color(0xFF12B5CB),
          gradientColors: [
            Color(0xFF1A73E8),
            Color(0xFF12B5CB),
            Color(0xFFA142F4),
          ],
          icon: Icons.school_outlined,
        ),
      _ => const LoginRoleTheme(
          primary: Color(0xFF1A73E8),
          primaryLight: Color(0xFF00897B),
          gradientColors: [
            Color(0xFF1A73E8),
            Color(0xFF00897B),
            Color(0xFF8E24AA),
          ],
          icon: Icons.login_outlined,
        ),
    };
  }
}
