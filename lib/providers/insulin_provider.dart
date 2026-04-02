import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/libre_link_service.dart';
import '../services/database_service.dart';
import '../models/chart_range.dart';
import '../models/insulin_reading.dart';
import '../models/daily_pattern_reading.dart';

class InsulinProvider extends ChangeNotifier {
  final LibreLinkService _service = LibreLinkService();

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _userEmail;
  String get userName => _service.firstName ?? 'Usuario';
  String get userEmail => _userEmail ?? 'No disponible';

  // Límites personalizables
  int _lowLimit = 70;
  int _highLimit = 180;
  int get lowLimit => _lowLimit;
  int get highLimit => _highLimit;

  // Umbrales para eventos críticos (independientes de TIR)
  int _hypoThreshold = 70;
  int _hyperThreshold = 250;
  int get hypoThreshold => _hypoThreshold;
  int get hyperThreshold => _hyperThreshold;

  double _currentValue = 0;
  double get currentValue => _currentValue;

  List<InsulinReading> _readings = [];
  List<DailyPatternReading> _dailyPattern = [];

  ChartRange _selectedRange = ChartRange.oneDay;
  ChartRange get selectedRange => _selectedRange;

  // Navegación histórica
  DateTime? _selectedDate; // null = hoy
  DateTime? get selectedDate => _selectedDate;
  bool get isViewingToday => _selectedDate == null;

  /// Indica si el rango actual necesita mostrar patrón diario promedio
  bool get needsPattern =>
      _selectedRange == ChartRange.threeDays ||
      _selectedRange == ChartRange.oneWeek ||
      _selectedRange == ChartRange.oneMonth ||
      _selectedRange == ChartRange.threeMonths;

  double _minPeriod = 0;
  double _maxPeriod = 0;
  double _averagePeriod = 0;
  double _tirPeriod = 0;
  double _cvPeriod = 0;
  double? _yesterdayAvg;

  // Nuevas métricas ampliadas
  double _aboveRange = 0;
  double _belowRange = 0;
  double _criticalHigh = 0;

  // Contadores de eventos críticos
  int _hypoCount = 0;
  int _hyperCount = 0;

  double get minToday => _minPeriod;
  double get maxToday => _maxPeriod;
  double get averageToday => _averagePeriod;
  double get tir => _tirPeriod;
  double get cv => _cvPeriod;
  double get aboveRange => _aboveRange;
  double get belowRange => _belowRange;
  double get criticalHigh => _criticalHigh;
  int get hypoCount => _hypoCount;
  int get hyperCount => _hyperCount;
  double get hba1cEst => _averagePeriod > 0
      ? double.parse(((_averagePeriod + 46.7) / 28.7).toStringAsFixed(2))
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
      DoseType.rapid => 'Rápida',
      DoseType.basal => 'Basal',
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
      return mins > 0
          ? 'Hace ${diff.inHours}h ${mins}m'
          : 'Hace ${diff.inHours}h';
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
    return (hours / 6.0).clamp(0.0, 1.0); // 6 horas = 100%
  }

  // Comparación con ayer: "↑ 5% vs ayer" o null si no hay datos
  String? get yesterdayComparison {
    if (_yesterdayAvg == null || _averagePeriod == 0) return null;

    final diff = _averagePeriod - _yesterdayAvg!;
    final pct = (diff / _yesterdayAvg!) * 100;

    if (pct.abs() < 1) return null; // Diferencia menor a 1% no se muestra

    final arrow = pct > 0 ? '↑' : '↓';
    return '$arrow ${pct.abs().toStringAsFixed(0)}% vs ayer';
  }

  List<InsulinReading> get readings => _filteredReadings();
  List<DailyPatternReading> get dailyPattern => _dailyPattern;

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
      _userEmail = email; // Guardar email del usuario

      // Guardar credenciales y token para auto-login futuro
      await _service.saveCredentials(email, password);
      await _service.saveToken();

      await _initialFetch();
      await loadSettings(); // Cargar límites desde SharedPreferences
      _startPolling();
      notifyListeners();
      return true;
    } on LibreAuthException catch (e) {
      _errorMessage =
          'Credenciales incorrectas. Verifica tu email y contraseña.';
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

  /// Intenta auto-login usando credenciales guardadas
  Future<bool> tryAutoLogin() async {
    _setLoading(true);
    notifyListeners();

    try {
      // 1. Intentar cargar token guardado
      final hasToken = await _service.loadToken();

      if (hasToken) {
        // 2. Validar que el token sigue siendo válido
        final isValid = await _service.validateToken();

        if (isValid) {
          debugPrint('✅ Token válido, auto-login exitoso');
          _isAuthenticated = true;

          // Cargar patientId si no está
          if (_service.patientId == null) {
            await _service.fetchPatientId();
          }

          await _initialFetch();
          await loadSettings();
          _startPolling();
          _setLoading(false);
          notifyListeners();
          return true;
        }

        debugPrint('⚠️  Token expirado, intentando re-login con credenciales');
      }

      // 3. Si el token no existe o expiró, intentar login con credenciales guardadas
      final credentials = await _service.loadCredentials();

      if (credentials != null) {
        final email = credentials['email']!;
        final password = credentials['password']!;

        debugPrint('🔄 Intentando re-login con credenciales guardadas');

        await _service.login(email, password);
        await _service.fetchPatientId();
        await _service.saveToken(); // Guardar nuevo token

        _isAuthenticated = true;
        _userEmail = email;

        await _initialFetch();
        await loadSettings();
        _startPolling();
        _setLoading(false);
        notifyListeners();
        return true;
      }

      debugPrint('ℹ️  No hay credenciales guardadas');
      _setLoading(false);
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('❌ Auto-login falló: $e');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  void logout() async {
    _service.logout();
    await _service.clearCredentials(); // Limpiar credenciales guardadas
    _isAuthenticated = false;
    _userEmail = null; // Limpiar email
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
      ChartRange.sixHours => 6,
      ChartRange.oneDay => 24,
      ChartRange.threeDays => 72,
      ChartRange.oneWeek => 168,
      ChartRange.oneMonth => 720,
      ChartRange.threeMonths => 2160,
    };

    // Decidir el modo de visualización
    if (needsPattern) {
      // Para períodos largos (3D+): mostrar patrón diario promedio
      final days = switch (_selectedRange) {
        ChartRange.threeDays => 3,
        ChartRange.oneWeek => 7,
        ChartRange.oneMonth => 30,
        ChartRange.threeMonths => 90,
        _ => 1,
      };

      _dailyPattern = await DatabaseService.getDailyPattern(
        days: days,
        intervalMinutes: 1, // Resolución de 1 minuto para patrón diario
      );
      _readings = []; // Limpiar lecturas raw

      debugPrint(
        '📊 Patrón diario: ${_dailyPattern.length} franjas horarias (${_selectedRange.label}, $days días, 1 min)',
      );
    } else if (_selectedRange == ChartRange.oneDay) {
      // Día natural: desde 00:00 hasta 24:00 de HOY, agrupado por 5 minutos
      final dbReadings = await DatabaseService.getAggregatedReadings(
        intervalMinutes: 5,
      );
      _readings = dbReadings
          .map((r) => InsulinReading(timestamp: r.timestamp, value: r.value))
          .toList();
      _dailyPattern = []; // Limpiar patrón

      debugPrint(
        '📊 Día natural: ${_readings.length} lecturas agregadas (5 min) desde 00:00',
      );
    } else {
      // 6H: Últimas 6 horas desde ahora (rolling), sin agrupar
      final dbReadings = await DatabaseService.getReadings(hours: hours);
      _readings = dbReadings
          .map((r) => InsulinReading(timestamp: r.timestamp, value: r.value))
          .toList();
      _dailyPattern = []; // Limpiar patrón

      final now = DateTime.now();
      final since = now.subtract(Duration(hours: hours));
      debugPrint(
        '📊 Últimas ${hours}H: ${_readings.length} lecturas sin agrupar (desde ${since.hour}:${since.minute.toString().padLeft(2, '0')} hasta ${now.hour}:${now.minute.toString().padLeft(2, '0')})',
      );
    }

    final latest = await DatabaseService.getLatestReading();
    if (latest != null) _currentValue = latest.value;

    // Calcular estadísticas del período seleccionado
    final stats = await DatabaseService.getStatsForPeriod(
      hours: hours,
      lowLimit: _lowLimit,
      highLimit: _highLimit,
    );
    _minPeriod = stats['min'] ?? 0;
    _maxPeriod = stats['max'] ?? 0;
    _averagePeriod = stats['avg'] ?? 0;
    _tirPeriod = stats['tir'] ?? 0;
    _aboveRange = stats['above_range'] ?? 0;
    _belowRange = stats['below_range'] ?? 0;
    _criticalHigh = stats['critical_high'] ?? 0;

    // Cargar CV del período seleccionado
    _cvPeriod = await DatabaseService.getCVForPeriod(hours: hours);

    // Cargar eventos críticos (siempre últimas 24h)
    final events = await DatabaseService.getHypoHyperEvents(
      hours: 24,
      hypoThreshold: _hypoThreshold,
      hyperThreshold: _hyperThreshold,
    );
    _hypoCount = events['hypo_count'] ?? 0;
    _hyperCount = events['hyper_count'] ?? 0;

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

  /// Eliminar una dosis de insulina
  Future<void> deleteDose(DoseRecord dose) async {
    await DatabaseService.deleteDose(dose);
    _doses = await DatabaseService.getRecentDoses(limit: 10);
    notifyListeners();
  }

  /// Cargar límites de glucosa desde SharedPreferences
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _lowLimit = prefs.getInt('lowLimit') ?? 70;
    _highLimit = prefs.getInt('highLimit') ?? 180;
    _hypoThreshold = prefs.getInt('hypoThreshold') ?? 70;
    _hyperThreshold = prefs.getInt('hyperThreshold') ?? 250;
    notifyListeners();
  }

  /// Establecer límite bajo de glucosa
  Future<void> setLowLimit(int value) async {
    _lowLimit = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lowLimit', value);
    notifyListeners();
  }

  /// Establecer límite alto de glucosa
  Future<void> setHighLimit(int value) async {
    _highLimit = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('highLimit', value);
    notifyListeners();
  }

  /// Establecer umbral de hipoglucemia
  Future<void> setHypoThreshold(int value) async {
    _hypoThreshold = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('hypoThreshold', value);
    // Recargar eventos críticos
    await _loadFromDatabase();
  }

  /// Establecer umbral de hiperglucemia
  Future<void> setHyperThreshold(int value) async {
    _hyperThreshold = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('hyperThreshold', value);
    // Recargar eventos críticos
    await _loadFromDatabase();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollOnce());
  }

  List<InsulinReading> _filteredReadings() {
    if (_readings.isEmpty) return [];
    final cutoff = DateTime.now().subtract(switch (_selectedRange) {
      ChartRange.sixHours => const Duration(hours: 6),
      ChartRange.oneDay => const Duration(hours: 24),
      ChartRange.threeDays => const Duration(days: 3),
      ChartRange.oneWeek => const Duration(days: 7),
      ChartRange.oneMonth => const Duration(days: 30),
      ChartRange.threeMonths => const Duration(days: 90),
    });
    return _readings.where((r) => r.timestamp.isAfter(cutoff)).toList();
  }

  void setRange(ChartRange range) {
    _selectedRange = range;
    _loadFromDatabase();
  }

  /// Navegar al día anterior
  Future<void> goToPreviousDay() async {
    final currentDate = _selectedDate ?? DateTime.now();
    _selectedDate = DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day - 1,
    );
    await _loadFromDatabase();
  }

  /// Navegar al día siguiente
  Future<void> goToNextDay() async {
    if (_selectedDate == null) return; // Ya estamos en hoy

    final currentDate = _selectedDate!;
    final nextDate = DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day + 1,
    );

    // Si nextDate es hoy o en el futuro, volver a null (hoy)
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);

    if (nextDate.isAfter(todayMidnight) ||
        nextDate.isAtSameMomentAs(todayMidnight)) {
      _selectedDate = null; // Volver a hoy
    } else {
      _selectedDate = nextDate;
    }

    await _loadFromDatabase();
  }

  /// Establecer una fecha específica para visualizar
  Future<void> setSelectedDate(DateTime? date) async {
    if (date != null) {
      _selectedDate = DateTime(date.year, date.month, date.day);
    } else {
      _selectedDate = null;
    }
    await _loadFromDatabase();
  }

  /// Volver a la vista de hoy
  Future<void> goToToday() async {
    _selectedDate = null;
    await _loadFromDatabase();
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
