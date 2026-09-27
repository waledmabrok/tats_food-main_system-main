import '../../models/app_user.dart';

/// خدمة الجلسة — تحتفظ بالمستخدم الحالي في الذاكرة طوال فترة تشغيل البرنامج
/// Logout يمسح الجلسة فقط ولا يحذف أي بيانات
class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  AppUser? _currentUser;

  AppUser? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;

  bool get isOwner => _currentUser?.isManager ?? false;

  bool get isCashier => _currentUser?.role == UserRole.cashier;

  void login(AppUser user) {
    _currentUser = user;
  }

  void logout() {
    _currentUser = null;
  }
}
