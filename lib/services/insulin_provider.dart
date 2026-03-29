// lib/providers/insulin_provider.dart
// VERSIÓN COMPLETA — reemplaza el archivo anterior íntegramente

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/libre_link_service.dart';
import '../services/database_service.dart';
import '../models/chart_range.dart';
import '../models/insulin_reading.dart';

class InsulinProvider extends ChangeNotifier {
  final LibreLinkService _service = LibreLinkService();

  // ── Estado de auth ────────────────────────────────────
  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ── Datos de glucosa ──────────────────────────────────
  double _currentValue = 0;
  double get currentValue => _currentValue;

  List<InsulinReading> _readings = [];

  ChartRange _selectedRange = ChartRange.oneDay;
  ChartRange get selectedRange => _selectedRange;

  // ── Stats del día ─────────────────────────────────────
  double _minToday = 0;
  double _maxToday = 0;
  double _averageToday = 0;
  double _tir = 0;

  double get minToday      => _minToday;
  double get maxToday      => _maxToday;
  double get averageToday  => _averageToday;
  double get tir           => _tir;
  double get cv            => 32.0;
  double get hba1cEst      => _averageToday > 0
      ? ((_averageToday + 46.7) / 28.7)
      : 0;
  int    get dosesToday    => 0;

  List<InsulinReading> get readings => _filteredReadings();
  final List<DoseRecord> doses = [];

  Timer? _pollTimer;
  static const _pollInterval = Duration(minutes: 1);

  // ── Auth ──────────────────────────────────────────────

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
      _errorMessage = 'Error obteniendo datos: ${e.message}';
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

  // ── Fetching ──────────────────────────────────────────

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

    notifyListeners();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    