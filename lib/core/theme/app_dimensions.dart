

/// Design Tokens للأبعاد والمسافات والنصف قطر
/// تُستخدم هذه القيم بدلاً من الأرقام العشوائية داخل الـ Widgets
abstract final class AppDimensions {
  // ─── Spacing ──────────────────────────────────────────────────────
  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space6 = 6.0;
  static const double space8 = 8.0;
  static const double space10 = 10.0;
  static const double space12 = 12.0;
  static const double space14 = 14.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;

  // ─── Border Radius ────────────────────────────────────────────────
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusFull = 999.0;

  // ─── الـ Sidebar ──────────────────────────────────────────────────
  static const double sidebarWidth = 240.0;
  static const double sidebarCollapsedWidth = 68.0;

  // ─── الـ Top Bar ──────────────────────────────────────────────────
  static const double topBarHeight = 64.0;

  // ─── الأيقونات ────────────────────────────────────────────────────
  static const double iconSm = 16.0;
  static const double iconMd = 20.0;
  static const double iconLg = 24.0;
  static const double iconXl = 32.0;

  // ─── الأزرار ──────────────────────────────────────────────────────
  static const double buttonHeightSm = 32.0;
  static const double buttonHeightMd = 40.0;
  static const double buttonHeightLg = 48.0;

  // ─── الكروت ───────────────────────────────────────────────────────
  static const double cardPadding = 20.0;
  static const double cardElevation = 0.0;

  // ─── الـ Grid Gaps ────────────────────────────────────────────────
  static const double gridGap = 16.0;
  static const double sectionGap = 24.0;

  // ─── الحدود ───────────────────────────────────────────────────────
  static const double borderWidth = 1.0;
  static const double borderWidthMd = 1.5;

  // ─── Shadow ───────────────────────────────────────────────────────
  static const double shadowBlur = 8.0;
  static const double shadowOffset = 2.0;

  // ─── الـ Summary Cards ────────────────────────────────────────────
  static const double summaryCardMinHeight = 120.0;
  static const double summaryCardIconSize = 48.0;

  // ─── Sidebar item ─────────────────────────────────────────────────
  static const double sidebarItemHeight = 44.0;
  static const double sidebarItemRadius = radiusMd;
}
