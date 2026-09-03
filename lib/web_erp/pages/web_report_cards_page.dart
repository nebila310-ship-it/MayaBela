import 'package:flutter/material.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/markbook_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';
import 'package:mayabela/widgets/term_report_card_view.dart';

/// Term report cards — comments, attendance snapshot, publish to parents.
class WebReportCardsPage extends StatefulWidget {
  const WebReportCardsPage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  State<WebReportCardsPage> createState() => _WebReportCardsPageState();
}

class _WebReportCardsPageState extends State<WebReportCardsPage> {
  final _data = SchoolDataService.instance;
  String? _className;
  String _query = '';
  final _search = TextEditingController();

  bool get _canManage => ModuleAccess.canManage('report_cards');
  String get _schoolId => AuthService.activeSchoolId ?? '';

  List<String> get _classes {
    final names = <String>{
      ...SchoolRegistryService.instance.sectionsForSchool(_schoolId),
      ..._data.getAllGradeReports().map((r) => r.className),
      ...StudentRegistryService.instance
          .registrySnapshot()
          .where((s) =>
              _schoolId.isEmpty ||
              s.schoolId.toUpperCase() == _schoolId.toUpperCase())
          .map((s) => s.className),
    };
    final list = names.where((n) => n.trim().isNotEmpty).toList()..sort();
    return list;
  }

  List<StudentGradeReport> get _reports {
    final className = _className;
    var items = className == null || className.isEmpty
        ? _data.getAllGradeReports().where((r) => r.subjects.isNotEmpty).toList()
        : _data.getGradeReportsForClass(className);
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items
          .where((r) =>
              r.studentName.toLowerCase().contains(q) ||
              r.className.toLowerCase().contains(q))
          .toList();
    }
    items.sort((a, b) => a.studentName.compareTo(b.studentName));
    return items;
  }

  @override
  void initState() {
    super.initState();
    final classes = _classes;
    if (classes.isNotEmpty) _className = classes.first;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openEditor(StudentGradeReport report) async {
    final homeroom = TextEditingController(text: report.homeroomComment ?? '');
    final principal = TextEditingController(text: report.principalComment ?? '');
    final term = TextEditingController(text: report.term);
    final published = report.reportCardPublished;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(report.studentName),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TermReportCardView(
                    report: report,
                    schoolName:
                        SchoolRegistryService.instance.lookup(_schoolId)?.name,
                    compact: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: term,
                    enabled: _canManage,
                    decoration: const InputDecoration(
                      labelText: 'Term',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: homeroom,
                    enabled: _canManage,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Homeroom comment',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: principal,
                    enabled: _canManage,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Principal comment',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (published)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('This report card is already published to parents.'),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            if (_canManage)
              TextButton(
                onPressed: () {
                  MarkbookService.instance.saveReportCardDraft(
                    studentName: report.studentName,
                    className: report.className,
                    term: term.text,
                    homeroomComment: homeroom.text,
                    principalComment: principal.text,
                  );
                  Navigator.pop(context);
                  setState(() {});
                },
                child: const Text('Save draft'),
              ),
            if (_canManage)
              FilledButton(
                onPressed: () {
                  MarkbookService.instance.publishReportCard(
                    studentName: report.studentName,
                    className: report.className,
                    term: term.text,
                    homeroomComment: homeroom.text,
                    principalComment: principal.text,
                  );
                  Navigator.pop(context);
                  setState(() {});
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('Published ${report.studentName} report card'),
                    ),
                  );
                },
                child: const Text('Publish to parents'),
              ),
          ],
        );
      },
    );
    homeroom.dispose();
    principal.dispose();
    term.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final narrow = WebViewport.isNarrow(context);
    final reports = _reports;
    final unpublished = reports.where((r) => !r.reportCardPublished).length;
    return ListView(
      padding: EdgeInsets.all(narrow ? 12 : 20),
      children: [
        Text('Report cards', style: WebErpTheme.sectionTitle(context)),
        const SizedBox(height: 4),
        Text(
          'Term report with weighted subject finals, GPA, attendance, and comments. '
          'Parents and students only see a published card (and already-approved subject grades).',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                key: ValueKey('rc-class-$_className'),
                initialValue: _classes.contains(_className) ? _className : null,
                decoration: const InputDecoration(
                  labelText: 'Class',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final name in _classes)
                    DropdownMenuItem(value: name, child: Text(name)),
                ],
                onChanged: (v) => setState(() => _className = v),
              ),
            ),
            SizedBox(
              width: 240,
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Search student…',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Chip(label: Text('$unpublished unpublished')),
            TextButton(
              onPressed: () => widget.onNavigate?.call('markbook'),
              child: const Text('Open markbook'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (reports.isEmpty)
          const Text('No grade reports for this class yet.')
        else
          ...reports.map((report) {
            final snap = _data.attendanceSnapshotForStudent(
              studentName: report.studentName,
              className: report.className,
            );
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: WebErpTheme.cardDecoration(context),
              child: ListTile(
                title: Text(report.studentName,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  '${report.className} · ${report.term} · '
                  'avg ${report.average.toStringAsFixed(1)}% · '
                  'GPA ${report.gpa.toStringAsFixed(2)} · '
                  'attendance ${snap.sessions == 0 ? '—' : '${(snap.rate * 100).round()}%'}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(
                      label: Text(
                        report.reportCardPublished ? 'Published' : 'Draft',
                      ),
                      backgroundColor: report.reportCardPublished
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.orange.shade50,
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => _openEditor(report),
              ),
            );
          }),
      ],
    );
  }
}
