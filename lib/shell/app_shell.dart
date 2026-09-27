import 'package:flutter/material.dart';
import '../core/routing/app_router.dart';
import '../core/widgets/app_sidebar.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/services/session_service.dart';
import '../repositories/user_repository.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/cashier/presentation/screens/cashier_screen.dart';
import '../models/app_user.dart';

/// الـ Shell الرئيسي للتطبيق
/// Owner → يرى الـ Sidebar الكامل + كل الشاشات
/// Cashier → يرى POS فقط بدون Sidebar
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.user});

  final AppUser user;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String _currentRoute = AppRoutes.dashboard;

  @override
  void initState() {
    super.initState();
    if (!widget.user.isManager) {
      _currentRoute = AppRoutes.cashier;
    }
  }

  void _onRouteSelected(String route) {
    if (!widget.user.isManager) return;
    if (_currentRoute == route) return;
    setState(() => _currentRoute = route);
  }

  void _logout() {
    SessionService.instance.logout();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ─── واجهة الكاشير (POS فقط، بدون Sidebar) ─────────────────────
    if (!widget.user.isManager) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _CashierTopBar(
              userName: widget.user.name,
              onLogout: _logout,
              onChangePassword: () => _showChangePasswordDialog(),
            ),
            const Expanded(child: CashierScreen()),
          ],
        ),
      );
    }

    // ─── واجهة المالك (النظام الكامل) ───────────────────────────────
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        color: AppColors.background,
        child: Row(
          children: [
            // ─── الـ Sidebar على اليمين (RTL) ───────────────────────
            AppSidebar(
              currentRoute: _currentRoute,
              onRouteSelected: _onRouteSelected,
              user: widget.user,
              onLogout: _logout,
            ),

            // ─── فاصل عمودي ──────────────────────────────────────────
            Container(width: 1, color: AppColors.borderLight),

            // ─── المحتوى الرئيسي ──────────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: KeyedSubtree(
                  key: ValueKey(_currentRoute),
                  child: buildRouteWidget(_currentRoute),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ChangePasswordDialog(user: widget.user),
    );
  }
}

// ─── شريط الكاشير العلوي ───────────────────────────────────────────────────
class _CashierTopBar extends StatelessWidget {
  const _CashierTopBar({
    required this.userName,
    required this.onLogout,
    required this.onChangePassword,
  });

  final String userName;
  final VoidCallback onLogout;
  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.topBarBg,
        border: Border(bottom: BorderSide(color: AppColors.topBarBorder)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              'assets/images/logo.png',
              width: 28,
              height: 28,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${AppStrings.appName} — ${AppStrings.navCashier}',
            style: AppTypography.titleSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),

          const Spacer(),

          Icon(Icons.person_rounded, color: AppColors.textSecondary, size: 18),

          const SizedBox(width: 6),
          Text(
            userName,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'كاشير',
              style: AppTypography.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(width: 16),

          IconButton(
            tooltip: 'تغيير كلمة المرور',
            onPressed: onChangePassword,
            icon: const Icon(Icons.lock_reset_rounded),
            color: AppColors.textSecondary,
          ),

          TextButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: const Text('خروج'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.user});

  final AppUser user;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _repo = UserRepository();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_next.text.trim().length < 4 ||
        _next.text.trim() != _confirm.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('كلمة المرور الجديدة غير صحيحة أو غير متطابقة')),
      );
      return;
    }
    setState(() => _saving = true);
    final changed = await _repo.changePin(
      userId: widget.user.id,
      currentPin: _current.text.trim(),
      newPin: _next.text.trim(),
    );
    if (!mounted) return;
    if (changed) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح')),
      );
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كلمة المرور الحالية غير صحيحة')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تغيير كلمة المرور'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: _current,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'كلمة المرور الحالية')),
          TextField(
              controller: _next,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'كلمة المرور الجديدة')),
          TextField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'تأكيد كلمة المرور الجديدة')),
        ],
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('إلغاء')),
        ElevatedButton(
            onPressed: _saving ? null : _save, child: const Text('حفظ')),
      ],
    );
  }
}
