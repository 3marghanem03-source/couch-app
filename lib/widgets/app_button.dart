import 'package:flutter/material.dart';

import 'primary_button.dart';
import 'secondary_button.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return SecondaryButton(label: label, onPressed: onPressed);
    }
    return PrimaryButton(label: label, onPressed: onPressed);
  }
}
