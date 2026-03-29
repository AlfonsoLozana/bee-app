import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/insulin_reading.dart';
import '../models/chart_range.dart';

class InsulinProvider extends ChangeNotifier {
  final _rng = Random();

  ChartRange _selectedRange = ChartRange.oneDay;
  ChartRange get selectedRange => _selectedRange;

  double _currentValue = 142.0;
  double get currentValue => _currentValue;

  late Timer _liveTimer;

  final List<DoseRecord> doses = [
    DoseRecord(
      timestamp: DateTime.now().subtract(const Duration(hours: 3, minutes: 15)),
      type: DoseType.rapid, units: 10,
      insulinName: 'Glargina U-100', note: 'Desayuno',
    ),
    DoseRecord(
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
      type: DoseType.basal, units: 20, insulinName: 'Degludec',
    ),
    DoseRecord(
      timestamp: DateTime.now().subtract(const Duration(hours: 14, minutes: 30)),
      type: DoseType.correction, units: 4,
      insulinName: 'NovoRapid', note: 'Nivel alto (215)',
    ),
  ];

  List<InsulinReading> get readings => _generateReadings(_selectedRange);

  double get minToday    => 78.0;
  double get maxToday    => 210.0;
  double get averageToday => 138.0;
  int    get dosesToday  => 6;
  double get tir         => 78.0;
  double get cv          => 32.0;
  double get hba1cEst    => 6.8;

  InsulinProvider() {
    _liveTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final delta = (_rng.nextDouble() - 0.5) * 8;
      _currentValue = (_currentValue + delta).clamp(70.0, 220.0);
      notifyListeners();
    });
  }

  void setRange(ChartRange range) {
    _selectedRange = range;
    notifyListeners();
  }

  List<InsulinReading> _generateReadings(ChartRange range) {
    final now = DateTime.now();
    return switch (range) {
      ChartRange.oneDay => _build(
          count: 13,
          start: now.subtract(const Duration(hours: 24)),
          step: const Duration(hours: 2),
          values: [95,88,82,78,105,142,180,168,145,155,175,210,148]),
      ChartRange.threeDays => _build(
          count: 13,
          start: now.subtract(const Duration(days: 3)),
          step: const Duration(hours: 5, minutes: 30),
          values: [130,115,95,155,180,165,140,120,100,160,195,210,142]),
      ChartRange.oneWeek => _build(
          count: 7,
          start: now.subtract(const Duration(days: 6)),
          step: const Duration(days: 1),
          values: [120,135,148,125,160,142,138]),
      ChartRange.oneMonth => _build(
          count: 4,
          start: now.subtract(const Duration(days: 28)),
          step: const Duration(days: 7),
          values: [140,132,155,148]),
      ChartRange.threeMonths => _build(
          count: 3,
          start: now.subtract(const Duration(days: 60)),
          step: const Duration(days: 30),
          values: [155,148,142]),
    };
  }

  List<InsulinReading> _build({
    required int count,
    required DateTime start,
    required Duration step,
    required List<num> values,
  }) =>
    List.generate(count, (i) => InsulinReading(
      timestamp: start.add(step * i),
      value: values[i].toDouble(),
    ));

  @override
  void dispose() {
    _liveTimer.cancel();
    super.dispose();
  }
}