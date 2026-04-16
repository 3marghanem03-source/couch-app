import 'package:flutter/material.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({
    super.key,
    this.blocking = true,
    this.message,
  });

  final bool blocking;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final overlay = ColoredBox(
      color: const Color(0x33000000),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(message!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );

    if (!blocking) return overlay;
    return AbsorbPointer(child: overlay);
  }
}

