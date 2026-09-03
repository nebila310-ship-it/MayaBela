import 'package:flutter/material.dart';

import 'package:mayabela/models/admission_application.dart';
import 'package:mayabela/services/admission_service.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/class_structure_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';

/// Registrar admissions desk — funnel, pipeline, documents, exam, offer, enroll.
class WebAdmissionsPage extends StatefulWidget {
  const WebAdmissionsPage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  State<WebAdmissionsPage> createState() => _WebAdmissionsPageState();
}

class _WebAdmissionsPageState extends State<WebAdmissionsPage> {
  AdmissionStage? _stageFilter;
  String _query = '';
  final _search = TextEditingController();

  bool get _canManage => ModuleAccess.canManage('admissions');
  String get _schoolId => AuthService.activeSchoolId ?? '';

  @override
  void initState() {
    super.initState();
    AdmissionService.instance.ensureLoaded();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final narrow = WebViewport.isNarrow(context);
    return ListenableBuilder(
      listenable: AdmissionService.instance,
      builder: (context, _) {
        var items = AdmissionService.instance.forSchool(_schoolId);
        if (_stageFilter != null) {
          items = items.where((a) => a.stage == _stageFilter).toList();
        }
        final q = _query.trim().toLowerCase();
        if (q.isNotEmpty) {
          items = items
              .where(
                (a) =>
                    a.fullName.toLowerCase().contains(q) ||
                    a.id.toLowerCase().contains(q) ||
                    a.guardianPhone.contains(q),
              )
              .toList();
        }
        return SingleChildScrollView(
          padding: EdgeInsets.all(narrow ? 12 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Admissions', style: WebErpTheme.sectionTitle(context)),
              const SizedBox(height: 4),
              Text(
                'Inquiry → application → documents → entrance exam → '
                'waitlist / offer → enrollment. Online and walk-in applications '
                'share this pipeline.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              _funnel(context, narrow),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_canManage)
                    FilledButton.icon(
                      onPressed: () => _showNewDialog(context),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('New inquiry / application'),
                    ),
                  SizedBox(
                    width: 240,
                    child: TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        hintText: 'Search name, ID, phone…',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('All open'),
                    selected: _stageFilter == null,
                    onSelected: (_) => setState(() => _stageFilter = null),
                  ),
                  for (final stage in AdmissionApplication.funnelStages)
                    ChoiceChip(
                      label: Text(AdmissionApplication.stageLabelOf(stage)),
                      selected: _stageFilter == stage,
                      onSelected: (_) => setState(() => _stageFilter = stage),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (items.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: WebErpTheme.cardDecoration(context),
                  child: const Text('No applications in this filter yet.'),
                )
              else
                ...items.map((a) => _card(context, a)),
            ],
          ),
        );
      },
    );
  }

  Widget _funnel(BuildContext context, bool narrow) {
    final svc = AdmissionService.instance;
    final counts = svc.funnelCounts(_schoolId);
    final tiles = [
      ('Open', '${svc.openCount(_schoolId)}', Icons.inbox_outlined),
      ('Waitlist', '${svc.waitlistCount(_schoolId)}', Icons.queue_outlined),
      (
        'Enrolled this year',
        '${svc.enrolledThisYear(_schoolId)}',
        Icons.how_to_reg_outlined,
      ),
      (
        'Offers',
        '${counts[AdmissionStage.offered] ?? 0}',
        Icons.mail_outline,
      ),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (label, value, icon) in tiles)
          SizedBox(
            width: narrow ? double.infinity : 210,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: WebErpTheme.cardDecoration(context),
              child: Row(
                children: [
                  Icon(icon, color: WebErpTheme.primary),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(label),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _card(BuildContext context, AdmissionApplication app) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDetail(context, app.id),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: WebErpTheme.cardDecoration(context),
            child: Row(
              children: [
                CircleAvatar(
                  child: Text(
                    app.fullName.isEmpty ? '?' : app.fullName[0].toUpperCase(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${app.id} · ${app.gradeApplying.isEmpty ? 'Grade TBD' : app.gradeApplying}'
                        '${app.guardianPhone.isEmpty ? '' : ' · ${app.guardianPhone}'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Chip(label: Text(app.stageLabel)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showNewDialog(BuildContext context) async {
    final name = TextEditingController();
    final grade = TextEditingController();
    final guardian = TextEditingController();
    final phone = TextEditingController();
    final school = TextEditingController();
    var asApplication = false;
    final grades = ClassStructureService.instance.gradesForSchool();
    final campuses =
        SchoolRegistryService.instance.campusesForSchool(_schoolId);

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('New inquiry / application'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: name,
                        decoration: const InputDecoration(
                          labelText: 'Student full name',
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (grades.isEmpty)
                        TextField(
                          controller: grade,
                          decoration: const InputDecoration(
                            labelText: 'Grade applying',
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                        initialValue: grades.contains(grade.text)
                            ? grade.text
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Grade applying',
                        ),
                        items: [
                          for (final g in grades)
                            DropdownMenuItem(value: g, child: Text(g)),
                        ],
                        onChanged: (v) {
                          grade.text = v ?? '';
                          setLocal(() {});
                        },
                      ),
                      if (campuses.length > 1) ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: campuses.contains(school.text)
                              ? school.text
                              : null,
                          decoration:
                              const InputDecoration(labelText: 'Campus'),
                          items: [
                            for (final c in campuses)
                              DropdownMenuItem(value: c, child: Text(c)),
                          ],
                          onChanged: (v) => school.text = v ?? '',
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextField(
                        controller: guardian,
                        decoration:
                            const InputDecoration(labelText: 'Guardian name'),
                      ),
                      TextField(
                        controller: phone,
                        decoration:
                            const InputDecoration(labelText: 'Guardian phone'),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Record as submitted application'),
                        value: asApplication,
                        onChanged: (v) => setLocal(() => asApplication = v),
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
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (created != true || name.text.trim().isEmpty) return;
    await AdmissionService.instance.createInquiry(
      fullName: name.text,
      gradeApplying: grade.text,
      campus: school.text,
      guardianName: guardian.text,
      guardianPhone: phone.text,
      source: AdmissionSource.walkIn,
      stage: asApplication
          ? AdmissionStage.application
          : AdmissionStage.inquiry,
    );
  }

  Future<void> _openDetail(BuildContext context, String id) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return ListenableBuilder(
          listenable: AdmissionService.instance,
          builder: (ctx, _) {
            final app = AdmissionService.instance.byId(id);
            if (app == null) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Application not found.'),
              );
            }
            return _AdmissionDetail(
              application: app,
              canManage: _canManage,
            );
          },
        );
      },
    );
  }
}

class _AdmissionDetail extends StatelessWidget {
  const _AdmissionDetail({
    required this.application,
    required this.canManage,
  });

  final AdmissionApplication application;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final app = application;
    final next = AdmissionApplication.nextStages(app.stage);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      builder: (context, controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              app.fullName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            Text('${app.id} · ${app.stageLabel} · ${app.source.name}'),
            const SizedBox(height: 8),
            Text(
              [
                if (app.gradeApplying.isNotEmpty) 'Grade ${app.gradeApplying}',
                if (app.campus.isNotEmpty) app.campus,
                if (app.guardianName.isNotEmpty) app.guardianName,
                if (app.guardianPhone.isNotEmpty) app.guardianPhone,
              ].join(' · '),
            ),
            if (app.enrolledStudentId != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Enrolled as ${app.enrolledStudentId}'),
              ),
            const SizedBox(height: 16),
            Text('Documents', style: WebErpTheme.sectionTitle(context)),
            for (final doc in app.documents)
              CheckboxListTile(
                value: doc.verified,
                title: Text(doc.label),
                subtitle: Text(doc.verified ? 'Verified' : 'Awaiting review'),
                onChanged: !canManage
                    ? null
                    : (v) => AdmissionService.instance.setDocument(
                          app.id,
                          doc.id,
                          submitted: true,
                          verified: v ?? false,
                        ),
              ),
            const SizedBox(height: 8),
            Text('Entrance exam', style: WebErpTheme.sectionTitle(context)),
            if (app.examDate != null || app.examScore != null)
              Text(
                [
                  if (app.examDate != null)
                    'Scheduled ${app.examDate!.toIso8601String().substring(0, 10)}',
                  if (app.examScore != null)
                    'Score ${app.examScore} / ${app.examMaxScore}',
                ].join(' · '),
              ),
            if (canManage)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _examDialog(context, app),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Schedule / score exam'),
                ),
              ),
            const SizedBox(height: 12),
            if (canManage && next.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final stage in next)
                    FilledButton.tonal(
                      onPressed: () => _advance(context, app, stage),
                      child: Text(AdmissionApplication.stageLabelOf(stage)),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  Future<void> _advance(
    BuildContext context,
    AdmissionApplication app,
    AdmissionStage stage,
  ) async {
    if (stage == AdmissionStage.enrolled) {
      await _enrollDialog(context, app);
      return;
    }
    if (stage == AdmissionStage.waitlist) {
      await AdmissionService.instance.placeOnWaitlist(app.id);
      return;
    }
    if (stage == AdmissionStage.documentsVerified && !app.documentsComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verify all required documents first.'),
        ),
      );
      return;
    }
    await AdmissionService.instance.moveTo(app.id, stage);
  }

  Future<void> _examDialog(
    BuildContext context,
    AdmissionApplication app,
  ) async {
    final score = TextEditingController(
      text: app.examScore?.toString() ?? '',
    );
    DateTime date = app.examDate ?? DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Entrance exam'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Date ${date.toIso8601String().substring(0, 10)}'),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) date = picked;
                },
              ),
              TextField(
                controller: score,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Score (leave blank to schedule only)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    final parsed = double.tryParse(score.text.trim());
    await AdmissionService.instance.recordExam(
      app.id,
      examDate: date,
      score: parsed,
    );
  }

  Future<void> _enrollDialog(
    BuildContext context,
    AdmissionApplication app,
  ) async {
    final grades = ClassStructureService.instance.gradesForSchool();
    var grade = grades.contains(app.gradeApplying)
        ? app.gradeApplying
        : (grades.isEmpty ? app.gradeApplying : grades.first);
    var sections = ClassStructureService.instance.sectionsForGrade(grade);
    var section = sections.isEmpty ? 'A' : sections.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Enroll into student registry'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: grades.contains(grade) ? grade : null,
                    decoration: const InputDecoration(labelText: 'Grade'),
                    items: [
                      for (final g in grades)
                        DropdownMenuItem(value: g, child: Text(g)),
                    ],
                    onChanged: (v) {
                      grade = v ?? grade;
                      sections =
                          ClassStructureService.instance.sectionsForGrade(grade);
                      section = sections.isEmpty ? 'A' : sections.first;
                      setLocal(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: sections.contains(section) ? section : null,
                    decoration: const InputDecoration(labelText: 'Section'),
                    items: [
                      for (final s in sections)
                        DropdownMenuItem(value: s, child: Text(s)),
                    ],
                    onChanged: (v) => section = v ?? section,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Enroll'),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok != true) return;
    final className =
        ClassStructureService.instance.classNameFor(grade, section);
    final student = await AdmissionService.instance.enroll(
      app.id,
      className: className,
      grade: grade,
      campus: app.campus,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          student == null
              ? 'Could not enroll. Accept the offer first.'
              : 'Enrolled as ${student.studentId}',
        ),
      ),
    );
  }
}
