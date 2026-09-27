import 'package:flutter/material.dart';
import 'package:system_casher/core/constants/app_strings.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../repositories/user_repository.dart';
import '../../../../shell/app_shell.dart';

/// شاشة تسجيل الدخول — تظهر عند فتح البرنامج
/// Keyboard-friendly: Tab بين الحقول، Enter للدخول، Escape لمسح الخطأ
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userRepo = UserRepository();
  final _usernameFocus = FocusNode();
  final _pinFocus = FocusNode();
  final _usernameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  bool _isLoading = false;
  String? _errorMsg;
  bool _obscurePin = true;

  @override
  void initState() {
    super.initState();
    _usernameCtrl.text = 'cashier'; // القيمة الافتراضية
    // Focus تلقائي على حقل كلمة المرور لتسريع الدخول
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _usernameFocus.dispose();
    _pinFocus.dispose();
    _usernameCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameCtrl.text.trim();
    final pin = _pinCtrl.text.trim();

    if (username.isEmpty || pin.isEmpty) {
      setState(() => _errorMsg = 'يرجى إدخال اسم المستخدم وكلمة المرور');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final user = await _userRepo.authenticate(username, pin);
      if (!mounted) return;

      if (user != null) {
        SessionService.instance.login(user);
        // فتح شيفت تلقائي للكاشير بس — مش للأدمن/المالك
        if (user.role == 'cashier') {
          final currentShift = await DatabaseHelper.instance.getCurrentShift();
          if (currentShift == null) {
            await DatabaseHelper.instance.openShift(
              userId: user.id,
              userName: user.name,
              openingCash: 0,
            );
          }
        }
        // الانتقال إلى AppShell وإزالة LoginScreen من الـ Stack
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => AppShell(user: user)),
        );
      } else {
        setState(() {
          _errorMsg = 'اسم المستخدم أو كلمة المرور غير صحيحة';
          _isLoading = false;
        });
        // إعادة Focus على حقل كلمة المرور لتسهيل إعادة الإدخال
        _pinCtrl.clear();
        _pinFocus.requestFocus();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = 'حدث خطأ، يرجى المحاولة مرة أخرى';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: wide ? 56 : 16,
                vertical: wide ? 32 : 20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (wide ? 64 : 40),
                  maxWidth: 1180,
                ),
                child: wide
                    ? Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Expanded(child: _buildBrandPanel()),
                          const SizedBox(width: 44),
                          SizedBox(width: 430, child: _buildLoginCard()),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildCompactBrand(),
                          const SizedBox(height: 24),
                          _buildLoginCard(),
                        ],
                      ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBrandPanel() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLogo(size: 92),
          const SizedBox(height: 28),
          Text(
            AppStrings.appName,
            style: AppTypography.headlineLarge
                .copyWith(color: AppColors.textPrimary, fontSize: 40),
          ),
          const SizedBox(height: 8),
          Text(
            'كل طلب محسوب. كل شيفت واضح.',
            style:
                AppTypography.headlineSmall.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          Text(
            'نقطة تشغيل واحدة لإدارة المطعم، الكاشير، المخزون والمبيعات بدون تعقيد.',
            style: AppTypography.bodyLarge
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 36),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _FeatureBadge(
                  icon: Icons.point_of_sale_rounded, label: 'الكاشير'),
              _FeatureBadge(icon: Icons.inventory_2_outlined, label: 'المخزون'),
              _FeatureBadge(icon: Icons.assessment_outlined, label: 'التقارير'),
            ],
          ),
          const SizedBox(height: 34),
          Row(
            children: [
              Icon(Icons.lock_outline_rounded,
                  color: AppColors.success, size: 18),
              const SizedBox(width: 8),
              Text('بياناتك محفوظة محليًا وآمنة',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactBrand() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLogo(size: 58),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.appName,
                style: AppTypography.headlineSmall
                    .copyWith(color: AppColors.textPrimary)),
            Text('إدارة مطعمك بوضوح',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }

  Widget _buildLogo({required double size}) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('أهلاً بك',
              style: AppTypography.headlineSmall
                  .copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text('سجّل دخولك لبدء تشغيل المطعم', style: AppTypography.bodySmall),
          const SizedBox(height: 28),

          _LoginField(
            label: 'اسم المستخدم',
            hint: 'owner أو cashier',
            controller: _usernameCtrl,
            focusNode: _usernameFocus,
            icon: Icons.person_outline_rounded,
            onSubmitted: (_) => _pinFocus.requestFocus(),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _RoleCard(
                icon: Icons.admin_panel_settings_outlined,
                title: 'المالك',
                subtitle: 'إدارة كاملة',
                testLabel: '👤 المالك (Owner)',
                selected: _usernameCtrl.text == 'owner',
                onTap: () => setState(() => _usernameCtrl.text = 'owner'),
              )),
              const SizedBox(width: 8),
              Expanded(
                  child: _RoleCard(
                icon: Icons.point_of_sale_outlined,
                title: 'الكاشير',
                subtitle: 'نقطة البيع',
                testLabel: '💵 الكاشير (Cashier)',
                selected: _usernameCtrl.text == 'cashier',
                onTap: () => setState(() => _usernameCtrl.text = 'cashier'),
              )),
            ],
          ),
          const SizedBox(height: 22),

          // ─── كلمة المرور ──────────────────────────────
          _LoginField(
            label: 'كلمة المرور',
            hint: '••••••••',
            controller: _pinCtrl,
            focusNode: _pinFocus,
            icon: Icons.lock_outline_rounded,
            obscureText: _obscurePin,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePin
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: const Color(0xFF94A3B8),
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePin = !_obscurePin),
            ),
            onSubmitted: (_) => _login(),
            textInputAction: TextInputAction.done,
          ),

          if (_errorMsg != null) ...[
            const SizedBox(height: 16),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMsg!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'دخول',
                      style: AppTypography.button.copyWith(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  const _FeatureBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: AppColors.primary),
          const SizedBox(width: 7),
          Text(label,
              style: AppTypography.caption.copyWith(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.testLabel,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String testLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: testLabel,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(
                testLabel,
                style: const TextStyle(fontSize: 0, color: Colors.transparent),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: selected ? null : Border.all(color: AppColors.border),
                ),
                child: Icon(icon,
                    size: 19,
                    color: selected ? Colors.white : AppColors.textSecondary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700)),
                    Text(subtitle,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded,
                    size: 18, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── حقل إدخال مخصص للـ Login ────────────────────────────────────────────
class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.focusNode,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.onSubmitted,
    this.textInputAction = TextInputAction.next,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          cursorColor: AppColors.primary,
          obscureText: obscureText,
          textInputAction: textInputAction,
          style:
              AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: AppColors.textDisabled,
            ),
            prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.surfaceVariant,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
