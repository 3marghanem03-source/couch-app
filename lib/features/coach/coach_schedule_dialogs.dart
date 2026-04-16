import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../models/booking_status.dart'; // displayLabel extension
import '../../models/slot_status.dart';
import '../../models/time_slot.dart';

/// Coach-only slot taps (block / unblock / view booking).
Future<void> showCoachSlotActions(
  BuildContext context, {
  required int weekdayIndex,
  required TimeSlot slot,
}) async {
  if (slot.status == SlotStatus.available) {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _Sheet(
        title: slot.time,
        body: const Text('This slot is open. You can block it so clients cannot book.'),
        primaryLabel: 'Block slot',
        onPrimary: () async {
          await appState.blockSlot(weekdayIndex: weekdayIndex, timeKey: slot.timeKey);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
    return;
  }

  if (slot.status == SlotStatus.blocked) {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _Sheet(
        title: slot.time,
        body: const Text('This slot is blocked.'),
        primaryLabel: 'Unblock',
        onPrimary: () async {
          await appState.unblockSlot(weekdayIndex: weekdayIndex, timeKey: slot.timeKey);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
    return;
  }

  final booking = appState.bookingById(slot.bookingId);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(slot.time, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (booking == null)
              const Text('Booking details not found.')
            else ...[
              Text('Client: ${booking.clientName}'),
              const SizedBox(height: 4),
              Text('Status: ${booking.status.displayLabel}'),
            ],
            const SizedBox(height: 16),
            OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      ),
    ),
  );
}

class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final String title;
  final Widget body;
  final String primaryLabel;
  final Future<void> Function() onPrimary;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            body,
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await onPrimary();
              },
              child: Text(primaryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
