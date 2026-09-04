import 'package:flutter/material.dart';

import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';

/// Office homework desk — read-only. Teachers still post from teacher tiles.
class WebHomeworkPage extends StatefulWidget {
  const WebHomeworkPage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  State<WebHomeworkPage> createState() => _WebHomeworkPageState();
}

class _WebHomeworkPageState extends State<WebHomeworkPage> {
  String? _className;

  bool get _canView => ModuleAccess.canView('homework');
  String get _schoolId => AuthService.activeSchoolId ?? '';

  List<String> get _classes {
    final names = <String>{
      ...SchoolRegistryService.instance.sectionsForSchool(_schoolId),
      ...SchoolDataService.instance.homeworkSnapshot().map((h) => h.className),
      ...StudentRegistryService.instance
          .registrySnapshot()
          .where(
            (s) =>
                _schoolId.isEmpty ||
                s.schoolId.toUpperCase() == _schoolId.toUpperCase(),
          )
          .map((s) => s.className),
    };
    final list = names.where((n) => n.trim().isNotEmpty).toList()..sort();
    return list;
  }

  List<HomeworkItem> _itemsForFilter() {
    final all = SchoolDataService.instance.homeworkSnapshot();
    if (_className == null) return all.toList()
      ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
    return all
        .where(
          (h) => StudentRegistryService.classNamesMatch(h.className, _className!),
        )
        .toList()
      ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
  }

  @override
  Widget build(BuildContext context) {
    final narrow = WebViewport.isNarrow(context);
    if (!_canView) {
      return const Center(child: Text('You do not have access to homework.'));
    }
    final items = _itemsForFilter();
    return ListView(
      padding: EdgeInsets.all(narrow ? 12 : 20),
      children: [
        Text('Homework', style: WebErpTheme.sectionTitle(context)),
        const SizedBox(height: 4),
        Text(
          'Posted assignments for each class. This desk is read-only — '
          'teachers still create homework from their classroom tiles.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String?>(
            key: ValueKey('hw-class-$_className'),
            initialValue: _className,
            decoration: const InputDecoration(
              labelText: 'Class',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All classes'),
              ),
              for (final name in _classes)
                DropdownMenuItem(value: name, child: Text(name)),
            ],
            onChanged: (v) => setState(() => _className = v),
          ),
        ),
        const SizedBox(height: 14),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: WebErpTheme.cardDecoration(context),
            child: const Text('No homework posted for this class yet.'),
          )
        else
          for (final item in items) _card(item),
      ],
    );
  }

  Widget _card(HomeworkItem item) {
    final posted =
        '${item.postedAt.day}/${item.postedAt.month}/${item.postedAt.year}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: WebErpTheme.cardDecoration(context),
        child: ListTile(
          title: Text('${item.subject} · ${item.className}'),
          subtitle: Text(
            '${item.description}\n${item.teacherName} · $posted',
          ),
          isThreeLine: true,
        ),
      ),
    );
  }
}
