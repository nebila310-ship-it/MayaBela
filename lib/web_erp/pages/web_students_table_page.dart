import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/paginated_directory.dart';
import 'package:mayabela/web_erp/widgets/web_admin_profile_dialog.dart';
import 'package:mayabela/widgets/admin_student_qr_actions.dart';

class WebStudentsTablePage extends StatefulWidget {
  const WebStudentsTablePage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  State<WebStudentsTablePage> createState() => _WebStudentsTablePageState();
}

class _WebStudentsTablePageState extends State<WebStudentsTablePage> {
  final _search = TextEditingController();
  String _query = '';
  String? _gradeFilter;
  String? _campusFilter;
  int _page = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _runSearch() {
    setState(() {
      _query = _search.text.trim();
      _page = 0;
    });
  }

  bool get _canManage => ModuleAccess.canManage('students');

  void _openAdd() {
    final go = widget.onNavigate;
    if (go != null && _canManage) {
      go('add_student');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You do not have permission to add students.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = AuthService.activeSchoolId;
    final campuses = SchoolRegistryService.instance.campusesForSchool(schoolId);
    final multiCampus = campuses.length > 1;
    var students = schoolId == null
        ? StudentRegistryService.instance.getAllStudents()
        : StudentRegistryService.instance.studentsForSchool(schoolId);
    students = students.where((s) => s.isActive).toList();

    if (_query.isNotEmpty) {
      students = students
          .where(
            (s) => PaginatedDirectory.matchesText(_query, [
              s.fullName,
              s.studentId,
            ]),
          )
          .toList();
    }
    if (_gradeFilter != null) {
      students = students.where((s) => s.grade == _gradeFilter).toList();
    }
    if (_campusFilter != null) {
      students = students.where((s) => s.campus == _campusFilter).toList();
    }

    final grades = students.map((s) => s.grade).toSet().toList()..sort();
    final pageCount = PaginatedDirectory.pageCount(students.length);
    final slice = PaginatedDirectory.pageOf(students, _page);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Students', style: WebErpTheme.sectionTitle(context)),
              if (_canManage)
                FilledButton.icon(
                  onPressed: _openAdd,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Add Student'),
                ),
              const SizedBox(width: 12),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _runSearch(),
                  decoration: const InputDecoration(
                    hintText: 'Search by name or student ID…',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _runSearch,
                icon: const Icon(Icons.search),
                label: const Text('Search'),
              ),
              const SizedBox(width: 12),
              DropdownButton<String?>(
                value: _gradeFilter,
                hint: const Text('Grade'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All grades')),
                  for (final g in grades)
                    DropdownMenuItem(value: g, child: Text(g)),
                ],
                onChanged: (v) => setState(() {
                  _gradeFilter = v;
                  _page = 0;
                }),
              ),
              if (multiCampus) ...[
                const SizedBox(width: 8),
                DropdownButton<String?>(
                  value: _campusFilter,
                  hint: const Text('Campus'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All campuses'),
                    ),
                    for (final c in campuses)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setState(() {
                    _campusFilter = v;
                    _page = 0;
                  }),
                ),
              ],
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: students.isEmpty
                    ? null
                    : () => showStudentQrPrintPreview(
                          context,
                          students: students,
                        ),
                icon: const Icon(Icons.qr_code_2),
                label: Text(AppLocale.instance.strings.studentQrCodes),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Export Excel',
                onPressed: () {},
                icon: const Icon(Icons.table_view_outlined),
              ),
              IconButton(
                tooltip: 'Print QR cards',
                onPressed: students.isEmpty
                    ? null
                    : () => showStudentQrPrintPreview(
                          context,
                          students: students,
                        ),
                icon: const Icon(Icons.print_outlined),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: WebErpTheme.cardDecoration(context),
              child: students.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.school_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          const Text('No students registered yet.'),
                          if (_canManage) ...[
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _openAdd,
                              icon: const Icon(Icons.person_add_alt_1_outlined),
                              label: const Text('Add Student'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        sortColumnIndex: 2,
                        columns: [
                          const DataColumn(label: Text('Photo')),
                          const DataColumn(label: Text('Student ID')),
                          const DataColumn(label: Text('Name')),
                          const DataColumn(label: Text('Grade')),
                          const DataColumn(label: Text('Section')),
                          if (multiCampus)
                            const DataColumn(label: Text('Campus')),
                          const DataColumn(label: Text('Parent')),
                          const DataColumn(label: Text('Transport')),
                          const DataColumn(label: Text('Status')),
                          const DataColumn(label: Text('Actions')),
                        ],
                        rows: [
                          for (final s in slice)
                            DataRow(
                              onSelectChanged: (_) =>
                                  showWebStudentProfileDialog(
                                context,
                                studentId: s.studentId,
                                onUpdated: () => setState(() {}),
                              ),
                              cells: [
                                DataCell(
                                  CircleAvatar(
                                    child: Text(
                                      s.fullName.isEmpty
                                          ? '?'
                                          : s.fullName[0],
                                    ),
                                  ),
                                ),
                                DataCell(Text(s.studentId)),
                                DataCell(
                                  InkWell(
                                    onTap: () => showWebStudentProfileDialog(
                                      context,
                                      studentId: s.studentId,
                                      onUpdated: () => setState(() {}),
                                    ),
                                    child: Text(
                                      s.fullName,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(Text(s.grade)),
                                DataCell(Text(s.className)),
                                if (multiCampus) DataCell(Text(s.campus)),
                                DataCell(
                                  Text(s.fatherName ?? s.guardianName ?? '—'),
                                ),
                                DataCell(
                                  Icon(
                                    s.transportEnabled
                                        ? Icons.directions_bus
                                        : Icons.remove,
                                    size: 18,
                                  ),
                                ),
                                DataCell(
                                  Text(s.isActive ? 'Active' : 'Inactive'),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: AppLocale
                                            .instance.strings.generateStudentQr,
                                        icon: const Icon(Icons.qr_code_2),
                                        onPressed: () =>
                                            showAdminStudentQrSheet(
                                          context,
                                          student: s,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.visibility_outlined,
                                        ),
                                        onPressed: () =>
                                            showWebStudentProfileDialog(
                                          context,
                                          studentId: s.studentId,
                                          onUpdated: () => setState(() {}),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${students.length} students'),
              const Spacer(),
              IconButton(
                onPressed: _page > 0 ? () => setState(() => _page--) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('Page ${_page + 1} of ${pageCount == 0 ? 1 : pageCount}'),
              IconButton(
                onPressed: _page + 1 < pageCount
                    ? () => setState(() => _page++)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
