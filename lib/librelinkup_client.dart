import 'dart:convert';
import 'package:http/http.dart' as http;

class SimpleLibreLinkUp {
  final String email;
  final String password;
  final String baseUrl;
  
  String? _token;

  SimpleLibreLinkUp({
    required this.email,
    required this.password,
    // Por defecto usamos el servidor de Europa. 
    // Si estás en América u otra región, cámbialo a 'https://api.libreview.io'
    this.baseUrl = 'https://api-eu.libreview.io', 
  });

  // Cabeceras estrictamente necesarias para que la API no rechace la petición
  Map<String, String> get _headers => {
    'version': '4.7.0',
    'product': 'llu.android',
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  /// 1. Inicia sesión y guarda el token de acceso
  Future<void> login() async {
    final url = Uri.parse('$baseUrl/llu/auth/login');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['data']['authTicket']['token'];
    } else {
      throw Exception('Error al hacer login: ${response.statusCode} - ${response.body}');
    }
  }

  /// 2. Obtiene el ID del primer paciente vinculado a la cuenta
  Future<String> getPatientId() async {
    if (_token == null) throw Exception('Primero debes llamar a login()');

    final url = Uri.parse('$baseUrl/llu/connections');
    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final connections = data['data'] as List;
      
      if (connections.isEmpty) {
        throw Exception('No hay pacientes conectados a esta cuenta');
      }
      
      return connections[0]['patientId'];
    } else {
      throw Exception('Error al obtener conexiones');
    }
  }

  /// 3. Obtiene el historial de glucosa del paciente
  Future<List<dynamic>> getGlucoseData(String patientId) async {
    if (_token == null) throw Exception('Primero debes llamar a login()');

    final url = Uri.parse('$baseUrl/llu/connections/$patientId/graph');
    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // 'graphData' contiene el historial reciente, 'connection' tiene la medición actual
      return data['data']['graphData'] ?? []; 
    } else {
      throw Exception('Error al obtener datos de glucosa');
    }
  }
}