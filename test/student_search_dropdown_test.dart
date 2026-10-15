import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mayabela/widgets/student_search_dropdown.dart';

void main() {
  const options = [
    StudentSearchOption(id: '1', name: 'Nabil Ahmed', studentId: 'STU-1'),
    StudentSearchOption(id: '2', name: 'Nahom Yared', studentId: 'STU-2'),
    StudentSearchOption(id: '3', name: 'Liya Solomon', studentId: 'STU-3'),
  ];

  testWidgets('student dropdown searches and selects a match', (tester) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentSearchDropdown(
            options: options,
            selectedId: '1',
            onSelected: (id) => picked = id,
          ),
        ),
      ),
    );

    expect(find.text('Nabil Ahmed'), findsOneWidget);
    expect(find.text('Nahom Yared'), findsNothing);

    await tester.tap(find.text('Nabil Ahmed'));
    await tester.pumpAndSettle();

    expect(find.text('Search by name or ID'), findsOneWidget);
    expect(find.text('Nahom Yared'), findsOneWidget);
    expect(find.text('Liya Solomon'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'nah');
    await tester.pumpAndSettle();

    expect(find.text('Nahom Yared'), findsOneWidget);
    expect(find.text('Liya Solomon'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Nabil Ahmed'), findsNothing);

    await tester.tap(find.text('Nahom Yared'));
    await tester.pumpAndSettle();

    expect(picked, '2');
    expect(find.text('Search by name or ID'), findsNothing);
  });

  testWidgets('student search matches a student id', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentSearchDropdown(
            options: options,
            selectedId: '1',
            onSelected: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Nabil Ahmed'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'stu-3');
    await tester.pumpAndSettle();

    expect(find.text('Liya Solomon'), findsOneWidget);
    expect(find.text('Nahom Yared'), findsNothing);
  });

  testWidgets('an empty search result says no students match', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentSearchDropdown(
            options: options,
            selectedId: '1',
            onSelected: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Nabil Ahmed'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();

    expect(find.text('No matching students'), findsOneWidget);
  });
}
