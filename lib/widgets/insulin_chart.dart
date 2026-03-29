import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/insulin_provider.dart';
import '../models/insulin_reading.dart';
import '../theme/app_theme.dart';

class InsulinChart extends StatelessWidget {
  const InsulinChart({super.key});

  @override
  Widget build(BuildContext context) {
    final prov     = context.watch<InsulinProvider>();
    final readings = prov.readings;
    final lowLimit = prov.lowLimit;
    final highLimit = prov.highLimit;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Nivel de Glucosa',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text('${readings.length} lecturas · ${prov.selectedRange.label}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ]),
            const Row(children: [
              _LegendDot(color: AppColors.primary, label: 'Glucosa'),
            ]),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 180,
          child: LineChart(
            _buildChart(readings, lowLimit, highLimit),
            duration: const Duration(milliseconds: 600),
          ),
        ),
      ]),
    );
  }

  LineChartData _buildChart(List<InsulinReading> readings, int lowLimit, int highLimit) {
    final spots = readings.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();

    return LineChartData(
      minY: 50,
      gridData: FlGridData(
        drawVerticalLine: false,
        horizontalInterval: 50,
        getDrawingHorizontalLine: (_) =>
          FlLine(color: Colors.white.withValues(alpha: 0.04), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 34, interval: 50,
          getTitlesWidget: (v, _) => Text(v.toInt().toString(),
            style: const TextStyle(fontSize: 10, color: AppColors.textFaint)),
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 24,
          interval: (readings.length / 4).ceilToDouble(),
          getTitlesWidget: (val, _) {
            final idx = val.toInt();
            if (idx < 0 || idx >= readings.length) return const SizedBox();
            return Text(DateFormat('HH:mm').format(readings[idx].timestamp),
              style: const TextStyle(fontSize: 10, color: AppColors.textFaint));
          },
        )),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => AppColors.surface3,
          getTooltipItems: (spots) => spots.map((s) {
            return LineTooltipItem('${s.y.toStringAsFixed(0)} mg/dL',
              const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600));
          }).toList(),
        ),
      ),
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          // Límite bajo (dinámico)
          HorizontalLine(
            y: lowLimit.toDouble(),
            color: AppColors.warning.withValues(alpha: 0.4),
            strokeWidth: 1.5,
            dashArray: [6, 4],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topLeft,
              labelResolver: (_) => 'Límite bajo ($lowLimit)',
              style: const TextStyle(fontSize: 9, color: AppColors.warning),
            ),
          ),
          // Límite alto (dinámico)
          HorizontalLine(
            y: highLimit.toDouble(),
            color: AppColors.danger.withValues(alpha: 0.4),
            strokeWidth: 1.5,
            dashArray: [6, 4],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.bottomLeft,
              labelResolver: (_) => 'Límite alto ($highLimit)',
              style: const TextStyle(fontSize: 9, color: AppColors.danger),
            ),
          ),
        ],
      ),
      lineBarsData: [
        // Línea principal de glucosa
        LineChartBarData(
          spots: spots,
          color: AppColors.primary,
          barWidth: 2.5,
          isCurved: true,
          curveSmoothness: 0.35,
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary.withValues(alpha: 0.35),
                Colors.transparent,
              ],
            ),
          ),
          dotData: const FlDotData(show: false),  // Sin puntos, solo línea
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 8, height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
  ]);
}