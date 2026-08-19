import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:mayabela/web_erp/theme/web_erp_theme.dart';

class WebLineChartPanel extends StatelessWidget {
  const WebLineChartPanel({
    super.key,
    required this.title,
    required this.values,
    this.color,
    this.height = 220,
    this.ySuffix = '',
  });

  final String title;
  final List<double> values;
  final Color? color;
  final double height;
  final String ySuffix;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? WebErpTheme.primary;
    final spots = [
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];
    final maxY = values.isEmpty
        ? 10.0
        : values.reduce((a, b) => a > b ? a : b) * 1.2;

    return Container(
      decoration: WebErpTheme.cardDecoration(context),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: WebErpTheme.sectionTitle(context)),
          const SizedBox(height: 16),
          SizedBox(
            height: height,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY < 1 ? 1 : maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: Colors.grey.withValues(alpha: 0.15),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                        final i = value.toInt();
                        if (i < 0 || i >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          labels[i],
                          style: const TextStyle(fontSize: 11),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}$ySuffix',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: accent,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: accent.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WebBarChartPanel extends StatelessWidget {
  const WebBarChartPanel({
    super.key,
    required this.title,
    required this.data,
    this.color,
    this.height = 220,
  });

  final String title;
  final Map<String, int> data;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? WebErpTheme.primaryLight;
    final entries = data.entries.toList();
    final maxY = entries.isEmpty
        ? 10.0
        : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2;

    return Container(
      decoration: WebErpTheme.cardDecoration(context),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: WebErpTheme.sectionTitle(context)),
          const SizedBox(height: 16),
          SizedBox(
            height: height,
            child: BarChart(
              BarChartData(
                maxY: maxY < 1 ? 1 : maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: Colors.grey.withValues(alpha: 0.15),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= entries.length) {
                          return const SizedBox.shrink();
                        }
                        final label = entries[i].key;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            label.length > 6 ? label.substring(0, 6) : label,
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  for (var i = 0; i < entries.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: entries[i].value.toDouble(),
                          color: accent,
                          width: 18,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
