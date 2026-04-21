import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Loads `assets/app.env.example` and optional `--dart-define` overrides.
///
/// Required for Supabase:
/// - `SUPABASE_URL`
/// - `SUPABASE_ANON_KEY`
class AppConfig {
  AppConfig._();

  static const String _compileSupabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String _compileSupabaseAnon = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  static const String _compileOracleApiBaseUrl = String.fromEnvironment('ORACLE_API_BASE_URL', defaultValue: '');
  static const String _compileGenerateWeekFn = String.fromEnvironment(
    'SUPABASE_FN_GENERATE_TRAINING_WEEK',
    defaultValue: '',
  );

  static String _supabaseUrl = '';
  static String _supabaseAnonKey = '';
  static String _defaultCoachId = '';
  static String _generateTrainingWeekFunctionName = 'generate-training-week';
  static String _oracleApiBaseUrl = '';

  static String get supabaseUrl => _supabaseUrl;
  static String get supabaseAnonKey => _supabaseAnonKey;
  static String get oracleApiBaseUrl => _oracleApiBaseUrl;
  static bool get useOracleApi => _oracleApiBaseUrl.isNotEmpty;

  /// Optional: when set, clients load this coach’s schedule. If empty, the first `coach` in `users` is used.
  static String get defaultCoachId => _defaultCoachId;

  /// Edge Function slug (last path segment of `/functions/v1/...`). Must match the Supabase dashboard name.
  static String get generateTrainingWeekFunctionName => _generateTrainingWeekFunctionName;

  static Future<void> load() async {
    await dotenv.load(fileName: 'assets/app.env.example');
    final env = dotenv.env;

    final url = (_compileSupabaseUrl.isNotEmpty ? _compileSupabaseUrl : env['SUPABASE_URL']?.trim()) ?? '';
    final anon = (_compileSupabaseAnon.isNotEmpty ? _compileSupabaseAnon : env['SUPABASE_ANON_KEY']?.trim()) ?? '';
    _defaultCoachId = (env['DEFAULT_COACH_ID'] ?? env['EXPO_PUBLIC_DEFAULT_COACH_ID'] ?? '').trim();
    _oracleApiBaseUrl =
        (_compileOracleApiBaseUrl.isNotEmpty ? _compileOracleApiBaseUrl : env['ORACLE_API_BASE_URL']?.trim()) ?? '';

    final fnRaw = (_compileGenerateWeekFn.isNotEmpty
            ? _compileGenerateWeekFn
            : env['SUPABASE_FN_GENERATE_TRAINING_WEEK']?.trim()) ??
        '';
    _generateTrainingWeekFunctionName =
        fnRaw.isNotEmpty ? fnRaw : 'generate-training-week';

    _supabaseUrl = url;
    _supabaseAnonKey = anon;

    if (kDebugMode) {
      debugPrint('[AppConfig] Supabase URL set: ${url.isNotEmpty}');
      debugPrint('[AppConfig] Oracle API enabled: ${_oracleApiBaseUrl.isNotEmpty}');
    }
  }

  static void assertSupabaseConfigured() {
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing SUPABASE_URL or SUPABASE_ANON_KEY. For local dev, copy assets/app.env.example to assets/app.env and update it, or pass --dart-define values.',
      );
    }
  }
}
