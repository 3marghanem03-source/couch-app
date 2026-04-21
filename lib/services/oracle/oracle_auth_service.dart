import '../../models/user.dart' as models;
import '../../models/user_role.dart';
import 'oracle_api.dart';

class OracleAuthService {
  OracleAuthService();

  final OracleApi _api = OracleApi();
  final OracleSessionStore _store = OracleSessionStore();

  Future<void> signOut() => _store.clear();

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final res = await _api.login(email: email, password: password);
    final token = (res['token'] as String?) ?? '';
    if (token.isEmpty) throw StateError('Missing token from Oracle API');
    await _store.setToken(token);
  }

  Future<void> signUpWithProfile({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    String? coachCode,
  }) async {
    final res = await _api.signUp(
      name: name,
      email: email,
      password: password,
      role: role == UserRole.coach ? 'coach' : 'client',
      coachCode: coachCode,
    );
    final token = (res['token'] as String?) ?? '';
    if (token.isEmpty) throw StateError('Missing token from Oracle API');
    await _store.setToken(token);
  }

  Future<models.User?> getCurrentUser() async {
    final token = await _store.getToken();
    if (token == null || token.isEmpty) return null;
    final res = await _api.me();
    final u = Map<String, dynamic>.from(res['user'] as Map);
    final roleStr = (u['role'] as String?) ?? 'client';
    return models.User(
      id: u['id'] as String,
      name: (u['name'] as String?)?.trim().isNotEmpty == true ? u['name'] as String : 'User',
      role: roleStr == 'coach' ? UserRole.coach : UserRole.client,
      coachId: u['coach_id'] as String?,
      inviteCode: u['invite_code'] as String?,
      avatarUrl: u['avatar_url'] as String?,
      sessionsRemaining: 0,
    );
  }
}

