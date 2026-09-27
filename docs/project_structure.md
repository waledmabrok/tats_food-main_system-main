# هيكل مشروع نظام الكاشير

## البنية العامة

```
lib/
├── main.dart                          # نقطة الدخول — RTL + Theme + AppShell
│
├── core/                              # الكود المشترك بين كل الـ Features
│   ├── theme/
│   │   ├── app_colors.dart            # Color Tokens (كل الألوان هنا فقط)
│   │   ├── app_typography.dart        # TextStyle Tokens (خط Cairo)
│   │   ├── app_dimensions.dart        # Spacing / Radius / Sizes
│   │   └── app_theme.dart             # ThemeData الكامل
│   │
│   ├── constants/
│   │   └── app_strings.dart           # كل النصوص العربية (لا نصوص عشوائية في Widgets)
│   │
│   ├── routing/
│   │   └── app_router.dart            # Routes + NavItems + buildRouteWidget()
│   │
│   └── widgets/                       # مكونات مشتركة قابلة لإعادة الاستخدام
│       ├── app_sidebar.dart           # القائمة الجانبية (RTL)
│       ├── app_top_bar.dart           # الشريط العلوي
│       ├── app_button.dart            # زر موحد (5 variants + 3 sizes)
│       ├── app_card.dart              # كارت موحد + AppCardHeader
│       └── empty_state_widget.dart    # Empty State + Error State
│
├── shell/
│   ├── app_shell.dart                 # Desktop Shell (Sidebar + Content)
│   └── placeholder_screen.dart        # شاشة Placeholder للأقسام المستقبلية
│
└── features/
    └── dashboard/
        └── presentation/
            ├── screens/
            │   └── dashboard_screen.dart       # لوحة التحكم الرئيسية
            └── widgets/
                ├── dashboard_header.dart       # رأس الصفحة + الإجراءات السريعة
                ├── summary_card.dart           # كروت الإحصائيات الأربع
                ├── sales_overview.dart         # نظرة عامة على المبيعات (Placeholder)
                ├── recent_orders.dart          # أحدث الطلبات (Empty State)
                └── low_stock_section.dart      # منتجات منخفضة المخزون (Empty State)

docs/
└── project_structure.md               # هذا الملف
```

---

## نظام الـ Theme

### كيف يعمل:
1. **`app_colors.dart`** — يعرّف كل الألوان كـ `static const Color` في `AppColors`.
2. **`app_typography.dart`** — يعرّف كل TextStyles بخط Cairo عبر `AppTypography`.
3. **`app_dimensions.dart`** — يعرّف كل Spacing/Radius/Sizes في `AppDimensions`.
4. **`app_theme.dart`** — يجمع الثلاثة في `ThemeData` موحد يُطبَّق في `main.dart`.

### القاعدة:
```dart
// ✅ صح
color: AppColors.primary
style: AppTypography.titleLarge
padding: EdgeInsets.all(AppDimensions.space16)

// ❌ خطأ
color: Color(0xFF1B4F72)  // لا تكتب ألوانًا عشوائية
fontSize: 16              // لا تكتب أحجام عشوائية
padding: EdgeInsets.all(16) // استخدم AppDimensions
```

---

## نظام الـ Responsive

**بدون أبعاد شاشة ثابتة.** كل Layout يعتمد على:

- **`LayoutBuilder`** — لمعرفة العرض المتاح وتغيير عدد الأعمدة
- **`Expanded` / `Flexible`** — للتمدد بدون أرقام ثابتة
- **`Wrap`** — لعرض عناصر تتكيف مع العرض

مثال في `dashboard_screen.dart`:
```dart
LayoutBuilder(
  builder: (context, constraints) {
    final columns = constraints.maxWidth > 900 ? 4 : constraints.maxWidth > 600 ? 2 : 1;
    // ...
  }
)
```

---

## إضافة Widget مشترك جديد

1. أنشئ الملف في `lib/core/widgets/`
2. استخدم `AppColors` / `AppTypography` / `AppDimensions` فقط
3. لا تضع نصوصًا عربية مباشرة — أضفها في `app_strings.dart` أولاً

---

## إضافة Feature مستقبلية

```
lib/features/<feature_name>/
└── presentation/
    ├── screens/
    │   └── <feature>_screen.dart
    └── widgets/
        └── <component>.dart
```

ثم:
1. أضف Route في `app_router.dart`
2. أضف NavItem في `mainNavItems` أو `managementNavItems`
3. عدّل `buildRouteWidget()` في `app_router.dart`
4. أضف النصوص في `app_strings.dart`

---

## ما تم تنفيذه

- [x] Design System (Colors + Typography + Dimensions)
- [x] RTL من البداية عبر `Directionality`
- [x] Responsive Layout عبر `LayoutBuilder`
- [x] Desktop Shell (Sidebar + TopBar + Content)
- [x] Sidebar مع Active/Hover States
- [x] Top Bar مع التاريخ العربي + معلومات المستخدم
- [x] Dashboard كاملة مع 4 أقسام
- [x] Empty States عربية احترافية
- [x] Shared Widgets (Button + Card + EmptyState)
- [x] PlaceholderScreen للأقسام المستقبلية

---

## ما لم يتم تنفيذه (مقصود)

- [ ] شاشة الكاشير (Feature 2)
- [ ] قاعدة البيانات المحلية
- [ ] CRUD للمنتجات / المخزون
- [ ] نظام الطلبات
- [ ] نظام الدفع
- [ ] التقارير
- [ ] Authentication / PIN
- [ ] Charts حقيقية

---

## الـ Feature التالية المقترحة

**Feature 2: شاشة الكاشير**
- عرض المنتجات + السلة + إنشاء الطلب + اختيار طريقة الدفع
