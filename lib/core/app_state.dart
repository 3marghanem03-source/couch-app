import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../models/booking.dart';
import '../models/time_slot.dart';
import '../models/user.dart';
import '../models/user_role.dart';
import '../services/auth/auth_service.dart';
import '../services/booking/booking_service.dart';
import '../services/schedule/schedule_calendar.dart';
import '../services/schedule/schedule_service.dart';
import '../services/notifications/in_app_notification_service.dart';
import 'app_navigator.dart';
import 'app_routes.dart';
import 'config/app_config.dart';

/// Global session: Supabase auth + schedule + bookings.
final AppState appState = AppState();

class AppState extends ChangeNotifier {
  AppState();

  final AuthService authService = AuthService();
  final ScheduleService scheduleService = ScheduleService();
  final BookingService bookingService = BookingService();
  final InAppNotificationService notificationService = InAppNotificationService();

  User? currentUser;
  List<User> _clients = [];
  int _unreadNotifications = 0;
  Locale _locale = const Locale('en');

  bool isRefreshing = false;

  List<User> get coaches => []; // use Supabase queries if you add multi-coach UI
  List<User> get clients => List.unmodifiable(_clients);

  List<Booking> get bookings => bookingService.bookings;

  List<Booking> pendingRequests() => bookingService.pending();

  List<Booking> bookingsForClient(String clientId) => bookingService.forClientSorted(clientId);

  int get unreadNotifications => _unreadNotifications;

  Locale get locale => _locale;

  void toggleLanguage() {
    _locale = (_locale.languageCode.toLowerCase() == 'ar') ? const Locale('en') : const Locale('ar');
    notifyListeners();
  }

  Map<int, List<TimeSlot>> get scheduleByWeekday => scheduleService.scheduleByWeekday;

  List<TimeSlot> slotsForDay(int weekdayIndex) => scheduleService.slotsForDay(weekdayIndex);

  void init() {
    scheduleService.resetEmpty();
    bookingService.clear();
    _clients = [];
  }

  static const Duration _networkTimeout = Duration(seconds: 25);

  /// Restores Supabase session + data. Call **after** the first frame (see `main.dart`) so the splash does not hang.
  Future<void> recoverSessionIfAny() async {
    try {
      final u = await authService.getCurrentUser().timeout(_networkTimeout);
      if (u == null) return;
      currentUser = u;
      await refreshAll().timeout(_networkTimeout);
      notifyListeners();
      // Jump past login once navigator exists.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        final ctx = appNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted && currentUser != null) {
          AppRoutes.replaceWithRoleHome(ctx, currentUser!.role);
        }
      });
    } catch (e, st) {
      debugPrint('recoverSessionIfAny: $e\n$st');
    }
  }

  Future<String?> _coachIdForClient() async {
    if (AppConfig.defaultCoachId.isNotEmpty) return AppConfig.defaultCoachId;
    final linked = currentUser?.coachId;
    if (linked != null && linked.isNotEmpty) return linked;
    return authService.fetchFirstCoachId();
  }

  Future<void> refreshSchedule() async {
    if (currentUser == null) return;
    if (currentUser!.role == UserRole.coach) {
      await scheduleService.getAvailableSlots(coachId: currentUser!.id, coachView: true);
    } else {
      final cid = await _coachIdForClient();
      if (cid == null) {
        scheduleService.resetEmpty();
      } else {
        await scheduleService.getAvailableSlots(coachId: cid, coachView: false);
      }
    }
  }

  Future<void> refreshBookings() async {
    if (currentUser == null) return;
    if (currentUser!.role == UserRole.coach) {
      final list = await bookingService.getBookingsForCoach(currentUser!.id);
      bookingService.replaceAll(list);
      _clients = await authService.listClients();
    } else {
      final list = await bookingService.getBookingsForClient(currentUser!.id);
      bookingService.replaceAll(list);
    }
  }

  Future<void> refreshAll() async {
    isRefreshing = true;
    notifyListeners();
    try {
      await refreshSchedule();
      await refreshBookings();
      _unreadNotifications = await notificationService.countUnread();
    } finally {
      isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await authService.signIn(email: email, password: password);
    currentUser = await authService.getCurrentUser();
    if (currentUser == null) {
      throw StateError('Your account is missing a profile. Please create an account first, then sign in.');
    }
    await refreshAll();
    notifyListeners();
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    String? coachCode,
  }) async {
    await authService.signUpWithProfile(
      email: email,
      password: password,
      name: name,
      role: role,
      coachCode: coachCode,
    );
    currentUser = await authService.getCurrentUser();
    await refreshAll();
    notifyListeners();
  }

  Future<void> logout() async {
    await authService.signOut();
    currentUser = null;
    init();
    notifyListeners();
  }

  Booking? bookingById(String? id) => bookingService.byId(id);

  Future<void> approveBookingAsync(String bookingId) async {
    await bookingService.approveBooking(bookingId);
    await refreshAll();
  }

  Future<void> rejectBookingAsync(String bookingId) async {
    await bookingService.rejectBooking(bookingId);
    await refreshAll();
  }

  Future<void> blockSlot({
    required int weekdayIndex,
    required String timeKey,
  }) async {
    if (currentUser?.role != UserRole.coach) return;
    final date = ScheduleCalendar.dateForWeekdayIndex(weekdayIndex);
    await scheduleService.blockTime(coachId: currentUser!.id, date: date, timeKey: timeKey);
    await refreshSchedule();
    notifyListeners();
  }

  Future<void> unblockSlot({
    required int weekdayIndex,
    required String timeKey,
  }) async {
    if (currentUser?.role != UserRole.coach) return;
    final date = ScheduleCalendar.dateForWeekdayIndex(weekdayIndex);
    await scheduleService.unblockTime(coachId: currentUser!.id, date: date, timeKey: timeKey);
    await refreshSchedule();
    notifyListeners();
  }

  Future<void> bookSessionAsync({
    required int weekdayIndex,
    required String timeKey,
    TimeSlot? slot,
  }) async {
    final user = currentUser;
    if (user == null || user.role != UserRole.client) return;

    final coachId = await _coachIdForClient();
    if (coachId == null) {
      throw StateError('No coach is set up yet. Create a coach account first, then try again.');
    }

    final key = slot?.timeKey ?? timeKey;
    final date = ScheduleCalendar.dateForWeekdayIndex(weekdayIndex);
    await bookingService.createBooking(
      clientId: user.id,
      coachId: coachId,
      date: date,
      timeKey: key,
    );
    await refreshAll();
  }
}
