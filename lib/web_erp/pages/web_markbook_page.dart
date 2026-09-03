import 'package:flutter/material.dart';

import 'package:mayabela/constants/school_subjects.dart';
import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/markbook.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/markbook_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';

/// Weighted markbook grid and school category weights.
class WebMarkbookPage extends StatefulWidget {
  const WebMarkbookPage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  State<WebMarkbookPage> createState() => _WebMarkbookPageState();
}

class _WebMarkbookPageState extends State<WebMarkbookPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _data = SchoolDataService.instance;
  final _markbook = MarkbookService.instance;

  String? _className;
  String? _subject;
  final _cells = <String, Map<String, TextEditingController>>{};
  var _saving = false;

  bool get _canManage => ModuleAccess.canManage('markbook');
  String get _schoolId => AuthService.activeSchoolId ?? '';

  List<String> get _classes {
    final names = <String>{
      ...SchoolRegistryService.instance.sectionsForSchool(_schoolId),
      ..._data.getAllGradeReports().map((r) => r.className),
      ...StudentRegistryService.instance
          .registrySnapshot()
          .where((s) =>
              _schoolId.isEmpty ||
              s.schoolId.toUpperCase() == _schoolId.toUpperCase())
          .map((s) => s.className),
    };
    final list = names.where((n) => n.trim().isNotEmpty).toList()..sort();
    return list;
  }

  List<String> get _subjects {
    final className = _className;
    final fromReports = className == null
        ? const <String>{}
        : _data
            .getGradeReportsForClass(className)
            .expand((r) => r.subjects.map((s) => s.subject))
            .toSet();
    final list = {...fromReports, ...SchoolSubjects.all}.toList()..sort();
    return list;
  }

  List<StudentRefName> get _students {
    final className = _className;
    if (className == null) return const [];
    final roster = _data.getStudentsForClass(className);
    if (roster.isNotEmpty) {
      return roster
          .map((s) => StudentRefName(name: s.name, id: s.registryStudentId))
          .toList();
    }
    return _data
        .getGradeReportsForClass(className)
        .map((r) => StudentRefName(name: r.studentName, id: r.studentId))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    final classes = _classes;
    if (classes.isNotEmpty) _className = classes.first;
    final subjects = _subjects;
    if (subjects.isNotEmpty) _subject = subjects.first;
    _reloadCells();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _disposeCells();
    super.dispose();
  }

  void _disposeCells() {
    for (final row in _cells.values) {
      for (final c in row.values) {
        c.dispose();
      }
    }
    _cells.clear();
  }

  void _reloadCells() {
    _disposeCells();
    final className = _className;
    final subject = _subject;
    if (className == null || subject == null) return;
    for (final student in _students) {
      SubjectGrade? grade;
      for (final report in _data.getGradeReportsForClass(className)) {
        if (report.studentName != student.name) continue;
        for (final item in report.subjects) {
          if (item.subject == subject) {
            grade = item;
            break;
          }
        }
      }
      final marks = grade == null
          ? _markbook.templateMarks()
          : _markbook.marksForSubject(grade);
      _cells[student.name] = {
        for (final mark in marks)
          mark.categoryId: TextEditingController(
            text: mark.score == null ? '' : mark.score!.toStringAsFixed(0),
          ),
      };
    }
  }

  Future<void> _save({required bool submit}) async {
    if (!_canManage || _saving) return;
    final className = _className;
    final subject = _subject;
    if (className == null || subject == null) return;
    final cats = _markbook.settingsForSchool().categories;
    final assessments = <String, List<AssessmentMark>>{};
    for (final student in _students) {
      final row = _cells[student.name];
      if (row == null) continue;
      final marks = <AssessmentMark>[];
      var any = false;
      for (final cat in cats) {
        final raw = row[cat.id]?.text.trim() ?? '';
        double? score;
        if (raw.isNotEmpty) {
          score = double.tryParse(raw);
          if (score == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Invalid score for ${student.name} (${cat.label})')),
            );
            return;
          }
          score = score.clamp(0, 100);
          any = true;
        }
        marks.add(
          AssessmentMark(
            categoryId: cat.id,
            label: cat.label,
            weightPercent: cat.weightPercent,
            score: score,
            enteredAt: score == null ? null : DateTime.now(),
          ),
        );
      }
      if (any) assessments[student.name] = marks;
    }
    if (assessments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one category score.')),
      );
      return;
    }
    setState(() => _saving = true);
    final result = _markbook.enterClassAssessments(
      className: className,
      subject: subject,
      teacherId: AuthService.currentUser?.username ?? 'staff',
      assessmentsByStudent: assessments,
      submitForApproval: submit,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _reloadCells();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          submit
              ? 'Submitted ${result.saved} weighted score(s) for approval'
              : 'Saved ${result.saved} weighted score(s)',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final narrow = WebViewport.isNarrow(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(narrow ? 12 : 20, narrow ? 12 : 20, narrow ? 12 : 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Weighted markbook', style: WebErpTheme.sectionTitle(context)),
              const SizedBox(height: 4),
              Text(
                'Enter homework, quizzes, classwork, midterm, and final. '
                'The subject total is the weighted percentage and still goes through the existing grade approval chain.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabs: const [
                  Tab(text: 'Class grid'),
                  Tab(text: 'Category weights'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _gridTab(narrow),
              _weightsTab(narrow),
            ],
          ),
        ),
      ],
    );
  }

  Widget _gridTab(bool narrow) {
    final cats = _markbook.settingsForSchool().categories;
    final students = _students;
    return ListenableBuilder(
      listenable: _markbook,
      builder: (context, _) {
        return ListView(
          padding: EdgeInsets.all(narrow ? 12 : 20),
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('class-$_className'),
                    initialValue: _className,
                    decoration: const InputDecoration(
                      labelText: 'Class',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final name in _classes)
                        DropdownMenuItem(value: name, child: Text(name)),
                    ],
                    onChanged: (v) => setState(() {
                      _className = v;
                      final subjects = _subjects;
                      if (subjects.isNotEmpty &&
                          (v == null || !subjects.contains(_subject))) {
                        _subject = subjects.first;
                      }
                      _reloadCells();
                    }),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('subject-$_subject'),
                    initialValue: _subjects.contains(_subject) ? _subject : null,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final name in _subjects)
                        DropdownMenuItem(value: name, child: Text(name)),
                    ],
                    onChanged: (v) => setState(() {
                      _subject = v;
                      _reloadCells();
                    }),
                  ),
                ),
                if (_canManage) ...[
                  FilledButton.icon(
                    onPressed: _saving ? null : () => _save(submit: false),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving…' : 'Save drafts'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : () => _save(submit: true),
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Save & submit for approval'),
                  ),
                ],
                TextButton(
                  onPressed: () => widget.onNavigate?.call('report_cards'),
                  child: const Text('Open report cards'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (cats.isNotEmpty)
              Text(
                cats
                    .map((c) =>
                        '${c.label} ${c.weightPercent.toStringAsFixed(0)}%')
                    .join('  ·  '),
                style: TextStyle(color: Colors.grey.shade700),
              ),
            const SizedBox(height: 12),
            if (cats.isEmpty)
              const Text('Add category weights first, or enter a single final on the teacher grade screen.')
            else if (students.isEmpty)
              const Text('No students in this class yet.')
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStatePropertyAll(Colors.grey.shade100),
                  columns: [
                    const DataColumn(label: Text('Student')),
                    for (final cat in cats)
                      DataColumn(
                        label: Text(
                          '${cat.label}\n${cat.weightPercent.toStringAsFixed(0)}%',
                        ),
                      ),
                    const DataColumn(label: Text('Final')),
                    const DataColumn(label: Text('Letter')),
                  ],
                  rows: [
                    for (final student in students)
                      DataRow(
                        cells: [
                          DataCell(Text(student.name)),
                          for (final cat in cats)
                            DataCell(
                              SizedBox(
                                width: 72,
                                child: TextField(
                                  controller: _cells[student.name]?[cat.id],
                                  enabled: _canManage,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ),
                          DataCell(Text(_finalFor(student.name))),
                          DataCell(Text(_letterFor(student.name))),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  String _finalFor(String studentName) {
    final cats = _markbook.settingsForSchool().categories;
    final row = _cells[studentName];
    if (row == null) return '—';
    final marks = [
      for (final cat in cats)
        AssessmentMark(
          categoryId: cat.id,
          label: cat.label,
          weightPercent: cat.weightPercent,
          score: double.tryParse(row[cat.id]?.text.trim() ?? ''),
        ),
    ];
    if (!marks.any((m) => m.isEntered)) return '—';
    final pct = MarkbookMath.weightedPercentage(
      marks,
      missingCountsAsZero: _markbook.settingsForSchool().missingCountsAsZero,
    );
    return pct.toStringAsFixed(1);
  }

  String _letterFor(String studentName) {
    final raw = _finalFor(studentName);
    if (raw == '—') return '—';
    return MarkbookMath.letterFromPercentage(double.tryParse(raw) ?? 0);
  }

  Widget _weightsTab(bool narrow) {
    return _MarkbookWeightsEditor(
      canManage: _canManage,
      padding: EdgeInsets.all(narrow ? 12 : 20),
    );
  }
}

class StudentRefName {
  const StudentRefName({required this.name, this.id});
  final String name;
  final String? id;
}

class _MarkbookWeightsEditor extends StatefulWidget {
  const _MarkbookWeightsEditor({
    required this.canManage,
    required this.padding,
  });

  final bool canManage;
  final EdgeInsets padding;

  @override
  State<_MarkbookWeightsEditor> createState() => _MarkbookWeightsEditorState();
}

class _MarkbookWeightsEditorState extends State<_MarkbookWeightsEditor> {
  late List<AssessmentCategory> _cats;
  late bool _missingZero;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final settings = MarkbookService.instance.settingsForSchool();
    _cats = List.of(settings.categories);
    _missingZero = settings.missingCountsAsZero;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final error = await MarkbookService.instance.saveSettings(
      MarkbookSettings(
        categories: _cats,
        missingCountsAsZero: _missingZero,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Category weights saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _cats.fold<double>(0, (s, c) => s + c.weightPercent);
    return ListView(
      padding: widget.padding,
      children: [
        Text(
          'School-wide weights for every subject. Teachers enter marks in these columns; the final is the weighted average.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _cats.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: _cats[i].label,
                    enabled: widget.canManage,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => _cats[i] = _cats[i].copyWith(label: v),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    initialValue: _cats[i].weightPercent.toStringAsFixed(0),
                    enabled: widget.canManage,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Weight %',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      final n = double.tryParse(v) ?? 0;
                      setState(() => _cats[i] = _cats[i].copyWith(weightPercent: n));
                    },
                  ),
                ),
                if (widget.canManage)
                  IconButton(
                    tooltip: 'Remove',
                    onPressed: () => setState(() => _cats.removeAt(i)),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
          ),
        Text(
          'Total: ${total.toStringAsFixed(1)}%',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: (total - 100).abs() < 0.05 ? Colors.green.shade800 : Colors.orange.shade800,
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Count missing categories as zero'),
          subtitle: const Text(
            'Off: live standing uses only entered marks (weights renormalized). '
            'On: a blank category is 0% of its weight.',
          ),
          value: _missingZero,
          onChanged: widget.canManage
              ? (v) => setState(() => _missingZero = v)
              : null,
        ),
        if (widget.canManage) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _cats.add(
                    AssessmentCategory(
                      id: 'cat-${DateTime.now().millisecondsSinceEpoch}',
                      label: 'New category',
                      weightPercent: 0,
                    ),
                  );
                }),
                icon: const Icon(Icons.add),
                label: const Text('Add category'),
              ),
              OutlinedButton(
                onPressed: () => setState(() {
                  _cats = List.of(MarkbookSettings.liaDefaults.categories);
                  _missingZero = false;
                }),
                child: const Text('Reset LIA defaults'),
              ),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save weights'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
