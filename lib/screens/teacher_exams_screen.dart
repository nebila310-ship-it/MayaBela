import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/theme/teacher_theme.dart';
import 'package:mayabela/web_erp/pages/web_exam_desk_page.dart';

/// Teacher dashboard: own categorized bank, school vault, and scoring.
class TeacherExamsScreen extends StatelessWidget {
  const TeacherExamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCFDBEA),
      appBar: AppBar(
        backgroundColor: TeacherTheme.primaryDark,
        title: Text(AppLocale.instance.strings.dashboardTitle('exams')),
      ),
      body: const WebExamDeskPage(),
    );
  }
}
