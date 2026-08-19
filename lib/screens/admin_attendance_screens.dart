import 'package:flutter/material.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/attendance_export_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/admin_edit_dialog.dart';

class AdminAttendanceReportsScreen extends StatefulWidget {
  const AdminAttendanceReportsScreen({super.key});

  @override
  State<AdminAttendanceReportsScreen> createState() =>
      _AdminAttendanceReportsScreenState();
}

class _AdminAttendanceReportsScreenState
    extends State<AdminAttendanceReportsScreen> {
  final _data = SchoolDataService.instance;
  DateTime _selectedDate = DateTime.now();
  bool _exporting = false;

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _exportAttendance() async {
    final s = AppLocale.instance.strings;
    final range = await showAdminCustomDialog<({DateTime from, DateTime to})>(
      context: context,
      child: _ExportAttendanceDialog(initialDate: _selectedDate),
    );
    if (range == null || !mounted) return;

    setState(() => _exporting = true);
    AttendanceExportResult? export;
    try {
      export = await AttendanceExportService.instance.buildExcelExport(
        fromDate: range.from,
        toDate: range.to,
        labels: AttendanceExportLabels.fromStrings(s),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.exportAttendanceFailed),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      if (mounted) setState(() => _exporting = false);
      return;
    }

    if (!mounted) return;
    setState(() => _exporting = false);

    final channel = await showModalBottomSheet<AttendanceShareChannel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AttendanceShareSheet(export: export!),
    );

    if (channel == null || !mounted) return;

    setState(() => _exporting = true);
    try {
      final outcome = await AttendanceExportService.instance.shareViaChannel(
        export: export,
        channel: channel,
      );
      if (!mounted) return;
      if (channel == AttendanceShareChannel.download) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              outcome.usedIosSaveSheet
                  ? s.exportAttendanceIosSaveHint
                  : s.attendanceDownloadedTo(outcome.file.path),
            ),
            backgroundColor: Colors.green.shade700,
            duration: Duration(seconds: outcome.usedIosSaveSheet ? 5 : 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.exportAttendanceSuccess),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.exportAttendanceFailed),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _openStatusReport(AttendanceStatus status, DailyAttendanceReport report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminAttendanceStatusScreen(
          status: status,
          report: report,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final report = _data.buildDailyAttendanceReport(_selectedDate);
        final hasData = report.totalCount > 0;

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6FB),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1A237E),
            foregroundColor: Colors.white,
            elevation: 0,
            title: Text(s.attendanceReportsTitle),
            actions: [
              if (_exporting)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              else
                IconButton(
                  tooltip: s.exportAttendanceExcel,
                  onPressed: _exportAttendance,
                  icon: const Icon(Icons.download_rounded),
                ),
            ],
          ),
          body: ListView(
            padding: listPagePadding(context),
            children: [
              _ReportHeaderCard(
                dateLabel: _formatDate(_selectedDate),
                onChangeDate: _pickDate,
                report: report,
                hasData: hasData,
              ),
              const SizedBox(height: 14),
              _ExportExcelButton(
                enabled: !_exporting,
                onPressed: _exportAttendance,
              ),
              const SizedBox(height: 20),
              if (hasData) ...[
                _StatusReportButton(
                  label: s.absents,
                  count: report.absentCount,
                  subtitle: s.tapGradeToInvestigate,
                  icon: Icons.person_off_rounded,
                  gradient: const [Color(0xFFB71C1C), Color(0xFFE53935), Color(0xFFEF5350)],
                  onTap: () => _openStatusReport(AttendanceStatus.absent, report),
                ),
                const SizedBox(height: 14),
                _StatusReportButton(
                  label: s.lateArrivals,
                  count: report.lateCount,
                  subtitle: s.tapGradeToInvestigate,
                  icon: Icons.schedule_rounded,
                  gradient: const [Color(0xFFE65100), Color(0xFFFB8C00), Color(0xFFFFB74D)],
                  onTap: () => _openStatusReport(AttendanceStatus.late, report),
                ),
                const SizedBox(height: 14),
                _StatusReportButton(
                  label: s.presentToday,
                  count: report.presentCount,
                  subtitle: s.tapGradeToInvestigate,
                  icon: Icons.verified_rounded,
                  gradient: const [Color(0xFF1B5E20), Color(0xFF43A047), Color(0xFF66BB6A)],
                  onTap: () => _openStatusReport(AttendanceStatus.present, report),
                ),
                const SizedBox(height: 24),
                _TeachersRecordedCard(report: report),
              ] else
                _EmptyReportCard(message: s.noAttendanceReportForDay),
            ],
          ),
        );
      },
    );
  }
}

class _ReportHeaderCard extends StatelessWidget {
  const _ReportHeaderCard({
    required this.dateLabel,
    required this.onChangeDate,
    required this.report,
    required this.hasData,
  });

  final String dateLabel;
  final VoidCallback onChangeDate;
  final DailyAttendanceReport report;
  final bool hasData;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1B5E), Color(0xFF1A237E), Color(0xFF3949AB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      s.generatedReport,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onChangeDate,
                icon: const Icon(Icons.calendar_month_rounded, color: Colors.white),
                label: Text(
                  s.change,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            dateLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            s.readOnlyReportHint,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.35,
            ),
          ),
          if (hasData) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: Text(
                s.attendanceSummaryCounts(
                  report.absentCount,
                  report.lateCount,
                  report.presentCount,
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusReportButton extends StatelessWidget {
  const _StatusReportButton({
    required this.label,
    required this.count,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String label;
  final int count;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeachersRecordedCard extends StatelessWidget {
  const _TeachersRecordedCard({required this.report});

  final DailyAttendanceReport report;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.teachersRecordedAttendance,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A237E),
              ),
            ),
            const SizedBox(height: 12),
            ...report.sessions.map(
              (session) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6FB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.className,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.conductedByName(session.conductedBy),
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s.historyPresentLateAbsent(
                          session.presentCount,
                          session.lateCount,
                          session.absentCount,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyReportCard extends StatelessWidget {
  const _EmptyReportCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(Icons.event_busy_rounded, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminAttendanceStatusScreen extends StatelessWidget {
  const AdminAttendanceStatusScreen({
    super.key,
    required this.status,
    required this.report,
  });

  final AttendanceStatus status;
  final DailyAttendanceReport report;

  Color get _accentColor {
    switch (status) {
      case AttendanceStatus.absent:
        return const Color(0xFFD32F2F);
      case AttendanceStatus.late:
        return const Color(0xFFEF6C00);
      case AttendanceStatus.present:
        return const Color(0xFF2E7D32);
    }
  }

  String _title(AppStrings s) {
    switch (status) {
      case AttendanceStatus.absent:
        return s.absents;
      case AttendanceStatus.late:
        return s.lateArrivals;
      case AttendanceStatus.present:
        return s.presentToday;
    }
  }

  String _gradeLine(AppStrings s, String grade, int count) {
    switch (status) {
      case AttendanceStatus.absent:
        return s.gradeAbsentCount(grade, count);
      case AttendanceStatus.late:
        return s.gradeLateCount(grade, count);
      case AttendanceStatus.present:
        return s.gradePresentCount(grade, count);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final gradeCounts = report.gradeCountsForStatus(status);
        final grades = gradeCounts.keys.toList()..sort();

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6FB),
          appBar: AppBar(
            backgroundColor: _accentColor,
            foregroundColor: Colors.white,
            title: Text(_title(s)),
          ),
          body: grades.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      s.noAttendanceReportForDay,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              : ListView(
                  padding: listPagePadding(context),
                  children: [
                    _ReadOnlyBanner(color: _accentColor),
                    const SizedBox(height: 16),
                    ...grades.map(
                      (grade) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: _accentColor.withValues(alpha: 0.12),
                              child: Text(
                                '${gradeCounts[grade]}',
                                style: TextStyle(
                                  color: _accentColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            title: Text(
                              grade,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(_gradeLine(s, grade, gradeCounts[grade]!)),
                            trailing: Icon(Icons.chevron_right, color: _accentColor),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdminAttendanceGradeDetailScreen(
                                    status: status,
                                    grade: grade,
                                    report: report,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class AdminAttendanceGradeDetailScreen extends StatelessWidget {
  const AdminAttendanceGradeDetailScreen({
    super.key,
    required this.status,
    required this.grade,
    required this.report,
  });

  final AttendanceStatus status;
  final String grade;
  final DailyAttendanceReport report;

  Color get _accentColor {
    switch (status) {
      case AttendanceStatus.absent:
        return const Color(0xFFD32F2F);
      case AttendanceStatus.late:
        return const Color(0xFFEF6C00);
      case AttendanceStatus.present:
        return const Color(0xFF2E7D32);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final students = report
            .recordsForStatus(status)
            .where((record) => record.grade == grade)
            .toList()
          ..sort((a, b) => a.studentName.compareTo(b.studentName));

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6FB),
          appBar: AppBar(
            backgroundColor: _accentColor,
            foregroundColor: Colors.white,
            title: Text(grade),
          ),
          body: ListView(
            padding: listPagePadding(context),
            children: [
              _ReadOnlyBanner(color: _accentColor),
              const SizedBox(height: 16),
              Text(
                s.studentsWithStatus(students.length, _statusLabel(s)),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 12),
              ...students.map(
                (student) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _accentColor.withValues(alpha: 0.12),
                        child: Icon(Icons.person_rounded, color: _accentColor),
                      ),
                      title: Text(
                        student.studentName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(student.className),
                          Text(s.conductedByName(student.conductedBy)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(AppStrings s) {
    switch (status) {
      case AttendanceStatus.absent:
        return s.absents.toLowerCase();
      case AttendanceStatus.late:
        return s.lateArrivals.toLowerCase();
      case AttendanceStatus.present:
        return s.presentToday.toLowerCase();
    }
  }
}

class _ReadOnlyBanner extends StatelessWidget {
  const _ReadOnlyBanner({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.readOnlyReportHint,
              style: TextStyle(
                color: color.withValues(alpha: 0.95),
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportExcelButton extends StatelessWidget {
  const _ExportExcelButton({
    required this.onPressed,
    required this.enabled,
  });

  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF1A237E).withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E20).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.table_view_rounded,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.exportAttendanceExcel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.exportAttendanceChooseDate,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade600),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExportAttendanceDialog extends StatefulWidget {
  const _ExportAttendanceDialog({required this.initialDate});

  final DateTime initialDate;

  @override
  State<_ExportAttendanceDialog> createState() => _ExportAttendanceDialogState();
}

class _ExportAttendanceDialogState extends State<_ExportAttendanceDialog> {
  late DateTime _fromDate;
  late DateTime _toDate;

  @override
  void initState() {
    super.initState();
    _toDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _fromDate = _toDate.subtract(const Duration(days: 29));
  }

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2024),
      lastDate: _toDate,
    );
    if (picked != null) {
      setState(() => _fromDate = picked);
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: _fromDate,
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _toDate = picked);
    }
  }

  void _setLast30Days() {
    setState(() {
      _toDate = DateTime.now();
      _fromDate = _toDate.subtract(const Duration(days: 29));
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final valid = !_fromDate.isAfter(_toDate);
    const accent = Color(0xFF00796B);

    return AdminFormDialogFrame(
      title: s.exportAttendanceTitle,
      subtitle: s.exportAttendanceChooseDate,
      accent: accent,
      icon: Icons.file_download_outlined,
      primaryLabel: s.exportAttendanceExcel,
      primaryEnabled: valid,
      onPrimary: valid
          ? () => Navigator.pop(context, (from: _fromDate, to: _toDate))
          : null,
      secondaryLabel: s.close,
      onSecondary: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          adminDialogField(
            OutlinedButton.icon(
              onPressed: _pickFromDate,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(color: accent.withValues(alpha: 0.35)),
              ),
              icon: const Icon(Icons.date_range_rounded),
              label: Text('${s.exportFromDate}: ${_formatDate(_fromDate)}'),
            ),
          ),
          adminDialogField(
            OutlinedButton.icon(
              onPressed: _pickToDate,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(color: accent.withValues(alpha: 0.35)),
              ),
              icon: const Icon(Icons.event_rounded),
              label: Text('${s.exportToDate}: ${_formatDate(_toDate)}'),
            ),
          ),
          TextButton.icon(
            onPressed: _setLast30Days,
            icon: const Icon(Icons.calendar_view_month_rounded),
            label: Text(s.exportLast30Days),
          ),
          if (!valid) ...[
            const SizedBox(height: 8),
            Text(
              s.exportDateRangeInvalid,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _AttendanceShareSheet extends StatelessWidget {
  const _AttendanceShareSheet({required this.export});

  final AttendanceExportResult export;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final service = AttendanceExportService.instance;
    final rangeLabel = export.report.fromDate == export.report.toDate
        ? service.formatDate(export.report.fromDate)
        : '${service.formatDate(export.report.fromDate)} – ${service.formatDate(export.report.toDate)}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              s.exportAttendanceShareTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              rangeLabel,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            Text(
              s.exportAttendanceShareHint,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              s.attendanceSummaryCounts(
                export.report.absentCount,
                export.report.lateCount,
                export.report.presentCount,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Divider(color: Colors.white24, height: 28),
            ListTile(
              leading: const Icon(Icons.download_rounded, color: Colors.lightGreenAccent),
              title: Text(s.download, style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                export.fileName,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () => Navigator.pop(context, AttendanceShareChannel.download),
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.greenAccent),
              title: Text(s.sendViaWhatsApp, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, AttendanceShareChannel.whatsApp),
            ),
            ListTile(
              leading: const Icon(Icons.send, color: Colors.lightBlueAccent),
              title: Text(s.sendViaTelegram, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, AttendanceShareChannel.telegram),
            ),
            ListTile(
              leading: const Icon(Icons.email_outlined, color: Colors.orangeAccent),
              title: Text(s.sendViaEmail, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, AttendanceShareChannel.email),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined, color: Colors.white70),
              title: Text(s.share, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, AttendanceShareChannel.share),
            ),
          ],
        ),
      ),
    );
  }
}
