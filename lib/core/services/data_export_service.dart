import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../database/database_helper.dart';

/// خدمة تصدير واستيراد بيانات النظام كاملةً (Excel & JSON Backup)
class DataExportService {
  DataExportService._();
  static final instance = DataExportService._();

  final _db = DatabaseHelper.instance;

  static const _allTables = [
    'categories',
    'products',
    'orders',
    'order_items',
    'stock_movements',
    'expenses',
    'users',
    'settings',
    'suppliers',
    'purchase_invoices',
    'purchase_invoice_items',
    'supplier_payments',
    'customers',
    'accounts',
    'account_transactions',
    'shifts',
    'raw_materials',
    'product_recipes',
    'inventory_counts',
    'inventory_count_items',
    'employees',
    'employee_transactions',
    'fixed_assets', // ← جديد
    'order_audit_log', // ← جديد
  ];
  // ═══════════════════════════════════════════════════════════════════════════
  // 1) تصدير كل البيانات إلى Excel
  // ═══════════════════════════════════════════════════════════════════════════
// ─── ورقة الأصول الثابتة ─────────────────────────────────────────────────
  Future<void> _addFixedAssetsSheet(Excel excel) async {
    final sheet = excel['الأصول الثابتة'];
    _setHeaders(sheet, [
      'الاسم',
      'النوع',
      'التكلفة / القيمة الشهرية',
      'متكرر؟',
      'مُهلَك حتى الآن',
      'العمر الافتراضي (شهر)',
      'تاريخ الشراء',
      'الملاحظات',
    ]);

    final assets =
        await _db.query('fixed_assets', orderBy: 'purchased_at DESC');
    int row = 1;
    for (final a in assets) {
      _setRow(sheet, row++, [
        a['name'],
        _translateAssetCategory(a['category'] as String?),
        a['cost'],
        (a['is_recurring'] as int?) == 1 ? 'نعم' : 'لا',
        a['accumulated_depreciation'] ?? 0,
        a['useful_life_months'] ?? '',
        _formatDate(a['purchased_at'] as String?),
        a['notes'] ?? '',
      ]);
    }
  }

// ─── ورقة سجل التعديلات والإلغاءات ────────────────────────────────────────
  Future<void> _addAuditLogSheet(Excel excel) async {
    final sheet = excel['سجل التعديلات'];
    _setHeaders(sheet, [
      'رقم الطلب',
      'الإجراء',
      'التفاصيل',
      'بواسطة',
      'التاريخ',
    ]);

    final log = await _db.query('order_audit_log', orderBy: 'created_at DESC');
    int row = 1;
    for (final e in log) {
      _setRow(sheet, row++, [
        e['order_number'] ?? '',
        (e['action'] as String?) == 'cancel' ? 'إلغاء' : 'تعديل',
        e['details'] ?? '',
        e['user_name'] ?? '',
        _formatDate(e['created_at'] as String?),
      ]);
    }
  }

  String _translateAssetCategory(String? category) => switch (category) {
        'rent' => 'إيجار',
        'equipment' => 'معدات',
        'furniture' => 'أثاث',
        _ => 'أخرى',
      };

  /// تصدير كل البيانات إلى ملف Excel — يرجع مسار الملف المحفوظ
  Future<String> exportAllToExcel() async {
    final excel = Excel.createExcel();

    // احذف الورقة الافتراضية
    excel.delete('Sheet1');

    await _addOrdersSheet(excel);
    await _addProductsSheet(excel);
    await _addCategoriesSheet(excel);
    await _addExpensesSheet(excel);
    await _addSuppliersSheet(excel);
    await _addCustomersSheet(excel);
    await _addStockMovementsSheet(excel);
    await _addShiftsSheet(excel);
    await _addFixedAssetsSheet(excel);
    await _addAuditLogSheet(excel);
    // حفظ الملف في مجلد Documents
    final dir = await _getSaveDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-')
        .substring(0, 19);
    final filePath = p.join(dir, 'SystemFood_Export_$timestamp.xlsx');

    final bytes = excel.encode();
    if (bytes == null) throw Exception('فشل في إنشاء ملف Excel');

    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return filePath;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2) تصدير واستيراد نسخة احتياطية كاملة (JSON)
  // ═══════════════════════════════════════════════════════════════════════════

  /// تصدير كل بيانات النظام إلى ملف JSON
  Future<String> exportAllDataToJson() async {
    final Map<String, dynamic> backup = {
      'system': 'FoodPro',
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'tables': <String, dynamic>{},
    };

    final tablesMap = backup['tables'] as Map<String, dynamic>;
    for (final table in _allTables) {
      try {
        final rows = await _db.query(table);
        tablesMap[table] = rows;
      } catch (_) {}
    }

    final dir = await _getSaveDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-')
        .substring(0, 19);
    final filePath = p.join(dir, 'FoodPro_Backup_$timestamp.json');

    final jsonStr = const JsonEncoder.withIndent('  ').convert(backup);
    final file = File(filePath);
    await file.writeAsString(jsonStr, encoding: utf8);
    return filePath;
  }

  /// استيراد بيانات النظام كاملةً من ملف JSON
  Future<int> importAllDataFromJson(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('الملف المحدد غير موجود');
    }

    final jsonStr = await file.readAsString(encoding: utf8);
    final dynamic decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic> || !decoded.containsKey('tables')) {
      throw Exception('صيغة ملف النسخة الاحتياطية غير صالحة');
    }

    final tablesMap = decoded['tables'] as Map<String, dynamic>;
    int importedRows = 0;

    final db = await _db.database;
    await db.transaction((txn) async {
      for (final entry in tablesMap.entries) {
        final table = entry.key;
        final rows = entry.value;
        if (rows is List) {
          for (final row in rows) {
            if (row is Map<String, dynamic>) {
              try {
                await txn.insert(
                  table,
                  row,
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
                importedRows++;
              } catch (_) {}
            }
          }
        }
      }
    });

    return importedRows;
  }

  Future<String> _getSaveDirectory() async {
    if (Platform.isWindows) {
      final home = Platform.environment['USERPROFILE'] ?? '';
      final docs = p.join(home, 'Documents');
      final dir = Directory(docs);
      if (await dir.exists()) return docs;
    }
    final appDir = await getApplicationDocumentsDirectory();
    return appDir.path;
  }

  // ─── ورقة الطلبات ────────────────────────────────────────────────────────
// ─── ورقة الطلبات ────────────────────────────────────────────────────────
  Future<void> _addOrdersSheet(Excel excel) async {
    final sheet = excel['الطلبات'];
    _setHeaders(sheet, [
      'رقم الطلب',
      'التاريخ',
      'اسم الكاشير',
      'نوع الطلب',
      'الإجمالي قبل الخصم',
      'الخصم',
      'الإجمالي النهائي',
      'طريقة الدفع',
      'الحالة',
      'الملاحظات',
    ]);

    final orders = await _db.rawQuery(
      'SELECT * FROM orders ORDER BY created_at DESC',
    );

    int row = 1;
    for (final o in orders) {
      _setRow(sheet, row++, [
        o['order_number'],
        _formatDate(o['created_at'] as String?),
        o['user_name'] ?? '',
        _translateOrderType(o['order_type'] as String?),
        o['subtotal'],
        o['discount_amount'],
        o['final_amount'],
        _translatePayment(o['payment_method'] as String?),
        _translateOrderStatus(o['status'] as String?),
        o['notes'] ?? '',
      ]);
    }
  }

  // ─── ورقة الأصناف ────────────────────────────────────────────────────────
  Future<void> _addProductsSheet(Excel excel) async {
    final sheet = excel['الأصناف'];
    _setHeaders(sheet, [
      'اسم الصنف',
      'التصنيف',
      'السعر',
      'التكلفة',
      'المخزون الحالي',
      'الحد الأدنى',
      'الوحدة',
      'نشط',
    ]);

    final products = await _db.rawQuery('''
      SELECT p.*, c.name AS cat_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      ORDER BY c.name, p.name
    ''');

    int row = 1;
    for (final p in products) {
      _setRow(sheet, row++, [
        p['name'],
        p['cat_name'] ?? '',
        p['price'],
        p['cost'] ?? 0,
        p['stock'],
        p['min_stock'],
        p['unit'],
        (p['is_active'] as int?) == 1 ? 'نعم' : 'لا',
      ]);
    }
  }

  // ─── ورقة التصنيفات ──────────────────────────────────────────────────────
  Future<void> _addCategoriesSheet(Excel excel) async {
    final sheet = excel['التصنيفات'];
    _setHeaders(sheet, ['اسم التصنيف', 'تاريخ الإنشاء', 'نشط']);

    final cats = await _db.query('categories', orderBy: 'name ASC');
    int row = 1;
    for (final c in cats) {
      _setRow(sheet, row++, [
        c['name'],
        _formatDate(c['created_at'] as String?),
        (c['is_active'] as int?) == 1 ? 'نعم' : 'لا',
      ]);
    }
  }

  // ─── ورقة المصروفات ──────────────────────────────────────────────────────
  Future<void> _addExpensesSheet(Excel excel) async {
    final sheet = excel['المصروفات'];
    _setHeaders(sheet, ['التاريخ', 'الفئة', 'المبلغ', 'الوصف']);

    final expenses = await _db.query('expenses', orderBy: 'date DESC');
    int row = 1;
    for (final e in expenses) {
      _setRow(sheet, row++, [
        _formatDate(e['date'] as String?),
        e['category'],
        e['amount'],
        e['description'] ?? '',
      ]);
    }
  }

  // ─── ورقة الموردين ───────────────────────────────────────────────────────
  Future<void> _addSuppliersSheet(Excel excel) async {
    final sheet = excel['الموردين'];
    _setHeaders(sheet, ['الاسم', 'الهاتف', 'العنوان', 'الرصيد', 'الملاحظات']);

    final suppliers = await _db.query('suppliers', orderBy: 'name ASC');
    int row = 1;
    for (final s in suppliers) {
      _setRow(sheet, row++, [
        s['name'],
        s['phone'] ?? '',
        s['address'] ?? '',
        s['balance'],
        s['notes'] ?? '',
      ]);
    }
  }

  // ─── ورقة العملاء ────────────────────────────────────────────────────────
  Future<void> _addCustomersSheet(Excel excel) async {
    final sheet = excel['العملاء'];
    _setHeaders(sheet, ['الاسم', 'الهاتف', 'العنوان', 'المنطقة', 'الملاحظات']);

    final customers = await _db.query('customers', orderBy: 'name ASC');
    int row = 1;
    for (final c in customers) {
      _setRow(sheet, row++, [
        c['name'],
        c['phone'],
        c['address'] ?? '',
        c['area'] ?? '',
        c['notes'] ?? '',
      ]);
    }
  }

  // ─── ورقة حركات المخزون ──────────────────────────────────────────────────
  Future<void> _addStockMovementsSheet(Excel excel) async {
    final sheet = excel['حركات المخزون'];
    _setHeaders(sheet, [
      'التاريخ',
      'اسم الصنف',
      'النوع',
      'الكمية',
      'المخزون قبل',
      'المخزون بعد',
      'السبب',
    ]);

    final movements = await _db.query(
      'stock_movements',
      orderBy: 'created_at DESC',
      limit: 5000,
    );
    int row = 1;
    for (final m in movements) {
      _setRow(sheet, row++, [
        _formatDate(m['created_at'] as String?),
        m['product_name'],
        _translateMovementType(m['type'] as String?),
        m['quantity'],
        m['stock_before'],
        m['stock_after'],
        m['reason'] ?? m['notes'] ?? '',
      ]);
    }
  }

  // ─── ورقة الشيفتات ───────────────────────────────────────────────────────
  Future<void> _addShiftsSheet(Excel excel) async {
    final sheet = excel['الشيفتات'];
    _setHeaders(sheet, [
      'اسم الكاشير',
      'تاريخ الفتح',
      'تاريخ الإغلاق',
      'رصيد الفتح',
      'مبيعات كاش',
      'مبيعات فيزا',
      'إجمالي المبيعات',
      'إجمالي المصروفات',
      'عدد الطلبات',
      'الحالة',
    ]);

    final shifts = await _db.query('shifts', orderBy: 'opened_at DESC');
    int row = 1;
    for (final s in shifts) {
      _setRow(sheet, row++, [
        s['user_name'],
        _formatDate(s['opened_at'] as String?),
        _formatDate(s['closed_at'] as String?),
        s['opening_cash'],
        s['cash_sales'],
        s['card_sales'],
        s['total_sales'],
        s['total_expenses'],
        s['orders_count'],
        (s['status'] as String?) == 'open' ? 'مفتوح' : 'مغلق',
      ]);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  String _translateOrderStatus(String? status) => switch (status) {
        'completed' => 'مكتمل',
        'cancelled' => 'ملغي',
        _ => status ?? '',
      };
  void _setHeaders(Sheet sheet, List<String> headers) {
    for (int i = 0; i < headers.length; i++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('FF1E293B'),
        fontColorHex: ExcelColor.fromHexString('FFF1F5F9'),
        horizontalAlign: HorizontalAlign.Center,
      );
    }
  }

  void _setRow(Sheet sheet, int row, List<dynamic> values) {
    for (int i = 0; i < values.length; i++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row));
      final v = values[i];
      if (v is num) {
        cell.value = DoubleCellValue(v.toDouble());
      } else {
        cell.value = TextCellValue(v?.toString() ?? '');
      }
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  String _translateOrderType(String? type) => switch (type) {
        'dine_in' => 'داخل المطعم',
        'takeaway' => 'تيك أواي',
        'delivery' => 'دليفري',
        _ => type ?? '',
      };

  String _translatePayment(String? method) => switch (method) {
        'cash' => 'كاش',
        'card' => 'فيزا/شبكة',
        'delivery' => 'دليفري',
        _ => method ?? '',
      };

  String _translateMovementType(String? type) => switch (type) {
        'sale' => 'بيع',
        'purchase' => 'شراء',
        'purchase_in' => 'استلام من مورد',
        'consumption' => 'استهلاك خامة',
        'adjustment' => 'تسوية',
        'return' => 'مرتجع',
        'sale_adjust_out' => 'زيادة كمية بعد البيع',
        'sale_adjust_in' => 'تقليل كمية بعد البيع',
        'manual_in' => 'إضافة يدوية',
        'manual_out' => 'خصم يدوي',
        _ => type ?? '',
      };
} // ← القوس ده لازم يكون موجود
