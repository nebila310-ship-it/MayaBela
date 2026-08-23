import 'package:flutter_test/flutter_test.dart';

import 'package:mayabela/theme/classroom_palette.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';

void main() {
  test('Classroom palette cycles distinct class colors', () {
    expect(ClassroomPalette.classes.length, greaterThanOrEqualTo(8));
    expect(ClassroomPalette.at(0), ClassroomPalette.teal);
    expect(ClassroomPalette.at(1), isNot(ClassroomPalette.at(0)));
    expect(ClassroomPalette.forKey('students'), isNotNull);
  });

  test('ERP theme uses Classroom stream tokens', () {
    expect(WebErpTheme.primary, ClassroomPalette.teal);
    expect(WebErpTheme.paper, ClassroomPalette.card);
    expect(WebErpTheme.paperBackdrop, ClassroomPalette.stream);
    expect(WebErpTheme.sidebarBg, ClassroomPalette.card);
  });
}
