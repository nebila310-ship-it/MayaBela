import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mayabela/models/admission_application.dart';
import 'package:mayabela/models/admission_extra_program.dart';
import 'package:mayabela/screens/public_admission_apply_screen.dart';

void main() {
  test('extra programme catalogue covers film, sport, AI, and arts', () {
    expect(
      AdmissionExtraPrograms.all.map((p) => p.id),
      containsAll([
        'film_editing',
        'football',
        'ai_learning',
        'visual_arts',
        'music',
        'dance',
        'drama',
        'creative_writing',
        'photography',
      ]),
    );
    expect(AdmissionExtraPrograms.groups, containsAll(['Media', 'Sport', 'STEM', 'Art & creative']));
    expect(
      AdmissionExtraPrograms.titlesFor(['film_editing', 'ai_learning']),
      ['Film & editing class', 'AI learning class'],
    );
  });

  test('required admission documents include identity and prior reports', () {
    final docs = AdmissionApplication.defaultDocuments(
      submittedIds: {'birth-certificate'},
    );
    expect(docs.map((d) => d.id), containsAll([
      'birth-certificate',
      'previous-school-reports',
      'parent-national-id',
    ]));
    expect(
      docs.firstWhere((d) => d.id == 'birth-certificate').submitted,
      isTrue,
    );
    expect(
      docs.firstWhere((d) => d.id == 'parent-national-id').submitted,
      isFalse,
    );
  });

  testWidgets('public apply form shows attachments and extra programmes',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PublicAdmissionApplyScreen()),
    );
    await tester.pump();

    expect(find.text('Apply for admission'), findsOneWidget);
    expect(find.textContaining('Birth certificate'), findsWidgets);
    expect(find.textContaining('Previous school reports'), findsWidgets);
    expect(find.textContaining('Parent / guardian national ID'), findsWidgets);
    expect(find.text('Film & editing class'), findsOneWidget);
    expect(find.text('Sport / football class'), findsOneWidget);
    expect(find.text('AI learning class'), findsOneWidget);
    expect(find.text('Visual arts'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Submit application'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Submit application'));
    await tester.pump();
    expect(
      find.textContaining('School ID, student name, date of birth'),
      findsOneWidget,
    );
  });
}
