import 'package:flutter/material.dart';

import 'package:mayabela/models/qa_monitor_models.dart';
import 'package:mayabela/services/curriculum_service.dart';
import 'package:mayabela/services/qa_monitor_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';

/// Phase I tabs hosted on the existing QA desk.
class QaMonitorTabs {
  QaMonitorTabs._();

  static Widget observations() => const _ObservationsTab();
  static Widget audits() => const _AuditsTab();
  static Widget surveys() => const _SurveysTab();
  static Widget research() => const _ResearchTab();
  static Widget analytics() => const _AnalyticsTab();
}

class _ObservationsTab extends StatelessWidget {
  const _ObservationsTab();

  @override
  Widget build(BuildContext context) {
    final svc = QaMonitorService.instance;
    final canManage = ModuleAccess.canManage('quality_assurance');
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final items = svc.observationsForSchool();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (canManage)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => _addObservation(context),
                  icon: const Icon(Icons.add),
                  label: const Text('New observation'),
                ),
              ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No teaching observations yet.'),
              ),
            for (final row in items)
              _card(
                context,
                title: '${row.teacherName} · ${row.subject}',
                subtitle:
                    '${row.className} · avg ${row.averageScore.toStringAsFixed(1)} · ${row.status.name}',
                body: [
                  Text(
                    'Planning ${row.planning} · Instruction ${row.instruction} · '
                    'Engagement ${row.engagement} · Assessment ${row.assessment}',
                  ),
                  if (row.notes.isNotEmpty) Text(row.notes),
                  if (canManage && row.status != ObservationStatus.shared)
                    TextButton(
                      onPressed: () => svc.shareObservation(row.id),
                      child: const Text('Share with teacher'),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  Future<void> _addObservation(BuildContext context) async {
    final svc = QaMonitorService.instance;
    final teachers = svc.teachersForPicker();
    var teacherId = teachers.isEmpty ? '' : teachers.first.teacherId;
    final subject = TextEditingController();
    final notes = TextEditingController();
    var planning = 3;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Teaching observation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (teachers.isNotEmpty)
                DropdownButtonFormField<String>(
                  key: ValueKey(teacherId),
                  initialValue: teacherId,
                  items: [
                    for (final t in teachers)
                      DropdownMenuItem(
                        value: t.teacherId,
                        child: Text(t.fullName),
                      ),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => teacherId = v ?? teacherId),
                ),
              TextField(
                controller: subject,
                decoration: const InputDecoration(labelText: 'Subject'),
              ),
              DropdownButtonFormField<int>(
                key: ValueKey(planning),
                initialValue: planning,
                decoration: const InputDecoration(labelText: 'Planning (1–5)'),
                items: [
                  for (var i = 1; i <= 5; i++)
                    DropdownMenuItem(value: i, child: Text('$i')),
                ],
                onChanged: (v) => setDialogState(() => planning = v ?? planning),
              ),
              TextField(
                controller: notes,
                decoration: const InputDecoration(labelText: 'Notes'),
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
        ),
      ),
    );
    if (ok != true) return;
    AdminTeacherRecord? teacher;
    for (final row in teachers) {
      if (row.teacherId == teacherId) teacher = row;
    }
    await svc.recordObservation(
      teacherName: teacher?.fullName ?? teacherId,
      teacherUsername: teacher?.loginUsername ?? '',
      teacherId: teacherId.isEmpty ? null : teacherId,
      className: teacher?.assignedClass ?? '',
      subject: subject.text,
      planning: planning,
      instruction: planning,
      engagement: planning,
      assessment: planning,
      notes: notes.text,
    );
  }
}

class _AuditsTab extends StatelessWidget {
  const _AuditsTab();

  @override
  Widget build(BuildContext context) {
    final svc = QaMonitorService.instance;
    final canManage = ModuleAccess.canManage('quality_assurance');
    return ListenableBuilder(
      listenable: Listenable.merge([svc, CurriculumService.instance]),
      builder: (context, _) {
        final items = svc.auditsForSchool();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (canManage)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => _addAudit(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Audit a unit'),
                ),
              ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No curriculum audits yet.'),
              ),
            for (final row in items)
              _card(
                context,
                title: '${row.unitTitle} · ${row.verdict.name}',
                subtitle: row.standardCodes.join(', '),
                body: [
                  if (row.notes.isNotEmpty) Text(row.notes),
                  Text(row.status.name),
                ],
              ),
          ],
        );
      },
    );
  }

  Future<void> _addAudit(BuildContext context) async {
    final units = CurriculumService.instance.unitsForSchool();
    if (units.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a curriculum unit first.')),
      );
      return;
    }
    var unitId = units.first.id;
    var verdict = AuditVerdict.aligned;
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Curriculum audit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey(unitId),
                initialValue: unitId,
                items: [
                  for (final unit in units)
                    DropdownMenuItem(value: unit.id, child: Text(unit.title)),
                ],
                onChanged: (v) => setDialogState(() => unitId = v ?? unitId),
              ),
              DropdownButtonFormField<AuditVerdict>(
                key: ValueKey(verdict),
                initialValue: verdict,
                items: [
                  for (final value in AuditVerdict.values)
                    DropdownMenuItem(value: value, child: Text(value.name)),
                ],
                onChanged: (v) => setDialogState(() => verdict = v ?? verdict),
              ),
              TextField(
                controller: notes,
                decoration: const InputDecoration(labelText: 'Notes'),
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
        ),
      ),
    );
    if (ok != true) return;
    await QaMonitorService.instance.recordAudit(
      curriculumUnitId: unitId,
      verdict: verdict,
      notes: notes.text,
    );
  }
}

class _SurveysTab extends StatelessWidget {
  const _SurveysTab();

  @override
  Widget build(BuildContext context) {
    final svc = QaMonitorService.instance;
    final canManage = ModuleAccess.canManage('quality_assurance');
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final items = svc.surveysForSchool();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (canManage)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => _addSurvey(context),
                  icon: const Icon(Icons.add),
                  label: const Text('New survey'),
                ),
              ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No surveys yet.'),
              ),
            for (final row in items)
              _card(
                context,
                title: '${row.title} · ${row.audience.name}',
                subtitle:
                    '${row.published ? 'Published' : 'Draft'} · ${svc.responsesForSurvey(row.id).length} responses',
                body: [
                  for (final q in row.questions)
                    Text(
                      '${q.prompt} · avg ${svc.surveyAverage(row.id, q.id)?.toStringAsFixed(1) ?? '—'}',
                    ),
                  if (canManage && !row.published)
                    TextButton(
                      onPressed: () => svc.publishSurvey(row.id),
                      child: const Text('Publish'),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  Future<void> _addSurvey(BuildContext context) async {
    final title = TextEditingController();
    var audience = SurveyAudience.all;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('QA survey'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              DropdownButtonFormField<SurveyAudience>(
                key: ValueKey(audience),
                initialValue: audience,
                items: [
                  for (final value in SurveyAudience.values)
                    DropdownMenuItem(value: value, child: Text(value.name)),
                ],
                onChanged: (v) => setDialogState(() => audience = v ?? audience),
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
        ),
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    await QaMonitorService.instance.createSurvey(
      title: title.text,
      audience: audience,
    );
  }
}

class _ResearchTab extends StatelessWidget {
  const _ResearchTab();

  @override
  Widget build(BuildContext context) {
    final svc = QaMonitorService.instance;
    final canManage = ModuleAccess.canManage('quality_assurance');
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final items = svc.researchForSchool();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (canManage)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => _addResearch(context),
                  icon: const Icon(Icons.add),
                  label: const Text('New cycle'),
                ),
              ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No action-research cycles yet.'),
              ),
            for (final row in items)
              _card(
                context,
                title: '${row.title} · ${row.status.name}',
                subtitle: row.inquiry,
                body: [
                  if (row.findings.isNotEmpty) Text(row.findings),
                  if (canManage && row.status != ActionResearchStatus.complete)
                    TextButton(
                      onPressed: () => svc.updateResearchStatus(
                        row.id,
                        ActionResearchStatus.complete,
                        findings: row.findings,
                      ),
                      child: const Text('Complete'),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  Future<void> _addResearch(BuildContext context) async {
    final title = TextEditingController();
    final inquiry = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Action research'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: inquiry,
              decoration: const InputDecoration(labelText: 'Inquiry'),
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
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    await QaMonitorService.instance.recordResearch(
      title: title.text,
      inquiry: inquiry.text,
    );
  }
}

class _AnalyticsTab extends StatelessWidget {
  const _AnalyticsTab();

  @override
  Widget build(BuildContext context) {
    final snap = QaMonitorService.instance.analyticsForSchool();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Read-only Phase F snapshot. This does not enter grades or '
          'attendance, and students/parents never see at-risk labels here.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text('At-risk · ${snap.atRisk}')),
            Chip(label: Text('Academic watch · ${snap.academicWatch}')),
            Chip(label: Text('Attendance watch · ${snap.attendanceWatch}')),
            Chip(label: Text('With grades · ${snap.withGrades}')),
            Chip(
              label: Text(
                'Avg absence ${(snap.averageAbsenceRate * 100).toStringAsFixed(0)}%',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Widget _card(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<Widget> body,
}) {
  return Padding(
    padding: const EdgeInsets.only(top: 10),
    child: DecoratedBox(
      decoration: WebErpTheme.cardDecoration(context),
      child: ExpansionTile(
        title: Text(title),
        subtitle: Text(subtitle),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: body,
      ),
    ),
  );
}
