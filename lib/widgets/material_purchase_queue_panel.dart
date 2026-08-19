import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/material_purchase_models.dart';
import 'package:mayabela/services/material_purchase_service.dart';
import 'package:mayabela/widgets/material_payment_sheet.dart';

/// Compact queue panels for parent approvals / admin payment confirms.
class MaterialPurchaseQueuePanel extends StatelessWidget {
  const MaterialPurchaseQueuePanel({
    super.key,
    required this.mode,
  });

  final MaterialPurchaseQueueMode mode;

  @override
  Widget build(BuildContext context) {
    final svc = MaterialPurchaseService.instance;
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final items = switch (mode) {
          MaterialPurchaseQueueMode.parentApprovals =>
            svc.pendingParentApprovals(),
          MaterialPurchaseQueueMode.parentPay => svc.forParent().where((r) {
              return r.status == MaterialPurchaseStatus.awaitingPayment ||
                  r.status == MaterialPurchaseStatus.paymentSubmitted;
            }).toList(),
          MaterialPurchaseQueueMode.adminConfirm =>
            svc.awaitingAdminConfirm(),
        };
        if (items.isEmpty) return const SizedBox.shrink();
        final s = AppLocale.instance.strings;
        final title = switch (mode) {
          MaterialPurchaseQueueMode.parentApprovals =>
            s.bookUnlockRequestsTitle,
          MaterialPurchaseQueueMode.parentPay => s.bookPaymentsPendingTitle,
          MaterialPurchaseQueueMode.adminConfirm =>
            s.bookPaymentConfirmTitle,
        };
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...items.map(
                (req) => _RequestCard(request: req, mode: mode),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum MaterialPurchaseQueueMode {
  parentApprovals,
  parentPay,
  adminConfirm,
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.mode});

  final MaterialPurchaseRequest request;
  final MaterialPurchaseQueueMode mode;

  Future<void> _approve(BuildContext context) async {
    final err =
        await MaterialPurchaseService.instance.approveByParent(request.id);
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    await showMaterialPaymentSheet(context: context, request: request);
  }

  Future<void> _reject(BuildContext context) async {
    final err =
        await MaterialPurchaseService.instance.rejectByParent(request.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          err ?? AppLocale.instance.strings.bookRequestRejectedToast,
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final err = await MaterialPurchaseService.instance
        .confirmPaymentByAdmin(request.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          err ?? AppLocale.instance.strings.bookUnlockedToast,
        ),
      ),
    );
  }

  Future<void> _rejectAdmin(BuildContext context) async {
    final err =
        await MaterialPurchaseService.instance.rejectByAdmin(request.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          err ?? AppLocale.instance.strings.bookRequestRejectedToast,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final statusLabel = switch (request.status) {
      MaterialPurchaseStatus.pendingParentApproval => s.awaitingParentApproval,
      MaterialPurchaseStatus.awaitingPayment => s.awaitingPayment,
      MaterialPurchaseStatus.paymentSubmitted => s.paymentSubmittedStatus,
      MaterialPurchaseStatus.approved => s.approvedStatus,
      MaterialPurchaseStatus.rejected => s.bookRequestRejectedToast,
      MaterialPurchaseStatus.cancelled => s.bookRequestRejectedToast,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request.materialTitle,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${request.studentName} · ${request.priceEtb.toStringAsFixed(0)} ETB',
              style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              statusLabel,
              style: TextStyle(
                fontSize: 12,
                color: Colors.teal.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            if (mode == MaterialPurchaseQueueMode.parentApprovals)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _reject(context),
                      child: Text(s.reject),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _approve(context),
                      child: Text(s.approveAndPay),
                    ),
                  ),
                ],
              )
            else if (mode == MaterialPurchaseQueueMode.parentPay &&
                request.status == MaterialPurchaseStatus.paymentSubmitted)
              Text(
                s.paymentSubmittedStatus,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade900,
                ),
              )
            else if (mode == MaterialPurchaseQueueMode.parentPay &&
                request.status == MaterialPurchaseStatus.awaitingPayment)
              FilledButton(
                onPressed: () => showMaterialPaymentSheet(
                  context: context,
                  request: request,
                ),
                child: Text(s.payNow),
              )
            else if (mode == MaterialPurchaseQueueMode.adminConfirm)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _rejectAdmin(context),
                      child: Text(s.reject),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _confirm(context),
                      child: Text(s.confirmPaymentUnlock),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
