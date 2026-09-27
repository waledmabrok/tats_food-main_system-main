import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_button.dart';

/// رأس لوحة التحكم — يعرض تحية + وصف + الإجراءات السريعة
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ─── التحية والوصف ────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(AppStrings.dashboardTitle, style: AppTypography.headlineMedium),
                    const SizedBox(width: AppDimensions.space8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.space8,
                        vertical: AppDimensions.space2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      ),
                      child: Text(
                        AppStrings.dashboardToday,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.space4),
                Text(AppStrings.dashboardSubtitle, style: AppTypography.bodySmall),
              ],
            ),
          ),

          // ─── الإجراءات السريعة ────────────────────────────────────
          Row(
            children: [
              AppButton(
                label: AppStrings.quickActionNewOrder,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.md,
                prefixIcon: Icons.add_rounded,
                onPressed: () {},
                tooltip: 'إنشاء طلب جديد من شاشة الكاشير',
              ),
              const SizedBox(width: AppDimensions.space8),
              AppButton(
                label: AppStrings.btnRefresh,
                variant: AppButtonVariant.outlined,
                size: AppButtonSize.md,
                prefixIcon: Icons.refresh_rounded,
                onPressed: () {},
                tooltip: 'تحديث البيانات',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
