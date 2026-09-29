import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/module_right.dart';
import 'package:mayabela/services/rbac/role_module_catalog.dart';
import 'package:mayabela/services/rbac/school_role_catalog_service.dart';
import 'package:mayabela/services/rbac/staff_dashboard_modules.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';
import 'package:mayabela/widgets/staff_roles_dialog.dart';

/// School-owner screen: grant none / read / edit on every ERP module and
/// sub-module per staff role. Full Access stays owner-only.
class StaffRoleConfigPage extends StatefulWidget {
  const StaffRoleConfigPage({super.key});

  @override
  State<StaffRoleConfigPage> createState() => _StaffRoleConfigPageState();
}

class _StaffRoleConfigPageState extends State<StaffRoleConfigPage> {
  bool _loading = true;
  String? _selectedKey;
  Map<String, ModuleRight> _draftRights = {};
  final _customLabel = TextEditingController();
  final _filter = TextEditingController();

  AppStrings get s => AppLocale.instance.strings;

  @override
  void initState() {
    super.initState();
    _filter.addListener(() => setState(() {}));
    _bootstrap();
  }

  @override
  void dispose() {
    _customLabel.dispose();
    _filter.dispose();
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
      _loadDraft(first);
    });
  }

  List<StaffRole> get _roles =>
      SchoolRoleCatalogService.instance.rolesForAssign();

  StaffRole? get _selected {
    final key = _selectedKey;
    if (key == null) return null;
    return SchoolRoleCatalogService.instance.lookup(key);
  }

  void _loadDraft(StaffRole role) {
    _selectedKey = role.key;
    _draftRights = RoleModuleCatalog.hydrate(
      SchoolRoleCatalogService.instance.moduleRightsFor(role.key),
      role: role,
    );
  }

  void _selectRole(StaffRole role) {
    setState(() => _loadDraft(role));
  }

  void _setModuleRight(String moduleId, ModuleRight right) {
    final spec = RoleModuleCatalog.byId[moduleId];
    if (spec == null || !spec.configurable) return;
    setState(() {
      _draftRights = {..._draftRights, moduleId: right};
    });
  }

  void _setSectionRight(String section, ModuleRight right) {
    setState(() {
      _draftRights = RoleModuleCatalog.applySectionRight(
        current: _draftRights,
        section: section,
        right: right,
      );
    });
  }

  Future<void> _save() async {
    final key = _selectedKey;
    final selected = _selected;
    if (key == null || selected == null) return;
    final permissions = RoleModuleCatalog.permissionsFor(
      _draftRights,
      previous: selected.permissions,
    );
    final err = await SchoolRoleCatalogService.instance.saveRoleModules(
      roleKey: key,
      permissions: permissions,
      moduleRights: _draftRights,
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
    setState(() => _loadDraft(added));
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
    final narrow = WebViewport.isNarrow(context);
    final roleList = _buildRoleListPane(narrow: narrow);
    final modulesPane = _buildModulesPane(selected, narrow: narrow);

    return Padding(
      padding: EdgeInsets.all(narrow ? 12 : 20),
      child: narrow
          ? ListView(
              children: [
                SizedBox(height: 280, child: roleList),
                const SizedBox(height: 12),
                SizedBox(height: 720, child: modulesPane),
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
              'Pick a role, then set None, Read, or Edit on each module and sub-module. Messages, dashboard, profile, and settings stay on for every role.',
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

  Widget _buildModulesPane(StaffRole? selected, {required bool narrow}) {
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
                else ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(narrow ? 12 : 20, 0, narrow ? 12 : 20, 8),
                    child: const Text(
                      'None hides the desk. Read lets the role open it without changing records. Edit allows changes. A section shows Partial when its sub-modules mix those rights.',
                      style: TextStyle(fontSize: 12, height: 1.35),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(narrow ? 12 : 20, 0, narrow ? 12 : 20, 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _CountChip(
                          label: 'Edit',
                          count: _count(ModuleRight.edit),
                          color: const Color(0xFF2E7D32),
                        ),
                        _CountChip(
                          label: 'Read',
                          count: _count(ModuleRight.read),
                          color: const Color(0xFF1565C0),
                        ),
                        _CountChip(
                          label: 'None',
                          count: _count(ModuleRight.none),
                          color: const Color(0xFF616161),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _draftRights = RoleModuleCatalog.applyAllConfigurable(
                              _draftRights,
                              ModuleRight.none,
                            );
                          }),
                          child: const Text('Clear all'),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _draftRights = RoleModuleCatalog.applyAllConfigurable(
                              _draftRights,
                              ModuleRight.read,
                            );
                          }),
                          child: const Text('All read'),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _draftRights = RoleModuleCatalog.applyAllConfigurable(
                              _draftRights,
                              ModuleRight.edit,
                            );
                          }),
                          child: const Text('All edit'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(narrow ? 12 : 20, 0, narrow ? 12 : 20, 8),
                    child: TextField(
                      controller: _filter,
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: 20),
                        hintText: 'Filter modules and sub-modules',
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(8, 0, 8, narrow ? 12 : 20),
                      children: [
                        for (final section in _visibleSections)
                          _SectionBlock(
                            section: section,
                            specs: _visibleItems(section),
                            rights: _draftRights,
                            onModuleChanged: _setModuleRight,
                            onSectionChanged: _setSectionRight,
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  int _count(ModuleRight right) {
    var n = 0;
    for (final spec in RoleModuleCatalog.configurableItems) {
      if ((_draftRights[spec.id] ?? ModuleRight.none) == right) n++;
    }
    return n;
  }

  String get _query => _filter.text.trim().toLowerCase();

  List<String> get _visibleSections {
    return RoleModuleCatalog.sections
        .where((section) => _visibleItems(section).isNotEmpty)
        .toList();
  }

  List<RoleModuleSpec> _visibleItems(String section) {
    final q = _query;
    return RoleModuleCatalog.itemsInSection(section).where((spec) {
      if (q.isEmpty) return true;
      return spec.label.toLowerCase().contains(q) ||
          spec.id.toLowerCase().contains(q) ||
          spec.section.toLowerCase().contains(q);
    }).toList();
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(
        '$count $label',
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      backgroundColor: color.withValues(alpha: 0.08),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.section,
    required this.specs,
    required this.rights,
    required this.onModuleChanged,
    required this.onSectionChanged,
  });

  final String section;
  final List<RoleModuleSpec> specs;
  final Map<String, ModuleRight> rights;
  final void Function(String moduleId, ModuleRight right) onModuleChanged;
  final void Function(String section, ModuleRight right) onSectionChanged;

  @override
  Widget build(BuildContext context) {
    final configurable = specs.where((spec) => spec.configurable).toList();
    final summary = SectionRight.fromChildren(
      configurable.map((spec) => rights[spec.id] ?? ModuleRight.none),
    );
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 10),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(
          section,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: configurable.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _RightSelector(
                  value: summary == SectionRight.partial
                      ? null
                      : switch (summary) {
                          SectionRight.none => ModuleRight.none,
                          SectionRight.read => ModuleRight.read,
                          SectionRight.edit => ModuleRight.edit,
                          SectionRight.partial => null,
                        },
                  partial: summary == SectionRight.partial,
                  onChanged: (right) => onSectionChanged(section, right),
                ),
              ),
        children: [
          for (final spec in specs)
            _ModuleRightRow(
              spec: spec,
              right: rights[spec.id] ?? spec.lockedRight ?? ModuleRight.none,
              onChanged: spec.configurable
                  ? (right) => onModuleChanged(spec.id, right)
                  : null,
            ),
        ],
      ),
    );
  }
}

class _ModuleRightRow extends StatelessWidget {
  const _ModuleRightRow({
    required this.spec,
    required this.right,
    required this.onChanged,
  });

  final RoleModuleSpec spec;
  final ModuleRight right;
  final ValueChanged<ModuleRight>? onChanged;

  @override
  Widget build(BuildContext context) {
    final locked = onChanged == null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(spec.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (spec.ownerOnly || spec.alwaysOn)
                  Text(
                    spec.ownerOnly
                        ? 'Owner only'
                        : 'Included for every role',
                    style: const TextStyle(fontSize: 11),
                  ),
              ],
            ),
          ),
          _RightSelector(
            value: right,
            enabled: !locked,
            onChanged: onChanged ?? (_) {},
          ),
        ],
      ),
    );
  }
}

class _RightSelector extends StatelessWidget {
  const _RightSelector({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.partial = false,
  });

  final ModuleRight? value;
  final ValueChanged<ModuleRight> onChanged;
  final bool enabled;
  final bool partial;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: [
        if (partial)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Chip(
              visualDensity: VisualDensity.compact,
              label: Text('Partial', style: TextStyle(fontSize: 11)),
            ),
          ),
        _chip('None', ModuleRight.none, const Color(0xFF616161)),
        _chip('Read', ModuleRight.read, const Color(0xFF1565C0)),
        _chip('Edit', ModuleRight.edit, const Color(0xFF2E7D32)),
      ],
    );
  }

  Widget _chip(String label, ModuleRight right, Color color) {
    final selected = value == right;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      selectedColor: color.withValues(alpha: 0.18),
      side: BorderSide(color: selected ? color : Colors.grey.shade400),
      labelStyle: TextStyle(color: selected ? color : Colors.grey.shade800),
      onSelected: enabled ? (_) => onChanged(right) : null,
    );
  }
}
