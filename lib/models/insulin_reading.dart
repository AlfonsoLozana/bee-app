// lib/models/insulin_reading.dart
class InsulinReading {
  final DateTime timestamp;
  final double value;

  const InsulinReading({required this.timestamp, required this.value});

  InsulinStatus get status {
    if (value > 240) return InsulinStatus.criticalHigh;
    if (value > 180) return InsulinStatus.high;
    if (value < 54) return InsulinStatus.criticalLow;
    if (value < 70) return InsulinStatus.low;
    return InsulinStatus.normal;
  }
}

enum InsulinStatus { criticalLow, low, normal, high, criticalHigh }

class DoseRecord {
  final DateTime timestamp;
  final DoseType type;
  final double units;
  final String insulinName;
  final String? note;

  const DoseRecord({
    required this.timestamp,
    required this.type,
    required this.units,
    required this.insulinName,
    this.note,
  });
}

enum DoseType { rapid, basal, correction }
