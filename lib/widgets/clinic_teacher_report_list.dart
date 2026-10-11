import 'package:flutter/material.dart';

import 'package:mayabela/models/student_support_models.dart';
import 'package:mayabela/services/student_support_service.dart';
import 'package:mayabela/theme/teacher_theme.dart';

/// Expandable clinic / incident reports for a homeroom teacher.
class ClinicTeacherReportList extends StatelessWidget {
  const ClinicTeacherReportList({
    super.key,
    required this.reports,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
  });

  final List<HealthRecord> reports;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No clinic or incident reports for your homeroom yet. '
            'When Student Support takes a child to the clinic, the report '
            'lands here so you can watch for special attention or follow-up.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: padding,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'Tap a report to see what happened, the clinic decision, and '
            'whether this child needs follow-up in class.',
          ),
        ),
        for (final row in reports) _ClinicTeacherReportTile(row: row),
      ],
    );
  }
}

class _ClinicTeacherReportTile extends StatelessWidget {
  const _ClinicTeacherReportTile({required this.row});

  final HealthRecord row;

  @override
  Widget build(BuildContext context) {
    final attention = row.needsSpecialAttention;
    final disposition = row.disposition.isEmpty
        ? ''
        : StudentSupportPlaybook.label(
            StudentSupportPlaybook.dispositions,
            row.disposition,
          );
    final when = row.recordedAt.toIso8601String().split('T').first;
    final color = attention ? const Color(0xFFC62828) : TeacherTheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: ValueKey('clinic-report-${row.id}'),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            attention
                ? Icons.health_and_safety_outlined
                : Icons.local_hospital_outlined,
            color: color,
          ),
        ),
        title: Text(
          row.studentName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            row.teacherTypeLabel,
            if (row.className != null && row.className!.trim().isNotEmpty)
              row.className!,
            when,
            if (attention) 'Special attention',
          ].join(' · '),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (attention)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Chip(
                      avatar: const Icon(Icons.visibility_outlined, size: 18),
                      label: Text(
                        row.followUpAt == null
                            ? 'Needs special attention in class'
                            : 'Follow-up ${_dateLabel(row.followUpAt!)}',
                      ),
                      backgroundColor: const Color(0xFFFFEBEE),
                    ),
                  ),
                if (row.title.trim().isNotEmpty)
                  _line('Complaint', row.title.trim()),
                if (row.details.trim().isNotEmpty)
                  _line('What the clinic did', row.details.trim()),
                if (disposition.isNotEmpty) _line('Decision', disposition),
                if (row.vitalNotes.trim().isNotEmpty)
                  _line('How the child was', row.vitalNotes.trim()),
                if (row.followUpAt != null)
                  _line('Clinic follow-up', _dateLabel(row.followUpAt!)),
                if (row.parentContactMethod.isNotEmpty)
                  _line(
                    'Parent reached',
                    StudentSupportPlaybook.label(
                      StudentSupportPlaybook.parentContactMethods,
                      row.parentContactMethod,
                    ),
                  ),
                if (row.parentNotifiedAt != null)
                  _line('Parent notified', _dateLabel(row.parentNotifiedAt!)),
                if (row.createdBy != null && row.createdBy!.trim().isNotEmpty)
                  _line('Recorded by', row.createdBy!.trim()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  static String _dateLabel(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

/// Shared body used by the teacher tile and Student Support preview.
class ClinicTeacherReportsBody extends StatelessWidget {
  const ClinicTeacherReportsBody({
    super.key,
    required this.classNames,
    this.schoolId,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
  });

  final List<String> classNames;
  final String? schoolId;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final svc = StudentSupportService.instance;
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final reports = svc.clinicReportsForClasses(
          classNames,
          schoolId: schoolId,
        );
        return ClinicTeacherReportList(reports: reports, padding: padding);
      },
    );
  }
}
