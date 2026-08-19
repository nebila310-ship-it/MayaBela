import 'package:flutter/material.dart';

import 'package:mayabela/widgets/professional_qr_scanner.dart';
import 'package:mayabela/widgets/qr_scanner_theme.dart';

/// Bright full-page QR scanner layout with mode switching and status feedback.
class AdvancedQrScannerShell extends StatelessWidget {
  const AdvancedQrScannerShell({
    super.key,
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.modeOptions,
    required this.selectedModeIndex,
    required this.onModeSelected,
    required this.onCode,
    this.bannerText,
    this.statusMessage,
    this.statusSuccess = false,
    this.scannerHeight = 360,
    this.unavailableMessage = 'Camera scanner is not available on this device.',
    this.errorMessage = 'Unable to start the camera scanner.',
    this.permissionDeniedMessage =
        'Camera permission is required to scan QR codes.',
    this.startingMessage = 'Starting camera…',
    this.retryLabel = 'Try again',
    this.bottomChild,
  });

  final QrScannerTheme theme;
  final String title;
  final String subtitle;
  final List<QrScannerModeOption> modeOptions;
  final int selectedModeIndex;
  final ValueChanged<int> onModeSelected;
  final void Function(String code) onCode;
  final String? bannerText;
  final String? statusMessage;
  final bool statusSuccess;
  final double scannerHeight;
  final String unavailableMessage;
  final String errorMessage;
  final String permissionDeniedMessage;
  final String startingMessage;
  final String retryLabel;
  final Widget? bottomChild;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: theme.pageGradient),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (bannerText != null && bannerText!.trim().isNotEmpty) ...[
            _InfoBanner(text: bannerText!, theme: theme),
            const SizedBox(height: 12),
          ],
          _ModeSelector(
            options: modeOptions,
            selectedIndex: selectedModeIndex,
            onSelected: onModeSelected,
          ),
          const SizedBox(height: 16),
          ProfessionalQrScannerPanel(
            theme: theme,
            title: title,
            subtitle: subtitle,
            height: scannerHeight,
            onCode: onCode,
            statusMessage: statusMessage,
            statusSuccess: statusSuccess,
            unavailableMessage: unavailableMessage,
            errorMessage: errorMessage,
            permissionDeniedMessage: permissionDeniedMessage,
            startingMessage: startingMessage,
            retryLabel: retryLabel,
          ),
          if (bottomChild != null) ...[
            const SizedBox(height: 16),
            bottomChild!,
          ],
          if (theme.footerHint != null) ...[
            const SizedBox(height: 14),
            Text(
              theme.footerHint!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Colors.blueGrey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AdvancedQrScannerAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const AdvancedQrScannerAppBar({
    super.key,
    required this.title,
    required this.theme,
    this.subtitle,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final QrScannerTheme theme;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize {
    var height = subtitle != null ? 88.0 : kToolbarHeight;
    if (bottom != null) {
      height += bottom!.preferredSize.height;
    }
    return Size.fromHeight(height);
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      foregroundColor: Colors.white,
      bottom: bottom,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: theme.headerGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: subtitle != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ],
            )
          : Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text, required this.theme});

  final String text;
  final QrScannerTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(theme.bannerIcon, color: theme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.primary.withValues(alpha: 0.95),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<QrScannerModeOption> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _ModeChip(
              option: options[i],
              selected: selectedIndex == i,
              onTap: () => onSelected(i),
            ),
          ),
        ],
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final QrScannerModeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? option.activeColor : Colors.white;
    final fg = selected ? Colors.white : option.activeColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: option.activeColor.withValues(alpha: selected ? 0 : 0.35),
              width: 1.4,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: option.activeColor.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(option.icon, color: fg, size: 26),
              const SizedBox(height: 6),
              Text(
                option.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
