import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_typography.dart';

/// الـ ThemeData الرئيسي للنظام — Dark & Light Themes
abstract final class AppTheme {
  // ═══════════════════════════════════════════════════════════════════════════
  // 1) الوضع الداكن (Dark Professional — Royal Blue & Slate-900)
  // ═══════════════════════════════════════════════════════════════════════════
  static ThemeData get dark {
    final dk = AppColors.dk;
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: dk.primary,
        secondary: dk.primaryLight,
        surface: dk.surface,
        error: dk.error,
        onPrimary: dk.textOnPrimary,
        onSecondary: dk.textOnPrimary,
        onSurface: dk.textPrimary,
        onError: dk.textOnPrimary,
        outline: dk.border,
        surfaceContainerHighest: dk.surfaceVariant,
      ),
    );

    final textTheme = GoogleFonts.cairoTextTheme(base.textTheme).apply(
      bodyColor: dk.textPrimary,
      displayColor: dk.textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: dk.background,
      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: dk.topBarBg,
        foregroundColor: dk.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: dk.primary,
          foregroundColor: dk.textOnPrimary,
          elevation: 0,
          minimumSize: const Size(0, AppDimensions.buttonHeightMd),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space24,
            vertical: AppDimensions.space12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          textStyle: AppTypography.button,
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) return dk.primaryDark;
            if (states.contains(WidgetState.disabled)) return dk.surfaceVariant;
            return dk.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return dk.textDisabled;
            return dk.textOnPrimary;
          }),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: dk.primaryLight,
          minimumSize: const Size(0, AppDimensions.buttonHeightMd),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space24,
            vertical: AppDimensions.space12,
          ),
          side: BorderSide(color: dk.border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          textStyle: AppTypography.button.copyWith(color: dk.primaryLight),
        ).copyWith(
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return BorderSide(color: dk.primary, width: 1.5);
            }
            return BorderSide(color: dk.border, width: 1.5);
          }),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: dk.primaryLight,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space16,
            vertical: AppDimensions.space8,
          ),
          textStyle: AppTypography.button,
        ),
      ),

      cardTheme: CardThemeData(
        color: dk.surface,
        elevation: 0,
        shadowColor: dk.cardShadow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          side: BorderSide(color: dk.border, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      dividerTheme: DividerThemeData(
        color: dk.divider,
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dk.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical: AppDimensions.space14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(color: dk.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(color: dk.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(color: dk.borderFocus, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(color: dk.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(color: dk.error, width: 2),
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(color: dk.textDisabled),
        labelStyle: AppTypography.bodyMedium.copyWith(color: dk.textSecondary),
        prefixIconColor: dk.textSecondary,
        suffixIconColor: dk.textSecondary,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: dk.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 24,
        shadowColor: const Color(0x80000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          side: BorderSide(color: dk.border, width: 1),
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dk.surfaceElevated,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          border: Border.all(color: dk.border),
        ),
        textStyle: AppTypography.caption.copyWith(color: dk.textPrimary),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space12,
          vertical: AppDimensions.space8,
        ),
      ),

      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(dk.surfaceVariant),
        trackColor: WidgetStateProperty.all(Colors.transparent),
        radius: const Radius.circular(AppDimensions.radiusFull),
        thickness: WidgetStateProperty.all(5),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: dk.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          side: BorderSide(color: dk.border, width: 1),
        ),
        textStyle: AppTypography.bodyMedium.copyWith(color: dk.textPrimary),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: dk.surfaceElevated,
        contentTextStyle: AppTypography.bodyMedium.copyWith(color: dk.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: dk.surfaceVariant,
        textColor: dk.textPrimary,
        iconColor: dk.textSecondary,
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: dk.textSecondary,
          hoverColor: dk.surfaceVariant,
        ),
      ),

      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(dk.surface),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          elevation: WidgetStateProperty.all(8),
          side: WidgetStateProperty.all(BorderSide(color: dk.border)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
          ),
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return dk.primary;
          return dk.surfaceVariant;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: dk.border, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return dk.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return dk.primary;
          return dk.surfaceVariant;
        }),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2) الوضع الفاتح (Light Clean — Vibrant Orange & Clean White)
  // ═══════════════════════════════════════════════════════════════════════════
  static ThemeData get light {
    final lt = AppColors.light;
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: lt.primary,
        secondary: lt.primaryLight,
        surface: lt.surface,
        error: lt.error,
        onPrimary: lt.textOnPrimary,
        onSecondary: lt.textOnPrimary,
        onSurface: lt.textPrimary,
        onError: lt.textOnPrimary,
        outline: lt.border,
        surfaceContainerHighest: lt.surfaceVariant,
      ),
    );

    final textTheme = GoogleFonts.cairoTextTheme(base.textTheme).apply(
      bodyColor: lt.textPrimary,
      displayColor: lt.textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: lt.background,
      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: lt.topBarBg,
        foregroundColor: lt.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lt.primary,
          foregroundColor: lt.textOnPrimary,
          elevation: 0,
          minimumSize: const Size(0, AppDimensions.buttonHeightMd),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space24,
            vertical: AppDimensions.space12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          textStyle: AppTypography.button,
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) return lt.primaryDark;
            if (states.contains(WidgetState.disabled)) return lt.surfaceVariant;
            return lt.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return lt.textDisabled;
            return lt.textOnPrimary;
          }),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lt.primary,
          minimumSize: const Size(0, AppDimensions.buttonHeightMd),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space24,
            vertical: AppDimensions.space12,
          ),
          side: BorderSide(color: lt.border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          textStyle: AppTypography.button.copyWith(color: lt.primary),
        ).copyWith(
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return BorderSide(color: lt.primary, width: 1.5);
            }
            return BorderSide(color: lt.border, width: 1.5);
          }),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lt.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space16,
            vertical: AppDimensions.space8,
          ),
          textStyle: AppTypography.button,
        ),
      ),

      cardTheme: CardThemeData(
        color: lt.surface,
        elevation: 0,
        shadowColor: lt.cardShadow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          side: BorderSide(color: lt.border, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      dividerTheme: DividerThemeData(
        color: lt.divider,
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lt.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical: AppDimensions.space14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(color: lt.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(color: lt.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(color: lt.borderFocus, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(color: lt.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(color: lt.error, width: 2),
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(color: lt.textDisabled),
        labelStyle: AppTypography.bodyMedium.copyWith(color: lt.textSecondary),
        prefixIconColor: lt.textSecondary,
        suffixIconColor: lt.textSecondary,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: lt.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 24,
        shadowColor: const Color(0x33000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          side: BorderSide(color: lt.border, width: 1),
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        textStyle: AppTypography.caption.copyWith(color: Colors.white),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space12,
          vertical: AppDimensions.space8,
        ),
      ),

      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(const Color(0xFFCBD5E1)),
        trackColor: WidgetStateProperty.all(Colors.transparent),
        radius: const Radius.circular(AppDimensions.radiusFull),
        thickness: WidgetStateProperty.all(5),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: lt.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          side: BorderSide(color: lt.border, width: 1),
        ),
        textStyle: AppTypography.bodyMedium.copyWith(color: lt.textPrimary),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF0F172A),
        contentTextStyle: AppTypography.bodyMedium.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: lt.surfaceVariant,
        textColor: lt.textPrimary,
        iconColor: lt.textSecondary,
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: lt.textSecondary,
          hoverColor: lt.surfaceVariant,
        ),
      ),

      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(lt.surface),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          elevation: WidgetStateProperty.all(8),
          side: WidgetStateProperty.all(BorderSide(color: lt.border)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
          ),
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return lt.primary;
          return lt.surfaceVariant;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: lt.border, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return lt.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return lt.primary;
          return lt.surfaceVariant;
        }),
      ),
    );
  }
}
