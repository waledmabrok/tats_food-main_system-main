import 'package:flutter/material.dart';
import '../../../../core/services/session_service.dart';
import '../../../../models/app_user.dart';

/// يلف أي Widget ويظهره بس لو المستخدم الحالي (owner/manager)
/// لو مش مدير: يظهر [fallback] أو حاجة فاضية.
///
/// استخدام سريع للتحقق من الصلاحية داخل أي دالة (مش بس widget):
///   if (ManagerOnly.isManager) { ... }
class ManagerOnly extends StatelessWidget {
  const ManagerOnly({super.key, required this.child, this.fallback});

  final Widget child;
  final Widget? fallback;

  /// عدّل هنا لو اسم الـ getter في SessionService مختلف (مثلاً .user بدل .currentUser)
  static AppUser? get _currentUser => SessionService.instance.currentUser;

  static bool get isManager => _currentUser?.role == UserRole.manager;

  @override
  Widget build(BuildContext context) {
    if (isManager) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

/// نفس الفكرة لكن كصفحة كاملة (Scaffold) — تستخدم كـ body لشاشة كاملة
/// لو حد وصل للشاشة من غير صلاحية (مثلاً بلينك مباشر) يشوف رسالة واضحة بدل ما ينهار.
class ManagerOnlyScreen extends StatelessWidget {
  const ManagerOnlyScreen({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (ManagerOnly.isManager) return child;
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'الشاشة دي متاحة للمدير فقط',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
