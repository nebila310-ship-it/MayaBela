import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:mayabela/services/enrolment_excel_import.dart';
import 'package:mayabela/services/enrolment_import_service.dart';
import 'package:mayabela/services/staff_registry_notifier.dart';

/// Picks the Fenote enrolment .xlsx and writes ready rows into the registry.
abstract final class EnrolmentExcelImportAction {
  static Future<void> run(
    BuildContext context, {
    EnrolmentImportScope scope = EnrolmentImportScope.all,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      if (!context.mounted) return;
      _snack(context, 'Could not read file bytes.');
      return;
    }

    late final EnrolmentWorkbookDraft draft;
    try {
      if (!EnrolmentExcelImport.looksLikeFenote(bytes)) {
        if (!context.mounted) return;
        _snack(
          context,
          'Use Fenote_Raey_Enrolment_Forms.xlsx (Student / Teacher / Staff sheets).',
        );
        return;
      }
      draft = EnrolmentExcelImport.parseBytes(bytes);
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, 'Could not read Excel: $e');
      return;
    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import enrolment Excel'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_previewLine(draft, scope)),
                const SizedBox(height: 8),
                const Text(
                  'Partial rows are saved with the fields that were filled. '
                  'Gold office ID columns are ignored — MayaBela issues STU- / TCH- / role IDs.',
                ),
                if (draft.skipped.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Will skip ${draft.skipped.length}:',
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                  for (final line in draft.skipped.take(12))
                    Text('• $line', style: Theme.of(ctx).textTheme.bodySmall),
                  if (draft.skipped.length > 12)
                    Text('+ ${draft.skipped.length - 12} more'),
                ],
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
            onPressed: _readyFor(draft, scope) == 0
                ? null
                : () => Navigator.pop(ctx, true),
            child: Text('Import ${_readyFor(draft, scope)}'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final imported = await EnrolmentImportService.instance.importDraft(
        draft,
        scope: scope,
      );
      StaffRegistryNotifier.instance.notifyChanged();
      if (!context.mounted) return;
      final ids = [
        ...imported.createdStudentIds,
        ...imported.createdTeacherIds,
        ...imported.createdStaffIds,
      ];
      _snack(
        context,
        'Created ${imported.createdCount}'
        '${ids.isEmpty ? '' : ': ${ids.take(12).join(', ')}'}'
        '${imported.skipped.isEmpty ? '' : '. Skipped ${imported.skipped.length}.'}',
      );
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, e.toString());
    }
  }

  static int _readyFor(EnrolmentWorkbookDraft draft, EnrolmentImportScope scope) {
    return switch (scope) {
      EnrolmentImportScope.students => draft.students.length,
      EnrolmentImportScope.teachers => draft.teachers.length,
      EnrolmentImportScope.staff => draft.staff.length,
      EnrolmentImportScope.all => draft.readyCount,
    };
  }

  static String _previewLine(
    EnrolmentWorkbookDraft draft,
    EnrolmentImportScope scope,
  ) {
    final parts = <String>[];
    if (scope == EnrolmentImportScope.all ||
        scope == EnrolmentImportScope.students) {
      parts.add('${draft.students.length} student(s)');
    }
    if (scope == EnrolmentImportScope.all ||
        scope == EnrolmentImportScope.teachers) {
      parts.add('${draft.teachers.length} teacher(s)');
    }
    if (scope == EnrolmentImportScope.all ||
        scope == EnrolmentImportScope.staff) {
      parts.add('${draft.staff.length} staff');
    }
    return 'Ready: ${parts.join(' · ')}.';
  }

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
