import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../models/booking.dart';
import '../../models/booking_status.dart';
import '../../widgets/booking_card.dart';
import '../../widgets/empty_state_widget.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final user = appState.currentUser;
        if (user == null) {
          return const Scaffold(body: Center(child: Text('Not signed in.')));
        }

        final mine = appState.bookingsForClient(user.id);

        Widget buildSection(String title, List<Booking> items) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (items.isEmpty)
                const EmptyStateWidget(
                  message: 'None',
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                )
              else
                ...items.map((b) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: BookingCard(
                      booking: b,
                      trailing: Text(
                        b.status.displayLabel,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  );
                }),
            ],
          );
        }

        final pending = mine.where((b) => b.status == BookingStatus.pending).toList();
        final confirmed = mine.where((b) => b.status == BookingStatus.approved).toList();
        final rejected = mine.where((b) => b.status == BookingStatus.rejected).toList();

        return Scaffold(
          appBar: AppBar(title: const Text('My bookings')),
          body: ListView(
            children: [
              buildSection('Pending', pending),
              buildSection('Confirmed', confirmed),
              buildSection('Rejected', rejected),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
