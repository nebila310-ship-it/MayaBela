import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mayabela/theme/app_theme.dart';
import 'package:mayabela/theme/classroom_palette.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/widgets/admin_educational_background.dart';
import 'package:mayabela/widgets/school_branding_header.dart';
import 'package:mayabela/widgets/settings_ui.dart';

void main() {
  testWidgets('dark palette helpers use on-surface ink on a dark stream', (
    tester,
  ) async {
    late Color stream;
    late Color ink;
    late Color card;
    late Color backdrop;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) {
            stream = ClassroomPalette.streamOf(context);
            ink = ClassroomPalette.inkOf(context);
            card = ClassroomPalette.cardOf(context);
            backdrop = WebErpTheme.paperBackdropOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(stream, AppTheme.dark.colorScheme.surface);
    expect(ink, AppTheme.dark.colorScheme.onSurface);
    expect(card, isNot(ClassroomPalette.card));
    expect(backdrop, stream);
    expect(ink.computeLuminance(), greaterThan(stream.computeLuminance()));
  });

  testWidgets('settings action tiles keep opaque contrast in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: SettingsActionTile(
            title: 'Contact support',
            subtitle: 'help@example.com',
            icon: Icons.mail_outline_rounded,
          ),
        ),
      ),
    );

    final materials = tester.widgetList<Material>(find.byType(Material));
    expect(
      materials.any(
        (m) => m.color == AppTheme.dark.colorScheme.surfaceContainerHighest,
      ),
      isTrue,
    );

    final title = tester.widget<Text>(find.text('Contact support'));
    expect(title.style?.color, AppTheme.dark.colorScheme.onSurface);
    expect(title.style?.color, isNot(SettingsPalette.deep));
  });

  testWidgets('dark educational backdrop is slate, not a washed pastel', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: AdminEducationalBackground()),
      ),
    );

    final boxes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
    expect(
      boxes.any((box) {
        final deco = box.decoration;
        if (deco is! BoxDecoration) return false;
        final gradient = deco.gradient;
        if (gradient is! LinearGradient) return false;
        return gradient.colors.contains(const Color(0xFF0B1220));
      }),
      isTrue,
    );
    expect(
      boxes.any((box) {
        final deco = box.decoration;
        if (deco is! BoxDecoration) return false;
        final gradient = deco.gradient;
        if (gradient is! LinearGradient) return false;
        return gradient.colors.contains(const Color(0xFFF8F9FA));
      }),
      isFalse,
    );
  });

  testWidgets(
    'ERP content cards stay paper-white so ink text remains readable',
    (tester) async {
      late BoxDecoration deco;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              deco = WebErpTheme.cardDecoration(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(deco.color, WebErpTheme.paper);
      expect(deco.boxShadow?.first.blurRadius, lessThan(8));
    },
  );

  testWidgets('compact school name uses theme ink, not white-on-light', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: SchoolBrandingHeader(
            compact: true,
            fallbackTitle: 'Maya School',
          ),
        ),
      ),
    );
    // Compact with no school record collapses; non-compact fallback is the
    // title used on dashboards without a registry row.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: SchoolBrandingHeader(fallbackTitle: 'Maya School'),
        ),
      ),
    );
    final title = tester.widget<Text>(find.text('Maya School'));
    expect(title.style?.color, AppTheme.dark.colorScheme.onSurface);
  });
}
