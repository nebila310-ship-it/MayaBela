import 'package:flutter/material.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/fee_record.dart';
import 'package:mayabela/services/persistence/cloud_save_honesty.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';

enum FeesView { parent, admin }

class FeesPaymentsScreen extends StatefulWidget {
  const FeesPaymentsScreen({
    super.key,
    this.view = FeesView.parent,
  });

  final FeesView view;

  @override
  State<FeesPaymentsScreen> createState() => _FeesPaymentsScreenState();
}

class _FeesPaymentsScreenState extends State<FeesPaymentsScreen>
    with SingleTickerProviderStateMixin {
  final _data = SchoolDataService.instance;
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<FeeRecord> get _fees =>
      widget.view == FeesView.parent ? _data.getFeesForParent() : _data.getAllFees();

  PaymentSummary get _summary =>
      _data.getPaymentSummary(parentOnly: widget.view == FeesView.parent);

  Future<void> _payFee(FeeRecord fee) async {
    final s = AppLocale.instance.strings;
    final method = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(s.payFeeTitle(fee.title)),
              subtitle: Text('${fee.amount.toStringAsFixed(0)} ETB'),
            ),
            ListTile(
              leading: const Icon(Icons.phone_android, color: Colors.purple),
              title: Text(s.telebirr),
              onTap: () => Navigator.pop(context, 'Telebirr'),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance, color: Colors.blue),
              title: Text(s.bankTransfer),
              onTap: () => Navigator.pop(context, 'Bank Transfer'),
            ),
            ListTile(
              leading: const Icon(Icons.payments, color: Colors.green),
              title: Text(s.cashAtSchool),
              onTap: () => Navigator.pop(context, 'Cash at School'),
            ),
          ],
        ),
      ),
    );

    if (method == null) return;

    final success = _data.payFee(fee.id, method);
    if (!mounted) return;

    setState(() {});
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.paymentFailed),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final outcome = await CloudSaveHonesty.settle();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      CloudSaveHonesty.snackBar(
        savedOk: s.feeRecordedOnThisDevice,
        outcome: outcome,
        strings: s,
      ),
    );
  }

  Color _statusColor(FeeStatus status) {
    switch (status) {
      case FeeStatus.pending:
        return Colors.orange;
      case FeeStatus.paid:
        return Colors.green;
      case FeeStatus.overdue:
        return Colors.red;
    }
  }

  String _statusLabel(FeeStatus status, AppStrings s) {
    switch (status) {
      case FeeStatus.pending:
        return s.pending;
      case FeeStatus.paid:
        return s.paid;
      case FeeStatus.overdue:
        return s.overdue;
    }
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final pending = _fees.where((f) => !f.isPaid).toList();
    final paid = _fees.where((f) => f.isPaid).toList();

    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.indigo,
            title: Text(
              widget.view == FeesView.parent ? s.feesTitle : s.finance,
            ),
            bottom: TabBar(
              controller: _tabs,
              tabs: [
                Tab(text: s.outstanding),
                Tab(text: s.paidTab),
              ],
            ),
          ),
          body: Column(
            children: [
              _summaryCard(s),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _feeList(pending, s, showPayButton: widget.view == FeesView.parent),
                    _feeList(paid, s, showPayButton: false),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryCard(AppStrings s) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.indigo, Colors.deepPurple],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.paymentSummary,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            s.etbDue(_summary.totalDue),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _miniStat(
                s.paidTab,
                '${_summary.totalPaid.toStringAsFixed(0)} ETB',
              ),
              const SizedBox(width: 16),
              _miniStat(
                s.overdueLabel,
                s.overdueItems(_summary.overdueCount),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _feeList(
    List<FeeRecord> fees,
    AppStrings s, {
    required bool showPayButton,
  }) {
    if (fees.isEmpty) {
      return Center(child: Text(s.noRecordsHere));
    }

    return ListView.separated(
      padding: listPagePadding(context, bottom: kScrollBottomSpacing),
      itemCount: fees.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final fee = fees[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        fee.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(fee.status).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _statusLabel(fee.status, s),
                        style: TextStyle(
                          color: _statusColor(fee.status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(s.studentLabel(fee.studentName)),
                Text('${s.termLabel}: ${fee.term}'),
                Text(
                  fee.isPaid
                      ? s.paidOn(_formatDate(fee.paidDate!), fee.paidVia!)
                      : s.dueOn(_formatDate(fee.dueDate)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${fee.amount.toStringAsFixed(0)} ETB',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    const Spacer(),
                    if (showPayButton && !fee.isPaid)
                      ElevatedButton(
                        onPressed: () => _payFee(fee),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(s.payNow),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
