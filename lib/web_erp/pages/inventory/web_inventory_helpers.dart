import 'package:flutter/material.dart';

import 'package:mayabela/web_erp/theme/web_erp_theme.dart';

String formatInventoryDate(DateTime date) {
  final d = date.toLocal();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

String formatInventoryMoney(double value) =>
    '${value.toStringAsFixed(0)} ETB';

Widget inventoryPageHeader(
  BuildContext context, {
  required String title,
  String? subtitle,
  List<Widget>? actions,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: WebErpTheme.sectionTitle(context)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
      ...?actions,
    ],
  );
}

Widget inventorySearchField({
  required String hint,
  required ValueChanged<String> onChanged,
  double width = 280,
}) {
  return SizedBox(
    width: width,
    child: TextField(
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, size: 20),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      onChanged: onChanged,
    ),
  );
}

Widget inventoryDataCard(BuildContext context, {required Widget child}) {
  return Container(
    width: double.infinity,
    decoration: WebErpTheme.cardDecoration(context),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: child,
    ),
  );
}

Widget inventoryEmptyState(
  BuildContext context, {
  required IconData icon,
  required String message,
}) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 48, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text(
          message,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    ),
  );
}

Chip inventoryStatusChip(String label, Color color) {
  return Chip(
    label: Text(label, style: const TextStyle(fontSize: 11)),
    backgroundColor: color.withValues(alpha: 0.12),
    side: BorderSide(color: color.withValues(alpha: 0.3)),
    padding: EdgeInsets.zero,
    visualDensity: VisualDensity.compact,
  );
}
