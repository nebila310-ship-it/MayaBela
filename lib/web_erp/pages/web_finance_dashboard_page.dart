import 'package:flutter/material.dart';

import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/widgets/web_chart_widgets.dart';

class WebFinanceDashboardPage extends StatelessWidget {
  const WebFinanceDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final summary =
        SchoolDataService.instance.getPaymentSummary(parentOnly: false);
    final fees = SchoolDataService.instance.getAllFees();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final paidToday = fees
        .where((f) =>
            f.isPaid &&
            f.paidDate != null &&
            f.paidDate!.year == today.year &&
            f.paidDate!.month == today.month &&
            f.paidDate!.day == today.day)
        .fold<double>(0, (s, f) => s + f.amount);

    // Last 7 days of actual paid amounts (real series, not synthetic).
    final dailyIncome = List<double>.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      return fees
          .where((f) =>
              f.isPaid &&
              f.paidDate != null &&
              f.paidDate!.year == day.year &&
              f.paidDate!.month == day.month &&
              f.paidDate!.day == day.day)
          .fold<double>(0, (s, f) => s + f.amount);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Finance Dashboard', style: WebErpTheme.sectionTitle(context)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _moneyCard(context, 'Collected', summary.totalPaid, Colors.green),
              _moneyCard(context, 'Outstanding', summary.totalDue, Colors.orange),
              _moneyCard(context, 'Today', paidToday, WebErpTheme.primary),
              _countCard(context, 'Overdue invoices', summary.overdueCount),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth > 900;
              return Flex(
                direction: wide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: WebLineChartPanel(
                      title: 'Income (last 7 days)',
                      values: dailyIncome,
                      color: Colors.green.shade600,
                    ),
                  ),
                  SizedBox(width: wide ? 16 : 0, height: wide ? 0 : 16),
                  Expanded(
                    child: WebBarChartPanel(
                      title: 'Fee Status',
                      data: {
                        'Paid': fees.where((f) => f.isPaid).length,
                        'Due': fees.where((f) => !f.isPaid).length,
                        'Overdue': summary.overdueCount,
                      },
                      color: Colors.teal,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            decoration: WebErpTheme.cardDecoration(context),
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Student')),
                DataColumn(label: Text('Title')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('Status')),
              ],
              rows: [
                for (final f in fees.take(12))
                  DataRow(
                    cells: [
                      DataCell(Text(f.studentName)),
                      DataCell(Text(f.title)),
                      DataCell(Text('${f.amount.toStringAsFixed(0)} ETB')),
                      DataCell(Text(f.status.name)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _moneyCard(
    BuildContext context,
    String label,
    double value,
    Color color,
  ) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: WebErpTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(
            '${value.toStringAsFixed(0)} ETB',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _countCard(BuildContext context, String label, int value) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: WebErpTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
