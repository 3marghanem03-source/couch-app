import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_navigator.dart';
import 'core/app_routes.dart';
import 'core/app_state.dart';
import 'core/config/app_config.dart';
import 'core/ui/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  AppConfig.assertSupabaseConfigured();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  appState.init();
  // Important: do not await network work before runApp — the native splash stays up until the first frame.
  runApp(const CoachSessionsApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    appState.recoverSessionIfAny().then((_) {}, onError: (Object e, StackTrace st) {
      debugPrint('Session recovery failed (app still opens on login): $e');
      debugPrint('$st');
    });
  });
}

class CoachSessionsApp extends StatelessWidget {
  const CoachSessionsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'Coach Sessions',
          theme: AppTheme.light(),
          initialRoute: AppRoutes.login,
          routes: AppRoutes.materialRoutes(),
        );
      },
    );
  }
}
