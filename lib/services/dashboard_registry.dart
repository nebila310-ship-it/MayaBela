import 'package:flutter/material.dart';

class DashboardEntry {
  const DashboardEntry({
    required this.id,
    required this.icon,
    required this.color,
    required this.builder,
    this.isVisible,
  });

  final String id;
  final IconData icon;
  final Color color;
  final Widget Function(BuildContext context) builder;

  /// When set, evaluated at dashboard build time (after login) to show/hide tiles.
  final bool Function()? isVisible;
}

/// Defines a labeled group of dashboard tile ids (admin / teacher layouts).
class DashboardSectionDefinition {
  const DashboardSectionDefinition({
    required this.title,
    required this.entryIds,
    this.icon,
  });

  final String title;
  final IconData? icon;
  final List<String> entryIds;
}

class BuiltDashboardSection {
  const BuiltDashboardSection({
    required this.title,
    required this.cards,
    this.icon,
  });

  final String title;
  final IconData? icon;
  final List<Widget> cards;
}

class DashboardRegistry {
  static List<String> defaultOrderFor(String roleKey) {
    return visibleEntriesFor(roleKey).map((entry) => entry.id).toList();
  }

  static List<DashboardEntry> entriesForRole(String roleKey) {
    return switch (roleKey) {
      'teacher' => _teacherEntries,
      'staff' => _staffEntries,
      'parent' => _parentEntries,
      'student' => _studentEntries,
      'admin' => _adminEntries,
      'driver' => _driverEntries,
      _ => const [],
    };
  }

  static DashboardEntry? find(String roleKey, String id) {
    try {
      return entriesForRole(roleKey).firstWhere((entry) => entry.id == id);
    } catch (_) {
      return null;
    }
  }

  static bool shouldShow(DashboardEntry entry) {
    final visible = entry.isVisible;
    return visible == null || visible();
  }

  static List<DashboardEntry> visibleEntriesFor(String roleKey) {
    return entriesForRole(roleKey).where(shouldShow).toList();
  }

  static List<DashboardEntry> _teacherEntries = [];
  static List<DashboardEntry> _staffEntries = [];
  static List<DashboardEntry> _parentEntries = [];
  static List<DashboardEntry> _studentEntries = [];
  static List<DashboardEntry> _adminEntries = [];
  static List<DashboardEntry> _driverEntries = [];

  static void registerTeacherEntries(List<DashboardEntry> entries) {
    _teacherEntries = entries;
  }

  static void registerStaffEntries(List<DashboardEntry> entries) {
    _staffEntries = entries;
  }

  static void registerParentEntries(List<DashboardEntry> entries) {
    _parentEntries = entries;
  }

  static void registerStudentEntries(List<DashboardEntry> entries) {
    _studentEntries = entries;
  }

  static void registerAdminEntries(List<DashboardEntry> entries) {
    _adminEntries = entries;
  }

  static void registerDriverEntries(List<DashboardEntry> entries) {
    _driverEntries = entries;
  }
}
