import 'package:flutter/material.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';

/// Admin management of the school's campuses. Students and teachers are
/// assigned to campuses; renames cascade to their records automatically.
class WebCampusManagementPage extends StatefulWidget {
  const WebCampusManagementPage({super.key});

  @override
  State<WebCampusManagementPage> createState() =>
      _WebCampusManagementPageState();
}

class _WebCampusManagementPageState extends State<WebCampusManagementPage> {
  final _registry = SchoolRegistryService.instance;

  String? get _schoolId => AuthService.activeSchoolId;

  List<String> get _campuses => _registry.campusesForSchool(_schoolId);

  int _studentCount(String campus) {
    final sid = _schoolId;
    if (sid == null) return 0;
    return StudentRegistryService.instance
        .studentsForSchool(sid)
        .where((s) => s.campus == campus)
        .length;
  }

  int _teacherCount(String campus) {
    final sid = _schoolId;
    if (sid == null) return 0;
    return TeacherRegistryService.instance
        .teachersForSchool(sid)
        .where((t) => t.campus == campus)
        .length;
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : Colors.green,
      ),
    );
  }

  Future<String?> _promptForName({required String title, String initial = ''}) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Campus name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addCampus() async {
    final sid = _schoolId;
    if (sid == null) return;
    final name = await _promptForName(title: 'Add Campus');
    if (name == null || name.isEmpty || !mounted) return;
    final ok = await _registry.addCampus(sid, name);
    if (!mounted) return;
    setState(() {});
    _snack(
      ok ? 'Campus "$name" added' : 'A campus with that name already exists',
      error: !ok,
    );
  }

  Future<void> _renameCampus(String from) async {
    final sid = _schoolId;
    if (sid == null) return;
    final to = await _promptForName(title: 'Rename Campus', initial: from);
    if (to == null || to.isEmpty || to == from || !mounted) return;
    final ok = await _registry.renameCampus(sid, from: from, to: to);
    if (!mounted) return;
    setState(() {});
    _snack(
      ok
          ? 'Renamed to "$to" — students and teachers were reassigned'
          : 'Rename failed (name may already exist)',
      error: !ok,
    );
  }

  Future<void> _deleteCampus(String name) async {
    final sid = _schoolId;
    if (sid == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete campus'),
        content: Text('Remove "$name" from this school?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await _registry.removeCampus(sid, name);
    if (!mounted) return;
    setState(() {});
    _snack(
      ok
          ? 'Campus "$name" removed'
          : 'Cannot delete: move its students and teachers first '
              '(the last campus cannot be deleted)',
      error: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final campuses = _campuses;
    final canManage = ModuleAccess.canManage('campus');

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Campus Management',
                  style: WebErpTheme.sectionTitle(context)),
              const Spacer(),
              FilledButton.icon(
                onPressed: canManage ? _addCampus : null,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Add Campus'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Students and teachers are assigned to a campus. Renaming a '
            'campus updates everyone on it; a campus can only be deleted '
            'when it is empty.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: campuses.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final campus = campuses[index];
                final students = _studentCount(campus);
                final teachers = _teacherCount(campus);
                final deletable =
                    campuses.length > 1 && students == 0 && teachers == 0;
                return ListTile(
                  tileColor: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  leading: const Icon(Icons.location_city_outlined),
                  title: Text(
                    campus,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('$students students · $teachers teachers'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Rename',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed:
                            canManage ? () => _renameCampus(campus) : null,
                      ),
                      IconButton(
                        tooltip: deletable
                            ? 'Delete'
                            : 'Only empty campuses can be deleted',
                        icon: Icon(
                          Icons.delete_outline,
                          color: deletable && canManage
                              ? Colors.red.shade700
                              : null,
                        ),
                        onPressed: deletable && canManage
                            ? () => _deleteCampus(campus)
                            : null,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
