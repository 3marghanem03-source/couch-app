import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Converts technical exceptions into messages normal people understand.
///
/// Keep messages short, actionable, and non-scary.
String userFriendlyErrorMessage(Object error) {
  // Timeouts (we set timeouts in a few places in AppState).
  if (error is TimeoutException) {
    return 'This is taking too long. Please check your internet connection and try again.';
  }

  // Device network issues.
  if (error is SocketException) {
    return 'No internet connection. Please connect to Wi‑Fi or mobile data and try again.';
  }

  // Supabase Auth.
  if (error is AuthApiException) {
    final code = (error.code ?? '').toLowerCase();
    final msg = (error.message).toLowerCase();

    if (code.contains('invalid_login_credentials') || msg.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (code.contains('email_not_confirmed') || msg.contains('confirm') && msg.contains('email')) {
      return 'Please confirm your email, then try signing in again.';
    }
    if (code.contains('user_already_exists')) {
      return 'An account with this email already exists. Try signing in instead.';
    }
    if (code.contains('over_email_send_rate_limit') || int.tryParse('${error.statusCode}') == 429) {
      return 'Too many email requests. Please wait a bit and try again.';
    }
    if (code.contains('weak_password') || msg.contains('password')) {
      return 'That password is too weak. Please choose a stronger one.';
    }
    if (code.contains('signup_disabled')) {
      return 'Account creation is disabled right now.';
    }

    // Fallback: show a clean, user-facing auth error.
    return 'Login failed. Please check your details and try again.';
  }

  // Supabase database (PostgREST).
  if (error is PostgrestException) {
    final msg = (error.message).toLowerCase();
    // Common RLS symptom.
    if (msg.contains('permission') || msg.contains('rls') || msg.contains('not allowed') || msg.contains('access')) {
      return 'You don’t have permission to do that with this account.';
    }
    return 'Something went wrong while loading data. Please try again.';
  }

  // Supabase / HTTP / other platform errors.
  if (error is StorageException) {
    return 'Upload failed. Please try again.';
  }

  // App-thrown errors intended for users.
  if (error is StateError) {
    final m = error.message;
    if (m.trim().isNotEmpty) return m;
  }

  // Last resort.
  return 'Something went wrong. Please try again.';
}

