enum BookingStatus { pending, approved, rejected }

extension BookingStatusLabel on BookingStatus {
  /// UI copy (approved → “Confirmed”).
  String get displayLabel => switch (this) {
        BookingStatus.pending => 'Pending',
        BookingStatus.approved => 'Confirmed',
        BookingStatus.rejected => 'Rejected',
      };
}
