import 'package:flutter/material.dart';

import 'package:mayabela/web_erp/theme/web_erp_theme.dart';

/// Institution / multi-school is owned by the platform console — not a stub.
class WebInstitutionPage extends StatelessWidget {
  const WebInstitutionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Institution Management',
              style: WebErpTheme.sectionTitle(context)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: WebErpTheme.cardDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.account_balance_outlined,
                    size: 36, color: WebErpTheme.primary),
                const SizedBox(height: 12),
                Text(
                  'Multi-school institution settings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Branding, contracts, and multi-school configuration are managed '
                  'in the Platform Console (Majo Bridge). Use School Management and '
                  'Campus Management in this ERP for the active school.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
