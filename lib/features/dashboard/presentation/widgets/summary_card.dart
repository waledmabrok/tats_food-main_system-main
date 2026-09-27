import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/constants/app_strings.dart';

/// بيانات كارت الإحصائيات
class SummaryCardData {
  const SummaryCardData({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    this.trend,
    this.trendPositive,
  });

  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final String? trend;
  final bool? trendPositive;
}

/// كارت إحصائية للـ Dashboard
/// يعرض: العنوان + الرقم + الأيقونة + اتجاه التغيير
class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.data});

  final SummaryCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: AppDimensions.shadowBlur,
            offset: Offset(0, AppDimensions.shadowOffset),
          ),
        ],

      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── الصف العلوي: العنوان + الأيقونة ─────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.title, style: AppTypography.bodySmall),
                    const SizedBox(height: AppDimensions.space8),

                    // ─── الرقم الرئيسي ──────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          data.value,
                          style: AppTypography.statNumber.copyWith(color: AppColors.textPrimary),
                        ),
                        const SizedBox(width: AppDimensions.space4),
                        Text(
                          data.unit,
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ─── أيقونة الكارت ──────────────────────────────────────
              Container(
                width: AppDimensions.summaryCardIconSize,
                height: AppDimensions.summaryCardIconSize,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Icon(data.icon, color: data.color, size: AppDimensions.iconXl),
              ),
            ],
          ),

          // ─── اتجاه التغيير ─────────────────────────────────────────
          if (data.trend != null) ...[
            const SizedBox(height: AppDimensions.space12),
            const Divider(height: 1),
            const SizedBox(height: AppDimensions.space10),
            Row(
              children: [
                Icon(
                  data.trendPositive == true
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: AppDimensions.iconSm,
                  color: data.trendPositive == true ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: AppDimensions.space4),
                Text(
                  data.trend!,
                  style: AppTypography.caption.copyWith(
                    color: data.trendPositive == true ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: AppDimensions.space4),
                Text(
                  AppStrings.statComparedYesterday,
                  style: AppTypography.caption,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
