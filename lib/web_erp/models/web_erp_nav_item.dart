import 'package:flutter/material.dart';

class WebErpNavItem {
  const WebErpNavItem({
    required this.id,
    required this.label,
    required this.icon,
    this.section,
    this.badgeId,
    this.isDivider = false,
    this.isLogout = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final String? section;
  final String? badgeId;
  final bool isDivider;
  final bool isLogout;
}
