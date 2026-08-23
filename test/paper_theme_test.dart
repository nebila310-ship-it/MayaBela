import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mayabela/screens/admin_dashboard.dart';
import 'package:mayabela/theme/classroom_palette.dart';
import 'package:mayabela/web_erp/shell/web_erp_shell.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/widgets/admin_educational_background.dart';
import 'package:mayabela/widgets/dashboard_card.dart';

void main() {
  testWidgets('ERP cards use the Classroom white surface', (tester) async {
    late BoxDecoration deco;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            deco = WebErpTheme.cardDecoration(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(deco.color, WebErpTheme.paper);
    expect(WebErpTheme.paper, ClassroomPalette.card);
    expect(WebErpTheme.primary, ClassroomPalette.teal);
  });

  testWidgets('Admin ERP shell sits on the Classroom stream background',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            expect(const AdminDashboard().build(context), isA<WebErpAdminShell>());
            return const AdminEducationalBackground();
          },
        ),
      ),
    );
    expect(find.byType(AdminEducationalBackground), findsOneWidget);
  });

  testWidgets('dashboard tiles use a colorful Classroom class banner',
      (tester) async {
    const accent = Color(0xFF1565C0);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 160,
            height: 140,
            child: DashboardCard(
              icon: Icons.school,
              title: 'Students',
              color: accent,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Students'), findsOneWidget);
    expect(find.byIcon(Icons.school), findsOneWidget);
    final boxes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
    expect(
      boxes.any((box) {
        final deco = box.decoration;
        return deco is BoxDecoration &&
            deco.gradient is LinearGradient &&
            (deco.gradient as LinearGradient).colors.first == accent;
      }),
      isTrue,
    );
  });
}
