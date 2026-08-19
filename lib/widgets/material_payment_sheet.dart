import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/material_purchase_models.dart';
import 'package:mayabela/services/material_purchase_service.dart';
import 'package:mayabela/services/school_payment_accounts.dart';

Future<void> showMaterialPaymentSheet({
  required BuildContext context,
  required MaterialPurchaseRequest request,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _MaterialPaymentSheet(request: request),
  );
}

class _MaterialPaymentSheet extends StatefulWidget {
  const _MaterialPaymentSheet({required this.request});

  final MaterialPurchaseRequest request;

  @override
  State<_MaterialPaymentSheet> createState() => _MaterialPaymentSheetState();
}

class _MaterialPaymentSheetState extends State<_MaterialPaymentSheet> {
  MaterialPaymentMethod _method = MaterialPaymentMethod.cbe;
  bool _busy = false;

  String get _message => SchoolPaymentAccounts.receiptMessage(
        materialTitle: widget.request.materialTitle,
        studentName: widget.request.studentName,
        priceEtb: widget.request.priceEtb,
        requestId: widget.request.id,
      );

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  Future<void> _open(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open app')),
      );
    }
  }

  Future<void> _markSent() async {
    setState(() => _busy = true);
    final err = await MaterialPurchaseService.instance.markPaymentSubmitted(
      widget.request.id,
      method: _method,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocale.instance.strings.bookPaymentSubmittedToast),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final req = widget.request;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              s.bookPaymentTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '${req.materialTitle}\n${req.studentName} · ${req.priceEtb.toStringAsFixed(0)} ETB',
              style: TextStyle(color: Colors.grey.shade800, height: 1.35),
            ),
            const SizedBox(height: 16),
            Text(
              s.bookPaymentAccountsHint,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            _AccountTile(
              title: 'CBE',
              subtitle:
                  '${SchoolPaymentAccounts.cbeAccountNumber}\n${SchoolPaymentAccounts.cbeAccountName}',
              selected: _method == MaterialPaymentMethod.cbe,
              onTap: () => setState(() => _method = MaterialPaymentMethod.cbe),
              onCopy: () => _copy(
                'CBE account',
                SchoolPaymentAccounts.cbeAccountNumber,
              ),
            ),
            const SizedBox(height: 8),
            _AccountTile(
              title: 'Telebirr',
              subtitle: SchoolPaymentAccounts.telebirrPhone,
              selected: _method == MaterialPaymentMethod.telebirr,
              onTap: () =>
                  setState(() => _method = MaterialPaymentMethod.telebirr),
              onCopy: () =>
                  _copy('Telebirr', SchoolPaymentAccounts.telebirrPhone),
            ),
            const SizedBox(height: 16),
            Text(
              s.bookPaymentSendReceiptHint,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _open(
                      SchoolPaymentAccounts.telegramReceiptUri(_message),
                    ),
                    icon: const Icon(Icons.send_outlined),
                    label: Text(s.sendViaTelegram),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _open(
                      SchoolPaymentAccounts.whatsappReceiptUri(_message),
                    ),
                    icon: const Icon(Icons.chat_outlined),
                    label: Text(s.sendViaWhatsApp),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _markSent,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(s.iSentReceipt),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.onCopy,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.teal.shade50 : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: Colors.teal.shade800,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(height: 1.3)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Copy',
                onPressed: onCopy,
                icon: const Icon(Icons.copy),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
