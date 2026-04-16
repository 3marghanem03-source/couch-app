import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('ar')];

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final v = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(v != null, 'AppLocalizations not found in context');
    return v!;
  }

  bool get isArabic => locale.languageCode.toLowerCase() == 'ar';

  String t(String key) {
    final lang = isArabic ? _ar : _en;
    return lang[key] ?? _en[key] ?? key;
  }

  static const Map<String, String> _en = {
    'lang.en': 'EN',
    'lang.ar': 'AR',
    'common.save': 'Save',
    'common.saving': 'Saving…',
    'common.loading': 'Loading…',
    'common.cancel': 'Cancel',
    'common.delete': 'Delete',
    'common.add': 'Add',
    'auth.login': 'Login',
    'auth.signup': 'Sign up',
    'coach.schedule': 'My schedule',
    'client.home': 'Home',
    'client.book': 'Book a session',
    'client.book.title': 'Book a session',
    'client.book.pick': 'Choose a day, then an open slot.',
    'client.book.button': 'Book session',
    'client.book.buttoning': 'Booking…',
    'client.book.sent': 'Request sent — pending coach approval.',
    'client.myBookings': 'My bookings',
    'common.logout': 'Log out',
    'profile.title': 'Profile',
    'notifications.title': 'Notifications',
    'coach.client': 'Client',
    'coach.clientVisible': 'Client-visible info',
    'coach.coachOnlyNotes': 'Coach-only notes',
    'coach.privateNotes': 'Private notes',
    'coach.tableTitle': 'Coach-only table',
    'coach.table.empty': 'No rows yet.',
    'coach.table.addRow': 'Add row',
    'coach.table.editRow': 'Edit row',
    'coach.table.date': 'Date (YYYY-MM-DD)',
    'coach.table.colDate': 'Date',
    'coach.table.colTitle': 'Title',
    'coach.table.colValue': 'Value',
    'coach.table.colNotes': 'Notes',
  };

  static const Map<String, String> _ar = {
    'lang.en': 'EN',
    'lang.ar': 'AR',
    'common.save': 'حفظ',
    'common.saving': 'جارٍ الحفظ…',
    'common.loading': 'جارٍ التحميل…',
    'common.cancel': 'إلغاء',
    'common.delete': 'حذف',
    'common.add': 'إضافة',
    'auth.login': 'تسجيل الدخول',
    'auth.signup': 'إنشاء حساب',
    'coach.schedule': 'جدولي',
    'client.home': 'الرئيسية',
    'client.book': 'حجز جلسة',
    'client.book.title': 'حجز جلسة',
    'client.book.pick': 'اختر اليوم ثم الوقت المتاح.',
    'client.book.button': 'حجز الجلسة',
    'client.book.buttoning': 'جارٍ الحجز…',
    'client.book.sent': 'تم إرسال الطلب — بانتظار موافقة الكوتش.',
    'client.myBookings': 'حجوزاتي',
    'common.logout': 'تسجيل الخروج',
    'profile.title': 'الملف الشخصي',
    'notifications.title': 'الإشعارات',
    'coach.client': 'عميل',
    'coach.clientVisible': 'معلومات يراها العميل',
    'coach.coachOnlyNotes': 'ملاحظات للكوتش فقط',
    'coach.privateNotes': 'ملاحظات خاصة',
    'coach.tableTitle': 'جدول للكوتش فقط',
    'coach.table.empty': 'لا يوجد بيانات بعد.',
    'coach.table.addRow': 'إضافة صف',
    'coach.table.editRow': 'تعديل الصف',
    'coach.table.date': 'التاريخ (YYYY-MM-DD)',
    'coach.table.colDate': 'التاريخ',
    'coach.table.colTitle': 'العنوان',
    'coach.table.colValue': 'القيمة',
    'coach.table.colNotes': 'ملاحظات',
  };
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ar'].contains(locale.languageCode.toLowerCase());

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

