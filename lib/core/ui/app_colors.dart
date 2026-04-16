import 'package:flutter/material.dart';

abstract final class AppColors {
  // Reference-driven palette (red primary, soft gray background, white cards).
  static const Color primary = Color(0xFFE53935); // red
  static const Color onPrimary = Colors.white;

  static const Color bg = Color(0xFFF4F4F6);
  static const Color card = Colors.white;

  static const Color text = Color(0xFF111111);
  static const Color muted = Color(0xFF6B6B6F);

  static const Color border = Color(0xFFE2E2E6);
  static const Color shadow = Color(0x1A000000);

  static const Color disabled = Color(0xFFBDBDC2);

  // Slot colors (match screenshot intent).
  static const Color slotOpen = Colors.white;
  static const Color slotBlocked = Color(0xFFE9E9ED);
  static const Color slotBooked = primary;
}

