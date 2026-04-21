import 'dart:async';
import 'dart:io';

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

  // Backend / API errors (we throw StateError with user-ready messages).

  // App-thrown errors intended for users.
  if (error is StateError) {
    final m = error.message;
    if (m.trim().isNotEmpty) return m;
  }

  // Last resort.
  return 'Something went wrong. Please try again.';
}

