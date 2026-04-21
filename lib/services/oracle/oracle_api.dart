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

  Future<Map<String, String>> _authHeaders() async {
    final t = await OracleSessionStore().getToken();
    if (t == null || t.isEmpty) return {};
    return {'Authorization': 'Bearer $t'};
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

  Future<List<Map<String, dynamic>>> listCoachClients() async {
    final res = await http.get(_u('/api/auth/clients'), headers: await _authHeaders());
    if (res.statusCode != 200) {
      throw StateError('Oracle API clients failed (${res.statusCode}): ${res.body}');
    }
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    final rows = (m['rows'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return rows;
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

  Future<Map<String, dynamic>> weeklySchedulePublic({
    required String coachId,
    required String weekStartIso,
  }) async {
    final res = await http.get(
      _u('/api/schedule/weekly/public', {'coachId': coachId, 'weekStart': weekStartIso}),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) {
      throw StateError('Oracle API schedule (public) failed (${res.statusCode}): ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> addBlockedTime({required String dateIso, required String timeHhmm}) async {
    final res = await http.post(
      _u('/api/schedule/blocked-times'),
      headers: {'Content-Type': 'application/json', ...(await _authHeaders())},
      body: jsonEncode({'date': dateIso, 'time': timeHhmm}),
    );
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw StateError('Oracle API block slot failed (${res.statusCode}): ${res.body}');
    }
  }

  Future<void> removeBlockedTime({required String dateIso, required String timeHhmm}) async {
    final res = await http.delete(
      _u('/api/schedule/blocked-times', {'date': dateIso, 'time': timeHhmm}),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) {
      throw StateError('Oracle API unblock failed (${res.statusCode}): ${res.body}');
    }
  }

  Future<void> addDayClosure({required String dateIso}) async {
    final res = await http.post(
      _u('/api/schedule/day-closures'),
      headers: {'Content-Type': 'application/json', ...(await _authHeaders())},
      body: jsonEncode({'date': dateIso}),
    );
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw StateError('Oracle API day closure failed (${res.statusCode}): ${res.body}');
    }
  }

  Future<void> removeDayClosure({required String dateIso}) async {
    final res = await http.delete(
      _u('/api/schedule/day-closures', {'date': dateIso}),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) {
      throw StateError('Oracle API remove closure failed (${res.statusCode}): ${res.body}');
    }
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

  Future<List<Map<String, dynamic>>> listBookingsCoach({
    required String coachId,
    required String fromIso,
    required String toIso,
  }) async {
    final res = await http.get(
      _u('/api/bookings/coach', {'coachId': coachId, 'from': fromIso, 'to': toIso}),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) {
      throw StateError('Oracle API coach bookings failed (${res.statusCode}): ${res.body}');
    }
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    return (m['rows'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> listBookingsClient({
    required String fromIso,
    required String toIso,
  }) async {
    final res = await http.get(
      _u('/api/bookings', {'from': fromIso, 'to': toIso}),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) {
      throw StateError('Oracle API client bookings failed (${res.statusCode}): ${res.body}');
    }
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    return (m['rows'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> patchBookingStatus({required String bookingId, required String status}) async {
    final res = await http.patch(
      _u('/api/bookings/$bookingId'),
      headers: {'Content-Type': 'application/json', ...(await _authHeaders())},
      body: jsonEncode({'status': status}),
    );
    if (res.statusCode != 200) {
      throw StateError('Oracle API booking update failed (${res.statusCode}): ${res.body}');
    }
  }

  Future<Map<String, dynamic>?> getClientDetails(String clientId) async {
    final res = await http.get(_u('/api/profile/clients/$clientId/details'), headers: await _authHeaders());
    if (res.statusCode != 200) {
      throw StateError('Oracle API client details failed (${res.statusCode}): ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> putClientDetailsAsCoach({
    required String clientId,
    required String publicBio,
    required String goals,
    required String injuries,
    required String privateNotes,
  }) async {
    final res = await http.put(
      _u('/api/profile/clients/$clientId/details'),
      headers: {'Content-Type': 'application/json', ...(await _authHeaders())},
      body: jsonEncode({
        'public_bio': publicBio,
        'goals': goals,
        'injuries': injuries,
        'private_notes': privateNotes,
      }),
    );
    if (res.statusCode != 200) {
      throw StateError('Oracle API save details failed (${res.statusCode}): ${res.body}');
    }
  }

  Future<void> patchClientDetailsPublic({
    required String clientId,
    required String publicBio,
    required String goals,
    required String injuries,
  }) async {
    final res = await http.patch(
      _u('/api/profile/clients/$clientId/details/public'),
      headers: {'Content-Type': 'application/json', ...(await _authHeaders())},
      body: jsonEncode({
        'public_bio': publicBio,
        'goals': goals,
        'injuries': injuries,
      }),
    );
    if (res.statusCode != 200) {
      throw StateError('Oracle API public details failed (${res.statusCode}): ${res.body}');
    }
  }

  Future<List<Map<String, dynamic>>> listCoachClientRows({
    required String clientId,
  }) async {
    final res = await http.get(_u('/api/profile/clients/$clientId/rows'), headers: await _authHeaders());
    if (res.statusCode != 200) {
      throw StateError('Oracle API rows failed (${res.statusCode}): ${res.body}');
    }
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    return (m['rows'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> createCoachClientRow({
    required String clientId,
    required String rowDateIso,
    required String muscle,
    required String exercise,
    int? sets,
    int? reps,
    double? weight,
    required String weightUnit,
    required String notes,
  }) async {
    final res = await http.post(
      _u('/api/profile/clients/$clientId/rows'),
      headers: {'Content-Type': 'application/json', ...(await _authHeaders())},
      body: jsonEncode({
        'row_date': rowDateIso,
        'muscle': muscle,
        'exercise': exercise,
        'sets': sets,
        'reps': reps,
        'weight': weight,
        'weight_unit': weightUnit,
        'notes': notes,
      }),
    );
    if (res.statusCode != 201) {
      throw StateError('Oracle API create row failed (${res.statusCode}): ${res.body}');
    }
  }

  Future<void> updateCoachClientRow({
    required String rowId,
    required String rowDateIso,
    required String muscle,
    required String exercise,
    int? sets,
    int? reps,
    double? weight,
    required String weightUnit,
    required String notes,
  }) async {
    final res = await http.put(
      _u('/api/profile/rows/$rowId'),
      headers: {'Content-Type': 'application/json', ...(await _authHeaders())},
      body: jsonEncode({
        'row_date': rowDateIso,
        'muscle': muscle,
        'exercise': exercise,
        'sets': sets,
        'reps': reps,
        'weight': weight,
        'weight_unit': weightUnit,
        'notes': notes,
      }),
    );
    if (res.statusCode != 200) {
      throw StateError('Oracle API update row failed (${res.statusCode}): ${res.body}');
    }
  }

  Future<void> deleteCoachClientRow({required String rowId}) async {
    final res = await http.delete(_u('/api/profile/rows/$rowId'), headers: await _authHeaders());
    if (res.statusCode != 200) {
      throw StateError('Oracle API delete row failed (${res.statusCode}): ${res.body}');
    }
  }

  Future<int> notificationsUnreadCount() async {
    final res = await http.get(_u('/api/notifications/unread-count'), headers: await _authHeaders());
    if (res.statusCode != 200) return 0;
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    return (m['count'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> notificationsList() async {
    final res = await http.get(_u('/api/notifications'), headers: await _authHeaders());
    if (res.statusCode != 200) {
      throw StateError('Oracle API notifications failed (${res.statusCode}): ${res.body}');
    }
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    return (m['rows'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> markNotificationRead(String id) async {
    final res = await http.patch(_u('/api/notifications/$id/read'), headers: await _authHeaders());
    if (res.statusCode != 200) {
      throw StateError('Oracle API mark read failed (${res.statusCode}): ${res.body}');
    }
  }

  Future<void> markAllNotificationsRead() async {
    final res = await http.post(_u('/api/notifications/read-all'), headers: await _authHeaders());
    if (res.statusCode != 200) {
      throw StateError('Oracle API mark all read failed (${res.statusCode}): ${res.body}');
    }
  }

  Future<Map<String, dynamic>> generateAiWeekPlan({
    required String clientId,
    String? weekStartIso,
  }) async {
    final res = await http.post(
      _u('/api/ai/week-plan'),
      headers: {'Content-Type': 'application/json', ...(await _authHeaders())},
      body: jsonEncode({
        'client_id': clientId,
        if (weekStartIso != null && weekStartIso.isNotEmpty) 'week_start': weekStartIso,
      }),
    );
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw StateError('Oracle API AI week plan failed (${res.statusCode}): ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> latestAiWeekPlan({required String clientId}) async {
    final res = await http.get(
      _u('/api/ai/week-plan/latest', {'client_id': clientId}),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) {
      throw StateError('Oracle API AI latest failed (${res.statusCode}): ${res.body}');
    }
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    final plan = m['plan'];
    if (plan == null) return null;
    if (plan is Map<String, dynamic>) return plan;
    if (plan is Map) return Map<String, dynamic>.from(plan);
    return null;
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
