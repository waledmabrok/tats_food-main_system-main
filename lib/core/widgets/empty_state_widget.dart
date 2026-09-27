import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';

/// Empty State widget موحد يُستخدم في جميع أنحاء النظام
/// عند عدم وجود بيانات لعرضها
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.title,
    this.description,
    this.icon = Icons.inbox_outlined,
    this.iconColor,
    this.action,
    this.actionLabel,
    this.compact = false,
  });

  final String title;
  final String? description;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback? action;
  final String? actionLabel;

  /// النمط المضغوط لاستخدامه داخل الجداول أو الأقسام الصغيرة
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? AppColors.textDisabled;
    final iconContainerSize = compact ? 56.0 : 80.0;
    final iconSize = compact ? AppDimensions.iconXl : 40.0;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? AppDimensions.space24 : AppDimensions.space40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── الأيقونة ────────────────────────────────────────
            Container(
              width: iconContainerSize,
              height: iconContainerSize,
              decoration: BoxDecoration(
                color: effectiveIconColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              ),
              child: Icon(icon, size: iconSize, color: effectiveIconColor),
            ),

            SizedBox(height: compact ? AppDimensions.space12 : AppDimensions.space16),

            // ─── العنوان ─────────────────────────────────────────
            Text(
              title,
              style: compact ? AppTypography.titleMedium : AppTypography.titleLarge,
              textAlign: TextAlign.center,
            ),

            // ─── الوصف ───────────────────────────────────────────
            if (description != null) ...[
              SizedBox(height: compact ? AppDimensions.space4 : AppDimensions.space8),
              Text(
                description!,
                style: AppTypography.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // ─── الزر (اختياري) ──────────────────────────────────
            if (action != null && actionLabel != null) ...[
              SizedBox(height: compact ? AppDimensions.space16 : AppDimensions.space24),
              OutlinedButton.icon(
                onPressed: action,
                icon: const Icon(Icons.add, size: AppDimensions.iconMd),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty State مخصص لحالة عدم اتصال الشبكة أو الخطأ
class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    super.key,
    this.message,
    this.onRetry,
  });

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.error_outline_rounded,
      iconColor: AppColors.error,
      title: 'حدث خطأ ما',
      description: message ?? 'يرجى المحاولة مرة أخرى',
      action: onRetry,
      actionLabel: onRetry != null ? 'إعادة المحاولة' : null,
    );
  }
}
