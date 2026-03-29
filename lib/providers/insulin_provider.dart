import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/libre_link_service.dart';
import '../services/database_service.dart';
import '../models/chart_range.dart';
import '../models/insulin_reading.dart';

class InsulinProvider extends ChangeNotifier {
  final LibreLinkService _service = LibreLinkService();

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String get userName => _service.firstName ?? 'Usuario';

  double _currentValue = 0;
  double get currentValue => _currentValue;

  List<InsulinReading> _readings = [];

  ChartRange _selectedRange = ChartRange.oneDay;
  ChartRange get selectedRange => _selectedRange;

  double _minToday = 0;
  double _maxToday = 0;
  double _averageToday = 0;
  double _tir = 0;
  double _cv = 0;
  double? _yesterdayAvg;

  double get minToday     => _minToday;
  double get maxToday     => _maxToday;
  double get averageToday => _averageToday;
  double get tir          => _tir;
  double get cv           => _cv;
  double get hba1cEst     => _averageToday > 0 
      ? double.parse(((_averageToday + 46.7) / 28.7).toStringAsFixed(2))
      : 0.0;
  
  List<DoseRecord> _doses = [];
  List<DoseRecord> get doses => _doses;
  
  int get dosesToday => _doses.where((d) {
    final today = DateTime.now();
    final doseDate = d.timestamp;
    return doseDate.year == today.year && 
           doseDate.month == today.month && 
           doseDate.day == today.day;
  }).length;

  // Última dosis registrada
  DoseRecord? get lastDose => _doses.isNotEmpty ? _doses.first : null;
  
  // Display de última dosis: "12 UI Rápida" o "-"
  String get lastDoseDisplay {
    final dose = lastDose;
    if (dose == null) return '-';
    final typeLabel = switch (dose.type) {
      DoseType.rapid      => 'Rápida',
      DoseType.basal      => 'Basal',
      DoseType.correction => 'Corrección',
    };
    return '${dose.units.toStringAsFixed(0)} UI $typeLabel';
  }
  
  // Tiempo desde última dosis: "Hace 3h 25m" o "-"
  String get lastDoseTime {
    final dose = lastDose;
    if (dose == null) return '-';
    
    final diff = DateTime.now().difference(dose.timestamp);
    if (diff.inDays > 0) {
      return 'Hace ${diff.inDays}d';
    } else if (diff.inHours > 0) {
      final mins = diff.inMinutes % 60;
      return mins > 0 ? 'Hace ${diff.inHours}h ${mins}m' : 'Hace ${diff.inHours}h';
    } else if (diff.inMinutes > 0) {
      return 'Hace ${diff.inMinutes}m';
    } else {
      return 'Ahora mismo';
    }
  }
  
  // Progress de última dosis (0-1 basado en tiempo: 6 horas = 1.0)
  double get lastDoseProgress {
    final dose = lastDose;
    if (dose == null) return 0.0;
    
    final diff = DateTime.now().difference(dose.timestamp);
    final hours = diff.inMinutes / 60.0;
    return (hours / 6.0).clamp(0.0, 1.0);  // 6 horas = 100%
  }
  
  // Comparación con ayer: "↑ 5% vs ayer" o null si no hay datos
  String? get yesterdayComparison {
    if (_yesterdayAvg == null || _averageToday == 0) return null;
    
    final diff = _averageToday - _yesterdayAvg!;
    final pct = (diff / _yesterdayAvg!) * 100;
    
    if (pct.abs() < 1) return null;  // Diferencia menor a 1% no se muestra
    
    final arrow = pct > 0 ? '↑' : '↓';
    return '$arrow ${pct.abs().toStringAsFixed(0)}% vs ayer';
  }

  List<InsulinReading> get readings => _filteredReadings();

  Timer? _pollTimer;
  static const _pollInterval = Duration(minutes: 1);

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.login(email, password);
      await _service.fetchPatientId();
      _isAuthenticated = true;
      await _initialFetch();
      _startPolling();
      notifyListeners();
      return true;
    } on LibreAuthException catch (e) {
      _errorMessage = 'Credenciales incorrectas. Verifica tu email y contraseña.';
      debugPrint('Auth error: $e');
    } on LibreDataException catch (e) {
      _errorMessage = 'Error obteniendo datos: \${e.message}';
      debugPrint('Data error: $e');
    } catch (e) {
      _errorMessage = 'Error de conexión. Verifica tu internet.';
      debugPrint('Unknown error: $e');
    } finally {
      _setLoading(false);
    }
    return false;
  }

  void logout() {
    _service.logout();
    _isAuthenticated = false;
    _readings.clear();
    _currentValue = 0;
    _pollTimer?.cancel();
    notifyListeners();
  }

  Future<void> _initialFetch() async {
    final apiReadings = await _service.fetchGraph();
    await DatabaseService.insertReadings(apiReadings);
    await _loadFromDatabase();
  }

  Future<void> _pollOnce() async {
    try {
      final current = await _service.fetchCurrentReading();
      await DatabaseService.insertReadings([current]);
      _currentValue = current.value;
      await _loadFromDatabase();
    } catch (e) {
      debugPrint('Poll error: $e');
    }
  }

  Future<void> _loadFromDatabase() async {
    final hours = switch (_selectedRange) {
      ChartRange.oneDay      => 24,
      ChartRange.threeDays   => 72,
      ChartRange.oneWeek     => 168,
      ChartRange.oneMonth    => 720,
      ChartRange.threeMonths => 2160,
    };

    final dbReadings = await DatabaseService.getReadings(hours: hours);
    _readings = dbReadings
        .map((r) => InsulinReading(timestamp: r.timestamp, value: r.value))
        .toList();

    final latest = await DatabaseService.getLatestReading();
    if (latest != null) _currentValue = latest.value;

    final stats = await DatabaseService.getDayStats();
    _minToday     = stats['min'] ?? 0;
    _maxToday     = stats['max'] ?? 0;
    _averageToday = stats['avg'] ?? 0;
    _tir          = stats['tir'] ?? 0;

    // Cargar CV del día actual
    _cv = await DatabaseService.getCVToday();

    // Cargar promedio de ayer para comparación
    _yesterdayAvg = await DatabaseService.getYesterdayAverage();

    // Cargar dosis recientes
    _doses = await DatabaseService.getRecentDoses(limit: 10);

    notifyListeners();
  }

  /// Añadir una nueva dosis de insulina
  Future<void> addDose(DoseRecord dose) async {
    await DatabaseService.insertDose(dose);
    _doses = await DatabaseService.getRecentDoses(limit: 10);
    notifyListeners();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollOnce());
  }

  List<InsulinReading> _filteredReadings() {
    if (_readings.isEmpty) return [];
    final cutoff = DateTime.now().subtract(switch (_selectedRange) {
      ChartRange.oneDay      => const Duration(hours: 24),
      ChartRange.threeDays   => const Duration(days: 3),
      ChartRange.oneWeek     => const Duration(days: 7),
      ChartRange.oneMonth    => const Duration(days: 30),
      ChartRange.threeMonths => const Duration(days: 90),
    });
    return _readings.where((r) => r.timestamp.isAfter(cutoff)).toList();
  }

  void setRange(ChartRange range) {
    _selectedRange = range;
    _loadFromDatabase();
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
