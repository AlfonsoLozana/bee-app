// lib/services/libre_link_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LibreLinkService {
  static const _baseUrl = 'https://api-eu.libreview.io';

  static const Map<String, String> _baseHeaders = {
    'Content-Type':    'application/json',
    'Accept':          'application/json',
    'product':         'llu.android',
    'version':         '4.16.0',
    'Accept-Encoding': 'gzip',
    'cache-control':   'no-cache',
    'Connection':      'Keep-Alive',
    'User-Agent':      'Mozilla/5.0',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  String? _token;
  String? _patientId;
  String? _accountId;
  String? firstName;
  String? lastName;

  bool get isAuthenticated => _token != null;
  String? get patientId => _patientId;

  Map<String, String> get _authHeaders => {
    ..._baseHeaders,
    'authorization': 'Bearer $_token',
    if (_accountId != null) 'account-id': _accountId!,
  };

  // ── Auth ──────────────────────────────────────────────────

  Future<void> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/llu/auth/login'),
      headers: _baseHeaders,
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode != 200) {
      throw LibreAuthException('Login fallido (${response.statusCode}): ${response.body}');
    }

    final body   = jsonDecode(response.body) as Map<String, dynamic>;
    final status = body['status'] as int? ?? 0;

    if (status == 4) {
      // Redirect a otra región
      final redirect = (body['data'] as Map<String, dynamic>?)?['redirect'] as String?;
      if (redirect != null) {
        await _loginWithUrl('https://$redirect/llu/auth/login', email, password);
        return;
      }
    }

    _parseLoginBody(body);
  }

  Future<void> _loginWithUrl(String url, String email, String password) async {
    final response = await http.post(
      Uri.parse(url),
      headers: _baseHeaders,
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode != 200) {
      throw LibreAuthException('Login (redirect) fallido (${response.statusCode})');
    }

    _parseLoginBody(jsonDecode(response.body) as Map<String, dynamic>);
  }

  void _parseLoginBody(Map<String, dynamic> body) {
    final data   = body['data'] as Map<String, dynamic>?;
    final ticket = data?['authTicket'] as Map<String, dynamic>?;
    final user   = data?['user']       as Map<String, dynamic>?;

    _token = ticket?['token'] as String?;
    if (_token == null) throw LibreAuthException('Token nulo.');

    // Guardar firstName y lastName del usuario
    firstName = user?['firstName'] as String?;
    lastName  = user?['lastName']  as String?;

    // SHA-256 del user.id — igual que hace pylibrelinkup
    final userId = user?['id']?.toString();
    if (userId != null) {
      _accountId = sha256.convert(utf8.encode(userId)).toString();
    }

    debugPrint('✅ Login OK | account-id (SHA-256): $_accountId | Nombre: $firstName $lastName');
  }

  // ── Connections / patients ────────────────────────────────

  Future<String> fetchPatientId() async {
    _ensureAuthenticated();

    final response = await http.get(
      Uri.parse('$_baseUrl/llu/connections'),
      headers: _authHeaders,
    );

    _checkStatus(response, 'Connections');

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>?;
    if (data == null || data.isEmpty) {
      throw LibreDataException('No hay pacientes en esta cuenta.');
    }

    _patientId = (data.first as Map<String, dynamic>)['patientId'] as String?;
    if (_patientId == null) throw LibreDataException('patientId no encontrado.');
    return _patientId!;
  }

  // ── Graph data ────────────────────────────────────────────

  Future<List<GlucoseReading>> fetchGraph() async {
    _ensureAuthenticated();
    _ensurePatient();

    final response = await http.get(
      Uri.parse('$_baseUrl/llu/connections/$_patientId/graph'),
      headers: _authHeaders,
    );

    _checkStatus(response, 'Graph');

    final body      = jsonDecode(response.body) as Map<String, dynamic>;
    final data      = body['data'] as Map<String, dynamic>?;
    final graphData = data?['graphData'] as List<dynamic>? ?? [];

    return graphData.map((e) {
      final entry = e as Map<String, dynamic>;
      return GlucoseReading(
        timestamp: _parseTimestamp(entry['Timestamp']),
        value:     (entry['Value'] as num?)?.toDouble() ?? 0.0,
        isHigh:    entry['isHigh'] as bool? ?? false,
        isLow:     entry['isLow']  as bool? ?? false,
      );
    }).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<GlucoseReading> fetchCurrentReading() async {
    _ensureAuthenticated();
    _ensurePatient();

    final response = await http.get(
      Uri.parse('$_baseUrl/llu/connections/$_patientId/graph'),
      headers: _authHeaders,
    );

    _checkStatus(response, 'Current');

    final body    = jsonDecode(response.body) as Map<String, dynamic>;
    final data    = body['data'] as Map<String, dynamic>?;
    final current = data?['connection'] as Map<String, dynamic>?;
    final measure = current?['glucoseMeasurement'] as Map<String, dynamic>?;

    if (measure == null) throw LibreDataException('Sin lectura actual.');

    return GlucoseReading(
      timestamp: _parseTimestamp(measure['Timestamp']),
      value:     (measure['Value'] as num?)?.toDouble() ?? 0.0,
      isHigh:    measure['isHigh'] as bool? ?? false,
      isLow:     measure['isLow']  as bool? ?? false,
    );
  }

  // ── Helpers ───────────────────────────────────────────────

  /// Parsea el campo Timestamp de la API, que puede ser:
  /// - String: "1/14/2025 5:30:00 PM"  (formato US con AM/PM)
  /// - String: "2025-01-14T17:30:00"   (ISO 8601)
  /// - int:    epoch en segundos        (formato antiguo)
  DateTime _parseTimestamp(dynamic raw) {
    if (raw == null) return DateTime.now();

    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw * 1000, isUtc: true).toLocal();
    }

    if (raw is String) {
      // Intentar ISO 8601 primero
      try {
        return DateTime.parse(raw).toLocal();
      } catch (_) {}

      // Formato "M/D/YYYY H:MM:SS AM/PM"
      try {
        final parts     = raw.trim().split(' ');
        final dateParts = parts[0].split('/');
        final timeParts = parts[1].split(':');
        final isPm      = parts.length > 2 && parts[2].toUpperCase() == 'PM';

        int month = int.parse(dateParts[0]);
        int day   = int.parse(dateParts[1]);
        int year  = int.parse(dateParts[2]);
        int hour  = int.parse(timeParts[0]);
        int min   = int.parse(timeParts[1]);
        int sec   = int.parse(timeParts[2]);

        if (isPm && hour != 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;

        return DateTime(year, month, day, hour, min, sec);
      } catch (e) {
        debugPrint('⚠️  No se pudo parsear timestamp: $raw — $e');
      }
    }

    return DateTime.now();
  }

  void _ensureAuthenticated() {
    if (_token == null) throw LibreAuthException('No autenticado. Llama login() primero.');
  }

  void _ensurePatient() {
    if (_patientId == null) throw LibreDataException('Sin patientId. Llama fetchPatientId() primero.');
  }

  void _checkStatus(http.Response r, String ctx) {
    if (r.statusCode != 200) {
      throw LibreDataException('$ctx falló (${r.statusCode}): ${r.body}');
    }
  }

  void logout() {
    _token = _patientId = _accountId = null;
    firstName = lastName = null;
  }

  // ── Persistencia de Credenciales ─────────────────────────

  /// Guarda las credenciales del usuario en SharedPreferences
  Future<void> saveCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Codificar las credenciales en base64 para ofuscar (no es encriptación real)
    final encodedEmail = base64Encode(utf8.encode(email));
    final encodedPassword = base64Encode(utf8.encode(password));
    
    await prefs.setString('libre_email', encodedEmail);
    await prefs.setString('libre_password', encodedPassword);
    
    debugPrint('✅ Credenciales guardadas');
  }

  /// Guarda el token de autenticación
  Future<void> saveToken() async {
    if (_token == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('libre_token', _token!);
    if (_accountId != null) {
      await prefs.setString('libre_account_id', _accountId!);
    }
    if (_patientId != null) {
      await prefs.setString('libre_patient_id', _patientId!);
    }
    if (firstName != null) {
      await prefs.setString('libre_first_name', firstName!);
    }
    if (lastName != null) {
      await prefs.setString('libre_last_name', lastName!);
    }
    
    debugPrint('✅ Token guardado');
  }

  /// Carga las credenciales guardadas
  Future<Map<String, String>?> loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    
    final encodedEmail = prefs.getString('libre_email');
    final encodedPassword = prefs.getString('libre_password');
    
    if (encodedEmail == null || encodedPassword == null) {
      return null;
    }
    
    try {
      final email = utf8.decode(base64Decode(encodedEmail));
      final password = utf8.decode(base64Decode(encodedPassword));
      return {'email': email, 'password': password};
    } catch (e) {
      debugPrint('⚠️  Error decodificando credenciales: $e');
      return null;
    }
  }

  /// Carga el token guardado
  Future<bool> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    
    _token = prefs.getString('libre_token');
    _accountId = prefs.getString('libre_account_id');
    _patientId = prefs.getString('libre_patient_id');
    firstName = prefs.getString('libre_first_name');
    lastName = prefs.getString('libre_last_name');
    
    if (_token != null) {
      debugPrint('✅ Token cargado desde SharedPreferences');
      return true;
    }
    
    return false;
  }

  /// Limpia todas las credenciales guardadas
  Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('libre_email');
    await prefs.remove('libre_password');
    await prefs.remove('libre_token');
    await prefs.remove('libre_account_id');
    await prefs.remove('libre_patient_id');
    await prefs.remove('libre_first_name');
    await prefs.remove('libre_last_name');
    
    debugPrint('✅ Credenciales limpiadas');
  }

  /// Valida si el token actual sigue siendo válido
  Future<bool> validateToken() async {
    if (_token == null) return false;
    
    try {
      // Intentar hacer una llamada simple para validar el token
      final response = await http.get(
        Uri.parse('$_baseUrl/llu/connections'),
        headers: _authHeaders,
      );
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('⚠️  Token inválido: $e');
      return false;
    }
  }
}

// ── Modelos ───────────────────────────────────────────────

class GlucoseReading {
  final DateTime timestamp;
  final double value;
  final bool isHigh;
  final bool isLow;

  const GlucoseReading({
    required this.timestamp,
    required this.value,
    this.isHigh = false,
    this.isLow  = false,
  });

  @override
  String toString() =>
      'GlucoseReading($value mg/dL @ $timestamp, high=$isHigh, low=$isLow)';
}

// ── Excepciones ───────────────────────────────────────────

class LibreAuthException implements Exception {
  final String message;
  const LibreAuthException(this.message);
  @override String toString() => 'LibreAuthException: $message';
}

class LibreDataException implements Exception {
  final String message;
  const LibreDataException(this.message);
  @override String toString() => 'LibreDataException: $message';
}