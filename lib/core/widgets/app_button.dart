import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';

/// أنواع الزر
enum AppButtonVariant { primary, secondary, outlined, ghost, danger }

/// حجم الزر
enum AppButtonSize { sm, md, lg }

/// زر مشترك يُستخدم في جميع أنحاء النظام
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.prefixIcon,
    this.suffixIcon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool isLoading;
  final bool isFullWidth;
  final String? tooltip;

  bool get _isDisabled => onPressed == null || isLoading;

  double get _height {
    return switch (size) {
      AppButtonSize.sm => AppDimensions.buttonHeightSm,
      AppButtonSize.md => AppDimensions.buttonHeightMd,
      AppButtonSize.lg => AppDimensions.buttonHeightLg,
    };
  }

  EdgeInsets get _padding {
    return switch (size) {
      AppButtonSize.sm => const EdgeInsets.symmetric(horizontal: AppDimensions.space12, vertical: AppDimensions.space6),
      AppButtonSize.md => const EdgeInsets.symmetric(horizontal: AppDimensions.space20, vertical: AppDimensions.space10),
      AppButtonSize.lg => const EdgeInsets.symmetric(horizontal: AppDimensions.space24, vertical: AppDimensions.space12),
    };
  }

  double get _fontSize {
    return switch (size) {
      AppButtonSize.sm => 12,
      AppButtonSize.md => 14,
      AppButtonSize.lg => 15,
    };
  }

  @override
  Widget build(BuildContext context) {
    final Widget btn = switch (variant) {
      AppButtonVariant.primary => _buildElevated(
          bg: _isDisabled ? AppColors.primary.withValues(alpha: 0.5) : AppColors.primary,
          fg: AppColors.textOnPrimary,
        ),
      AppButtonVariant.secondary => _buildElevated(
          bg: _isDisabled ? AppColors.primaryLight.withValues(alpha: 0.5) : AppColors.primaryLight,
          fg: AppColors.textOnPrimary,
        ),
      AppButtonVariant.outlined => _buildOutlined(),
      AppButtonVariant.ghost => _buildGhost(),
      AppButtonVariant.danger => _buildElevated(
          bg: _isDisabled ? AppColors.error.withValues(alpha: 0.5) : AppColors.error,
          fg: AppColors.textOnPrimary,
        ),
    };

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }

  Widget _buildContent() {
    final iconSize = size == AppButtonSize.sm ? AppDimensions.iconSm : AppDimensions.iconMd;
    if (isLoading) {
      return SizedBox(
        width: iconSize,
        height: iconSize,
        child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    }
    return Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (prefixIcon != null) ...[
          Icon(prefixIcon, size: iconSize),
          SizedBox(width: size == AppButtonSize.sm ? AppDimensions.space4 : AppDimensions.space8),
        ],
        Text(label, style: AppTypography.button.copyWith(fontSize: _fontSize)),
        if (suffixIcon != null) ...[
          SizedBox(width: size == AppButtonSize.sm ? AppDimensions.space4 : AppDimensions.space8),
          Icon(suffixIcon, size: iconSize),
        ],
      ],
    );
  }

  Widget _buildElevated({required Color bg, required Color fg}) {
    return SizedBox(
      height: _height,
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: _isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          padding: _padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          disabledBackgroundColor: bg.withValues(alpha: 0.5),
          disabledForegroundColor: fg.withValues(alpha: 0.7),
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildOutlined() {
    return SizedBox(
      height: _height,
      width: isFullWidth ? double.infinity : null,
      child: OutlinedButton(
        onPressed: _isDisabled ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: _padding,
          side: BorderSide(
            color: _isDisabled ? AppColors.border : AppColors.primary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildGhost() {
    return SizedBox(
      height: _height,
      width: isFullWidth ? double.infinity : null,
      child: TextButton(
        onPressed: _isDisabled ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: _padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
        ),
        child: _buildContent(),
      ),
    );
  }
}
