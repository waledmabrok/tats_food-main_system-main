import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// نظام Typography المركزي — خط Cairo بأحجام واضحة وعريضة للـ POS
abstract final class AppTypography {
  /// دالة البناء الأساسية
  static TextStyle _base({
    required double fontSize,
    required FontWeight fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.cairo(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height ?? 1.32,
      letterSpacing: letterSpacing,
    );
  }

  // ─── العناوين الرئيسية ─────────────────────────────────────────────────
  /// عنوان كبير جدًا — للشاشات الرئيسية
  static TextStyle headlineLarge = _base(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  /// عنوان متوسط — لعناوين الحوارات الرئيسية
  static TextStyle headlineMedium = _base(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  /// عنوان صغير — لعناوين الصفحات والأقسام
  static TextStyle headlineSmall = _base(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  // ─── العناوين الفرعية ──────────────────────────────────────────────────
  /// عنوان كبير للكروت والأقسام
  static TextStyle titleLarge = _base(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// عنوان متوسط لعناوين الجداول
  static TextStyle titleMedium = _base(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// عنوان صغير للـ Labels والـ Tags
  static TextStyle titleSmall = _base(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  // ─── النصوص الأساسية ───────────────────────────────────────────────────
  /// نص كبير — للأسعار الرئيسية
  static TextStyle bodyLarge = _base(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// نص متوسط — للمحتوى العام
  static TextStyle bodyMedium = _base(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  /// نص صغير — للمعلومات الثانوية
  static TextStyle bodySmall = _base(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  // ─── النصوص المساعدة ────────────────────────────────────────────────────
  /// Caption — للـ Labels والـ Hints
  static TextStyle caption = _base(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  /// نص الأزرار — عريض وواضح
  static TextStyle button = _base(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textOnPrimary,
    letterSpacing: 0.2,
  );

  // ─── أرقام الإحصائيات ──────────────────────────────────────────────────
  /// أرقام كبيرة جدًا لـ Stat Cards
  static TextStyle statNumber = _base(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  /// أرقام متوسطة لـ Stat Cards الثانوية
  static TextStyle statNumberMedium = _base(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  /// أسعار الكاشير — واضحة وكبيرة
  static TextStyle price = _base(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  /// إجمالي الكاشير — أكبر الأرقام
  static TextStyle totalPrice = _base(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.primary,
  );

  // ─── نصوص الـ Sidebar ─────────────────────────────────────────────────
  /// عنصر Sidebar عادي
  static TextStyle sidebarItem = _base(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.sidebarText,
  );

  /// عنصر Sidebar نشط
  static TextStyle sidebarItemActive = _base(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.sidebarTextActive,
  );

  /// عنوان قسم الـ Sidebar
  static TextStyle sidebarSection = _base(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.textDisabled,
    letterSpacing: 0.8,
  );

  // ─── نصوص الجداول ──────────────────────────────────────────────────────
  /// رأس الجدول
  static TextStyle tableHeader = _base(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
    letterSpacing: 0.3,
  );

  /// خلية الجدول
  static TextStyle tableCell = _base(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  // ─── نصوص الفاتورة ─────────────────────────────────────────────────────
  /// عنوان المطعم في الفاتورة
  static TextStyle receiptTitle = _base(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  /// نص الفاتورة العادي
  static TextStyle receiptBody = _base(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
}
