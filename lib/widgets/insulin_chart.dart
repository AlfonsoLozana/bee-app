import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/insulin_provider.dart';
import '../models/insulin_reading.dart';
import '../models/daily_pattern_reading.dart';
import '../models/chart_range.dart';
import '../theme/app_theme.dart';

class InsulinChart extends StatelessWidget {
  const InsulinChart({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<InsulinProvider>();
    final readings = prov.readings;
    final dailyPattern = prov.dailyPattern;
    final lowLimit = prov.lowLimit;
    final highLimit = prov.highLimit;
    final selectedRange = prov.selectedRange;
    final showsPattern = dailyPattern.isNotEmpty;

    // Determinar el conteo de datos para mostrar
    final dataCount = showsPattern ? dailyPattern.length : readings.length;

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
              Text(
                showsPattern 
                  ? '$dataCount franjas · ${selectedRange.label}'
                  : '$dataCount lecturas · ${selectedRange.label}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)
              ),
            ]),
            Row(children: [
              const _LegendDot(color: AppColors.primary, label: 'Glucosa'),
              if (showsPattern) ...[
                const SizedBox(width: 12),
                _LegendDot(
                  color: AppColors.primary.withValues(alpha: 0.25), 
                  label: '±1σ'
                ),
              ],
            ]),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 180,
          child: dataCount == 0
            ? const Center(
                child: Text('No hay datos suficientes para este período',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted))
              )
            : LineChart(
                showsPattern
                  ? _buildDailyPatternChart(dailyPattern, lowLimit, highLimit)
                  : _buildRawChart(readings, lowLimit, highLimit, selectedRange),
                duration: const Duration(milliseconds: 600),
              ),
        ),
      ]),
    );
  }

  /// Construir gráfica con datos raw (6H, 1D)
  LineChartData _buildRawChart(List<InsulinReading> readings, int lowLimit, int highLimit, ChartRange selectedRange) {
    if (readings.isEmpty) {
      return LineChartData(minY: 50, lineBarsData: []);
    }

    // Para 1D: eje X fijo 00:00-24:00 (basado en minutos del día)
    // Para 6H: eje X dinámico basado en timestamps
    final is1D = selectedRange == ChartRange.oneDay;
    
    List<FlSpot> spots;
    double minX, maxX;
    
    if (is1D) {
      // 1D: Convertir timestamps a minutos del día (0-1439)
      final startOfDay = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
      spots = readings.map((r) {
        final minuteOfDay = r.timestamp.difference(startOfDay).inMinutes.toDouble();
        return FlSpot(minuteOfDay, r.value);
      }).toList();
      
      minX = 0;
      maxX = 1439; // 23:59
    } else {
      // 6H: Índices secuenciales
      spots = readings.asMap().entries
          .map((e) => FlSpot(e.key.toDouble(), e.value.value))
          .toList();
      
      minX = 0;
      maxX = (readings.length - 1).toDouble();
    }

    return LineChartData(
      minY: 50,
      minX: minX,
      maxX: maxX,
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
          interval: is1D ? 240 : _getXAxisInterval(readings.length, selectedRange), // 240 min = 4 horas
          getTitlesWidget: (val, _) {
            if (is1D) {
              // Para 1D: mostrar horas del día (00:00, 04:00, 08:00, etc.)
              final minute = val.toInt();
              if (minute < 0 || minute > 1439) return const SizedBox();
              
              final hour = minute ~/ 60;
              if (minute % 240 != 0) return const SizedBox(); // Mostrar solo cada 4 horas
              
              return Text(
                '${hour.toString().padLeft(2, '0')}:00',
                style: const TextStyle(fontSize: 10, color: AppColors.textFaint)
              );
            } else {
              // Para 6H: mostrar timestamps
              final idx = val.toInt();
              if (idx < 0 || idx >= readings.length) return const SizedBox();
              final timestamp = readings[idx].timestamp;
              final format = _getDateFormat(selectedRange);
              return Text(DateFormat(format).format(timestamp),
                style: const TextStyle(fontSize: 10, color: AppColors.textFaint));
            }
          },
        )),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => AppColors.surface3,
          getTooltipItems: (spots) {
            if (spots.isEmpty) return [];
            final spot = spots.first;
            
            if (is1D) {
              // Para 1D: mostrar hora del día
              final minute = spot.x.toInt();
              final hour = minute ~/ 60;
              final min = minute % 60;
              return [
                LineTooltipItem(
                  '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}\n${spot.y.toStringAsFixed(0)} mg/dL',
                  const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)
                ),
              ];
            } else {
              // Para 6H: valor simple
              return [
                LineTooltipItem(
                  '${spot.y.toStringAsFixed(0)} mg/dL',
                  const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)
                ),
              ];
            }
          },
        ),
      ),
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          _buildLowLimitLine(lowLimit),
          _buildHighLimitLine(highLimit),
        ],
      ),
      lineBarsData: [
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
          dotData: const FlDotData(show: false),
        ),
      ],
    );
  }

  /// Construir gráfica con patrón diario promedio (3D+)
  /// Eje X: minutos del día (0-1439) representando 00:00 - 24:00
  /// Cada punto representa la media de ese minuto a través de múltiples días
  /// con banda de desviación estándar simétrica
  LineChartData _buildDailyPatternChart(
    List<DailyPatternReading> pattern,
    int lowLimit,
    int highLimit,
  ) {
    if (pattern.isEmpty) {
      return LineChartData(minY: 50, lineBarsData: []);
    }

    // Convertir TimeOfDay a minutos del día para el eje X (0-1439)
    final meanSpots = pattern.map((p) {
      final minuteOfDay = p.timeOfDay.hour * 60 + p.timeOfDay.minute;
      return FlSpot(minuteOfDay.toDouble(), p.mean);
    }).toList();

    final upperSpots = pattern.map((p) {
      final minuteOfDay = p.timeOfDay.hour * 60 + p.timeOfDay.minute;
      return FlSpot(minuteOfDay.toDouble(), p.meanPlusStdDev);
    }).toList();

    final lowerSpots = pattern.map((p) {
      final minuteOfDay = p.timeOfDay.hour * 60 + p.timeOfDay.minute;
      return FlSpot(minuteOfDay.toDouble(), p.meanMinusStdDev);
    }).toList();

    return LineChartData(
      minY: 50,
      minX: 0,
      maxX: 1439, // 23:59 en minutos
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
          interval: 240, // 4 horas en minutos
          getTitlesWidget: (val, _) {
            final minute = val.toInt();
            if (minute < 0 || minute > 1439) return const SizedBox();
            
            final hour = minute ~/ 60;
            // Mostrar solo horas exactas (00:00, 04:00, 08:00, etc.)
            if (minute % 240 != 0) return const SizedBox();
            
            return Text(
              '${hour.toString().padLeft(2, '0')}:00',
              style: const TextStyle(fontSize: 10, color: AppColors.textFaint)
            );
          },
        )),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => AppColors.surface3,
          getTooltipItems: (spots) {
            if (spots.isEmpty) return [];
            
            // Encontrar el punto más cercano en pattern
            final touchedX = spots.first.x;
            final closestPattern = pattern.reduce((a, b) {
              final aMinute = a.timeOfDay.hour * 60 + a.timeOfDay.minute;
              final bMinute = b.timeOfDay.hour * 60 + b.timeOfDay.minute;
              return ((aMinute - touchedX).abs() < (bMinute - touchedX).abs()) ? a : b;
            });
            
            final hour = closestPattern.timeOfDay.hour.toString().padLeft(2, '0');
            final minute = closestPattern.timeOfDay.minute.toString().padLeft(2, '0');
            
            return [
              LineTooltipItem(
                '$hour:$minute\n'
                'Media: ${closestPattern.mean.toStringAsFixed(0)} mg/dL\n'
                'Rango: ${closestPattern.min.toStringAsFixed(0)}-${closestPattern.max.toStringAsFixed(0)}\n'
                '${closestPattern.sampleCount} muestras',
                const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 11),
              ),
            ];
          },
        ),
      ),
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          _buildLowLimitLine(lowLimit),
          _buildHighLimitLine(highLimit),
        ],
      ),
      betweenBarsData: [
        // Banda de desviación estándar (área entre upper y lower)
        BetweenBarsData(
          fromIndex: 0,
          toIndex: 1,
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
      ],
      lineBarsData: [
        // Línea superior (invisible, para BetweenBarsData)
        LineChartBarData(
          spots: upperSpots,
          show: false,
          dotData: const FlDotData(show: false),
        ),
        // Línea inferior (invisible, para BetweenBarsData)
        LineChartBarData(
          spots: lowerSpots,
          show: false,
          dotData: const FlDotData(show: false),
        ),
        // Línea de media (visible)
        LineChartBarData(
          spots: meanSpots,
          color: AppColors.primary,
          barWidth: 2.5,
          isCurved: true,
          curveSmoothness: 0.3,
          dotData: const FlDotData(show: false),
        ),
      ],
    );
  }

  /// Línea de límite bajo
  HorizontalLine _buildLowLimitLine(int lowLimit) {
    return HorizontalLine(
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
    );
  }

  /// Línea de límite alto
  HorizontalLine _buildHighLimitLine(int highLimit) {
    return HorizontalLine(
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
    );
  }

  /// Obtener formato de fecha apropiado para datos raw (6H, 1D)
  String _getDateFormat(ChartRange range) {
    return switch (range) {
      ChartRange.sixHours || ChartRange.oneDay => 'HH:mm',
      ChartRange.threeDays || ChartRange.oneWeek || ChartRange.oneMonth || ChartRange.threeMonths => 'dd/MM',
    };
  }

  /// Calcular intervalo apropiado para el eje X según el rango
  double _getXAxisInterval(int readingsCount, ChartRange range) {
    if (readingsCount == 0) return 1;
    
    // Aproximadamente 4-5 labels en el eje X
    return switch (range) {
      ChartRange.sixHours    => (readingsCount / 4).ceilToDouble().clamp(1, readingsCount.toDouble()),
      ChartRange.oneDay      => (readingsCount / 5).ceilToDouble().clamp(1, readingsCount.toDouble()),
      ChartRange.threeDays   => (readingsCount / 4).ceilToDouble().clamp(1, readingsCount.toDouble()),
      ChartRange.oneWeek     => (readingsCount / 5).ceilToDouble().clamp(1, readingsCount.toDouble()),
      ChartRange.oneMonth    => (readingsCount / 5).ceilToDouble().clamp(1, readingsCount.toDouble()),
      ChartRange.threeMonths => (readingsCount / 4).ceilToDouble().clamp(1, readingsCount.toDouble()),
    };
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