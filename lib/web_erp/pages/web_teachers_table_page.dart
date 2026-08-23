import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/paginated_directory.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';
import 'package:mayabela/web_erp/widgets/web_admin_profile_dialog.dart';
import 'package:mayabela/widgets/staff_role_labels.dart';
import 'package:mayabela/widgets/staff_roles_dialog.dart';

/// Unified directory for administration staff or classroom teachers.
enum WebTeachersDirectoryMode {
  administrationStaff,
  classroomTeachers,
}

/// Lists registered staff or classroom teachers; add button matches the mode.
class WebTeachersTablePage extends StatefulWidget {
  const WebTeachersTablePage({
    super.key,
    this.onNavigate,
    this.directoryMode = WebTeachersDirectoryMode.administrationStaff,
  });

  final ValueChanged<String>? onNavigate;
  final WebTeachersDirectoryMode directoryMode;

  @override
  State<WebTeachersTablePage> createState() => _WebTeachersTablePageState();
}

class _WebTeachersTablePageState extends State<WebTeachersTablePage> {
  final _search = TextEditingController();
  String _query = '';
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

  bool get _isStaffDir =>
      widget.directoryMode == WebTeachersDirectoryMode.administrationStaff;

  String get _addRoute => _isStaffDir ? 'add_staff' : 'add_teacher';
  String get _title =>
      _isStaffDir ? 'Administration Staff Directory' : 'Classroom Teachers';
  String get _addLabel =>
      _isStaffDir ? 'Add Administration Staff' : 'Add Teacher';
  String get _subtitle => _isStaffDir
      ? 'Staff with an assigned role. They sign in as Administration Staff and only see that role’s modules.'
      : 'Classroom teachers (no admin role). They sign in as Teacher. Section Director assigns classes later.';

  void _openAdd() {
    final go = widget.onNavigate;
    if (go != null && ModuleAccess.canManage(_addRoute)) {
      go(_addRoute);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isStaffDir
              ? 'You do not have permission to add staff.'
              : 'You do not have permission to add teachers.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = AuthService.activeSchoolId;
    final campuses = SchoolRegistryService.instance.campusesForSchool(schoolId);
    final multiCampus = campuses.length > 1;
    var teachers = schoolId == null
        ? TeacherRegistryService.instance.allTeachersIncludingInactive()
        : TeacherRegistryService.instance.teachersForSchool(
            schoolId,
            includeInactive: true,
          );

    teachers = teachers.where((t) {
      final hasStaffRole = t.staffRoles.isNotEmpty;
      return _isStaffDir ? hasStaffRole : !hasStaffRole;
    }).toList();

    if (_query.isNotEmpty) {
      teachers = teachers
          .where(
            (t) => PaginatedDirectory.matchesText(_query, [
              t.fullName,
              t.employeeId ?? t.teacherId,
              t.teacherId,
              t.phone,
              t.loginUsername,
            ]),
          )
          .toList();
    }
    if (_campusFilter != null) {
      teachers = teachers.where((t) => t.campus == _campusFilter).toList();
    }

    final pageCount = PaginatedDirectory.pageCount(teachers.length);
    final slice = PaginatedDirectory.pageOf(teachers, _page);
    final canAdd = ModuleAccess.canHireStaff;
    final s = AppLocale.instance.strings;
    final narrow = WebViewport.isNarrow(context);

    return Padding(
      padding: EdgeInsets.all(narrow ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (narrow) ...[
            Text(
              _title,
              style: WebErpTheme.sectionTitle(context),
            ),
            if (canAdd) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openAdd,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: Text(_addLabel),
                ),
              ),
            ],
          ] else
            Row(
              children: [
                Expanded(
                  child: Text(
                    _title,
                    style: WebErpTheme.sectionTitle(context),
                  ),
                ),
                if (canAdd)
                  FilledButton.icon(
                    onPressed: _openAdd,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: Text(_addLabel),
                  ),
              ],
            ),
          const SizedBox(height: 6),
          Text(
            _subtitle,
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
                width: narrow ? double.infinity : 320,
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _runSearch(),
                  decoration: const InputDecoration(
                    hintText: 'Search by name or staff ID…',
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
              if (_query.isNotEmpty)
                TextButton(
                  onPressed: () {
                    _search.clear();
                    _runSearch();
                  },
                  child: const Text('Clear'),
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
              Text(
                teachers.isEmpty
                    ? '0 registered'
                    : '${teachers.length} registered · 10 per page',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: WebErpTheme.cardDecoration(context),
              child: teachers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.badge_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _query.isNotEmpty
                                ? 'No ${_isStaffDir ? 'staff' : 'teachers'} match this search.'
                                : (_isStaffDir
                                    ? 'No administration staff registered yet.'
                                    : 'No classroom teachers registered yet.'),
                          ),
                          if (canAdd) ...[
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _openAdd,
                              icon: const Icon(Icons.person_add_alt_1_outlined),
                              label: Text(_addLabel),
                            ),
                          ],
                        ],
                      ),
                    )
                  : narrow
                      ? ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: slice.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final t = slice[index];
                            final roleText = _roleOrAssignmentText(t, s);
                            return ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  t.fullName.isEmpty
                                      ? '?'
                                      : t.fullName[0].toUpperCase(),
                                ),
                              ),
                              title: Text(
                                t.fullName,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                [
                                  t.employeeId ?? t.teacherId,
                                  t.phone ?? t.loginUsername ?? '—',
                                  if (multiCampus) t.campus,
                                  roleText,
                                  t.isActive ? 'Active' : 'Inactive',
                                ].join(' · '),
                              ),
                              isThreeLine: true,
                              onTap: () => showWebTeacherProfileDialog(
                                context,
                                teacherId: t.teacherId,
                                onUpdated: () => setState(() {}),
                              ),
                              trailing: AuthService.canAssignStaffRoles
                                  ? IconButton(
                                      tooltip: s.staffRolesTitle,
                                      icon: const Icon(
                                        Icons.admin_panel_settings_outlined,
                                      ),
                                      onPressed: () => showStaffRolesDialog(
                                        context: context,
                                        teacher: t,
                                        onSaved: () {
                                          if (mounted) setState(() {});
                                        },
                                      ),
                                    )
                                  : const Icon(Icons.chevron_right),
                            );
                          },
                        )
                      : Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                            columns: [
                              const DataColumn(label: Text('Photo')),
                              const DataColumn(label: Text('Staff ID')),
                              const DataColumn(label: Text('Name')),
                              const DataColumn(label: Text('Phone')),
                              if (multiCampus)
                                const DataColumn(label: Text('Campus')),
                              DataColumn(
                                label: Text(_isStaffDir ? 'Role' : 'Assignment'),
                              ),
                              const DataColumn(label: Text('Status')),
                              const DataColumn(label: Text('Actions')),
                            ],
                            rows: [
                              for (final t in slice)
                                DataRow(
                                  onSelectChanged: (_) =>
                                      showWebTeacherProfileDialog(
                                    context,
                                    teacherId: t.teacherId,
                                    onUpdated: () => setState(() {}),
                                  ),
                                  cells: [
                                    DataCell(
                                      CircleAvatar(
                                        child: Text(
                                          t.fullName.isEmpty
                                              ? '?'
                                              : t.fullName[0].toUpperCase(),
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(t.employeeId ?? t.teacherId)),
                                    DataCell(
                                      InkWell(
                                        onTap: () => showWebTeacherProfileDialog(
                                          context,
                                          teacherId: t.teacherId,
                                          onUpdated: () => setState(() {}),
                                        ),
                                        child: Text(
                                          t.fullName,
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(t.phone ?? t.loginUsername ?? '—'),
                                    ),
                                    if (multiCampus) DataCell(Text(t.campus)),
                                    DataCell(
                                      Text(
                                        _roleOrAssignmentText(t, s),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: _isUnassigned(t)
                                              ? Colors.orange.shade800
                                              : null,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(t.isActive ? 'Active' : 'Inactive'),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'View profile',
                                            icon: const Icon(
                                              Icons.visibility_outlined,
                                            ),
                                            onPressed: () =>
                                                showWebTeacherProfileDialog(
                                              context,
                                              teacherId: t.teacherId,
                                              onUpdated: () => setState(() {}),
                                            ),
                                          ),
                                          if (AuthService.canAssignStaffRoles)
                                            TextButton.icon(
                                              onPressed: () =>
                                                  showStaffRolesDialog(
                                                context: context,
                                                teacher: t,
                                                onSaved: () {
                                                  if (mounted) setState(() {});
                                                },
                                              ),
                                              icon: const Icon(
                                                Icons
                                                    .admin_panel_settings_outlined,
                                                size: 18,
                                              ),
                                              label: Text(s.staffRolesTitle),
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
            ),
          ),
          if (teachers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Page ${_page + 1} of $pageCount'),
                IconButton(
                  onPressed: _page <= 0
                      ? null
                      : () => setState(() => _page -= 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  onPressed: _page >= pageCount - 1
                      ? null
                      : () => setState(() => _page += 1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _isUnassigned(AdminTeacherRecord teacher) {
    if (_isStaffDir) return teacher.staffRoles.isEmpty;
    return teacher.classAssignments.isEmpty &&
        teacher.assignedClass.trim().isEmpty;
  }

  String _roleOrAssignmentText(AdminTeacherRecord teacher, AppStrings s) {
    if (_isStaffDir) {
      final text = staffRolesSummary(teacher.staffRoles, s).trim();
      return text.isEmpty ? 'No role yet' : text;
    }
    final text = classroomAssignmentSummary(teacher, s).trim();
    return text.isEmpty ? 'Not assigned yet' : text;
  }
}
