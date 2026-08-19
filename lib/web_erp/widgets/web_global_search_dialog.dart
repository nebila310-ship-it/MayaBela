import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';

class WebGlobalSearchResult {
  const WebGlobalSearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.routeId,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String routeId;
}

Future<void> showWebGlobalSearchDialog(
  BuildContext context, {
  required ValueChanged<String> onSelectRoute,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _WebGlobalSearchDialog(onSelectRoute: onSelectRoute),
  );
}

class _WebGlobalSearchDialog extends StatefulWidget {
  const _WebGlobalSearchDialog({required this.onSelectRoute});

  final ValueChanged<String> onSelectRoute;

  @override
  State<_WebGlobalSearchDialog> createState() => _WebGlobalSearchDialogState();
}

class _WebGlobalSearchDialogState extends State<_WebGlobalSearchDialog> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  List<WebGlobalSearchResult> _results = [];

  @override
  void initState() {
    super.initState();
    _refresh('');
    _controller.addListener(() => _refresh(_controller.text));
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _refresh(String query) {
    final q = query.trim().toLowerCase();
    final schoolId = AuthService.activeSchoolId;
    final out = <WebGlobalSearchResult>[];

    for (final item in webErpNavItemsForCurrentUser()) {
      if (item.isLogout || item.isDivider) continue;
      if (q.isEmpty || item.label.toLowerCase().contains(q)) {
        out.add(
          WebGlobalSearchResult(
            id: 'nav-${item.id}',
            title: item.label,
            subtitle: 'Navigate',
            icon: item.icon,
            routeId: item.id,
          ),
        );
      }
    }

    final students = schoolId == null
        ? StudentRegistryService.instance.getAllStudents()
        : StudentRegistryService.instance.studentsForSchool(schoolId);
    for (final s in students) {
      if (q.isEmpty ||
          s.fullName.toLowerCase().contains(q) ||
          s.studentId.toLowerCase().contains(q)) {
        out.add(
          WebGlobalSearchResult(
            id: 'stu-${s.studentId}',
            title: s.fullName,
            subtitle: '${s.studentId} · ${s.grade}',
            icon: Icons.person_outline,
            routeId: 'students',
          ),
        );
      }
    }

    final teachers = schoolId == null
        ? TeacherRegistryService.instance.getAllTeachers()
        : TeacherRegistryService.instance.teachersForSchool(schoolId);
    for (final t in teachers) {
      if (q.isEmpty ||
          t.fullName.toLowerCase().contains(q) ||
          t.employeeId?.toLowerCase().contains(q) == true ||
          t.teacherId.toLowerCase().contains(q)) {
        out.add(
          WebGlobalSearchResult(
            id: 'tea-${t.teacherId}',
            title: t.fullName,
            subtitle: t.employeeId ?? t.teacherId,
            icon: Icons.school_outlined,
            routeId: 'teachers',
          ),
        );
      }
    }

    setState(() => _results = out.take(20).toList());
  }

  void _pick(WebGlobalSearchResult result) {
    Navigator.pop(context);
    widget.onSelectRoute(result.routeId);
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              Navigator.pop(context);
              return null;
            },
          ),
        },
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640, maxHeight: 480),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    decoration: InputDecoration(
                      hintText: 'Search students, teachers, modules…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Ctrl+K', style: TextStyle(fontSize: 11)),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final r = _results[index];
                      return ListTile(
                        leading: Icon(r.icon),
                        title: Text(r.title),
                        subtitle: Text(r.subtitle),
                        onTap: () => _pick(r),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
