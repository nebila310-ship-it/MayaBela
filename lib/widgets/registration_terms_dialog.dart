import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/l10n/parent_guardian_terms.dart';

/// Scrollable terms dialog with required checkbox before registration.
Future<bool> showRegistrationTermsDialog({
  required BuildContext context,
  required String title,
  required String termsBody,
  required String checkboxLabel,
  required String agreeLabel,
  required String cancelLabel,
}) async {
  var agreed = false;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final maxHeight = MediaQuery.sizeOf(dialogContext).height * 0.82;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        termsBody,
                        style: const TextStyle(height: 1.45, fontSize: 14),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    controlAffinity: ListTileControlAffinity.leading,
                    value: agreed,
                    onChanged: (value) {
                      setDialogState(() => agreed = value ?? false);
                    },
                    title: Text(
                      checkboxLabel,
                      style: const TextStyle(fontSize: 13, height: 1.35),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext, false),
                            child: Text(cancelLabel),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed:
                                agreed ? () => Navigator.pop(dialogContext, true) : null,
                            child: Text(agreeLabel),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  return result == true;
}

/// Parent registration terms with English, Amharic, and Afaan Oromoo language choice.
Future<bool> showParentGuardianTermsDialog(BuildContext context) async {
  var termsLanguage = ParentGuardianTerms.defaultLanguageForApp();
  var agreed = false;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final maxHeight = MediaQuery.sizeOf(dialogContext).height * 0.82;
      final ui = AppLocale.instance.strings;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          final readLabel =
              ParentGuardianTerms.readInLanguageLabelFor(termsLanguage);

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      ParentGuardianTerms.titleFor(termsLanguage),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          readLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: [
                            ButtonSegment(
                              value: 'en',
                              label: Text(ui.english),
                            ),
                            ButtonSegment(
                              value: 'am',
                              label: Text(ui.amharic),
                            ),
                            ButtonSegment(
                              value: 'om',
                              label: Text(ui.oromo),
                            ),
                          ],
                          selected: {termsLanguage},
                          onSelectionChanged: (value) {
                            setDialogState(() {
                              termsLanguage = value.first;
                              agreed = false;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        ParentGuardianTerms.bodyFor(termsLanguage),
                        style: const TextStyle(height: 1.45, fontSize: 14),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    controlAffinity: ListTileControlAffinity.leading,
                    value: agreed,
                    onChanged: (value) {
                      setDialogState(() => agreed = value ?? false);
                    },
                    title: Text(
                      ParentGuardianTerms.checkboxFor(termsLanguage),
                      style: const TextStyle(fontSize: 13, height: 1.35),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext, false),
                            child: Text(
                              ParentGuardianTerms.cancelLabelFor(termsLanguage),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed:
                                agreed ? () => Navigator.pop(dialogContext, true) : null,
                            child: Text(
                              ParentGuardianTerms.agreeLabelFor(termsLanguage),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  return result == true;
}
