import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  static const String? fontFamily = null; // use platform default (close to reference)

  static TextStyle get titleHero => const TextStyle(
        fontSize: 22,
        height: 1.15,
        fontWeight: FontWeight.w800,
        color: AppColors.text,
      );

  static TextStyle get titlePage => const TextStyle(
        fontSize: 18,
        height: 1.2,
        fontWeight: FontWeight.w800,
        color: AppColors.text,
      );

  static TextStyle get body => const TextStyle(
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w500,
        color: AppColors.text,
      );

  static TextStyle get muted => const TextStyle(
        fontSize: 12,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: AppColors.muted,
      );

  static TextStyle get section => const TextStyle(
        fontSize: 13,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      );

  static TextStyle get button => const TextStyle(
        fontSize: 13,
        height: 1.0,
        fontWeight: FontWeight.w800,
      );
}

