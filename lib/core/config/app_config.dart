import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Loads `assets/app.env` and optional `--dart-define` overrides.
///
/// Required for Supabase:
/// - `SUPABASE_URL`
/// - `SUPABASE_ANON_KEY`
class AppConfig {
  AppConfig._();

  static const String _compileSupabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String _compileSupabaseAnon = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  static String _supabaseUrl = '';
  static String _supabaseAnonKey = '';
  static String _defaultCoachId = '';

  static String get supabaseUrl => _supabaseUrl;
  static String get supabaseAnonKey => _supabaseAnonKey;

  /// Optional: when set, clients load this coach’s schedule. If empty, the first `coach` in `users` is used.
  static String get defaultCoachId => _defaultCoachId;

  static Future<void> load() async {
    await dotenv.load(fileName: 'assets/app.env', isOptional: true);
    final env = dotenv.env;

    final url = (_compileSupabaseUrl.isNotEmpty ? _compileSupabaseUrl : env['SUPABASE_URL']?.trim()) ?? '';
    final anon = (_compileSupabaseAnon.isNotEmpty ? _compileSupabaseAnon : env['SUPABASE_ANON_KEY']?.trim()) ?? '';
    _defaultCoachId = (env['DEFAULT_COACH_ID'] ?? env['EXPO_PUBLIC_DEFAULT_COACH_ID'] ?? '').trim();

    _supabaseUrl = url;
    _supabaseAnonKey = anon;

    if (kDebugMode) {
      debugPrint('[AppConfig] Supabase URL set: ${url.isNotEmpty}');
    }
  }

  static void assertSupabaseConfigured() {
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing SUPABASE_URL or SUPABASE_ANON_KEY. Add them to assets/app.env (see assets/app.env.example).',
      );
    }
  }
}
