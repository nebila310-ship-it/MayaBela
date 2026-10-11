import 'package:flutter/material.dart';

import 'package:mayabela/models/transfer_models.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/web_erp/pages/web_sis_page.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/paginated_directory.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';
import 'package:mayabela/web_erp/widgets/web_admin_profile_dialog.dart';
import 'package:mayabela/services/staff_registry_notifier.dart';
import 'package:mayabela/widgets/admin_student_qr_actions.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';
import 'package:mayabela/widgets/maya_floating_chat.dart';
import 'package:mayabela/widgets/staff_registry_avatar.dart';

class WebStudentsTablePage extends StatefulWidget {
  const WebStudentsTablePage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  /// Wide enough for identity, family, transport, type, and actions.
  static const double directoryMinTableWidth = 1400;

  @override
  State<WebStudentsTablePage> createState() => _WebStudentsTablePageState();
}

class _WebStudentsTablePageState extends State<WebStudentsTablePage> {
  final _search = TextEditingController();
  String _query = '';
  String? _gradeFilter;
  String? _campusFilter;
  String _lifecycleFilter = 'active';
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

  void _openProfile(AdminStudentRecord student) {
    showWebStudentProfileDialog(
      context,
      studentId: student.studentId,
      onUpdated: () => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StaffRegistryNotifier.instance,
      builder: (context, _) => _buildDirectory(context),
    );
  }

  Widget _buildDirectory(BuildContext context) {
    final schoolId = AuthService.activeSchoolId;
    final campuses = SchoolRegistryService.instance.campusesForSchool(schoolId);
    final multiCampus = campuses.length > 1;
    var students = StudentRegistryService.instance.visibleStudents(
      schoolId: schoolId,
      includeInactive: true,
    );
    students = switch (_lifecycleFilter) {
      'active' => students.where((s) => s.isActive).toList(),
      'graduated' =>
        students
            .where((s) => s.lifecycleStatus == StudentLifecycleStatus.graduated)
            .toList(),
      'left' =>
        students
            .where(
              (s) =>
                  s.lifecycleStatus == StudentLifecycleStatus.left ||
                  s.lifecycleStatus == StudentLifecycleStatus.transferred,
            )
            .toList(),
      _ => students,
    };

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
    final size = MediaQuery.sizeOf(context);
    final phone = size.shortestSide < 600;
    final narrow = WebViewport.isNarrow(context) || phone;

    final toolbar = _toolbar(
      context: context,
      students: students,
      grades: grades,
      campuses: campuses,
      multiCampus: multiCampus,
      narrow: narrow,
    );
    final pager = _pager(students.length, pageCount);

    if (narrow) {
      return SingleChildScrollView(
        key: const ValueKey('students-page-scroll'),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            toolbar,
            const SizedBox(height: 12),
            if (students.isEmpty)
              _emptyState()
            else
              Container(
                clipBehavior: Clip.hardEdge,
                decoration: WebErpTheme.cardDecoration(context),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      for (var i = 0; i < slice.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _studentTile(slice[i], multiCampus: multiCampus),
                      ],
                    ],
                  ),
                ),
              ),
            pager,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          toolbar,
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              clipBehavior: Clip.hardEdge,
              decoration: WebErpTheme.cardDecoration(context),
              child: students.isEmpty
                  ? _emptyState()
                  : _wideStudentTable(
                      context: context,
                      slice: slice,
                      multiCampus: multiCampus,
                    ),
            ),
          ),
          pager,
        ],
      ),
    );
  }

  Widget _toolbar({
    required BuildContext context,
    required List<AdminStudentRecord> students,
    required List<String> grades,
    required List<String> campuses,
    required bool multiCampus,
    required bool narrow,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Students', style: WebErpTheme.sectionTitle(context)),
        if (_canManage)
          SizedBox(
            width: narrow ? double.infinity : null,
            child: FilledButton.icon(
              onPressed: _openAdd,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Add Student'),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => widget.onNavigate?.call('sis'),
          icon: const Icon(Icons.badge_outlined),
          label: const Text('Student SIS'),
        ),
        SizedBox(
          width: narrow ? double.infinity : 260,
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
        DropdownButton<String?>(
          value: _gradeFilter,
          hint: const Text('Grade'),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('All grades'),
            ),
            for (final g in grades)
              DropdownMenuItem(value: g, child: Text(g)),
          ],
          onChanged: (v) => setState(() {
            _gradeFilter = v;
            _page = 0;
          }),
        ),
        DropdownButton<String>(
          value: _lifecycleFilter,
          items: const [
            DropdownMenuItem(value: 'active', child: Text('Active')),
            DropdownMenuItem(value: 'graduated', child: Text('Alumni')),
            DropdownMenuItem(
              value: 'left',
              child: Text('Withdrawn / transferred'),
            ),
            DropdownMenuItem(value: 'all', child: Text('All statuses')),
          ],
          onChanged: (v) => setState(() {
            _lifecycleFilter = v ?? 'active';
            _page = 0;
          }),
        ),
        if (multiCampus)
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
    );
  }

  Widget _pager(int studentCount, int pageCount) {
    return Padding(
      key: const ValueKey('students-pagination'),
      padding: const EdgeInsets.only(
        top: 8,
        right: MayaFloatingChat.pageEndClearance,
        bottom: 8,
      ),
      child: Row(
        children: [
          Text('$studentCount students'),
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
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
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
    );
  }

  Widget _studentTile(
    AdminStudentRecord student, {
    required bool multiCampus,
  }) {
    return ListTile(
      leading: StaffRegistryAvatar(
        key: ValueKey(
          'stu-photo-${student.studentId}-${student.photoPath ?? ''}',
        ),
        staffId: student.studentId,
        name: student.fullName,
        photoPath: student.photoPath,
        radius: 20,
        isStudent: true,
        fallbackColor: AdminFormTheme.student.secondary,
      ),
      title: Text(
        student.fullName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          student.studentId,
          student.grade,
          student.className,
          if (multiCampus) student.campus,
          student.fundingType.label,
          student.lifecycleStatus.label,
        ].join(' · '),
      ),
      isThreeLine: true,
      onTap: () => _openProfile(student),
      trailing: IconButton(
        tooltip: 'View profile',
        icon: const Icon(Icons.visibility_outlined),
        onPressed: () => _openProfile(student),
      ),
    );
  }

  Widget _wideStudentTable({
    required BuildContext context,
    required List<AdminStudentRecord> slice,
    required bool multiCampus,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth =
            constraints.maxWidth < WebStudentsTablePage.directoryMinTableWidth
                ? WebStudentsTablePage.directoryMinTableWidth
                : constraints.maxWidth;
        return Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              height: constraints.maxHeight,
              child: SingleChildScrollView(
                child: DataTable(
                  showCheckboxColumn: false,
                  headingRowHeight: 48,
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 64,
                  horizontalMargin: 16,
                  columnSpacing: 20,
                  columns: [
                    const DataColumn(label: Text('Photo')),
                    const DataColumn(label: Text('Student ID')),
                    const DataColumn(label: Text('Name')),
                    const DataColumn(label: Text('Grade')),
                    const DataColumn(label: Text('Section')),
                    if (multiCampus) const DataColumn(label: Text('Campus')),
                    const DataColumn(label: Text('Parent')),
                    const DataColumn(label: Text('Transport')),
                    const DataColumn(label: Text('Status')),
                    const DataColumn(label: Text('Student type')),
                    const DataColumn(label: Text('Actions')),
                  ],
                  rows: [
                    for (final s in slice)
                      DataRow(
                        cells: [
                          DataCell(
                            StaffRegistryAvatar(
                              key: ValueKey(
                                'stu-photo-${s.studentId}-${s.photoPath ?? ''}',
                              ),
                              staffId: s.studentId,
                              name: s.fullName,
                              photoPath: s.photoPath,
                              radius: 20,
                              isStudent: true,
                              fallbackColor: AdminFormTheme.student.secondary,
                            ),
                          ),
                          DataCell(Text(s.studentId)),
                          DataCell(
                            InkWell(
                              onTap: () => _openProfile(s),
                              child: Text(
                                s.fullName,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
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
                          DataCell(Text(s.lifecycleStatus.label)),
                          DataCell(Text(s.fundingType.label)),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: AppLocale
                                      .instance
                                      .strings
                                      .generateStudentQr,
                                  icon: const Icon(Icons.qr_code_2),
                                  onPressed: () => showAdminStudentQrSheet(
                                    context,
                                    student: s,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined),
                                  onPressed: () => _openProfile(s),
                                ),
                                IconButton(
                                  tooltip: 'Open SIS',
                                  icon: const Icon(
                                    Icons.folder_shared_outlined,
                                  ),
                                  onPressed: () {
                                    SisRoute.pendingStudentId = s.studentId;
                                    widget.onNavigate?.call('sis');
                                  },
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
        );
      },
    );
  }
}
