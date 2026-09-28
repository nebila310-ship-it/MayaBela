import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';

/// One labeled row inside success / info dialogs.
class AdminDialogSummaryItem {
  const AdminDialogSummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

/// Styled action for success dialogs.
class AdminDialogAction {
  const AdminDialogAction({
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final bool primary;
  final IconData? icon;
}

/// Card-style section inside admin form dialogs.
class AdminFormDialogSection extends StatelessWidget {
  const AdminFormDialogSection({
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.14),
                  color.withValues(alpha: 0.04),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: color.withValues(alpha: 0.95),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
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

/// Key-value summary row for success dialogs.
class AdminDialogSummaryRow extends StatelessWidget {
  const AdminDialogSummaryRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Spacing wrapper for dialog form fields.
Widget adminDialogField(Widget child) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: child,
  );
}

const _kAdminDialogTransitionMs = 320;

Future<T?> _showAdminAnimatedDialog<T>({
  required BuildContext context,
  required Widget child,
  bool barrierDismissible = true,
}) async {
  // Flutter web: custom BackdropFilter / full-screen Stack barriers can leave
  // a permanent grey wash after the route is popped. Use stock dialogs there.
  if (kIsWeb) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        final viewInsets = MediaQuery.viewInsetsOf(dialogContext);
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: child,
        );
      },
    );
  }

  final result = await showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: _kAdminDialogTransitionMs),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _AdminDialogHost(
        barrierDismissible: barrierDismissible,
        animation: animation,
        child: child,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, dialogChild) {
      return dialogChild;
    },
  );
  // showGeneralDialog completes on pop, not when the exit animation finishes.
  // Wait so callers can safely setState / dispose controllers used in the dialog.
  await Future<void>.delayed(
    const Duration(milliseconds: _kAdminDialogTransitionMs + 20),
  );
  return result;
}

/// Positions dialog above keyboard and animates backdrop blur.
class _AdminDialogHost extends StatelessWidget {
  const _AdminDialogHost({
    required this.barrierDismissible,
    required this.animation,
    required this.child,
  });

  final bool barrierDismissible;
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    final scale = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final padding = MediaQuery.paddingOf(context);
    final keyboardOpen = viewInsets.bottom > 0;

    return Stack(
      fit: StackFit.expand,
      children: [
        FadeTransition(
          opacity: fade,
          child: IgnorePointer(
            // When faded out, never leave a sticky web hit-target / filter layer.
            ignoring: animation.value < 0.02,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: barrierDismissible ? () => Navigator.pop(context) : null,
              child: kIsWeb
                  // BackdropFilter on Flutter web can leave a permanent grey wash.
                  ? ColoredBox(
                      color: Colors.black.withValues(
                        alpha: 0.45 * animation.value.clamp(0.0, 1.0),
                      ),
                    )
                  : BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 8 * animation.value,
                        sigmaY: 8 * animation.value,
                      ),
                      child: Container(
                        color: Colors.black.withValues(
                          alpha: 0.42 * animation.value,
                        ),
                      ),
                    ),
            ),
          ),
        ),
        AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(
            top: padding.top + 8,
            bottom: viewInsets.bottom + padding.bottom + 12,
            left: 16,
            right: 16,
          ),
          child: Align(
            alignment: keyboardOpen ? Alignment.topCenter : Alignment.center,
            child: FadeTransition(
              opacity: fade,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1).animate(scale),
                child: Material(
                  type: MaterialType.transparency,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<T?> showAdminCustomDialog<T>({
  required BuildContext context,
  required Widget child,
  bool barrierDismissible = true,
}) {
  return _showAdminAnimatedDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    child: child,
  );
}

/// Professional themed form dialog for admin edit/create flows.
Future<bool> showAdminFormDialog({
  required BuildContext context,
  required String title,
  String? subtitle,
  required Color accent,
  IconData icon = Icons.edit_outlined,
  required Widget Function(BuildContext context, StateSetter setDialogState)
      builder,
  String? saveLabel,
  String? cancelLabel,
  String? saveActionLabel,
  bool barrierDismissible = true,
  bool Function(BuildContext dialogContext)? canSave,
  String? Function(BuildContext dialogContext)? saveBlockedReason,
}) async {
  final s = AppLocale.instance.strings;
  final result = await _showAdminAnimatedDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    child: Builder(
      builder: (dialogContext) => _AdminFormDialogShell(
        title: title,
        subtitle: subtitle,
        accent: accent,
        icon: icon,
        saveLabel: saveLabel ?? saveActionLabel ?? s.save,
        cancelLabel: cancelLabel ?? s.cancel,
        saveIcon: Icons.check_rounded,
        builder: builder,
        canSave: canSave,
        saveBlockedReason: saveBlockedReason,
        onCancel: () => Navigator.pop(dialogContext, false),
        onSave: () => Navigator.pop(dialogContext, true),
      ),
    ),
  );
  return result ?? false;
}

/// Success / created summary dialog with structured rows.
Future<void> showAdminSuccessDialog({
  required BuildContext context,
  required String title,
  String? subtitle,
  required Color accent,
  required IconData icon,
  required List<AdminDialogSummaryItem> items,
  String? footnote,
  Widget? extra,
  List<AdminDialogAction>? actions,
  bool barrierDismissible = true,
}) {
  final s = AppLocale.instance.strings;
  final list = actions ??
      [
        AdminDialogAction(
          label: s.done,
          primary: true,
          icon: Icons.check_rounded,
          onPressed: () => Navigator.pop(context),
        ),
      ];
  final primary = list.firstWhere(
    (a) => a.primary,
    orElse: () => list.last,
  );
  AdminDialogAction? secondary;
  if (list.length > 1) {
    secondary = list.firstWhere(
      (a) => a != primary,
      orElse: () => list.first,
    );
  }

  return _showAdminAnimatedDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    child: AdminFormDialogFrame(
      title: title,
      subtitle: subtitle,
      accent: accent,
      icon: icon,
      primaryLabel: primary.label,
      primaryEnabled: true,
      onPrimary: primary.onPressed,
      secondaryLabel: secondary?.label,
      onSecondary: secondary?.onPressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in items)
            AdminDialogSummaryRow(
              icon: item.icon,
              label: item.label,
              value: item.value,
              color: accent,
            ),
          if (extra != null) ...[
            const SizedBox(height: 12),
            extra,
          ],
          if (footnote != null && footnote.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.12)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      footnote,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Confirmation dialog with optional destructive primary action.
Future<bool> showAdminConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  Color accent = const Color(0xFF3949AB),
  IconData icon = Icons.help_outline_rounded,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final s = AppLocale.instance.strings;
  final confirmColor = destructive ? Colors.red.shade700 : accent;
  final result = await _showAdminAnimatedDialog<bool>(
    context: context,
    child: Builder(
      builder: (dialogContext) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Material(
            color: Colors.white,
            elevation: 24,
            shadowColor: confirmColor.withValues(alpha: 0.35),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AdminFormDialogHeader(
                  title: title,
                  accent: confirmColor,
                  icon: icon,
                  cancelLabel: cancelLabel ?? s.cancel,
                  onClose: () => Navigator.pop(dialogContext, false),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: Text(cancelLabel ?? s.cancel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: adminPrimaryButton(
                          label: confirmLabel ?? s.save,
                          color: confirmColor,
                          onPressed: () => Navigator.pop(dialogContext, true),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}

/// Reusable header + scroll body + footer shell for custom dialog flows.
class AdminFormDialogFrame extends StatelessWidget {
  const AdminFormDialogFrame({
    super.key,
    required this.title,
    this.subtitle,
    required this.accent,
    required this.icon,
    required this.primaryLabel,
    required this.onPrimary,
    required this.child,
    this.secondaryLabel,
    this.onSecondary,
    this.primaryEnabled = true,
    this.primaryIcon,
  });

  final String title;
  final String? subtitle;
  final Color accent;
  final IconData icon;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final Widget child;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool primaryEnabled;
  final IconData? primaryIcon;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final cancel = secondaryLabel ?? s.cancel;
    final mq = MediaQuery.of(context);
    final viewInsets = mq.viewInsets;
    final availableHeight = mq.size.height -
        viewInsets.top -
        viewInsets.bottom -
        mq.padding.top -
        mq.padding.bottom -
        32;
    final maxH = availableHeight.clamp(260.0, mq.size.height * 0.82);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 520, maxHeight: maxH),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.white,
          elevation: 28,
          shadowColor: accent.withValues(alpha: 0.35),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AdminFormDialogHeader(
                title: title,
                subtitle: subtitle,
                accent: accent,
                icon: icon,
                cancelLabel: cancel,
                onClose: onSecondary ?? () => Navigator.pop(context),
              ),
              Flexible(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      8 + (viewInsets.bottom > 0 ? 12 : 0),
                    ),
                    child: child,
                  ),
                ),
              ),
              _AdminFormDialogFooter(
                accent: accent,
                cancelLabel: cancel,
                primaryLabel: primaryLabel,
                primaryEnabled: primaryEnabled,
                primaryIcon: primaryIcon,
                onCancel: onSecondary,
                onPrimary: onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminFormDialogFooter extends StatelessWidget {
  const _AdminFormDialogFooter({
    required this.accent,
    required this.cancelLabel,
    required this.primaryLabel,
    required this.primaryEnabled,
    required this.onCancel,
    required this.onPrimary,
    this.primaryIcon,
  });

  final Color accent;
  final String cancelLabel;
  final String primaryLabel;
  final bool primaryEnabled;
  final VoidCallback? onCancel;
  final VoidCallback? onPrimary;
  final IconData? primaryIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.paddingOf(context).bottom * 0.25,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          if (onCancel != null) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: Text(cancelLabel),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: BorderSide(color: Colors.grey.shade300),
                  foregroundColor: Colors.grey.shade800,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: onCancel != null ? 2 : 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: primaryEnabled
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: adminPrimaryButton(
                label: primaryLabel,
                color: accent,
                onPressed: primaryEnabled ? onPrimary : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminFormDialogHeader extends StatelessWidget {
  const _AdminFormDialogHeader({
    required this.title,
    this.subtitle,
    required this.accent,
    required this.icon,
    required this.cancelLabel,
    required this.onClose,
  });

  final String title;
  final String? subtitle;
  final Color accent;
  final IconData icon;
  final String cancelLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 8, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent,
            Color.lerp(accent, Colors.white, 0.15)!,
            accent.withValues(alpha: 0.88),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 36,
            top: -20,
            child: Icon(
              icon,
              size: 110,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Material(
                color: Colors.white.withValues(alpha: 0.15),
                shape: const CircleBorder(),
                child: IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.white,
                  tooltip: cancelLabel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminFormDialogShell extends StatefulWidget {
  const _AdminFormDialogShell({
    required this.title,
    this.subtitle,
    required this.accent,
    required this.icon,
    required this.saveLabel,
    required this.cancelLabel,
    required this.builder,
    required this.onCancel,
    required this.onSave,
    this.saveIcon,
    this.canSave,
    this.saveBlockedReason,
  });

  final String title;
  final String? subtitle;
  final Color accent;
  final IconData icon;
  final String saveLabel;
  final String cancelLabel;
  final IconData? saveIcon;
  final Widget Function(BuildContext context, StateSetter setDialogState)
      builder;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final bool Function(BuildContext dialogContext)? canSave;
  final String? Function(BuildContext dialogContext)? saveBlockedReason;

  @override
  State<_AdminFormDialogShell> createState() => _AdminFormDialogShellState();
}

class _AdminFormDialogShellState extends State<_AdminFormDialogShell> {
  bool _canSaveNow(BuildContext dialogContext) {
    if (widget.canSave == null) return true;
    return widget.canSave!(dialogContext);
  }

  void _handleSave(BuildContext dialogContext) {
    final blocked = widget.saveBlockedReason?.call(dialogContext);
    if (blocked != null && blocked.isNotEmpty) {
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        SnackBar(content: Text(blocked)),
      );
      return;
    }
    if (widget.canSave != null && !widget.canSave!(dialogContext)) {
      return;
    }
    widget.onSave();
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormDialogFrame(
      title: widget.title,
      subtitle: widget.subtitle,
      accent: widget.accent,
      icon: widget.icon,
      primaryLabel: widget.saveLabel,
      primaryIcon: widget.saveIcon,
      primaryEnabled: _canSaveNow(context),
      onPrimary: () => _handleSave(context),
      onSecondary: widget.onCancel,
      child: StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return widget.builder(dialogContext, (fn) {
            setDialogState(fn);
            if (widget.canSave != null) {
              setState(() {});
            }
          });
        },
      ),
    );
  }
}
