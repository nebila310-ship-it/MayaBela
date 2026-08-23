import 'package:flutter/material.dart';

import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/widgets/admin_educational_background.dart';

/// Hosts a web-ERP page inside a mobile-friendly Scaffold with AppBar + back.
///
/// Keeps one feature surface for web and mobile: same page widget, same
/// services/RBAC — only the chrome differs on phone.
class MobileErpHost extends StatelessWidget {
  const MobileErpHost({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.backgroundColor,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? WebErpTheme.paperBackdrop,
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AdminEducationalBackground(accentColor: WebErpTheme.primary),
          SafeArea(child: child),
        ],
      ),
    );
  }
}
