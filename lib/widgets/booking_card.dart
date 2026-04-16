import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/booking.dart';

class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    this.leading,
    this.trailing,
  });

  final Booking booking;
  final Widget? leading;
  final Widget? trailing;

  static final DateFormat _df = DateFormat.MMMd();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: leading,
        title: Text('${_df.format(booking.date)} · ${booking.time}'),
        subtitle: booking.clientName.isEmpty ? null : Text(booking.clientName),
        trailing: trailing,
      ),
    );
  }
}

