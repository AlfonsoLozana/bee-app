class InsulinReading {
  final DateTime timestamp;
  final double value; // pmol/L

  const InsulinReading({required this.timestamp, required this.value});

  InsulinStatus get status {
    if (value > 180) return InsulinStatus.high;
    if (value < 80)  return InsulinStatus.low;
    return InsulinStatus.normal;
  }
}

enum InsulinStatus { normal, high, low }

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