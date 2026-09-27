import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';
import '../constants/app_strings.dart';
import '../services/restaurant_info_service.dart';
import '../services/session_service.dart';

/// الشريط العلوي للنظام — Dark Professional
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.action,
    this.onBack,
  });

  final String title;
  final Widget? action;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(AppDimensions.topBarHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimensions.topBarHeight,
      decoration: BoxDecoration(
        color: AppColors.topBarBg,
        border: Border(
          bottom: BorderSide(color: AppColors.topBarBorder, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space24),
      child: Row(
        children: [
          // ─── عنوان الصفحة ─────────────────────────────────────────
          Expanded(
            child: Row(
              children: [
                if (onBack != null) ...[
                  IconButton(
                    tooltip: AppStrings.btnBack,
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppDimensions.space4),
                ],
                // خط ملوّن للعنوان
                Container(
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusFull),
                  ),
                ),
                const SizedBox(width: AppDimensions.space12),
                Text(
                  title,
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          // ─── معلومات على اليسار ───────────────────────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (action != null) ...[
                action!,
                const SizedBox(width: AppDimensions.space8),
              ],
              // التاريخ الحالي
              _DateChip(),

              const SizedBox(width: AppDimensions.space8),

              // الإشعارات
              Tooltip(
                message: AppStrings.topBarNotifications,
                child: _NotificationButton(),
              ),

              const SizedBox(width: AppDimensions.space8),

              // فاصل
              Container(
                width: 1,
                height: 24,
                color: AppColors.border,
              ),

              const SizedBox(width: AppDimensions.space16),

              // معلومات المستخدم
              _UserChip(),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationButton extends StatefulWidget {
  const _NotificationButton();

  @override
  State<_NotificationButton> createState() => _NotificationButtonState();
}

class _NotificationButtonState extends State<_NotificationButton> {
  int _count = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final products = await DatabaseHelper.instance.rawQuery(
      'SELECT COUNT(*) AS count FROM products WHERE is_active = 1 AND min_stock > 0 AND stock <= min_stock',
    );
    final shift = await DatabaseHelper.instance.getCurrentShift();
    if (mounted) {
      setState(() {
        _count =
            (products.first['count'] as num).toInt() + (shift == null ? 0 : 1);
        _loading = false;
      });
    }
  }

  Future<void> _openNotifications() async {
    final products = await DatabaseHelper.instance.rawQuery(
      'SELECT name, stock, unit, min_stock FROM products WHERE is_active = 1 AND min_stock > 0 AND stock <= min_stock ORDER BY stock ASC',
    );
    final shift = await DatabaseHelper.instance.getCurrentShift();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.notifications_active_outlined, color: AppColors.primary),
            const SizedBox(width: AppDimensions.space8),
            Text(AppStrings.topBarNotifications,
                style: AppTypography.titleLarge),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: products.isEmpty && shift == null
              ? const Padding(
                  padding:
                      EdgeInsets.symmetric(vertical: AppDimensions.space24),
                  child: Text('لا توجد إشعارات جديدة'),
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    if (shift != null)
                      ListTile(
                        leading: Icon(Icons.point_of_sale_outlined,
                            color: AppColors.success),
                        title: const Text('يوجد شيفت مفتوح'),
                        subtitle: Text('المسؤول: ${shift['user_name']}'),
                      ),
                    for (final product in products)
                      ListTile(
                        leading: Icon(Icons.warning_amber_rounded,
                            color: AppColors.warning),
                        title: Text('مخزون منخفض: ${product['name']}'),
                        subtitle: Text(
                          'المتاح: ${product['stock']} ${product['unit']} - الحد الأدنى: ${product['min_stock']}',
                        ),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _loadCount();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('تحديث'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(AppStrings.btnClose),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _TopBarIconButton(
          icon: _loading || _count == 0
              ? Icons.notifications_none_rounded
              : Icons.notifications_active_rounded,
          onTap: _openNotifications,
        ),
        if (_count > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _count > 9 ? '9+' : '$_count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Date Chip ──────────────────────────────────────────────────────────────
class _DateChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formatted = _formatArabicDate(now);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space12,
        vertical: AppDimensions.space6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: AppDimensions.iconSm,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppDimensions.space6),
          Text(
            formatted,
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatArabicDate(DateTime date) {
    const weekdays = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد'
    ];
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    return '$weekday، ${date.day} $month ${date.year}';
  }
}

// ─── User Chip ──────────────────────────────────────────────────────────────

class _UserChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = SessionService.instance.currentUser;
    final isManager = user?.isManager ?? false;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // دور المستخدم
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space10,
            vertical: AppDimensions.space4,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Text(
            isManager ? AppStrings.roleManager : AppStrings.roleCashier,
            style: AppTypography.caption.copyWith(
              color: AppColors.primaryLight,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.space10),
        // أيقونة المستخدم
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Icon(
            Icons.person_rounded,
            size: AppDimensions.iconMd,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppDimensions.space10),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user?.name ?? AppStrings.currentUser,
              style: AppTypography.titleSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            ValueListenableBuilder<String>(
              valueListenable: RestaurantInfoService.instance.restaurantName,
              builder: (context, name, child) {
                return Text(
                  name.isEmpty ? AppStrings.appName : name,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Icon Button ────────────────────────────────────────────────────────────
class _TopBarIconButton extends StatefulWidget {
  const _TopBarIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_TopBarIconButton> createState() => _TopBarIconButtonState();
}

class _TopBarIconButtonState extends State<_TopBarIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceVariant : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            border: _isHovered ? Border.all(color: AppColors.border) : null,
          ),
          child: Icon(
            widget.icon,
            size: AppDimensions.iconLg,
            color: _isHovered ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
