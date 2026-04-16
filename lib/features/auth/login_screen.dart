import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../core/app_state.dart';
import '../../core/errors/user_friendly_error.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../models/user_role.dart';
import '../../widgets/card_container.dart';
import '../../widgets/input_field.dart';
import '../../widgets/language_toggle_action.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _coachCodeCtrl = TextEditingController();
  UserRole _role = UserRole.coach;
  bool _busy = false;
  bool _createAccount = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _coachCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitSignIn() async {
    setState(() => _busy = true);
    try {
      await appState.signIn(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      AppRoutes.replaceWithRoleHome(context, appState.currentUser!.role);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = userFriendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitSignUp() async {
    setState(() => _busy = true);
    try {
      await appState.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        name: _nameCtrl.text.trim(),
        role: _role,
        coachCode: _role == UserRole.client ? _coachCodeCtrl.text.trim() : null,
      );
      if (!mounted) return;
      AppRoutes.replaceWithRoleHome(context, appState.currentUser!.role);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = userFriendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: CardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(alignment: Alignment.centerRight, child: LanguageToggleAction()),
                    const SizedBox(height: 8),
                    Text(
                      'Welcome back.\nYour journey starts\nhere.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.titleHero,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Sign in or create an account.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.muted,
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Sign in')),
                        ButtonSegment(value: true, label: Text('Create account')),
                      ],
                      selected: {_createAccount},
                      onSelectionChanged: (s) => setState(() => _createAccount = s.first),
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _error!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onErrorContainer,
                              ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.itemGap),
                    ],
                    if (_createAccount) ...[
                      InputField(
                        controller: _nameCtrl,
                        label: 'Name',
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                      ),
                      const SizedBox(height: AppSpacing.itemGap),
                      Text('I am a', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      SegmentedButton<UserRole>(
                        segments: const [
                          ButtonSegment(value: UserRole.coach, label: Text('Coach'), icon: Icon(Icons.fitness_center)),
                          ButtonSegment(value: UserRole.client, label: Text('Client'), icon: Icon(Icons.person)),
                        ],
                        selected: {_role},
                        onSelectionChanged: (s) => setState(() {
                          _role = s.first;
                          if (_role != UserRole.client) _coachCodeCtrl.clear();
                        }),
                      ),
                      const SizedBox(height: AppSpacing.itemGap),
                      if (_role == UserRole.client) ...[
                        InputField(
                          controller: _coachCodeCtrl,
                          label: 'Coach code',
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                        ),
                        const SizedBox(height: AppSpacing.itemGap),
                      ],
                    ],
                    InputField(
                      controller: _emailCtrl,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                    const SizedBox(height: AppSpacing.itemGap),
                    InputField(
                      controller: _passwordCtrl,
                      label: 'Password',
                      obscureText: true,
                      onSubmitted: (_) {
                        if (_busy) return;
                        if (_createAccount) {
                          _submitSignUp();
                        } else {
                          _submitSignIn();
                        }
                      },
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),
                    PrimaryButton(
                      label: _busy ? s.t('common.loading') : (_createAccount ? s.t('auth.signup') : s.t('auth.login')),
                      onPressed: _busy
                          ? null
                          : () {
                              if (_createAccount) {
                                _submitSignUp();
                              } else {
                                _submitSignIn();
                              }
                            },
                    ),
                    const SizedBox(height: AppSpacing.itemGap),
                    SecondaryButton(
                      label: _createAccount ? 'Already have an account? Sign in' : 'Create account',
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _createAccount = !_createAccount;
                                _error = null;
                              }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
