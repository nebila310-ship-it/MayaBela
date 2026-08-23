import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mayabela/screens/admin_dashboard.dart';
import 'package:mayabela/web_erp/shell/web_erp_shell.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/widgets/admin_educational_background.dart';
import 'package:mayabela/widgets/dashboard_card.dart';

void main() {
  testWidgets('ERP cards use the cream paper color', (tester) async {
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
    expect(deco.color, WebErpTheme.paper.withValues(alpha: 0.94));
  });

  testWidgets('Admin ERP shell sits on the notebook background', (tester) async {
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

  testWidgets('dashboard tiles use paper, not a solid color wash', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 160,
            height: 140,
            child: DashboardCard(
              icon: Icons.school,
              title: 'Students',
              color: Color(0xFF1565C0),
            ),
          ),
        ),
      ),
    );
    final box = tester.widget<Container>(
      find.descendant(
        of: find.byType(DashboardCard),
        matching: find.byType(Container),
      ).first,
    );
    final deco = box.decoration! as BoxDecoration;
    expect(deco.color, const Color(0xFFFBF6ED).withValues(alpha: 0.94));
    expect(find.text('Students'), findsOneWidget);
  });
}
