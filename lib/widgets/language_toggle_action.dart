import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/i18n/app_localizations.dart';

class LanguageToggleAction extends StatelessWidget {
  const LanguageToggleAction({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final label = s.isArabic ? s.t('lang.en') : s.t('lang.ar');
    return TextButton(
      onPressed: () => appState.toggleLanguage(),
      child: Text(label),
    );
  }
}

