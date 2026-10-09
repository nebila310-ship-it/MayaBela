import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/screens/my_classes_screen.dart';
import 'package:mayabela/widgets/class_tools_panel.dart';
import 'package:mayabela/widgets/dashboard_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ClassAssignment assignment() => ClassAssignment(
    className: 'Grade 2A',
    role: ClassTeacherRole.homeroom,
    room: 'Room 12',
    schedule: 'Mon–Fri',
    students: [
      StudentRef(id: 'STU-1', name: 'Maya', grade: '2'),
      StudentRef(id: 'STU-2', name: 'Abel', grade: '2'),
    ],
  );

  testWidgets('phone class tools keep compact chips', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(390, 844)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: ClassToolsPanel(className: 'Grade 2A', isHomeroom: true),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ClassToolChip), findsWidgets);
    expect(find.byType(DashboardCard), findsNothing);
    final grid = tester.widget<GridView>(
      find.byKey(const Key('class-tools-grid')),
    );
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 3);
  });

  testWidgets('PC class tools use colorful classroom cards', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(1280, 800)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: ClassToolsPanel(className: 'Grade 2A', isHomeroom: true),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(DashboardCard), findsWidgets);
    expect(find.byType(ClassToolChip), findsNothing);
    final grid = tester.widget<GridView>(
      find.byKey(const Key('class-tools-grid')),
    );
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 4);
  });

  testWidgets('PC class detail shows a colorful hero banner', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 800)),
          child: ClassDetailScreen(assignment: assignment()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('class-hero-banner')), findsOneWidget);
    expect(find.byType(DashboardCard), findsWidgets);
    expect(find.text('Grade 2A'), findsWidgets);
  });

  testWidgets('phone class detail keeps the compact header', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: ClassDetailScreen(assignment: assignment()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('class-hero-banner')), findsNothing);
    expect(find.byType(ClassToolChip), findsWidgets);
    expect(find.text(AppLocale.instance.strings.homeroomClass), findsOneWidget);
  });
}
