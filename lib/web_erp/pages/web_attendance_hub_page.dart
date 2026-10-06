import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:mayabela/screens/admin_attendance_screens.dart';
import 'package:mayabela/screens/attendance_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/year_start_sheet_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';

/// Teacher take-roll plus the existing daily reports, on the same register.
class WebAttendanceHubPage extends StatefulWidget {
  const WebAttendanceHubPage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  State<WebAttendanceHubPage> createState() => _WebAttendanceHubPageState();
}

class _WebAttendanceHubPageState extends State<WebAttendanceHubPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  bool get _canView => ModuleAccess.canView('attendance');
  bool get _canManage => ModuleAccess.canManage('attendance');
  String get _schoolId => AuthService.activeSchoolId ?? '';

  List<String> get _classes {
    final names = <String>{
      ...SchoolRegistryService.instance.sectionsForSchool(_schoolId),
      ...StudentRegistryService.instance
          .registrySnapshot()
          .where(
            (s) =>
                _schoolId.isEmpty ||
                s.schoolId.toUpperCase() == _schoolId.toUpperCase(),
          )
          .map((s) => s.className),
    };
    final list = names.where((n) => n.trim().isNotEmpty).toList()..sort();
    return list;
  }

  Future<void> _exportCsv() async {
    final classes = _classes;
    if (classes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No classes on file to export.')),
      );
      return;
    }
    var className = classes.first;
    var date = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Export attendance CSV'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: className,
                decoration: const InputDecoration(labelText: 'Class'),
                items: [
                  for (final name in classes)
                    DropdownMenuItem(value: name, child: Text(name)),
                ],
                onChanged: (v) => setLocal(() => className = v ?? className),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                    initialDate: date,
                  );
                  if (picked != null) setLocal(() => date = picked);
                },
                child: Text(
                  'Date ${date.day}/${date.month}/${date.year}',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Export'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final csv = YearStartSheetService.instance.attendanceCsv(
      className: className,
      date: date,
      schoolId: _schoolId.isEmpty ? null : _schoolId,
    );
    await YearStartSheetService.instance.shareCsv(
      csv: csv,
      fileName:
          'attendance_${className.replaceAll(' ', '_')}_${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}.csv',
      subject: 'Attendance CSV · $className',
    );
  }

  Future<void> _importCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.single.bytes;
    if (bytes == null) return;
    try {
      final n = YearStartSheetService.instance.importAttendanceCsv(
        String.fromCharCodes(bytes),
        conductedBy: AuthService.currentUser?.fullName ??
            AuthService.currentUser?.username ??
            'Staff',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            n == 0
                ? 'No attendance rows could be written.'
                : 'Imported $n attendance mark(s).',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final narrow = WebViewport.isNarrow(context);
    if (!_canView) {
      return const Center(child: Text('You do not have access to attendance.'));
    }
    return SizedBox.expand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            narrow ? 12 : 20,
            narrow ? 12 : 20,
            narrow ? 12 : 20,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Attendance',
                      style: WebErpTheme.sectionTitle(context),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Export class CSV',
                    visualDensity: VisualDensity.compact,
                    onPressed: _exportCsv,
                    icon: const Icon(Icons.download_outlined),
                  ),
                  if (_canManage)
                    IconButton(
                      tooltip: 'Import class CSV',
                      visualDensity: VisualDensity.compact,
                      onPressed: _importCsv,
                      icon: const Icon(Icons.upload_file_outlined),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Teachers mark the same daily register used on mobile. '
                'Reports and absence patterns stay on this store — this is not '
                'a second attendance ledger.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              if (widget.onNavigate != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => widget.onNavigate!('at_risk'),
                    child: const Text('Absence patterns & at-risk'),
                  ),
                ),
              ],
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'Take attendance'),
                  Tab(text: 'Daily reports'),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              SizedBox.expand(child: AttendanceScreen(embedded: true)),
              SizedBox.expand(
                child: AdminAttendanceReportsScreen(embedded: true),
              ),
            ],
          ),
        ),
        ],
      ),
    );
  }
}
