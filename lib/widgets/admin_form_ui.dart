import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:mayabela/web_erp/shell/web_erp_navigation_scope.dart';

/// Shared colorful styling for admin enrollment forms.
class AdminFormTheme {
  AdminFormTheme._({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.icon,
  });

  final Color primary;
  final Color secondary;
  final Color accent;
  final IconData icon;

  static AdminFormTheme teacher = AdminFormTheme._(
    primary: const Color(0xFF3949AB),
    secondary: const Color(0xFF5C6BC0),
    accent: const Color(0xFF7986CB),
    icon: Icons.school_outlined,
  );

  static AdminFormTheme driver = AdminFormTheme._(
    primary: const Color(0xFFE65100),
    secondary: const Color(0xFFEF6C00),
    accent: const Color(0xFFFFB74D),
    icon: Icons.directions_bus_outlined,
  );

  static AdminFormTheme student = AdminFormTheme._(
    primary: const Color(0xFF00796B),
    secondary: const Color(0xFF26A69A),
    accent: const Color(0xFF4DB6AC),
    icon: Icons.person_outline,
  );

  LinearGradient get headerGradient => LinearGradient(
        colors: [primary, secondary, accent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get backgroundGradient => LinearGradient(
        colors: [
          primary.withValues(alpha: 0.08),
          accent.withValues(alpha: 0.04),
          Colors.white,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
}

class AdminFormScaffold extends StatelessWidget {
  const AdminFormScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.theme,
    required this.body,
  });

  final String title;
  final String subtitle;
  final AdminFormTheme theme;
  final List<Widget> body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: theme.backgroundGradient),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 132,
              pinned: true,
              backgroundColor: theme.primary,
              foregroundColor: Colors.white,
              leading: BackButton(
                color: Colors.white,
                onPressed: () => webErpHandleBack(context),
              ),
              title: Text(title, style: const TextStyle(fontSize: 18)),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Container(
                  decoration: BoxDecoration(gradient: theme.headerGradient),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -20,
                        top: -10,
                        child: Icon(
                          theme.icon,
                          size: 120,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        bottom: 16,
                        right: 16,
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList(delegate: SliverChildListDelegate(body)),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminFormSection extends StatelessWidget {
  const AdminFormSection({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: color.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration adminFieldDecoration({
  required String label,
  String? hint,
  IconData? icon,
  Color? accent,
}) {
  final c = accent ?? Colors.indigo;
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon != null ? Icon(icon, color: c, size: 22) : null,
    filled: true,
    fillColor: c.withValues(alpha: 0.04),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c.withValues(alpha: 0.15)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c.withValues(alpha: 0.15)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: 1.5),
    ),
  );
}

class AdminPhotoPicker extends StatelessWidget {
  const AdminPhotoPicker({
    super.key,
    this.photo,
    this.photoBytes,
    required this.hint,
    required this.accent,
    required this.onTap,
  });

  final File? photo;
  final Uint8List? photoBytes;
  final String hint;
  final Color accent;
  final VoidCallback onTap;

  ImageProvider? get _image {
    if (photoBytes != null && photoBytes!.isNotEmpty) {
      return MemoryImage(photoBytes!);
    }
    if (photo != null) return FileImage(photo!);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [accent, accent.withValues(alpha: 0.6)],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white,
              backgroundImage: image,
              child: image == null
                  ? Icon(
                      Icons.person,
                      size: 48,
                      color: accent.withValues(alpha: 0.5),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hint,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      ],
    );
  }
}

Widget adminPrimaryButton({
  required String label,
  required Color color,
  required VoidCallback? onPressed,
  bool loading = false,
}) {
  return DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: LinearGradient(
        colors: onPressed == null
            ? [Colors.grey.shade400, Colors.grey.shade500]
            : [color, color.withValues(alpha: 0.75)],
      ),
      boxShadow: onPressed == null
          ? null
          : [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
    ),
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: loading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    ),
  );
}

Widget adminStatusChip({
  required String label,
  required Color color,
  required IconData icon,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}
