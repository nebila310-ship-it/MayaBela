import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mayabela/web_erp/widgets/web_erp_hscroll.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'narrow parent of a wide child has a real horizontal scroll extent',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.binding.setSurfaceSize(const Size(400, 300));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 200,
                child: WebErpHScroll(
                  minChildWidth: 1200,
                  controller: controller,
                  child: const SizedBox(
                    width: 1200,
                    height: 80,
                    child: Text('wide-child'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.hasClients, isTrue);
      expect(controller.position.maxScrollExtent, greaterThan(700));
      expect(controller.offset, 0);

      await tester.drag(
        find.byKey(const ValueKey('web-erp-hscroll-view')),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(200));
    },
  );

  testWidgets('unbounded-height parent still pins horizontal viewport', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 360,
              child: WebErpHScroll(
                minChildWidth: 900,
                controller: controller,
                child: const SizedBox(height: 40, child: Text('in-list')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.hasClients, isTrue);
    expect(controller.position.maxScrollExtent, greaterThan(400));
  });

  testWidgets(
    'bounded-height parent of a tall child has a real vertical extent',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 300));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 160,
                child: WebErpHScroll(
                  minChildWidth: 900,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(height: 80, child: Text('row-a')),
                      SizedBox(height: 80, child: Text('row-b')),
                      SizedBox(height: 80, child: Text('row-c')),
                      SizedBox(height: 80, child: Text('row-d')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('row-a'), findsOneWidget);
      final verticalFinder = find.byWidgetPredicate(
        (widget) => widget is Scrollable && widget.axis == Axis.vertical,
      );
      expect(verticalFinder, findsWidgets);
      final vertical = tester.widget<Scrollable>(verticalFinder.first);
      expect(vertical.controller, isNotNull);
      expect(vertical.controller!.position.maxScrollExtent, greaterThan(100));
    },
  );
}
