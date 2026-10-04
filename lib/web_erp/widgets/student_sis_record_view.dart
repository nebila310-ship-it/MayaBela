import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/student_conduct.dart';
import 'package:mayabela/services/student_sis_profile.dart';

/// Read-only SIS sections assembled from existing school stores.
class StudentSisRecordView extends StatelessWidget {
  const StudentSisRecordView({
    super.key,
    this.snapshot,
    this.compact = false,
  });

  final StudentSisSnapshot? snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final sis = snapshot;
    if (sis == null) return const SizedBox.shrink();

    final conductLabel = switch (sis.conduct) {
      StudentConductRating.excellent =>
        AppLocale.instance.strings.conductExcellent,
      StudentConductRating.satisfactory =>
        AppLocale.instance.strings.conductSatisfactory,
      StudentConductRating.needsAttention =>
        AppLocale.instance.strings.conductNeedsAttention,
      null => 'No classroom conduct rating yet',
    };

    final attendance = sis.attendance;
    final loans = compact ? sis.libraryLoans.take(6) : sis.libraryLoans;
    final cases = compact ? sis.disciplineCases.take(5) : sis.disciplineCases;
    final health = compact ? sis.healthRecords.take(5) : sis.healthRecords;
    final docs = compact ? sis.documents.take(6) : sis.documents;
    final moves = compact ? sis.movements.take(6) : sis.movements;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sisBlock(
          title: 'Attendance',
          empty: attendance.sessions == 0 && attendance.excused == 0
              ? 'No daily register marks yet. Take-roll stays on Attendance.'
              : null,
          children: [
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.fact_check_outlined, size: 20),
              title: Text(
                '${attendance.present} present · ${attendance.absent} absent · '
                '${attendance.late} late · ${attendance.excused} excused',
              ),
            ),
          ],
        ),
        _sisBlock(
          title: 'Academic history',
          empty: sis.academicHistory.isEmpty
              ? 'No published grade reports yet. Marks stay in Gradebook.'
              : null,
          children: [
            for (final report in sis.academicHistory)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.menu_book_outlined, size: 20),
                title: Text(
                  [
                    if ((report.academicYear ?? '').isNotEmpty)
                      report.academicYear!,
                    report.term,
                    report.className,
                  ].join(' · '),
                ),
                subtitle: Text(
                  report.subjects.isEmpty
                      ? 'No subject scores'
                      : 'Average ${report.average.toStringAsFixed(1)} · '
                          '${report.subjects.length} subjects',
                ),
              ),
          ],
        ),
        _sisBlock(
          title: 'Behavioral profile',
          empty: null,
          children: [
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.favorite_outline, size: 20),
              title: Text(conductLabel),
            ),
            if (sis.disciplineCases.isEmpty)
              const ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('No Student Affairs cases on file.'),
              )
            else
              for (final c in cases)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.balance_outlined, size: 20),
                  title: Text(c.title),
                  subtitle: Text(
                    '${c.kind.name} · ${c.status.name}'
                    '${c.conductCode.isEmpty ? '' : ' · ${c.conductCode}'}',
                  ),
                ),
          ],
        ),
        _sisBlock(
          title: 'Health records',
          empty: sis.healthRecords.isEmpty
              ? 'Clinic visits and vaccinations are stored in Student support.'
              : null,
          children: [
            for (final row in health)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.health_and_safety_outlined, size: 20),
                title: Text(row.title.isEmpty ? row.type.name : row.title),
                subtitle: Text(row.details.isEmpty ? row.type.name : row.details),
              ),
          ],
        ),
        _sisBlock(
          title: 'Digital documents',
          empty: sis.documents.isEmpty
              ? 'Identity and transcript files live in the student vault.'
              : null,
          children: [
            for (final doc in docs)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.attach_file, size: 20),
                title: Text(doc.title.isEmpty ? doc.category : doc.title),
                subtitle: Text(doc.category),
              ),
          ],
        ),
        _sisBlock(
          title: 'Library loans',
          empty: sis.libraryLoans.isEmpty
              ? 'No library checkouts or e-book rentals on file.'
              : null,
          children: [
            for (final loan in loans)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  loan.isOverdue()
                      ? Icons.warning_amber_outlined
                      : Icons.menu_book_outlined,
                  size: 20,
                ),
                title: Text(
                  [
                    loan.bookTitle,
                    if ((loan.copyCode ?? '').isNotEmpty) loan.copyCode!,
                  ].join(' · '),
                ),
                subtitle: Text(
                  loan.isActive
                      ? (loan.isOverdue() ? 'Overdue' : 'On loan')
                      : 'Returned',
                ),
              ),
          ],
        ),
        _sisBlock(
          title: 'Promotion, transfer, withdrawal',
          empty: sis.movements.isEmpty
              ? 'No transfer, promotion, or withdrawal requests yet.'
              : null,
          children: [
            for (final move in moves)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.swap_horiz, size: 20),
                title: Text(move.summary),
                subtitle: Text(move.status.name),
              ),
          ],
        ),
      ],
    );
  }

  Widget _sisBlock({
    required String title,
    required String? empty,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (empty != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    empty,
                    style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                  ),
                )
              else
                ...children,
            ],
          ),
        ),
      ),
    );
  }
}
