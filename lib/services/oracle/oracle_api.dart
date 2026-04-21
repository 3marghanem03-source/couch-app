import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';

class OracleApi {
  OracleApi();

  Uri _u(String path, [Map<String, String>? query]) {
    final base = AppConfig.oracleApiBaseUrl.trim();
    final uri = Uri.parse(base);
    return uri.replace(
      path: '${uri.path}${path.startsWith('/') ? path : '/$path'}',
      queryParameters: query,
    );
  }

  Future<Map<String, dynamic>> health() async {
    final res = await http.get(_u('/api/health'));
    if (res.statusCode != 200) throw StateError('Oracle API health failed (${res.statusCode})');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> signUp({
    required String name,
    required String email,
    required String password,
    required String role,
    String? coachCode,
  }) async {
    final res = await http.post(
      _u('/api/auth/signup'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        if (coachCode != null && coachCode.trim().isNotEmpty) 'coachCode': coachCode.trim(),
      }),
    );
    if (res.statusCode != 201) {
      throw StateError('Oracle API signup failed (${res.statusCode}): ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      _u('/api/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode != 200) {
      throw StateError('Oracle API login failed (${res.statusCode}): ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> me() async {
    final res = await http.get(_u('/api/auth/me'), headers: await _authHeaders());
    if (res.statusCode != 200) {
      throw StateError('Oracle API me failed (${res.statusCode}): ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> weeklySchedule({
    required String coachId,
    required String weekStartIso,
  }) async {
    final res = await http.get(
      _u('/api/schedule/weekly', {'coachId': coachId, 'weekStart': weekStartIso}),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) {
      throw StateError('Oracle API schedule failed (${res.statusCode}): ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> createBooking({
    required String id,
    required String clientId,
    required String coachId,
    required String dateIso,
    required String timeHhmm,
  }) async {
    final res = await http.post(
      _u('/api/bookings'),
      headers: {'Content-Type': 'application/json', ...(await _authHeaders())},
      body: jsonEncode({
        'id': id,
        'client_id': clientId,
        'coach_id': coachId,
        'date': dateIso,
        'time': timeHhmm,
      }),
    );
    if (res.statusCode != 201) {
      throw StateError('Oracle API booking failed (${res.statusCode}): ${res.body}');
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    final t = await OracleSessionStore().getToken();
    if (t == null || t.isEmpty) return {};
    return {'Authorization': 'Bearer $t'};
  }
}

class OracleSessionStore {
  static const _k = 'oracle_api_token';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_k);
  }

  Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_k, token);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_k);
  }
}

