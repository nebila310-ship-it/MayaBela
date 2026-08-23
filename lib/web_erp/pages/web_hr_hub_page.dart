import 'package:flutter/material.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/employee_registry_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/staff_registry_notifier.dart';
import 'package:mayabela/web_erp/pages/web_teachers_table_page.dart';
import 'package:mayabela/web_erp/pages/web_transport_dashboard_page.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';

/// Human Resource hub: classroom teachers, record-only employees, transport.
class WebHrHubPage extends StatefulWidget {
  const WebHrHubPage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  State<WebHrHubPage> createState() => _WebHrHubPageState();
}

class _WebHrHubPageState extends State<WebHrHubPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Human Resource',
                style: WebErpTheme.sectionTitle(context),
              ),
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'Teachers'),
                  Tab(text: 'Other staff'),
                  Tab(text: 'Transport'),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              WebTeachersTablePage(
                onNavigate: widget.onNavigate,
                directoryMode: WebTeachersDirectoryMode.classroomTeachers,
                embedded: true,
              ),
              _EmployeesTab(onNavigate: widget.onNavigate),
              WebTransportDashboardPage(onNavigate: widget.onNavigate),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmployeesTab extends StatefulWidget {
  const _EmployeesTab({this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  State<_EmployeesTab> createState() => _EmployeesTabState();
}

class _EmployeesTabState extends State<_EmployeesTab> {
  String _query = '';

  Future<void> _showAddOrEdit([EmployeeRecord? existing]) async {
    if (!ModuleAccess.canHireStaff) return;
    final schoolId = AuthService.activeSchoolId;
    if (schoolId == null || schoolId.trim().isEmpty) return;

    final name = TextEditingController(text: existing?.fullName ?? '');
    final title = TextEditingController(text: existing?.jobTitle ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final department = TextEditingController(text: existing?.department ?? '');
    final notes = TextEditingController(text: existing?.notes ?? '');
    final campuses =
        SchoolRegistryService.instance.campusesForSchool(schoolId);
    var campus = existing?.campus ??
        (campuses.isNotEmpty ? campuses.first : 'Main Campus');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(existing == null ? 'Add staff record' : 'Edit staff record'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: name,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: title,
                        decoration: const InputDecoration(
                          labelText: 'Job title',
                          hintText: 'e.g. Cleaner, Guard, Cook',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone (optional)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: department,
                        decoration: const InputDecoration(
                          labelText: 'Department (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (campuses.length > 1) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey(campus),
                          initialValue: campus,
                          decoration: const InputDecoration(
                            labelText: 'Campus',
                            border: OutlineInputBorder(),
                          ),
                          items: campuses
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setLocal(() => campus = v);
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: notes,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Record only — no app login is created.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (name.text.trim().isEmpty ||
                        title.text.trim().isEmpty) {
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: Text(existing == null ? 'Add' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) {
      name.dispose();
      title.dispose();
      phone.dispose();
      department.dispose();
      notes.dispose();
      return;
    }

    if (existing == null) {
      EmployeeRegistryService.instance.addEmployee(
        schoolId: schoolId,
        fullName: name.text,
        jobTitle: title.text,
        phone: phone.text,
        department: department.text,
        notes: notes.text,
        campus: campus,
      );
    } else {
      EmployeeRegistryService.instance.updateEmployee(
        existing.copyWith(
          fullName: name.text.trim(),
          jobTitle: title.text.trim(),
          phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
          department:
              department.text.trim().isEmpty ? null : department.text.trim(),
          notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
          campus: campus,
          clearPhone: phone.text.trim().isEmpty,
          clearDepartment: department.text.trim().isEmpty,
          clearNotes: notes.text.trim().isEmpty,
        ),
      );
    }

    name.dispose();
    title.dispose();
    phone.dispose();
    department.dispose();
    notes.dispose();
    if (mounted) setState(() {});
  }

  Future<void> _deactivate(EmployeeRecord employee) async {
    if (!ModuleAccess.canHireStaff) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate staff record?'),
        content: Text(
          'Remove ${employee.fullName} from the active employee list? '
          'This does not affect any login account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (ok == true) {
      EmployeeRegistryService.instance.deactivateEmployee(employee.employeeId);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        EmployeeRegistryService.instance,
        StaffRegistryNotifier.instance,
      ]),
      builder: (context, _) {
        final schoolId = AuthService.activeSchoolId;
        var employees = EmployeeRegistryService.instance.employeesForSchool(
          schoolId,
          includeInactive: true,
        );
        if (_query.isNotEmpty) {
          final q = _query.toLowerCase();
          employees = employees
              .where(
                (e) =>
                    e.fullName.toLowerCase().contains(q) ||
                    e.jobTitle.toLowerCase().contains(q) ||
                    e.employeeId.toLowerCase().contains(q) ||
                    (e.phone ?? '').toLowerCase().contains(q) ||
                    (e.department ?? '').toLowerCase().contains(q),
              )
              .toList();
        }
        final canHire = ModuleAccess.canHireStaff;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search staff records…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                  ),
                  if (canHire) ...[
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => _showAddOrEdit(),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Add record'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Non-administrative staff without app access '
                '(cleaners, guards, cooks, etc.).',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: employees.isEmpty
                    ? Center(
                        child: Text(
                          canHire
                              ? 'No staff records yet. Tap Add record.'
                              : 'No staff records yet.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.separated(
                        itemCount: employees.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final e = employees[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                e.fullName.isEmpty
                                    ? '?'
                                    : e.fullName[0].toUpperCase(),
                              ),
                            ),
                            title: Text(
                              e.fullName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: e.isActive ? null : Colors.grey,
                                decoration: e.isActive
                                    ? null
                                    : TextDecoration.lineThrough,
                              ),
                            ),
                            subtitle: Text(
                              [
                                e.employeeId,
                                e.jobTitle,
                                if (e.department != null) e.department!,
                                if (e.phone != null) e.phone!,
                                e.campus,
                                e.isActive ? 'Active' : 'Inactive',
                              ].join(' · '),
                            ),
                            isThreeLine: true,
                            trailing: canHire && e.isActive
                                ? PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _showAddOrEdit(e);
                                      } else if (value == 'deactivate') {
                                        _deactivate(e);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
                                      PopupMenuItem(
                                        value: 'deactivate',
                                        child: Text('Deactivate'),
                                      ),
                                    ],
                                  )
                                : null,
                            onTap: canHire && e.isActive
                                ? () => _showAddOrEdit(e)
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
