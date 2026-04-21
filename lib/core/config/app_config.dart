import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Loads `assets/app.env.example` and optional `--dart-define` overrides.
class AppConfig {
  AppConfig._();

  static const String _compileOracleApiBaseUrl = String.fromEnvironment('ORACLE_API_BASE_URL', defaultValue: '');

  static String _defaultCoachId = '';
  static String _oracleApiBaseUrl = '';

  static String get oracleApiBaseUrl => _oracleApiBaseUrl;
  static bool get useOracleApi => _oracleApiBaseUrl.isNotEmpty;

  /// Optional: when set, clients load this coach’s schedule. If empty, the first `coach` in `users` is used.
  static String get defaultCoachId => _defaultCoachId;

  static Future<void> load() async {
    await dotenv.load(fileName: 'assets/app.env.example');
    final env = dotenv.env;

    _defaultCoachId = (env['DEFAULT_COACH_ID'] ?? env['EXPO_PUBLIC_DEFAULT_COACH_ID'] ?? '').trim();
    _oracleApiBaseUrl =
        (_compileOracleApiBaseUrl.isNotEmpty ? _compileOracleApiBaseUrl : env['ORACLE_API_BASE_URL']?.trim()) ?? '';

    if (kDebugMode) {
      debugPrint('[AppConfig] Oracle API enabled: ${_oracleApiBaseUrl.isNotEmpty}');
    }
  }
}
