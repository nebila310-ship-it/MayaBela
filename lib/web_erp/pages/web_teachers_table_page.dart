import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/staff_registry_notifier.dart';
import 'package:mayabela/services/teacher_photo_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/paginated_directory.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';
import 'package:mayabela/web_erp/widgets/web_admin_profile_dialog.dart';
import 'package:mayabela/web_erp/widgets/web_erp_hscroll.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';
import 'package:mayabela/widgets/maya_floating_chat.dart';
import 'package:mayabela/widgets/profile_photo_align_dialog.dart';
import 'package:mayabela/widgets/staff_registry_avatar.dart';
import 'package:mayabela/widgets/staff_roles_dialog.dart';

/// Unified directory for administration staff or classroom teachers.
enum WebTeachersDirectoryMode { administrationStaff, classroomTeachers }

/// Lists registered staff or classroom teachers; add button matches the mode.
class WebTeachersTablePage extends StatefulWidget {
  const WebTeachersTablePage({
    super.key,
    this.onNavigate,
    this.directoryMode = WebTeachersDirectoryMode.administrationStaff,
    this.embedded = false,
  });

  final ValueChanged<String>? onNavigate;
  final WebTeachersDirectoryMode directoryMode;

  /// When true (HR Teachers tab), drop the large title so the list fills the page.
  final bool embedded;

  /// Wide enough that Status and Actions stay readable instead of clipping to "Stat".
  static const double directoryMinTableWidth = 1180;

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

  Future<void> _attachPhoto(AdminTeacherRecord teacher) async {
    if (!ModuleAccess.canHireStaff) return;
    final s = AppLocale.instance.strings;
    final bytes = await pickAlignedPhotoOrSnack(
      context,
      pick: TeacherPhotoService.instance.pickBytes,
      errorOf: () => TeacherPhotoService.instance.lastError,
    );
    if (bytes == null || !mounted) return;
    final path = await TeacherPhotoService.instance.saveBytesForTeacher(
      teacher.teacherId,
      bytes,
    );
    if (path == null) return;
    TeacherPhotoService.instance.rememberPath(teacher.teacherId, path);
    TeacherPhotoService.instance.rememberBytes(teacher.teacherId, bytes);
    TeacherRegistryService.instance.updatePhoto(teacher.teacherId, path);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isStaffDir ? s.staffUpdated : s.teacherUpdated),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _openProfile(AdminTeacherRecord teacher) {
    showWebTeacherProfileDialog(
      context,
      teacherId: teacher.teacherId,
      administrationStaff: _isStaffDir,
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
    var teachers = TeacherRegistryService.instance.visibleTeachers(
      schoolId: schoolId,
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
    final size = MediaQuery.sizeOf(context);
    final phone = size.shortestSide < 600;
    final narrow = WebViewport.isNarrow(context) || phone;

    final toolbar = _toolbar(
      context: context,
      teachers: teachers,
      campuses: campuses,
      multiCampus: multiCampus,
      narrow: narrow,
      canAdd: canAdd,
    );
    final pager = _pager(teachers.length, pageCount, narrow: narrow);

    return SingleChildScrollView(
      key: ValueKey(_isStaffDir ? 'staff-page-scroll' : 'teachers-page-scroll'),
      padding: EdgeInsets.fromLTRB(
        widget.embedded ? 8 : (narrow ? 12 : 16),
        widget.embedded ? 8 : 12,
        widget.embedded ? 8 : (narrow ? 12 : 16),
        20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          toolbar,
          const SizedBox(height: 12),
          if (teachers.isEmpty)
            _emptyState(canAdd)
          else if (narrow)
            Container(
              clipBehavior: Clip.hardEdge,
              decoration: WebErpTheme.cardDecoration(context),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    for (var i = 0; i < slice.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _staffTile(slice[i], multiCampus: multiCampus, strings: s),
                    ],
                  ],
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              clipBehavior: Clip.hardEdge,
              decoration: WebErpTheme.cardDecoration(context),
              child: _wideTeacherTable(
                context: context,
                slice: slice,
                multiCampus: multiCampus,
                strings: s,
              ),
            ),
          pager,
        ],
      ),
    );
  }

  Widget _toolbar({
    required BuildContext context,
    required List<AdminTeacherRecord> teachers,
    required List<String> campuses,
    required bool multiCampus,
    required bool narrow,
    required bool canAdd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded) ...[
          if (narrow) ...[
            Text(_title, style: WebErpTheme.sectionTitle(context)),
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
                  child: Text(_title, style: WebErpTheme.sectionTitle(context)),
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
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (widget.embedded)
              Text(_title, style: WebErpTheme.sectionTitle(context)),
            SizedBox(
              width: narrow ? double.infinity : 320,
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _runSearch(),
                decoration: const InputDecoration(
                  hintText: 'Search name, ID, or phone...',
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
            if (widget.embedded && canAdd)
              FilledButton.icon(
                onPressed: _openAdd,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: Text(_addLabel),
              ),
          ],
        ),
      ],
    );
  }

  Widget _pager(int count, int pageCount, {required bool narrow}) {
    return Padding(
      key: const ValueKey('teachers-pagination'),
      padding: EdgeInsets.only(
        top: 8,
        right: narrow ? 8 : MayaFloatingChat.pageEndClearance,
        bottom: 8,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Text(
            count == 0 ? '0 registered' : '$count registered · 10 per page',
          ),
          if (count > 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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

  Widget _emptyState(bool canAdd) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.badge_outlined, size: 48, color: Colors.grey.shade400),
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
    );
  }

  Widget _staffTile(
    AdminTeacherRecord teacher, {
    required bool multiCampus,
    required AppStrings strings,
  }) {
    final roleText = _roleOrAssignmentText(teacher, strings);
    return ListTile(
      leading: StaffRegistryAvatar(
        key: ValueKey('tch-tile-${teacher.teacherId}-${teacher.photoPath ?? ''}'),
        staffId: teacher.teacherId,
        name: teacher.fullName,
        photoPath: teacher.photoPath,
        radius: 20,
        fallbackColor: _isStaffDir
            ? AdminFormTheme.staff.secondary
            : AdminFormTheme.teacher.secondary,
      ),
      title: Text(
        teacher.fullName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          teacher.employeeId ?? teacher.teacherId,
          teacher.phone ?? teacher.loginUsername ?? '—',
          if (multiCampus) teacher.campus,
          roleText,
          teacher.isActive ? 'Active' : 'Inactive',
        ].join(' · '),
      ),
      isThreeLine: true,
      onTap: () => _openProfile(teacher),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ModuleAccess.canHireStaff)
            IconButton(
              tooltip: strings.changeProfilePhoto,
              icon: const Icon(Icons.camera_alt_outlined),
              onPressed: () => _attachPhoto(teacher),
            ),
          if (AuthService.canAssignStaffRoles)
            IconButton(
              tooltip: strings.staffRolesTitle,
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () => showStaffRolesDialog(
                context: context,
                teacher: teacher,
                onSaved: () {
                  if (mounted) setState(() {});
                },
              ),
            )
          else
            const Icon(Icons.chevron_right),
        ],
      ),
    );
  }

  Widget _wideTeacherTable({
    required BuildContext context,
    required List<AdminTeacherRecord> slice,
    required bool multiCampus,
    required AppStrings strings,
  }) {
    const statusWidth = 96.0;
    return WebErpHScroll(
      minChildWidth: WebTeachersTablePage.directoryMinTableWidth,
      child: DataTable(
        showCheckboxColumn: false,
        headingRowHeight: 48,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 64,
        horizontalMargin: 16,
        columnSpacing: 20,
        columns: [
          const DataColumn(label: Text('Photo')),
          const DataColumn(label: Text('Staff ID')),
          const DataColumn(label: Text('Name')),
          const DataColumn(label: Text('Phone')),
          if (multiCampus) const DataColumn(label: Text('Campus')),
          DataColumn(label: Text(_isStaffDir ? 'Role' : 'Assignment')),
          const DataColumn(
            label: SizedBox(width: statusWidth, child: Text('Status')),
          ),
          const DataColumn(
            label: SizedBox(width: 168, child: Text('Actions')),
          ),
        ],
        rows: [
          for (final t in slice)
            DataRow(
              cells: [
                DataCell(
                  StaffRegistryAvatar(
                    key: ValueKey('tch-photo-${t.teacherId}-${t.photoPath ?? ''}'),
                    staffId: t.teacherId,
                    name: t.fullName,
                    photoPath: t.photoPath,
                    radius: 20,
                    fallbackColor: _isStaffDir
                        ? AdminFormTheme.staff.secondary
                        : AdminFormTheme.teacher.secondary,
                  ),
                  onTap: ModuleAccess.canHireStaff
                      ? () => _attachPhoto(t)
                      : () => _openProfile(t),
                ),
                DataCell(Text(t.employeeId ?? t.teacherId)),
                DataCell(
                  InkWell(
                    onTap: () => _openProfile(t),
                    child: Text(
                      t.fullName,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                DataCell(Text(t.phone ?? t.loginUsername ?? '—')),
                if (multiCampus) DataCell(Text(t.campus)),
                DataCell(
                  Text(
                    _roleOrAssignmentText(t, strings),
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: _isUnassigned(t) ? Colors.orange.shade800 : null,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: statusWidth,
                    child: Text(t.isActive ? 'Active' : 'Inactive'),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 168,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (ModuleAccess.canHireStaff)
                          IconButton(
                            tooltip: strings.changeProfilePhoto,
                            icon: const Icon(Icons.camera_alt_outlined),
                            onPressed: () => _attachPhoto(t),
                          ),
                        IconButton(
                          tooltip: 'View profile',
                          icon: const Icon(Icons.visibility_outlined),
                          onPressed: () => _openProfile(t),
                        ),
                        if (AuthService.canAssignStaffRoles)
                          IconButton(
                            tooltip: strings.staffRolesTitle,
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
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
      final text = staffRolesSummary(
        teacher.staffRoles,
        s,
        schoolId: teacher.schoolId,
      ).trim();
      return text.isEmpty ? 'No role yet' : text;
    }
    final text = classroomAssignmentSummary(teacher, s).trim();
    return text.isEmpty ? 'Not assigned yet' : text;
  }
}
