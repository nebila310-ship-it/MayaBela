import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';

class FinancePalette {
  FinancePalette._();

  static const primary = Color(0xFFEA580C);
  static const secondary = Color(0xFFF97316);
  static const accent = Color(0xFFFDBA74);
  static const deep = Color(0xFF9A3412);
  static const surface = Color(0xFFFFF7ED);

  static const gradient = [Color(0xFF9A3412), Color(0xFFEA580C), Color(0xFFF97316)];
}

enum FinanceComingSoonMode { finance, parentFees }

class FinanceComingSoonScreen extends StatelessWidget {
  const FinanceComingSoonScreen({
    super.key,
    this.mode = FinanceComingSoonMode.finance,
  });

  final FinanceComingSoonMode mode;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final isParentFees = mode == FinanceComingSoonMode.parentFees;
        final screenTitle = isParentFees ? s.feesTitle : s.finance;
        final heroSubtitle =
            isParentFees ? s.parentFeesComingSoonSubtitle : s.financeComingSoonSubtitle;
        final description = isParentFees
            ? s.parentFeesComingSoonDescription
            : s.financeComingSoonDescription;
        final note =
            isParentFees ? s.parentFeesComingSoonNote : s.financeComingSoonNote;
        return Scaffold(
          backgroundColor: FinancePalette.surface,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 168,
                pinned: true,
                elevation: 0,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 14),
                  title: Text(
                    screenTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: FinancePalette.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -20,
                          right: -10,
                          child: Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 120,
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        Positioned(
                          bottom: 48,
                          left: 16,
                          right: 16,
                          child: Text(
                            heroSubtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: listPagePadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ComingSoonHeroCard(
                        title: s.comingSoon,
                        description: description,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        s.financePlannedFeatures,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 520;
                          return GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: wide ? 2 : 1,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: wide ? 1.55 : 2.4,
                            children: [
                              _FeaturePreviewCard(
                                icon: Icons.payments_outlined,
                                title: s.financeFeatureFees,
                                subtitle: s.financeFeatureFeesHint,
                              ),
                              _FeaturePreviewCard(
                                icon: Icons.receipt_long_outlined,
                                title: s.financeFeatureInvoices,
                                subtitle: s.financeFeatureInvoicesHint,
                              ),
                              _FeaturePreviewCard(
                                icon: Icons.sync_alt_rounded,
                                title: s.financeFeaturePayments,
                                subtitle: s.financeFeaturePaymentsHint,
                              ),
                              _FeaturePreviewCard(
                                icon: Icons.insights_outlined,
                                title: s.financeFeatureReports,
                                subtitle: s.financeFeatureReportsHint,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      _DevelopmentStatusCard(
                        label: s.financeInDevelopment,
                        note: note,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ComingSoonHeroCard extends StatelessWidget {
  const _ComingSoonHeroCard({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: FinancePalette.accent.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: FinancePalette.primary.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [FinancePalette.primary, FinancePalette.secondary],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: FinancePalette.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.construction_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: FinancePalette.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: FinancePalette.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: FinancePalette.deep,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.45,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeaturePreviewCard extends StatelessWidget {
  const _FeaturePreviewCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: FinancePalette.accent.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: FinancePalette.primary.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: FinancePalette.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: FinancePalette.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Icon(icon, color: FinancePalette.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.lock_clock_outlined,
            size: 18,
            color: Colors.grey.shade400,
          ),
        ],
      ),
    );
  }
}

class _DevelopmentStatusCard extends StatelessWidget {
  const _DevelopmentStatusCard({
    required this.label,
    required this.note,
  });

  final String label;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            FinancePalette.deep.withValues(alpha: 0.92),
            FinancePalette.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: FinancePalette.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: 0.42,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            note,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
