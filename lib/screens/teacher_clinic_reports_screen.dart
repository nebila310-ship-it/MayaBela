import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/student_support_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/theme/teacher_theme.dart';
import 'package:mayabela/widgets/clinic_teacher_report_list.dart';

/// Homeroom tile: clinic and incident reports for this teacher's classes.
class TeacherClinicReportsScreen extends StatefulWidget {
  const TeacherClinicReportsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<TeacherClinicReportsScreen> createState() =>
      _TeacherClinicReportsScreenState();
}

class _TeacherClinicReportsScreenState
    extends State<TeacherClinicReportsScreen> {
  @override
  void initState() {
    super.initState();
    StudentSupportService.instance.ensureLoaded();
  }

  List<String> get _classes =>
      TeacherAccessService.instance.homeroomClassNames;

  @override
  Widget build(BuildContext context) {
    final body = ClinicTeacherReportsBody(
      classNames: _classes,
      schoolId: AuthService.activeSchoolId,
    );
    if (widget.embedded) return body;
    return Scaffold(
      backgroundColor: const Color(0xFFCFDBEA),
      appBar: AppBar(
        backgroundColor: TeacherTheme.primaryDark,
        title: Text(
          AppLocale.instance.strings.dashboardTitle(
            'clinic_reports',
            roleKey: AuthService.roleTeacher,
          ),
        ),
      ),
      body: body,
    );
  }
}
