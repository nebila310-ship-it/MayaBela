import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/issue_report_service.dart';
import 'package:mayabela/widgets/admin_edit_dialog.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';

enum ReportIssueKind { general, transport }

enum _GeneralReportCategory { bug, login, data, other }

enum _TransportReportCategory { carIssue, trafficIssue, accident }

class ReportIssueDialog {
  ReportIssueDialog._();

  static const _accent = Color(0xFFEF6C00);
  static const _transportAccent = Color(0xFFD84315);

  static Future<void> show(
    BuildContext context, {
    ReportIssueKind kind = ReportIssueKind.general,
  }) async {
    return switch (kind) {
      ReportIssueKind.transport => _showTransport(context),
      ReportIssueKind.general => _showGeneral(context),
    };
  }

  static Future<void> showTransport(BuildContext context) =>
      show(context, kind: ReportIssueKind.transport);

  static String _generalCategoryLabel(
    AppStrings s,
    _GeneralReportCategory category,
  ) {
    return switch (category) {
      _GeneralReportCategory.bug => s.reportCategoryBug,
      _GeneralReportCategory.login => s.reportCategoryLogin,
      _GeneralReportCategory.data => s.reportCategoryData,
      _GeneralReportCategory.other => s.reportCategoryOther,
    };
  }

  static IconData _generalCategoryIcon(_GeneralReportCategory category) {
    return switch (category) {
      _GeneralReportCategory.bug => Icons.bug_report_outlined,
      _GeneralReportCategory.login => Icons.lock_outline,
      _GeneralReportCategory.data => Icons.analytics_outlined,
      _GeneralReportCategory.other => Icons.more_horiz,
    };
  }

  static String _transportCategoryLabel(
    AppStrings s,
    _TransportReportCategory category,
  ) {
    return switch (category) {
      _TransportReportCategory.carIssue => s.reportCategoryCarIssue,
      _TransportReportCategory.trafficIssue => s.reportCategoryTrafficIssue,
      _TransportReportCategory.accident => s.reportCategoryAccident,
    };
  }

  static IconData _transportCategoryIcon(_TransportReportCategory category) {
    return switch (category) {
      _TransportReportCategory.carIssue => Icons.directions_bus_outlined,
      _TransportReportCategory.trafficIssue => Icons.traffic_outlined,
      _TransportReportCategory.accident => Icons.car_crash_outlined,
    };
  }

  static Future<void> _showGeneral(BuildContext context) async {
    final s = AppLocale.instance.strings;
    final nameController = TextEditingController(
      text: AuthService.currentUser?.fullName ?? '',
    );
    final issueController = TextEditingController();
    var category = _GeneralReportCategory.bug;

    final sent = await showAdminFormDialog(
      context: context,
      title: s.reportTitle,
      subtitle: s.reportIssueSubtitle,
      accent: _accent,
      icon: Icons.support_agent_rounded,
      saveLabel: s.send,
      barrierDismissible: true,
      canSave: (_) =>
          nameController.text.trim().isNotEmpty &&
          issueController.text.trim().isNotEmpty,
      builder: (context, setDialogState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.reportIssueCategory,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _GeneralReportCategory.values.map((item) {
              final selected = category == item;
              return FilterChip(
                selected: selected,
                showCheckmark: false,
                avatar: Icon(
                  _generalCategoryIcon(item),
                  size: 18,
                  color: selected ? Colors.white : _accent,
                ),
                label: Text(
                  _generalCategoryLabel(s, item),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color:
                        selected ? Colors.white : _accent.withValues(alpha: 0.9),
                  ),
                ),
                selectedColor: _accent,
                backgroundColor: _accent.withValues(alpha: 0.07),
                side: BorderSide(
                  color: selected ? _accent : _accent.withValues(alpha: 0.25),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (_) => setDialogState(() => category = item),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          ..._sharedFields(
            s: s,
            accent: _accent,
            nameController: nameController,
            issueController: issueController,
            detailsHint: s.reportIssueDetailsHint,
            setDialogState: setDialogState,
          ),
        ],
      ),
    );

    if (!context.mounted) {
      nameController.dispose();
      issueController.dispose();
      return;
    }
    await _submitIfSent(
      context: context,
      sent: sent,
      nameController: nameController,
      issueController: issueController,
      categoryLabel: _generalCategoryLabel(s, category),
      kind: ReportIssueKind.general,
    );
  }

  static Future<void> _showTransport(BuildContext context) async {
    final s = AppLocale.instance.strings;
    final nameController = TextEditingController(
      text: AuthService.currentUser?.fullName ?? '',
    );
    final issueController = TextEditingController();
    var category = _TransportReportCategory.carIssue;

    final sent = await showAdminFormDialog(
      context: context,
      title: s.reportTransportTitle,
      subtitle: s.reportTransportSubtitle,
      accent: _transportAccent,
      icon: Icons.warning_amber_rounded,
      saveLabel: s.send,
      barrierDismissible: true,
      canSave: (_) =>
          nameController.text.trim().isNotEmpty &&
          issueController.text.trim().isNotEmpty,
      builder: (context, setDialogState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.reportIssueCategory,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _TransportReportCategory.values.map((item) {
              final selected = category == item;
              return FilterChip(
                selected: selected,
                showCheckmark: false,
                avatar: Icon(
                  _transportCategoryIcon(item),
                  size: 18,
                  color: selected ? Colors.white : _transportAccent,
                ),
                label: Text(
                  _transportCategoryLabel(s, item),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: selected
                        ? Colors.white
                        : _transportAccent.withValues(alpha: 0.9),
                  ),
                ),
                selectedColor: _transportAccent,
                backgroundColor: _transportAccent.withValues(alpha: 0.07),
                side: BorderSide(
                  color: selected
                      ? _transportAccent
                      : _transportAccent.withValues(alpha: 0.25),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (_) => setDialogState(() => category = item),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          ..._sharedFields(
            s: s,
            accent: _transportAccent,
            nameController: nameController,
            issueController: issueController,
            detailsHint: s.reportTransportDetailsHint,
            setDialogState: setDialogState,
          ),
        ],
      ),
    );

    if (!context.mounted) {
      nameController.dispose();
      issueController.dispose();
      return;
    }
    await _submitIfSent(
      context: context,
      sent: sent,
      nameController: nameController,
      issueController: issueController,
      categoryLabel: _transportCategoryLabel(s, category),
      kind: ReportIssueKind.transport,
    );
  }

  static List<Widget> _sharedFields({
    required AppStrings s,
    required Color accent,
    required TextEditingController nameController,
    required TextEditingController issueController,
    required String detailsHint,
    required void Function(void Function()) setDialogState,
  }) {
    return [
      adminDialogField(
        TextField(
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setDialogState(() {}),
          decoration: adminFieldDecoration(
            label: s.yourName,
            icon: Icons.person_outline,
            accent: accent,
          ),
        ),
      ),
      adminDialogField(
        TextField(
          controller: issueController,
          maxLines: 5,
          minLines: 4,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setDialogState(() {}),
          decoration: adminFieldDecoration(
            label: s.issueDescription,
            hint: detailsHint,
            icon: Icons.edit_note_outlined,
            accent: accent,
          ),
        ),
      ),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.mail_outline, size: 20, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.reportIssueEmailNote,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AuthService.supportEmail,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  static Future<void> _submitIfSent({
    required BuildContext context,
    required bool? sent,
    required TextEditingController nameController,
    required TextEditingController issueController,
    required String categoryLabel,
    required ReportIssueKind kind,
  }) async {
    final s = AppLocale.instance.strings;
    final name = nameController.text.trim();
    final issue = issueController.text.trim();
    nameController.dispose();
    issueController.dispose();

    if (sent != true || !context.mounted) return;

    if (name.isEmpty || issue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.fillReport)),
      );
      return;
    }

    try {
      await IssueReportService.instance.submit(
        reporterName: name,
        category: categoryLabel,
        description: issue,
        deliverToSchool: kind == ReportIssueKind.transport,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.reportSent),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.emailFailed)),
        );
      }
    }
  }
}
