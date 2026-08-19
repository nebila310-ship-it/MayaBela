import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/school_role_catalog_service.dart';
import 'package:mayabela/services/rbac/staff_dashboard_modules.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';
import 'package:mayabela/widgets/staff_roles_dialog.dart';

/// School-owner screen: configure dashboard module checkboxes per role and
/// add custom roles. Built-in roles keep working; Full Access stays owner-only.
class StaffRoleConfigPage extends StatefulWidget {
  const StaffRoleConfigPage({super.key});

  @override
  State<StaffRoleConfigPage> createState() => _StaffRoleConfigPageState();
}

class _StaffRoleConfigPageState extends State<StaffRoleConfigPage> {
  bool _loading = true;
  String? _selectedKey;
  Set<String> _draftPermissions = {};
  final _customLabel = TextEditingController();

  AppStrings get s => AppLocale.instance.strings;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _customLabel.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await SchoolRoleCatalogService.instance.ensureLoaded();
    if (!mounted) return;
    final roles = SchoolRoleCatalogService.instance.rolesForAssign();
    final first = roles.firstWhere(
      (r) => !r.ownerOnly,
      orElse: () => roles.first,
    );
    setState(() {
      _loading = false;
      _selectedKey = first.key;
      _draftPermissions = Set<String>.from(first.permissions);
    });
  }

  List<StaffRole> get _roles =>
      SchoolRoleCatalogService.instance.rolesForAssign();

  StaffRole? get _selected {
    final key = _selectedKey;
    if (key == null) return null;
    return SchoolRoleCatalogService.instance.lookup(key);
  }

  void _selectRole(StaffRole role) {
    setState(() {
      _selectedKey = role.key;
      _draftPermissions = Set<String>.from(role.permissions);
    });
  }

  Future<void> _save() async {
    final key = _selectedKey;
    if (key == null) return;
    final err = await SchoolRoleCatalogService.instance.saveRoleModules(
      roleKey: key,
      permissions: _draftPermissions,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          err == null
              ? 'Role modules saved. Staff see changes after next login.'
              : (err == 'cloud_failed' || err == 'cloud_session')
                  ? 'Saved on this device, but cloud sync failed. Stay signed in as Admin (Ready), then save again.'
                  : 'Could not save role ($err).',
        ),
        backgroundColor: err == null
            ? Colors.green
            : (err == 'cloud_failed' || err == 'cloud_session')
                ? Colors.orange.shade800
                : Colors.red.shade700,
      ),
    );
    if (err == null) setState(() {});
  }

  Future<void> _addCustom() async {
    final label = _customLabel.text.trim();
    if (label.isEmpty) return;
    final err = await SchoolRoleCatalogService.instance.addCustomRole(
      label: label,
      permissions: StaffDashboardModules.alwaysOnPermissions(),
    );
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err == 'cloud_failed' || err == 'cloud_session'
                ? 'Role saved on this device, but cloud sync failed. Stay signed in as Admin (Ready), then add/save again.'
                : 'Could not add role ($err).',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
      if (err != 'cloud_failed' && err != 'cloud_session') return;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Custom role added.'),
          backgroundColor: Colors.green,
        ),
      );
    }
    _customLabel.clear();
    await SchoolRoleCatalogService.instance.ensureLoaded();
    final roles = SchoolRoleCatalogService.instance.rolesForAssign();
    final added = roles.lastWhere((r) => !r.builtIn, orElse: () => roles.last);
    setState(() {
      _selectedKey = added.key;
      _draftPermissions = Set<String>.from(added.permissions);
    });
  }

  Future<void> _deleteCustom(StaffRole role) async {
    if (role.builtIn) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete custom role?'),
        content: Text('Remove "${role.labelEn}" from this school?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await SchoolRoleCatalogService.instance.deleteCustomRole(role.key);
    await _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService.currentUser?.roleKey != AuthService.roleAdmin) {
      return const Center(child: Text('Only the school owner can configure roles.'));
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final selected = _selected;
    final modules = StaffDashboardModules.configurableModules();
    final narrow = WebViewport.isNarrow(context);
    final roleList = _buildRoleListPane(narrow: narrow);
    final modulesPane = _buildModulesPane(selected, modules, narrow: narrow);

    return Padding(
      padding: EdgeInsets.all(narrow ? 12 : 20),
      child: narrow
          ? ListView(
              children: [
                SizedBox(height: 280, child: roleList),
                const SizedBox(height: 12),
                SizedBox(height: 420, child: modulesPane),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 280, child: roleList),
                const SizedBox(width: 16),
                Expanded(child: modulesPane),
              ],
            ),
    );
  }

  Widget _buildRoleListPane({required bool narrow}) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Staff roles',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Pick a role, then tick dashboard features. Shared tools (reports, support, Maya, audit, health, settings) stay on for every role.',
              style: TextStyle(fontSize: 12, height: 1.35),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                for (final role in _roles)
                  ListTile(
                    selected: role.key == _selectedKey,
                    title: Text(staffRoleLabel(role, s)),
                    subtitle: Text(
                      role.ownerOnly
                          ? 'Owner grant only'
                          : role.builtIn
                              ? 'Built-in'
                              : 'Custom',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: role.builtIn
                        ? null
                        : IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => _deleteCustom(role),
                          ),
                    onTap: () => _selectRole(role),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _customLabel,
                  decoration: const InputDecoration(
                    labelText: 'Add custom role',
                    hintText: 'e.g. Discipline Officer',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: _addCustom,
                    child: const Text('Add role'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModulesPane(
    StaffRole? selected,
    List<StaffDashboardModule> modules, {
    required bool narrow,
  }) {
    return Card(
      child: selected == null
          ? const Center(child: Text('Select a role'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(narrow ? 12 : 20, 16, narrow ? 12 : 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          staffRoleLabel(selected, s),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: narrow ? 16 : 18,
                          ),
                        ),
                      ),
                      if (!selected.ownerOnly)
                        FilledButton(
                          onPressed: _save,
                          child: Text(s.save),
                        ),
                    ],
                  ),
                ),
                if (selected.ownerOnly)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: narrow ? 12 : 20),
                    child: const Text(
                      'Full Access always includes every feature. Only the school owner can grant or revoke it.',
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(8, 0, 8, narrow ? 12 : 20),
                      children: [
                        for (final module in modules)
                          CheckboxListTile(
                            value: StaffDashboardModules.isModuleEnabled(
                              module.id,
                              _draftPermissions,
                            ),
                            title: Text(module.labelEn),
                            subtitle: module.alwaysOn
                                ? const Text(
                                    'Included for every role',
                                    style: TextStyle(fontSize: 11),
                                  )
                                : null,
                            onChanged: module.alwaysOn || selected.ownerOnly
                                ? null
                                : (v) => setState(() {
                                      _draftPermissions =
                                          StaffDashboardModules.toggleModule(
                                        current: _draftPermissions,
                                        moduleId: module.id,
                                        enabled: v == true,
                                      );
                                    }),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
