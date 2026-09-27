import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';

/// كارت مشترك يُستخدم في جميع أنحاء النظام
/// يوفر مظهراً موحداً مع خيارات مرونة
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.borderColor,
    this.borderRadius,
    this.elevation,
    this.onTap,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;
  final double? borderRadius;
  final double? elevation;
  final VoidCallback? onTap;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppDimensions.radiusMd;
    final content =
        padding != null ? Padding(padding: padding!, child: child) : child;

    return Material(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: clipBehavior,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        hoverColor: onTap != null
            ? AppColors.primary.withValues(alpha: 0.03)
            : Colors.transparent,
        splashColor: onTap != null
            ? AppColors.primary.withValues(alpha: 0.06)
            : Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: borderColor ?? AppColors.borderLight,
              width: AppDimensions.borderWidth,
            ),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: AppDimensions.shadowBlur,
                offset: const Offset(0, AppDimensions.shadowOffset),
              ),
            ],
          ),
          child: content,
        ),
      ),
    );
  }
}

/// ─── App Card Section Header ────────────────────────────────────────────────
/// رأس القسم داخل الكارت مع عنوان وإجراء اختياري
class AppCardHeader extends StatelessWidget {
  const AppCardHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding,
    this.icon,
    this.iconColor,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(AppDimensions.cardPadding),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(AppDimensions.space8),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Icon(icon,
                  size: AppDimensions.iconMd,
                  color: iconColor ?? AppColors.primary),
            ),
            const SizedBox(width: AppDimensions.space12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: AppDimensions.space2),
                  Text(subtitle!, style: AppTypography.caption),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
