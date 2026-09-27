import 'package:flutter/material.dart';
import 'theme_controller.dart';

/// نظام الألوان المركزي — يدعم الوضعين الداكن والفاتح بالكامل
abstract final class AppColors {
  /// التحقق من الوضع الحالي
  static bool get isDark => ThemeController.instance.isDark;

  // ─── الألوان الديناميكية تتغير تلقائياً مع الثيم ───────────────────────────
  static Color get primary => isDark ? dark.primary : light.primary;
  static Color get primaryLight => isDark ? dark.primaryLight : light.primaryLight;
  static Color get primaryDark => isDark ? dark.primaryDark : light.primaryDark;
  static Color get accent => isDark ? dark.accent : light.accent;

  static Color get background => isDark ? dark.background : light.background;
  static Color get surface => isDark ? dark.surface : light.surface;
  static Color get surfaceVariant => isDark ? dark.surfaceVariant : light.surfaceVariant;
  static Color get surfaceElevated => isDark ? dark.surfaceElevated : light.surfaceElevated;

  static Color get sidebarBg => isDark ? dark.sidebarBg : light.sidebarBg;
  static Color get sidebarItemActive => isDark ? dark.sidebarItemActive : light.sidebarItemActive;
  static Color get sidebarItemHover => isDark ? dark.sidebarItemHover : light.sidebarItemHover;
  static Color get sidebarText => isDark ? dark.sidebarText : light.sidebarText;
  static Color get sidebarTextActive => isDark ? dark.sidebarTextActive : light.sidebarTextActive;
  static Color get sidebarDivider => isDark ? dark.sidebarDivider : light.sidebarDivider;

  static Color get textPrimary => isDark ? dark.textPrimary : light.textPrimary;
  static Color get textSecondary => isDark ? dark.textSecondary : light.textSecondary;
  static Color get textDisabled => isDark ? dark.textDisabled : light.textDisabled;
  static Color get textOnPrimary => const Color(0xFFFFFFFF);
  static Color get textOnDark => const Color(0xFFF1F5F9);
  static Color get textOnSurface => isDark ? dark.textOnSurface : light.textOnSurface;

  static Color get success => const Color(0xFF10B981);
  static Color get successLight => isDark ? dark.successLight : light.successLight;
  static Color get successSurface => isDark ? dark.successSurface : light.successSurface;
  static Color get warning => const Color(0xFFF59E0B);
  static Color get warningLight => isDark ? dark.warningLight : light.warningLight;
  static Color get warningSurface => isDark ? dark.warningSurface : light.warningSurface;
  static Color get error => const Color(0xFFEF4444);
  static Color get errorLight => isDark ? dark.errorLight : light.errorLight;
  static Color get errorSurface => isDark ? dark.errorSurface : light.errorSurface;
  static Color get info => isDark ? dark.info : light.info;
  static Color get infoLight => isDark ? dark.infoLight : light.infoLight;

  static Color get border => isDark ? dark.border : light.border;
  static Color get borderLight => isDark ? dark.borderLight : light.borderLight;
  static Color get borderFocus => isDark ? dark.borderFocus : light.borderFocus;
  static Color get divider => isDark ? dark.divider : light.divider;

  static Color get topBarBg => isDark ? dark.topBarBg : light.topBarBg;
  static Color get topBarBorder => isDark ? dark.topBarBorder : light.topBarBorder;

  static Color get cardShadow => isDark ? dark.cardShadow : light.cardShadow;

  static Color get statSales => isDark ? dark.statSales : light.statSales;
  static Color get statOrders => const Color(0xFF10B981);
  static Color get statItems => const Color(0xFF8B5CF6);
  static Color get statStock => const Color(0xFFF59E0B);

  static Color get overlay => isDark ? dark.overlay : light.overlay;

  // ─── مصفوفات الألوان الثابتة ─────────────────────────────────────────────
  static const dark = _DarkColors();
  static const light = _LightColors();

  /// للتوافق مع استدعاءات AppColors.of(context)
  static _DarkColors of(BuildContext context) => isDark ? dark : const _LightAsAdapter();
  static const dk = dark;
}

/// ألوان الوضع الداكن — Dark Professional Theme (Royal Blue & Slate-900)
class _DarkColors {
  const _DarkColors();

  final Color primary = const Color(0xFF3B82F6);       // Blue-500
  final Color primaryLight = const Color(0xFF60A5FA);  // Blue-400
  final Color primaryDark = const Color(0xFF2563EB);   // Blue-600
  final Color accent = const Color(0xFFF59E0B);        // Amber-500

  final Color background = const Color(0xFF0F172A);     // Slate-900
  final Color surface = const Color(0xFF1E293B);        // Slate-800
  final Color surfaceVariant = const Color(0xFF334155); // Slate-700
  final Color surfaceElevated = const Color(0xFF263348); // بين 800 و 900

  final Color sidebarBg = const Color(0xFF0A111E);         // أغمق من background
  final Color sidebarItemActive = const Color(0xFF3B82F6); // Primary
  final Color sidebarItemHover = const Color(0xFF1E293B);  // Slate-800
  final Color sidebarText = const Color(0xFF94A3B8);       // Slate-400
  final Color sidebarTextActive = const Color(0xFFFFFFFF);
  final Color sidebarDivider = const Color(0xFF1E293B);    // Slate-800

  final Color textPrimary = const Color(0xFFF1F5F9);    // Slate-100
  final Color textSecondary = const Color(0xFF94A3B8);  // Slate-400
  final Color textDisabled = const Color(0xFF475569);   // Slate-600
  final Color textOnPrimary = const Color(0xFFFFFFFF);
  final Color textOnDark = const Color(0xFFF1F5F9);
  final Color textOnSurface = const Color(0xFFE2E8F0);  // Slate-200

  final Color success = const Color(0xFF10B981);       // Emerald-500
  final Color successLight = const Color(0xFF064E3B);  // Emerald-900
  final Color successSurface = const Color(0xFF065F46);
  final Color warning = const Color(0xFFF59E0B);       // Amber-500
  final Color warningLight = const Color(0xFF78350F);  // Amber-900
  final Color warningSurface = const Color(0xFF92400E);
  final Color error = const Color(0xFFEF4444);         // Red-500
  final Color errorLight = const Color(0xFF7F1D1D);    // Red-900
  final Color errorSurface = const Color(0xFF991B1B);
  final Color info = const Color(0xFF3B82F6);
  final Color infoLight = const Color(0xFF1E3A5F);

  final Color border = const Color(0xFF334155);       // Slate-700
  final Color borderLight = const Color(0xFF1E293B);  // Slate-800
  final Color borderFocus = const Color(0xFF3B82F6);  // Primary
  final Color divider = const Color(0xFF1E293B);      // Slate-800

  final Color topBarBg = const Color(0xFF0F172A);       // Slate-900
  final Color topBarBorder = const Color(0xFF1E293B);   // Slate-800

  final Color cardShadow = const Color(0x40000000);

  final Color statSales = const Color(0xFF3B82F6);   // Blue
  final Color statOrders = const Color(0xFF10B981);  // Emerald
  final Color statItems = const Color(0xFF8B5CF6);   // Violet
  final Color statStock = const Color(0xFFF59E0B);   // Amber

  final Color overlay = const Color(0xCC0A111E);
}

/// ألوان الوضع الفاتح — Light Clean Professional Theme (Vibrant Orange & Clean White)
class _LightColors {
  const _LightColors();

  final Color primary = const Color(0xFFEA580C);       // Orange-600
  final Color primaryLight = const Color(0xFFFB923C);  // Orange-400
  final Color primaryDark = const Color(0xFFC2410C);   // Orange-700
  final Color accent = const Color(0xFFF59E0B);        // Amber-500

  final Color background = const Color(0xFFF8FAFC);     // Slate-50
  final Color surface = const Color(0xFFFFFFFF);        // Pure White
  final Color surfaceVariant = const Color(0xFFF1F5F9); // Slate-100
  final Color surfaceElevated = const Color(0xFFFFFFFF);

  final Color sidebarBg = const Color(0xFFFFFFFF);
  final Color sidebarItemActive = const Color(0xFFEA580C);
  final Color sidebarItemHover = const Color(0xFFF8FAFC);
  final Color sidebarText = const Color(0xFF475569);       // Slate-600
  final Color sidebarTextActive = const Color(0xFFEA580C);
  final Color sidebarDivider = const Color(0xFFE2E8F0);    // Slate-200

  final Color textPrimary = const Color(0xFF0F172A);    // Slate-900
  final Color textSecondary = const Color(0xFF475569);  // Slate-600
  final Color textDisabled = const Color(0xFF94A3B8);   // Slate-400
  final Color textOnPrimary = const Color(0xFFFFFFFF);
  final Color textOnDark = const Color(0xFFF8FAFC);
  final Color textOnSurface = const Color(0xFF0F172A);

  final Color success = const Color(0xFF10B981);       // Emerald-500
  final Color successLight = const Color(0xFFECFDF5);  // Emerald-50
  final Color successSurface = const Color(0xFFD1FAE5);
  final Color warning = const Color(0xFFF59E0B);       // Amber-500
  final Color warningLight = const Color(0xFFFFFBEB);  // Amber-50
  final Color warningSurface = const Color(0xFFFEF3C7);
  final Color error = const Color(0xFFEF4444);         // Red-500
  final Color errorLight = const Color(0xFFFEF2F2);    // Red-50
  final Color errorSurface = const Color(0xFFFEE2E2);
  final Color info = const Color(0xFF2563EB);          // Blue-600
  final Color infoLight = const Color(0xFFEFF6FF);     // Blue-50

  final Color border = const Color(0xFFE2E8F0);       // Slate-200
  final Color borderLight = const Color(0xFFF1F5F9);  // Slate-100
  final Color borderFocus = const Color(0xFFEA580C);  // Orange-600
  final Color divider = const Color(0xFFE2E8F0);      // Slate-200

  final Color topBarBg = const Color(0xFFFFFFFF);
  final Color topBarBorder = const Color(0xFFE2E8F0);

  final Color cardShadow = const Color(0x0A0F172A);

  final Color statSales = const Color(0xFFEA580C);
  final Color statOrders = const Color(0xFF10B981);
  final Color statItems = const Color(0xFF8B5CF6);
  final Color statStock = const Color(0xFFF59E0B);

  final Color overlay = const Color(0x4D0F172A);
}

final class _LightAsAdapter extends _DarkColors {
  const _LightAsAdapter();

  @override Color get primary         => AppColors.light.primary;
  @override Color get primaryLight    => AppColors.light.primaryLight;
  @override Color get primaryDark     => AppColors.light.primaryDark;
  @override Color get accent          => AppColors.light.accent;

  @override Color get background      => AppColors.light.background;
  @override Color get surface         => AppColors.light.surface;
  @override Color get surfaceVariant  => AppColors.light.surfaceVariant;
  @override Color get surfaceElevated => AppColors.light.surfaceElevated;

  @override Color get sidebarBg         => AppColors.light.sidebarBg;
  @override Color get sidebarItemActive => AppColors.light.sidebarItemActive;
  @override Color get sidebarItemHover  => AppColors.light.sidebarItemHover;
  @override Color get sidebarText       => AppColors.light.sidebarText;
  @override Color get sidebarTextActive => AppColors.light.sidebarTextActive;
  @override Color get sidebarDivider    => AppColors.light.sidebarDivider;

  @override Color get textPrimary   => AppColors.light.textPrimary;
  @override Color get textSecondary => AppColors.light.textSecondary;
  @override Color get textDisabled  => AppColors.light.textDisabled;
  @override Color get textOnPrimary => AppColors.light.textOnPrimary;
  @override Color get textOnDark    => AppColors.light.textOnDark;
  @override Color get textOnSurface => AppColors.light.textOnSurface;

  @override Color get success        => AppColors.light.success;
  @override Color get successLight   => AppColors.light.successLight;
  @override Color get successSurface => AppColors.light.successSurface;
  @override Color get warning        => AppColors.light.warning;
  @override Color get warningLight   => AppColors.light.warningLight;
  @override Color get warningSurface => AppColors.light.warningSurface;
  @override Color get error          => AppColors.light.error;
  @override Color get errorLight     => AppColors.light.errorLight;
  @override Color get errorSurface   => AppColors.light.errorSurface;
  @override Color get info           => AppColors.light.info;
  @override Color get infoLight      => AppColors.light.infoLight;

  @override Color get border      => AppColors.light.border;
  @override Color get borderLight => AppColors.light.borderLight;
  @override Color get borderFocus => AppColors.light.borderFocus;
  @override Color get divider     => AppColors.light.divider;

  @override Color get topBarBg     => AppColors.light.topBarBg;
  @override Color get topBarBorder => AppColors.light.topBarBorder;

  @override Color get cardShadow => AppColors.light.cardShadow;

  @override Color get statSales  => AppColors.light.statSales;
  @override Color get statOrders => AppColors.light.statOrders;
  @override Color get statItems  => AppColors.light.statItems;
  @override Color get statStock  => AppColors.light.statStock;

  @override Color get overlay    => AppColors.light.overlay;
}
