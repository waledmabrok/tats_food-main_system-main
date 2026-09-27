/// جميع النصوص العربية الظاهرة للمستخدم مركزةً في ملف واحد
/// لا تُكتب نصوص عربية داخل الـ Widgets مباشرةً
abstract final class AppStrings {
  // ─── اسم التطبيق ──────────────────────────────────────────────────
  static const String appName = 'طاطس';
  static const String appSubtitle = 'نظام إدارة المطاعم';
  static const String currency = 'ج.م';

  // ─── عناوين الأقسام (Sidebar) ─────────────────────────────────────
  // ─── شريط علوي ────────────────────────────────────────────────────
  static const String topBarNotifications = 'الإشعارات';

  static const String navDashboard = 'الرئيسية';
  static const String navCashier = 'نقطة البيع (الكاشير)';
  static const String navProducts = 'الأصناف';
  static const String navCategories = 'التصنيفات';
  static const String navInventory = 'المخزون';
  static const String navOrders = 'الطلبات';
  static const String navReports = 'التقارير';
  static const String navExpenses = 'المصروفات';
  static const String navUsers = 'المستخدمون';
  static const String navSettings = 'الإعدادات';
  static const String navSuppliers = 'الموردون';
  static const String navPurchaseReceive = 'استلام بضاعة';
  static const String navCustomers = 'العملاء والدليفري';
  static const String navShifts = 'الشيفتات والدرج';
  static const String navRawMaterials = 'الخامات والوصفات';
  static const String navAccounting = 'الحسابات';
  static const String navEmployees = 'الموظفون والرواتب';

  // ─── الأقسام الفرعية للـ Sidebar ──────────────────────────────────
  static const String sidebarMainMenu = 'القائمة الرئيسية';
  static const String sidebarManagement = 'الإدارة والتقارير';
  static const String sidebarSystem = 'النظام';

  // ─── الدور الحالي ─────────────────────────────────────────────────
  static const String roleManager = 'مدير النظام';
  static const String roleCashier = 'كاشير';
  static const String currentUser = 'مدير النظام';

  // ─── لوحة التحكم ─────────────────────────────────────────────────
  static const String dashboardTitle = 'الرئيسية';
  static const String dashboardSubtitle = 'نظرة عامة على أداء المطعم اليوم';
  static const String dashboardToday = 'اليوم';

  // ─── كروت الإحصائيات ─────────────────────────────────────────────
  static const String statCurrency = 'ج.م';
  static const String statSalesToday = 'مبيعات اليوم';
  static const String statOrdersTotal = 'إجمالي الطلبات';
  static const String statItemsSold = 'الأصناف المباعة';
  static const String statLowStock = 'تنبيهات المخزون';
  static const String statComparedYesterday = 'مقارنةً بالأمس';
  static const String statOrder = 'طلب';
  static const String statItem = 'صنف';
  static const String statProduct = 'منتج';

  // ─── نقطة البيع (POS) ────────────────────────────────────────────
  static const String posTitle = 'نقطة البيع (الكاشير)';
  static const String posAllCategories = 'الكل';
  static const String posCart = 'سلة الطلب';
  static const String posCartEmpty = 'السلة فارغة';
  static const String posCartEmptyDesc = 'اضغط على أي صنف لإضافته إلى الطلب';
  static const String posSubtotal = 'المجموع الفرعي';
  static const String posDiscount = 'الخصم';
  static const String posTotal = 'الإجمالي';
  static const String posCheckout = 'إتمام الدفع';
  static const String posNewOrder = 'طلب جديد';
  static const String posSearchProducts = 'ابحث عن صنف...';
  static const String posQuantity = 'الكمية';
  static const String posOutOfStock = 'غير متوفر';
  static const String posLowStockWarning = 'مخزون منخفض';

  // ─── الدفع ────────────────────────────────────────────────────────
  static const String paymentTitle = 'إتمام الدفع';
  static const String paymentMethod = 'طريقة الدفع';
  static const String paymentCash = 'نقدي';
  static const String paymentVodafone = 'فودافون كاش';
  static const String paymentCard = 'بطاقة';
  static const String paymentOther = 'أخرى';
  static const String paymentPaidAmount = 'المبلغ المدفوع';
  static const String paymentChange = 'الباقي للعميل';
  static const String paymentRef = 'الرقم المرجعي';
  static const String paymentPhoneNumber = 'رقم الهاتف';
  static const String paymentSuccess = 'تم إتمام الدفع بنجاح';
  static const String paymentConfirm = 'تأكيد الدفع';

  // ─── الأصناف ──────────────────────────────────────────────────────
  static const String productsTitle = 'الأصناف';
  static const String productName = 'اسم الصنف';
  static const String productCategory = 'التصنيف';
  static const String productPrice = 'سعر البيع';
  static const String productCost = 'سعر التكلفة';
  static const String productStock = 'الكمية في المخزون';
  static const String productMinStock = 'الحد الأدنى للمخزون';
  static const String productUnit = 'وحدة القياس';
  static const String productStatus = 'الحالة';
  static const String productActive = 'متاح';
  static const String productInactive = 'غير متاح';
  static const String productAddNew = 'إضافة صنف جديد';
  static const String productEdit = 'تعديل الصنف';
  static const String productNoProducts = 'لا توجد أصناف';
  static const String productNoProductsDesc = 'ابدأ بإضافة أصنافك الأولى';
  static const String productSearchHint = 'ابحث باسم الصنف...';

  // ─── التصنيفات ────────────────────────────────────────────────────
  static const String categoriesTitle = 'التصنيفات';
  static const String categoryName = 'اسم التصنيف';
  static const String categoryColor = 'اللون';
  static const String categoryAddNew = 'إضافة تصنيف';
  static const String categoryEdit = 'تعديل التصنيف';
  static const String categoryNoCategories = 'لا توجد تصنيفات';
  static const String categoryNoCategoriesDesc = 'أضف تصنيفات لتنظيم أصنافك';

  // ─── المخزون ──────────────────────────────────────────────────────
  static const String inventoryTitle = 'المخزون';
  static const String inventoryAddStock = 'إضافة مخزون';
  static const String inventoryMovements = 'حركة المخزون';
  static const String inventoryLowStock = 'مخزون منخفض';
  static const String inventoryQuantityToAdd = 'الكمية المضافة';
  static const String inventoryReason = 'السبب';
  static const String inventoryNotes = 'ملاحظات';
  static const String inventoryStockBefore = 'قبل';
  static const String inventoryStockAfter = 'بعد';
  static const String inventoryMovementType = 'نوع الحركة';
  static const String inventoryMovementIn = 'إضافة';
  static const String inventoryMovementOut = 'خصم';
  static const String inventoryMovementSale = 'بيع';

  // ─── الطلبات ──────────────────────────────────────────────────────
  static const String ordersTitle = 'الطلبات';
  static const String orderNumber = 'رقم الطلب';
  static const String orderDate = 'التاريخ';
  static const String orderTime = 'الوقت';
  static const String orderCashier = 'الكاشير';
  static const String orderItems = 'الأصناف';
  static const String orderTotal = 'الإجمالي';
  static const String orderPayment = 'طريقة الدفع';
  static const String orderStatus = 'الحالة';
  static const String orderDetails = 'تفاصيل الطلب';
  static const String orderCompleted = 'مكتمل';
  static const String orderCancelled = 'ملغي';
  static const String orderRefunded = 'مسترد';
  static const String orderNoOrders = 'لا توجد طلبات';
  static const String orderNoOrdersDesc =
      'ستظهر هنا الطلبات بعد إنشائها من نقطة البيع';
  static const String orderCancel = 'إلغاء الطلب';
  static const String orderCancelConfirm = 'هل أنت متأكد من إلغاء هذا الطلب؟';

  // ─── التقارير ─────────────────────────────────────────────────────
  static const String reportsTitle = 'التقارير';
  static const String reportPeriodToday = 'اليوم';
  static const String reportPeriodYesterday = 'أمس';
  static const String reportPeriodThisWeek = 'هذا الأسبوع';
  static const String reportPeriodLastWeek = 'الأسبوع الماضي';
  static const String reportPeriodThisMonth = 'هذا الشهر';
  static const String reportPeriodLastMonth = 'الشهر الماضي';
  static const String reportPeriodCustom = 'فترة مخصصة';
  static const String reportTotalSales = 'إجمالي المبيعات';
  static const String reportOrderCount = 'عدد الطلبات';
  static const String reportAvgOrder = 'متوسط الطلب';
  static const String reportTopProducts = 'الأكثر مبيعاً';
  static const String reportSalesByPayment = 'المبيعات حسب طريقة الدفع';
  static const String reportTotalExpenses = 'إجمالي المصروفات';
  static const String reportNetProfit = 'صافي الأرباح';

  // ─── المصروفات ────────────────────────────────────────────────────
  static const String expensesTitle = 'المصروفات';
  static const String expenseCategory = 'التصنيف';
  static const String expenseAmount = 'المبلغ';
  static const String expenseDate = 'التاريخ';
  static const String expenseDescription = 'الوصف';
  static const String expenseAddNew = 'تسجيل مصروف';
  static const String expenseEdit = 'تعديل المصروف';
  static const String expenseNoExpenses = 'لا توجد مصروفات';
  static const String expenseNoExpensesDesc =
      'سجّل مصروفات المطعم لمتابعة التدفق النقدي';

  // ─── المستخدمون ───────────────────────────────────────────────────
  static const String usersTitle = 'المستخدمون';
  static const String userName = 'الاسم الكامل';
  static const String userUsername = 'اسم المستخدم';
  static const String userPin = 'رمز الدخول (PIN)';
  static const String userRole = 'الصلاحية';
  static const String userRoleManager = 'مدير النظام';
  static const String userRoleCashier = 'كاشير';
  static const String userStatus = 'الحالة';
  static const String userAddNew = 'إضافة مستخدم';
  static const String userEdit = 'تعديل المستخدم';
  static const String userNoUsers = 'لا يوجد مستخدمون';

  // ─── الإعدادات ────────────────────────────────────────────────────
  static const String settingsTitle = 'الإعدادات';
  static const String settingsRestaurant = 'بيانات المطعم';
  static const String settingsRestaurantName = 'اسم المطعم';
  static const String settingsRestaurantPhone = 'رقم الهاتف';
  static const String settingsRestaurantAddress = 'العنوان';
  static const String settingsSystem = 'إعدادات النظام';
  static const String settingsCurrency = 'العملة';
  static const String settingsSaved = 'تم حفظ الإعدادات بنجاح';

  // ─── الأزرار العامة ───────────────────────────────────────────────
  static const String btnViewAll = 'عرض الكل';
  static const String btnAdd = 'إضافة';
  static const String btnEdit = 'تعديل';
  static const String btnDelete = 'حذف';
  static const String btnSave = 'حفظ';
  static const String btnCancel = 'إلغاء';
  static const String btnConfirm = 'تأكيد';
  static const String btnClose = 'إغلاق';
  static const String btnBack = 'رجوع';
  static const String btnSearch = 'بحث';
  static const String btnFilter = 'تصفية';
  static const String btnRefresh = 'تحديث';
  static const String btnPrint = 'طباعة';
  static const String btnExport = 'تصدير';
  static const String btnActivate = 'تفعيل';
  static const String btnDeactivate = 'تعطيل';

  // ─── رسائل الحالات ────────────────────────────────────────────────
  static const String msgLoading = 'جاري التحميل...';
  static const String msgNoData = 'لا توجد بيانات';
  static const String msgError = 'حدث خطأ، يرجى المحاولة مرة أخرى';
  static const String msgSuccess = 'تمت العملية بنجاح';
  static const String msgDeleteConfirm =
      'هل أنت متأكد من الحذف؟ لا يمكن التراجع عن هذا الإجراء.';
  static const String msgUnderConstruction = 'هذا القسم قيد التطوير';
  static const String msgUnderConstructionDesc =
      'سيكون هذا القسم متاحاً في الإصدار القادم';

  // ─── التاريخ والوقت ───────────────────────────────────────────────
  static const String today = 'اليوم';
  static const String yesterday = 'أمس';
  static const String thisWeek = 'هذا الأسبوع';
  static const String thisMonth = 'هذا الشهر';
  static const String from = 'من';
  static const String to = 'إلى';
  static const String date = 'التاريخ';

  // ─── نظرة عامة على المبيعات ───────────────────────────────────────
  static const String salesOverviewTitle = 'نظرة عامة على المبيعات';
  static const String salesOverviewSubtitle = 'إحصائيات المبيعات الأسبوعية';
  static const String salesChartComingSoon = 'الرسم البياني قريباً';
  static const String salesChartDesc =
      'سيتم عرض بيانات المبيعات هنا بعد تسجيل أول طلب';
  static const String recentOrdersTitle = 'آخر الطلبات';
  static const String recentOrdersSubtitle = 'آخر الطلبات المنفذة اليوم';
  static const String recentOrdersEmpty = 'لا توجد طلبات بعد';
  static const String recentOrdersEmptyDesc =
      'ستظهر هنا الطلبات الجديدة عند إنشائها';
  static const String lowStockTitle = 'أصناف تحتاج تخزين';
  static const String lowStockSubtitle = 'أصناف وصلت للحد الأدنى';
  static const String lowStockEmpty = 'لا توجد تنبيهات مخزون';
  static const String lowStockEmptyDesc = 'جميع الأصناف متوفرة بكميات كافية';
  static const String quickActionsTitle = 'إجراءات سريعة';
  static const String quickActionNewOrder = 'طلب جديد';
  static const String quickActionAddProduct = 'إضافة صنف';
}
