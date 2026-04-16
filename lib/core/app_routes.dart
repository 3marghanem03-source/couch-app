import 'package:flutter/material.dart';

import '../features/auth/login_screen.dart';
import '../features/booking/my_bookings_screen.dart';
import '../features/client/client_booking_screen.dart';
import '../features/client/client_home_screen.dart';
import '../features/coach/coach_dashboard_screen.dart';
import '../features/coach/coach_schedule_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/profile/profile_screen.dart';
import '../models/user_role.dart';

/// All named routes in one place so paths are not duplicated across the app.
abstract final class AppRoutes {
  static const login = '/';
  static const coachDashboard = '/coach/dashboard';
  static const coachSchedule = '/coach/schedule';
  static const clientHome = '/client/home';
  static const clientBook = '/client/book';
  static const clientBookings = '/client/bookings';
  static const notifications = '/notifications';
  static const profile = '/profile';

  static Map<String, WidgetBuilder> materialRoutes() => {
        login: (_) => const LoginScreen(),
        coachDashboard: (_) => const CoachDashboardScreen(),
        coachSchedule: (_) => const CoachScheduleScreen(),
        clientHome: (_) => const ClientHomeScreen(),
        clientBook: (_) => const ClientBookingScreen(),
        clientBookings: (_) => const MyBookingsScreen(),
        notifications: (_) => const NotificationsScreen(),
        profile: (_) => const ProfileScreen(),
      };

  /// After login, go to the correct home for the role.
  static void replaceWithRoleHome(BuildContext context, UserRole role) {
    Navigator.pushReplacementNamed(
      context,
      role == UserRole.coach ? coachDashboard : clientHome,
    );
  }

  static void replaceWithLogin(BuildContext context) {
    Navigator.pushReplacementNamed(context, login);
  }
}
