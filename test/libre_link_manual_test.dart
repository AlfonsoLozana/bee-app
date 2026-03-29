// test/libre_link_manual_test.dart
// Ejecutar: dart run test/libre_link_manual_test.dart
// ⚠️ NO committear — contiene credenciales

import 'dart:convert';
import 'package:http/http.dart' as http;

const _email    = 'alfonsolozana@gmail.com';
const _password = 'JOhasu83_23@@';

const _urls = [
  'https://api-eu.libreview.io',
  'https://api.libreview.io',
];

const _baseHeaders = {
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

Map<String, String> _authHeaders(String token, String accountId) => {
  ..._baseHeaders,
  'authorization': 'Bearer $token',
  'account-id':   accountId,   // ← viene de data.user.id, no del JWT
};

void main() async {
  print('\n══════════════════════════════════════════');
  print('   LibreLinkUp API - Test de autenticación');
  print('══════════════════════════════════════════\n');

  for (final baseUrl in _urls) {
    print('🌐 Probando: $baseUrl');
    final ok = await _testLogin(baseUrl);
    if (ok) break; // si una URL funciona, no prueba la segunda
    print('');
  }
}

// Devuelve true si el login + connections fue exitoso
Future<bool> _testLogin(String baseUrl) async {
  try {
    final sw = Stopwatch()..start();
    final response = await http.post(
      Uri.parse('$baseUrl/llu/auth/login'),
      headers: _baseHeaders,
      body: jsonEncode({'email': _email, 'password': _password}),
    );
    sw.stop();

    print('  ⏱  ${sw.elapsedMilliseconds}ms  |  HTTP ${response.statusCode}');

    if (response.statusCode != 200) {
      print('  ❌ HTTP ${response.statusCode}: ${response.body}');
      return false;
    }

    final body   = jsonDecode(response.body) as Map<String, dynamic>;
    final status = body['status'] as int? ?? -1;

    // Redirect de región
    if (status == 4) {
      final redirect = (body['data'] as Map?)?['redirect'] as String?;
      if (redirect != null) {
        print('  🔄 Redirect → https://$redirect');
        return _testLogin('https://$redirect');
      }
      return false;
    }

    if (status != 0) {
      print('  ❌ status=$status'); _printHint(status); return false;
    }

    final data       = body['data'] as Map<String, dynamic>?;
    final authTicket = data?['authTicket'] as Map<String, dynamic>?;
    final token      = authTicket?['token'] as String?;
    final user       = data?['user']       as Map<String, dynamic>?;

    if (token == null) { print('  ⚠️  Token nulo'); return false; }

    // ── El account-id CORRECTO viene de data.user.id ──────────
    final accountId = user?['id']?.toString();

    print('  ✅ LOGIN OK');
    print('  🔑 Token:      ${token.substring(0, 30)}...');
    print('  🆔 account-id: $accountId  ← de data.user.id');
    if (user != null) {
      print('  👤 ${user['firstName']} ${user['lastName']}  |  ${user['email']}  |  ${user['country']}');
    }

    if (accountId == null) {
      print('  ⚠️  account-id nulo — imprimiendo campos de user:');
      user?.forEach((k, v) { if (v is! Map && v is! List) print('     user.$k = $v'); });
      return false;
    }

    print('\n  🔗 Probando /connections...');
    await _testConnections(baseUrl, token, accountId);
    return true;

  } catch (e, st) {
    print('  💥 $e\n  $st');
    return false;
  }
}

Future<void> _testConnections(String baseUrl, String token, String accountId) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/llu/connections'),
      headers: _authHeaders(token, accountId),
    );

    print('  📡 HTTP ${response.statusCode}');

    if (response.statusCode != 200) {
      print('  ❌ ${response.body}');
      // Diagnóstico extra: imprimir qué campo mandó el server como esperado
      try {
        final err = jsonDecode(response.body);
        print('  🔍 Error: $err');
      } catch (_) {}
      return;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    print('  ✅ ${data.length} paciente(s)');

    for (final conn in data) {
      final c = conn as Map<String, dynamic>;
      print('     • patientId: ${c['patientId']}  |  ${c['firstName']} ${c['lastName']}');
      final g = c['glucoseMeasurement'] as Map<String, dynamic>?;
      if (g != null) print('       Glucosa: ${g['Value']} ${g['GlucoseUnits']}');
    }

    if (data.isNotEmpty) {
      final pid = (data.first as Map<String, dynamic>)['patientId'] as String;
      print('\n  📈 Probando /graph...');
      await _testGraph(baseUrl, token, accountId, pid);
    }
  } catch (e) {
    print('  💥 $e');
  }
}

Future<void> _testGraph(String baseUrl, String token, String accountId, String patientId) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/llu/connections/$patientId/graph'),
      headers: _authHeaders(token, accountId),
    );

    print('  📡 HTTP ${response.statusCode}');
    if (response.statusCode != 200) { print('  ❌ ${response.body}'); return; }

    final body    = jsonDecode(response.body) as Map<String, dynamic>;
    final data    = body['data'] as Map<String, dynamic>?;
    final graph   = data?['graphData'] as List<dynamic>? ?? [];
    final current = data?['connection'] as Map<String, dynamic>?;
    final measure = current?['glucoseMeasurement'] as Map<String, dynamic>?;

    print('  ✅ Graph OK — ${graph.length} puntos históricos');
    if (measure != null) {
      print('     Actual: ${measure['Value']} ${measure['GlucoseUnits']}  |  ${measure['Timestamp']}');
      print('     isHigh=${measure['isHigh']}  isLow=${measure['isLow']}');
    }
    if (graph.isNotEmpty) {
      final first = (graph.first as Map)['Timestamp'];
      final last  = (graph.last  as Map)['Timestamp'];
      print('     Rango: $first → $last');
    }
  } catch (e) {
    print('  💥 $e');
  }
}

void _printHint(int s) {
  const h = {
    1: 'Error genérico auth', 2: 'Cuenta bloqueada',
    3: 'Demasiados intentos', 6: 'Versión desactualizada',
  };
  if (h[s] != null) print('  💡 ${h[s]}');
}