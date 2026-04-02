// lib/models/daily_pattern_reading.dart
import 'dart:math' show sqrt;
import 'package:flutter/material.dart';

/// Lectura de glucosa agregada por franja horaria del día
/// Representa el patrón glucémico promedio a una hora específica
/// basado en múltiples días de datos
class DailyPatternReading {
  final TimeOfDay timeOfDay; // Hora del día (ej: 08:00)
  final double mean; // Media de glucosa en esa hora a través de N días
  final double stdDev; // Desviación estándar
  final double min; // Valor mínimo observado
  final double max; // Valor máximo observado
  final int sampleCount; // Cuántas lecturas se usaron para calcular

  const DailyPatternReading({
    required this.timeOfDay,
    required this.mean,
    required this.stdDev,
    required this.min,
    required this.max,
    required this.sampleCount,
  });

  /// Límite superior de la banda (media + 1 desviación estándar)
  double get meanPlusStdDev => mean + stdDev;

  /// Límite inferior de la banda (media - 1 desviación estándar)
  double get meanMinusStdDev => mean - stdDev;

  /// Minutos desde medianoche (0-1439)
  int get minuteOfDay => timeOfDay.hour * 60 + timeOfDay.minute;

  /// Calcular desviación estándar de una lista de valores
  static double calculateStdDev(List<double> values, double mean) {
    if (values.length < 2) return 0.0;

    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
        values.length;

    return sqrt(variance);
  }

  @override
  String toString() {
    final hour = timeOfDay.hour.toString().padLeft(2, '0');
    final minute = timeOfDay.minute.toString().padLeft(2, '0');
    return 'DailyPatternReading($hour:$minute: $mean ± $stdDev, n=$sampleCount)';
  }
}
