import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../../models/category.dart';

/// قاعدة البيانات المحلية للنظام — SQLite عبر FFI (Windows/Linux/macOS)
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;
  static const int _version = 7;
  static const String _dbName = 'foodpro.db';
  static const _uuid = Uuid();

  /// الحصول على مثيل قاعدة البيانات (Lazy init)
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final appDir = await getApplicationSupportDirectory();
    final dbPath = p.join(appDir.path, _dbName);

    return await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _version,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.execute('PRAGMA journal_mode = WAL');
        },
        onOpen: (db) async {
          await _ensureManagementSchema(db);
        },
      ),
    );
  }

  Future<void> _ensureManagementSchema(Database db) async {
    await _upgradeToV4(db);
    await _upgradeToV5(db);
    await _upgradeToV6(db);
    await _upgradeToV7(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE products ADD COLUMN icon TEXT');
    }
    if (oldVersion < 3) {
      await _seedDefaultAccountsUsers(db);
    }
    if (oldVersion < 4) {
      await _upgradeToV4(db);
    }
    if (oldVersion < 5) {
      await _upgradeToV5(db);
    }
    if (oldVersion < 6) {
      await _upgradeToV6(db);
    }
    if (oldVersion < 7) {
      await _upgradeToV7(db);
    }
  }

  Future<void> _upgradeToV7(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS order_audit_log (
      id           TEXT PRIMARY KEY,
      order_id     TEXT NOT NULL,
      order_number TEXT,
      action       TEXT NOT NULL, -- 'edit' | 'cancel'
      details      TEXT,
      user_id      TEXT,
      user_name    TEXT,
      created_at   TEXT NOT NULL
    )
  ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_order ON order_audit_log(order_id)',
    );
  }

  Future<void> _upgradeToV5(Database db) async {
    for (final sql in [
      "ALTER TABLE orders ADD COLUMN order_type TEXT NOT NULL DEFAULT 'takeaway'",
      'ALTER TABLE orders ADD COLUMN customer_id TEXT',
    ]) {
      try {
        await db.execute(sql);
      } catch (_) {
        // العمود موجود بالفعل.
      }
    }
  }

  Future<void> _upgradeToV6(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS fixed_assets (
      id                      TEXT PRIMARY KEY,
      name                    TEXT NOT NULL,
      category                TEXT NOT NULL DEFAULT 'other',
      cost                    REAL NOT NULL, -- لمرة واحدة: التكلفة الكلية / متكرر: القيمة الشهرية
      is_recurring            INTEGER NOT NULL DEFAULT 0,
      useful_life_months      INTEGER,        -- لمرة واحدة فقط: مدة الإهلاك بالشهور
      accumulated_depreciation REAL NOT NULL DEFAULT 0,
      last_processed_date     TEXT,           -- آخر إهلاك مُرحّل أو آخر دفعة متكررة
      payment_type            TEXT NOT NULL DEFAULT 'cash',
      notes                   TEXT,
      user_id                 TEXT,
      purchased_at            TEXT NOT NULL,
      created_at              TEXT NOT NULL
    )
  ''');

    // لو الجدول كان موجود بالفعل من نسخة أقدم (CREATE TABLE IF NOT EXISTS
    // بتتجاهل تمامًا لو الجدول موجود)، نضيف أي عمود ناقص يدويًا هنا.
    Future<void> safeAlter(String sql) async {
      try {
        await db.execute(sql);
      } catch (_) {
        // العمود موجود بالفعل — تجاهل
      }
    }

    await safeAlter(
        "ALTER TABLE fixed_assets ADD COLUMN is_recurring INTEGER NOT NULL DEFAULT 0");
    await safeAlter(
        "ALTER TABLE fixed_assets ADD COLUMN useful_life_months INTEGER");
    await safeAlter(
        "ALTER TABLE fixed_assets ADD COLUMN accumulated_depreciation REAL NOT NULL DEFAULT 0");
    await safeAlter(
        "ALTER TABLE fixed_assets ADD COLUMN last_processed_date TEXT");
    await safeAlter(
        "ALTER TABLE fixed_assets ADD COLUMN payment_type TEXT NOT NULL DEFAULT 'cash'");
    await safeAlter("ALTER TABLE fixed_assets ADD COLUMN notes TEXT");
    await safeAlter("ALTER TABLE fixed_assets ADD COLUMN user_id TEXT");

    final exists = await db.query('accounts',
        where: 'code = ?', whereArgs: ['1.5'], limit: 1);
    if (exists.isEmpty) {
      final assetsParent = await db.query('accounts',
          where: 'code = ?', whereArgs: ['1'], limit: 1);
      await db.insert('accounts', {
        'id': _uuid.v4(),
        'code': '1.5',
        'name': 'معدات وأصول ثابتة',
        'type': 'asset',
        'parent_id': assetsParent.isNotEmpty ? assetsParent.first['id'] : null,
        'balance': 0,
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    final expExists = await db.query('accounts',
        where: 'code = ?', whereArgs: ['5.5'], limit: 1);
    if (expExists.isEmpty) {
      final expenseParent = await db.query('accounts',
          where: 'code = ?', whereArgs: ['5'], limit: 1);
      await db.insert('accounts', {
        'id': _uuid.v4(),
        'code': '5.5',
        'name': 'إهلاك أصول',
        'type': 'expense',
        'parent_id':
            expenseParent.isNotEmpty ? expenseParent.first['id'] : null,
        'balance': 0,
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // إنشاء قاعدة البيانات من الصفر
  // ═══════════════════════════════════════════════════════════════
  Future<void> _onCreate(Database db, int version) async {
    await _createCoreTables(db);
    await _createV4Tables(db);
    await _upgradeToV7(db);
    await _seedData(db);
    await _seedDefaultChartOfAccounts(db);
  }

  Future<void> _createCoreTables(Database db) async {
    await db.execute('''
      CREATE TABLE categories (
        id        TEXT PRIMARY KEY,
        name      TEXT NOT NULL,
        color_hex TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id          TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        name        TEXT NOT NULL,
        price       REAL NOT NULL,
        cost        REAL,
        stock       REAL NOT NULL DEFAULT 0,
        min_stock   REAL NOT NULL DEFAULT 0,
        unit        TEXT NOT NULL DEFAULT 'وحدة',
        icon        TEXT,
        is_active   INTEGER NOT NULL DEFAULT 1,
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_products_category ON products(category_id)',
    );
    await db.execute('CREATE INDEX idx_products_active ON products(is_active)');

    await db.execute('''
      CREATE TABLE orders (
        id              TEXT PRIMARY KEY,
        order_number    TEXT NOT NULL UNIQUE,
        user_id         TEXT,
        user_name       TEXT,
        customer_id     TEXT,
        delivery_address TEXT,
        delivery_fee    REAL NOT NULL DEFAULT 0,
        shift_id        TEXT,
        subtotal        REAL NOT NULL,
        discount_amount REAL NOT NULL DEFAULT 0,
        final_amount    REAL NOT NULL,
        paid_amount     REAL NOT NULL,
        change_amount   REAL NOT NULL DEFAULT 0,
        payment_method  TEXT NOT NULL,
        order_type      TEXT NOT NULL DEFAULT 'takeaway',
        customer_id     TEXT,
        payment_ref     TEXT,
        status          TEXT NOT NULL DEFAULT 'completed',
        notes           TEXT,
        created_at      TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_orders_date ON orders(created_at)');
    await db.execute('CREATE INDEX idx_orders_status ON orders(status)');
    await db.execute('CREATE INDEX idx_orders_shift ON orders(shift_id)');

    await db.execute('''
      CREATE TABLE order_items (
        id           TEXT PRIMARY KEY,
        order_id     TEXT NOT NULL,
        product_id   TEXT NOT NULL,
        product_name TEXT NOT NULL,
        unit_price   REAL NOT NULL,
        quantity     REAL NOT NULL,
        total_price  REAL NOT NULL,
        FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_order_items_order ON order_items(order_id)',
    );

    await db.execute('''
      CREATE TABLE stock_movements (
        id           TEXT PRIMARY KEY,
        product_id   TEXT NOT NULL,
        product_name TEXT NOT NULL,
        type         TEXT NOT NULL,
        item_type    TEXT NOT NULL DEFAULT 'product',
        quantity     REAL NOT NULL,
        stock_before REAL NOT NULL,
        stock_after  REAL NOT NULL,
        order_id     TEXT,
        reason       TEXT,
        notes        TEXT,
        user_id      TEXT,
        created_at   TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_stock_product ON stock_movements(product_id)',
    );

    await db.execute('''
      CREATE TABLE expenses (
        id          TEXT PRIMARY KEY,
        category    TEXT NOT NULL,
        amount      REAL NOT NULL,
        description TEXT,
        user_id     TEXT,
        shift_id    TEXT,
        date        TEXT NOT NULL,
        created_at  TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_expenses_date ON expenses(date)');

    await db.execute('''
      CREATE TABLE users (
        id         TEXT PRIMARY KEY,
        name       TEXT NOT NULL,
        username   TEXT NOT NULL UNIQUE,
        pin        TEXT NOT NULL,
        role       TEXT NOT NULL DEFAULT 'cashier',
        is_active  INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key   TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  /// كل الجداول الجديدة (نسخة 4)
  Future<void> _createV4Tables(Database db) async {
    // ── الموردين ────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id         TEXT PRIMARY KEY,
        name       TEXT NOT NULL,
        phone      TEXT,
        address    TEXT,
        notes      TEXT,
        balance    REAL NOT NULL DEFAULT 0,
        is_active  INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_invoices (
        id               TEXT PRIMARY KEY,
        invoice_number   TEXT NOT NULL,
        supplier_id      TEXT NOT NULL,
        total_amount     REAL NOT NULL,
        paid_amount      REAL NOT NULL DEFAULT 0,
        remaining_amount REAL NOT NULL DEFAULT 0,
        payment_type     TEXT NOT NULL DEFAULT 'cash',
        status           TEXT NOT NULL DEFAULT 'received',
        notes            TEXT,
        user_id          TEXT,
        created_at       TEXT NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pinv_supplier ON purchase_invoices(supplier_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_invoice_items (
        id          TEXT PRIMARY KEY,
        invoice_id  TEXT NOT NULL,
        item_type   TEXT NOT NULL,
        item_id     TEXT NOT NULL,
        item_name   TEXT NOT NULL,
        quantity    REAL NOT NULL,
        unit_cost   REAL NOT NULL,
        total_cost  REAL NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES purchase_invoices(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS supplier_payments (
        id             TEXT PRIMARY KEY,
        supplier_id    TEXT NOT NULL,
        invoice_id     TEXT,
        amount         REAL NOT NULL,
        payment_method TEXT NOT NULL DEFAULT 'cash',
        notes          TEXT,
        user_id        TEXT,
        created_at     TEXT NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
      )
    ''');

    // ── عملاء الدليفري ──────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id         TEXT PRIMARY KEY,
        name       TEXT NOT NULL,
        phone      TEXT NOT NULL,
        address    TEXT,
        area       TEXT,
        notes      TEXT,
        is_active  INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone)',
    );

    // ── شجرة الحسابات ────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS accounts (
        id         TEXT PRIMARY KEY,
        code       TEXT NOT NULL UNIQUE,
        name       TEXT NOT NULL,
        type       TEXT NOT NULL,
        parent_id  TEXT,
        balance    REAL NOT NULL DEFAULT 0,
        is_active  INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY (parent_id) REFERENCES accounts(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS account_transactions (
        id          TEXT PRIMARY KEY,
        account_id  TEXT NOT NULL,
        debit       REAL NOT NULL DEFAULT 0,
        credit      REAL NOT NULL DEFAULT 0,
        description TEXT,
        ref_type    TEXT,
        ref_id      TEXT,
        shift_id    TEXT,
        user_id     TEXT,
        created_at  TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_acc_trans_account ON account_transactions(account_id)',
    );

    // ── الشيفتات (الورديات) ──────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shifts (
        id             TEXT PRIMARY KEY,
        user_id        TEXT NOT NULL,
        user_name      TEXT NOT NULL,
        opening_cash   REAL NOT NULL DEFAULT 0,
        closing_cash   REAL,
        expected_cash  REAL,
        cash_sales     REAL NOT NULL DEFAULT 0,
        card_sales     REAL NOT NULL DEFAULT 0,
        other_sales    REAL NOT NULL DEFAULT 0,
        total_sales    REAL NOT NULL DEFAULT 0,
        total_expenses REAL NOT NULL DEFAULT 0,
        orders_count   INTEGER NOT NULL DEFAULT 0,
        status         TEXT NOT NULL DEFAULT 'open',
        opened_at      TEXT NOT NULL,
        closed_at      TEXT,
        notes          TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_shifts_status ON shifts(status)',
    );

    // ── الخامات ───────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS raw_materials (
        id            TEXT PRIMARY KEY,
        name          TEXT NOT NULL,
        unit          TEXT NOT NULL DEFAULT 'كجم',
        stock         REAL NOT NULL DEFAULT 0,
        min_stock     REAL NOT NULL DEFAULT 0,
        cost_per_unit REAL NOT NULL DEFAULT 0,
        is_active     INTEGER NOT NULL DEFAULT 1,
        created_at    TEXT NOT NULL,
        updated_at    TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_recipes (
        id              TEXT PRIMARY KEY,
        product_id      TEXT NOT NULL,
        raw_material_id TEXT NOT NULL,
        quantity_used   REAL NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
        FOREIGN KEY (raw_material_id) REFERENCES raw_materials(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_recipe_product ON product_recipes(product_id)',
    );

    // ── الجرد ─────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_counts (
        id         TEXT PRIMARY KEY,
        title      TEXT,
        user_id    TEXT,
        status     TEXT NOT NULL DEFAULT 'open',
        notes      TEXT,
        created_at TEXT NOT NULL,
        closed_at  TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_count_items (
        id           TEXT PRIMARY KEY,
        count_id     TEXT NOT NULL,
        item_type    TEXT NOT NULL,
        item_id      TEXT NOT NULL,
        item_name    TEXT NOT NULL,
        expected_qty REAL NOT NULL,
        actual_qty   REAL NOT NULL,
        difference   REAL NOT NULL,
        FOREIGN KEY (count_id) REFERENCES inventory_counts(id) ON DELETE CASCADE
      )
    ''');

    // ── الموظفين والرواتب ─────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS employees (
        id             TEXT PRIMARY KEY,
        name           TEXT NOT NULL,
        phone          TEXT,
        position       TEXT,
        monthly_salary REAL NOT NULL DEFAULT 0,
        hire_date      TEXT,
        is_active      INTEGER NOT NULL DEFAULT 1,
        notes          TEXT,
        created_at     TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS employee_transactions (
        id          TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        type        TEXT NOT NULL,
        amount      REAL NOT NULL,
        month_key   TEXT NOT NULL,
        notes       TEXT,
        user_id     TEXT,
        created_at  TEXT NOT NULL,
        FOREIGN KEY (employee_id) REFERENCES employees(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_emp_trans_employee ON employee_transactions(employee_id)',
    );
  }

  /// ترقية قاعدة بيانات موجودة من v3 إلى v4
  Future<void> _upgradeToV4(Database db) async {
    Future<void> safeAlter(String sql) async {
      try {
        await db.execute(sql);
      } catch (_) {
        // العمود موجود بالفعل — تجاهل
      }
    }

    await safeAlter('ALTER TABLE orders ADD COLUMN customer_id TEXT');
    await safeAlter('ALTER TABLE orders ADD COLUMN delivery_address TEXT');
    await safeAlter(
      "ALTER TABLE orders ADD COLUMN delivery_fee REAL NOT NULL DEFAULT 0",
    );
    await safeAlter('ALTER TABLE orders ADD COLUMN shift_id TEXT');
    await safeAlter('ALTER TABLE expenses ADD COLUMN shift_id TEXT');
    await safeAlter(
      "ALTER TABLE stock_movements ADD COLUMN item_type TEXT NOT NULL DEFAULT 'product'",
    );

    await _createV4Tables(db);
    await _seedDefaultChartOfAccounts(db);
  }

  Future<void> _seedData(Database db) async {
    final now = DateTime.now().toIso8601String();

    final defaultSettings = {
      'restaurant_name': 'مطعمي',
      'restaurant_phone': '',
      'restaurant_address': '',
      'currency': 'ج.م',
      'tax_rate': '0',
      'order_counter': '0',
    };
    for (final entry in defaultSettings.entries) {
      await db.insert('settings', {'key': entry.key, 'value': entry.value});
    }

    final managerId = _uuid.v4();
    await db.insert('users', {
      'id': managerId,
      'name': 'مدير النظام',
      'username': 'admin',
      'pin': '1234',
      'role': 'manager',
      'is_active': 1,
      'created_at': now,
    });

    await _seedDefaultAccountsUsers(db);
  }

  Future<void> _seedDefaultAccountsUsers(Database db) async {
    final now = DateTime.now().toIso8601String();

    final ownerCheck = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: ['owner'],
    );
    if (ownerCheck.isEmpty) {
      await db.insert('users', {
        'id': _uuid.v4(),
        'name': 'صاحب المطعم',
        'username': 'owner',
        'pin': 'owner1234',
        'role': 'manager',
        'is_active': 1,
        'created_at': now,
      });
    }

    final cashierCheck = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: ['cashier'],
    );
    if (cashierCheck.isEmpty) {
      await db.insert('users', {
        'id': _uuid.v4(),
        'name': 'الكاشير',
        'username': 'cashier',
        'pin': '1234',
        'role': 'cashier',
        'is_active': 1,
        'created_at': now,
      });
    }
  }

  /// شجرة الحسابات الافتراضية
  Future<void> _seedDefaultChartOfAccounts(Database db) async {
    final existing = await db.query('accounts', limit: 1);
    if (existing.isNotEmpty) return;
    final now = DateTime.now().toIso8601String();

    Future<String> addAccount(
      String code,
      String name,
      String type, {
      String? parentId,
    }) async {
      final id = _uuid.v4();
      await db.insert('accounts', {
        'id': id,
        'code': code,
        'name': name,
        'type': type,
        'parent_id': parentId,
        'balance': 0,
        'is_active': 1,
        'created_at': now,
      });
      return id;
    }

    final assets = await addAccount('1', 'الأصول', 'asset');
    await addAccount('1.1', 'الخزينة / الكاش', 'asset', parentId: assets);
    await addAccount('1.2', 'البنك', 'asset', parentId: assets);
    await addAccount('1.3', 'مخزون الأصناف', 'asset', parentId: assets);
    await addAccount('1.4', 'مخزون الخامات', 'asset', parentId: assets);
    await addAccount('1.5', 'معدات وأصول ثابتة', 'asset', parentId: assets);
    final liabilities = await addAccount('2', 'الخصوم', 'liability');
    await addAccount(
      '2.1',
      'حسابات الموردين',
      'liability',
      parentId: liabilities,
    );
    await addAccount('2.2', 'رواتب مستحقة', 'liability', parentId: liabilities);

    final equity = await addAccount('3', 'حقوق الملكية', 'equity');
    await addAccount('3.1', 'رأس المال', 'equity', parentId: equity);

    final revenue = await addAccount('4', 'الإيرادات', 'revenue');
    await addAccount('4.1', 'مبيعات نقدي', 'revenue', parentId: revenue);
    await addAccount('4.2', 'مبيعات فيزا/شبكة', 'revenue', parentId: revenue);
    await addAccount('4.3', 'مبيعات دليفري', 'revenue', parentId: revenue);

    final expenseRoot = await addAccount('5', 'المصروفات', 'expense');
    await addAccount('5.1', 'مشتريات خامات', 'expense', parentId: expenseRoot);
    await addAccount('5.2', 'رواتب وأجور', 'expense', parentId: expenseRoot);
    await addAccount('5.3', 'إيجار', 'expense', parentId: expenseRoot);
    await addAccount(
      '5.4',
      'مصاريف تشغيل عامة',
      'expense',
      parentId: expenseRoot,
    );
    await addAccount('5.5', 'إهلاك أصول', 'expense', parentId: expenseRoot);
  }

  /// توليد ID فريد
  static String generateId() => _uuid.v4();

  // ═══════════════════════════════════════════════════════════════
  // عمليات عامة
  // ═══════════════════════════════════════════════════════════════

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(
      table,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data,
    String where,
    List<dynamic> whereArgs,
  ) async {
    final db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table,
    String where,
    List<dynamic> whereArgs,
  ) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      table,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? args,
  ]) async {
    final db = await database;
    return await db.rawQuery(sql, args);
  }

  Future<void> runTransaction(
    Future<void> Function(Transaction txn) action,
  ) async {
    final db = await database;
    await db.transaction(action);
  }

  // ═══════════════════════════════════════════════════════════════
  // الإعدادات
  // ═══════════════════════════════════════════════════════════════

  Future<void> deleteAllSales({bool resetOrderCounter = true}) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('orders');
      if (resetOrderCounter) {
        await txn.insert(
            'settings',
            {
              'key': 'order_counter',
              'value': '0',
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<String?> getSetting(String key) async {
    final results = await query('settings', where: 'key = ?', whereArgs: [key]);
    if (results.isEmpty) return null;
    return results.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
        'settings',
        {
          'key': key,
          'value': value,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSavedDeviceId() => getSetting('device_id');

  Future<void> saveDeviceId(String deviceId) =>
      setSetting('device_id', deviceId);

  Future<String> generateOrderNumber() async {
    final db = await database;
    final counterStr = await getSetting('order_counter') ?? '0';
    final counter = (int.tryParse(counterStr) ?? 0) + 1;
    await db.insert(
        'settings',
        {
          'key': 'order_counter',
          'value': counter.toString(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
    return counter.toString().padLeft(6, '0');
  }

  // ═══════════════════════════════════════════════════════════════
  // التصنيفات
  // ═══════════════════════════════════════════════════════════════

  Future<List<Category>> getCategories({bool activeOnly = true}) async {
    final results = await query(
      'categories',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'created_at ASC',
    );
    return results.map(Category.fromMap).toList();
  }

  // ═══════════════════════════════════════════════════════════════
  // 1) الموردين + استلام البضاعة (كاش / آجل)
  // ═══════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getSuppliers(
          {bool activeOnly = true, int? limit, int? offset}) =>
      query(
        'suppliers',
        where: activeOnly ? 'is_active = 1' : null,
        orderBy: 'name ASC',
        limit: limit,
        offset: offset,
      );
  String _assetCategoryLabel(String category) => switch (category) {
        'rent' => 'إيجار',
        'equipment' => 'معدات',
        'furniture' => 'أثاث',
        _ => 'أصول ثابتة',
      };

  Future<String> addFixedAsset({
    required String name,
    required String category, // rent | equipment | furniture | other
    required double cost,
    required bool isRecurring,
    int? usefulLifeMonths, // مطلوب لو مش متكرر
    String paymentType = 'cash',
    String? notes,
    String? userId,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final id = generateId();
    final shift = await getCurrentShift();

    await db.transaction((txn) async {
      await txn.insert('fixed_assets', {
        'id': id,
        'name': name,
        'category': category,
        'cost': cost,
        'is_recurring': isRecurring ? 1 : 0,
        'useful_life_months': isRecurring ? null : (usefulLifeMonths ?? 12),
        'accumulated_depreciation': 0,
        'last_processed_date': isRecurring ? null : now,
        'payment_type': paymentType,
        'notes': notes,
        'user_id': userId,
        'purchased_at': now,
        'created_at': now,
      });

      if (!isRecurring) {
        // أصل لمرة واحدة: يدخل الميزانية كأصل، ومايتخصمش من الأرباح إلا تدريجيًا (إهلاك)
        final assetAccount = await getAccountIdByCode(txn, '1.5');
        if (assetAccount != null) {
          await postJournalEntryInTransaction(txn,
              accountId: assetAccount,
              debit: cost,
              description: 'شراء أصل ثابت: $name',
              refType: 'fixed_asset',
              refId: id,
              shiftId: shift?['id'] as String?,
              userId: userId);
        }
        if (paymentType == 'cash') {
          final cashAccount = await getAccountIdByCode(txn, '1.1');
          if (cashAccount != null) {
            await postJournalEntryInTransaction(txn,
                accountId: cashAccount,
                credit: cost,
                description: 'سداد شراء أصل ثابت: $name',
                refType: 'fixed_asset',
                refId: id,
                shiftId: shift?['id'] as String?,
                userId: userId);
          }
        }
      }
      // لو متكرر: مفيش قيد أو مصروف دلوقتي؛ كل دفعة بتتسجل وقتها بـ payRecurringAsset
    });
    return id;
  }

  double _monthsBetween(DateTime from, DateTime to) {
    final m = (to.year - from.year) * 12 +
        (to.month - from.month) +
        (to.day - from.day) / 30.0;
    return m < 0 ? 0 : m;
  }

  /// تسجيل دفعة شهرية لأصل متكرر (زي الإيجار) — بتتخصم كاملة من ربح الشهر
  Future<void> payRecurringAsset({
    required String assetId,
    double? amountOverride,
    String? userId,
  }) async {
    final db = await database;
    final rows =
        await query('fixed_assets', where: 'id = ?', whereArgs: [assetId]);
    if (rows.isEmpty) return;
    final asset = rows.first;
    final amount = amountOverride ?? (asset['cost'] as num).toDouble();
    final now = DateTime.now().toIso8601String();
    final shift = await getCurrentShift();

    await db.transaction((txn) async {
      await txn.insert('expenses', {
        'id': generateId(),
        'category': _assetCategoryLabel(asset['category'] as String),
        'amount': amount,
        'description': '${asset['name']} — دفعة شهرية',
        'user_id': userId,
        'shift_id': shift?['id'],
        'date': now,
        'created_at': now,
      });
      await txn.update('fixed_assets', {'last_processed_date': now},
          where: 'id = ?', whereArgs: [assetId]);
    });
  }

  /// تقرير الأرباح والخسائر لفترة معينة (افتراضيًا: من بداية النشاط لحد دلوقتي)
  Future<Map<String, dynamic>> getProfitLossReport({
    DateTime? from,
    DateTime? to,
  }) async {
    final fromStr = (from ?? DateTime(2000)).toIso8601String();
    final toStr = (to ?? DateTime.now()).toIso8601String();

    final salesRows = await rawQuery('''
      SELECT COALESCE(SUM(final_amount), 0) as total, COUNT(*) as cnt
      FROM orders WHERE status = 'completed' AND created_at BETWEEN ? AND ?
    ''', [fromStr, toStr]);
    final totalSales = (salesRows.first['total'] as num).toDouble();
    final ordersCount = salesRows.first['cnt'] as int;

    final itemRows = await rawQuery('''
      SELECT oi.product_id, oi.quantity, p.cost as direct_cost
      FROM order_items oi
      JOIN orders o ON o.id = oi.order_id
      LEFT JOIN products p ON p.id = oi.product_id
      WHERE o.status = 'completed' AND o.created_at BETWEEN ? AND ?
    ''', [fromStr, toStr]);

    double cogsTotal = 0;
    for (final row in itemRows) {
      final productId = row['product_id'] as String;
      final qty = (row['quantity'] as num).toDouble();
      final recipeCostRows = await rawQuery('''
        SELECT COALESCE(SUM(pr.quantity_used * rm.cost_per_unit), 0) as cost
        FROM product_recipes pr JOIN raw_materials rm ON rm.id = pr.raw_material_id
        WHERE pr.product_id = ?
      ''', [productId]);
      final recipeUnitCost = (recipeCostRows.first['cost'] as num).toDouble();
      final unitCost = recipeUnitCost > 0
          ? recipeUnitCost
          : ((row['direct_cost'] as num?)?.toDouble() ?? 0);
      cogsTotal += unitCost * qty;
    }

    final expenseRows = await rawQuery('''
      SELECT category, COALESCE(SUM(amount), 0) as total
      FROM expenses WHERE date BETWEEN ? AND ?
      GROUP BY category
    ''', [fromStr, toStr]);

    double expensesTotal = 0;
    final expensesByCategory = <String, double>{};
    for (final row in expenseRows) {
      final total = (row['total'] as num).toDouble();
      expensesTotal += total;
      expensesByCategory[row['category'] as String] = total;
    }

    final grossProfit = totalSales - cogsTotal;
    final netProfit = grossProfit - expensesTotal;

    return {
      'from': fromStr,
      'to': toStr,
      'total_sales': totalSales,
      'orders_count': ordersCount,
      'cogs_total': cogsTotal,
      'gross_profit': grossProfit,
      'expenses_total': expensesTotal,
      'expenses_by_category': expensesByCategory,
      'net_profit': netProfit,
    };
  }

  /// بترحّل نصيب كل شهر عدى من قيمة الأصول الثابتة كمصروف "إهلاك"، وتوقف
  /// تلقائيًا لما يوصل الإهلاك المتراكم لقيمة الأصل بالكامل. نادِها كل ما
  /// تفتح شاشة الحسابات (أو التقارير) عشان تفضل محدّثة أول بأول.
  Future<void> postAssetDepreciation({DateTime? asOf}) async {
    final now = asOf ?? DateTime.now();
    final assets = await query('fixed_assets', where: 'is_recurring = 0');
    final db = await database;

    for (final asset in assets) {
      final cost = (asset['cost'] as num).toDouble();
      final lifeMonths = (asset['useful_life_months'] as int?) ?? 12;
      final accumulated = (asset['accumulated_depreciation'] as num).toDouble();
      if (accumulated >= cost) continue; // اتهلك بالكامل خلاص

      final purchasedAt = DateTime.parse(asset['purchased_at'] as String);
      final lastProcessed = asset['last_processed_date'] != null
          ? DateTime.parse(asset['last_processed_date'] as String)
          : purchasedAt;

      final elapsedMonths = _monthsBetween(lastProcessed, now).floor();
      if (elapsedMonths < 1) continue; // لسه مفيش شهر كامل عدى من آخر ترحيل

      final monthlyDepreciation = cost / lifeMonths;
      var toDeprecate = monthlyDepreciation * elapsedMonths;
      if (accumulated + toDeprecate > cost) {
        toDeprecate = cost - accumulated;
      }
      if (toDeprecate <= 0) continue;

      final nowStr = now.toIso8601String();
      await db.transaction((txn) async {
        await txn.insert('expenses', {
          'id': generateId(),
          'category': 'إهلاك أصول',
          'amount': toDeprecate,
          'description': 'إهلاك ${asset['name']} ($elapsedMonths شهر)',
          'shift_id': null,
          'date': nowStr,
          'created_at': nowStr,
        });
        await txn.update(
            'fixed_assets',
            {
              'accumulated_depreciation': accumulated + toDeprecate,
              'last_processed_date': nowStr,
            },
            where: 'id = ?',
            whereArgs: [asset['id']]);

        final assetAccount = await getAccountIdByCode(txn, '1.5');
        final expenseAccount = await getAccountIdByCode(txn, '5.5');
        if (assetAccount != null && expenseAccount != null) {
          await postJournalEntryInTransaction(txn,
              accountId: expenseAccount,
              debit: toDeprecate,
              description: 'إهلاك ${asset['name']}',
              refType: 'depreciation',
              refId: asset['id'] as String);
          await postJournalEntryInTransaction(txn,
              accountId: assetAccount,
              credit: toDeprecate,
              description: 'إهلاك ${asset['name']}',
              refType: 'depreciation',
              refId: asset['id'] as String);
        }
      });
    }
  }

  Future<List<Map<String, dynamic>>> getFixedAssets(
          {int? limit, int? offset}) =>
      query('fixed_assets',
          orderBy: 'purchased_at DESC', limit: limit, offset: offset);
  Future<double> getTotalFixedAssetsValue() async {
    final rows = await rawQuery(
        'SELECT COALESCE(SUM(cost),0) as total FROM fixed_assets');
    return (rows.first['total'] as num).toDouble();
  }

  Future<void> deleteFixedAsset(String id) =>
      delete('fixed_assets', 'id = ?', [id]);
  Future<String> addSupplier({
    required String name,
    String? phone,
    String? address,
    String? notes,
  }) async {
    final id = generateId();
    await insert('suppliers', {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'notes': notes,
      'balance': 0,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
    return id;
  }

  /// تسجيل فاتورة استلام بضاعة من مورد (خامات أو أصناف جاهزة) — كاش أو آجل
  /// items: [{item_type: 'raw_material'|'product', item_id, item_name, quantity, unit_cost}]
  Future<String> receivePurchase({
    required String supplierId,
    required List<Map<String, dynamic>> items,
    required String paymentType, // 'cash' | 'credit'
    double paidAmount = 0,
    String? notes,
    String? userId,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final invoiceId = generateId();
    final invoiceNumber = 'PI-${DateTime.now().millisecondsSinceEpoch}';

    double total = 0;
    for (final it in items) {
      total += (it['quantity'] as num) * (it['unit_cost'] as num);
    }
    final remaining = paymentType == 'cash' ? 0.0 : (total - paidAmount);
    final activeShift = await getCurrentShift();

    await db.transaction((txn) async {
      await txn.insert('purchase_invoices', {
        'id': invoiceId,
        'invoice_number': invoiceNumber,
        'supplier_id': supplierId,
        'total_amount': total,
        'paid_amount': paymentType == 'cash' ? total : paidAmount,
        'remaining_amount': remaining,
        'payment_type': paymentType,
        'status': 'received',
        'notes': notes,
        'user_id': userId,
        'created_at': now,
      });

      for (final it in items) {
        final itemTotal = (it['quantity'] as num) * (it['unit_cost'] as num);
        await txn.insert('purchase_invoice_items', {
          'id': generateId(),
          'invoice_id': invoiceId,
          'item_type': it['item_type'],
          'item_id': it['item_id'],
          'item_name': it['item_name'],
          'quantity': it['quantity'],
          'unit_cost': it['unit_cost'],
          'total_cost': itemTotal,
        });

        final table =
            it['item_type'] == 'raw_material' ? 'raw_materials' : 'products';
        final current = await txn.query(
          table,
          where: 'id = ?',
          whereArgs: [it['item_id']],
        );
        if (current.isNotEmpty) {
          final before = (current.first['stock'] as num).toDouble();
          final after = before + (it['quantity'] as num).toDouble();
          final updateData = <String, dynamic>{'stock': after};
          if (table == 'raw_materials') updateData['updated_at'] = now;
          await txn.update(
            table,
            updateData,
            where: 'id = ?',
            whereArgs: [it['item_id']],
          );

          await txn.insert('stock_movements', {
            'id': generateId(),
            'product_id': it['item_id'],
            'product_name': it['item_name'],
            'type': 'purchase_in',
            'item_type': it['item_type'],
            'quantity': it['quantity'],
            'stock_before': before,
            'stock_after': after,
            'order_id': invoiceId,
            'reason': 'استلام بضاعة من مورد',
            'user_id': userId,
            'created_at': now,
          });
        }
      }

      if (remaining > 0) {
        await txn.rawUpdate(
          'UPDATE suppliers SET balance = balance + ? WHERE id = ?',
          [remaining, supplierId],
        );
      }

      final inventoryAccounts = <String, double>{};
      for (final it in items) {
        final code = it['item_type'] == 'raw_material' ? '1.4' : '1.3';
        final itemTotal = (it['quantity'] as num) * (it['unit_cost'] as num);
        inventoryAccounts[code] = (inventoryAccounts[code] ?? 0) + itemTotal;
      }
      for (final entry in inventoryAccounts.entries) {
        final accountId = await getAccountIdByCode(txn, entry.key);
        if (accountId != null) {
          await postJournalEntryInTransaction(
            txn,
            accountId: accountId,
            debit: entry.value,
            description: 'إضافة مخزون من فاتورة شراء $invoiceNumber',
            refType: 'purchase',
            refId: invoiceId,
            shiftId: activeShift?['id'] as String?,
            userId: userId,
          );
        }
      }
      final paid = paymentType == 'cash' ? total : paidAmount;
      if (paid > 0) {
        final cashAccount = await getAccountIdByCode(txn, '1.1');
        if (cashAccount != null) {
          await postJournalEntryInTransaction(
            txn,
            accountId: cashAccount,
            credit: paid,
            description: 'سداد شراء نقدي $invoiceNumber',
            refType: 'purchase',
            refId: invoiceId,
            shiftId: activeShift?['id'] as String?,
            userId: userId,
          );
        }
      }
      if (remaining > 0) {
        final supplierAccount = await getAccountIdByCode(txn, '2.1');
        if (supplierAccount != null) {
          await postJournalEntryInTransaction(
            txn,
            accountId: supplierAccount,
            credit: remaining,
            description: 'مستحقات مورد من فاتورة $invoiceNumber',
            refType: 'purchase',
            refId: invoiceId,
            shiftId: activeShift?['id'] as String?,
            userId: userId,
          );
        }
      }
    });

    return invoiceId;
  }

  /// سداد دفعة لمورد (تقفيل حساب آجل)
  Future<void> paySupplier({
    required String supplierId,
    required double amount,
    String? invoiceId,
    String paymentMethod = 'cash',
    String? notes,
    String? userId,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.insert('supplier_payments', {
        'id': generateId(),
        'supplier_id': supplierId,
        'invoice_id': invoiceId,
        'amount': amount,
        'payment_method': paymentMethod,
        'notes': notes,
        'user_id': userId,
        'created_at': now,
      });
      await txn.rawUpdate(
        'UPDATE suppliers SET balance = balance - ? WHERE id = ?',
        [amount, supplierId],
      );
      if (invoiceId != null) {
        await txn.rawUpdate(
          'UPDATE purchase_invoices SET paid_amount = paid_amount + ?, remaining_amount = remaining_amount - ? WHERE id = ?',
          [amount, amount, invoiceId],
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getSupplierInvoices(String supplierId) =>
      query(
        'purchase_invoices',
        where: 'supplier_id = ?',
        whereArgs: [supplierId],
        orderBy: 'created_at DESC',
      );

  Future<void> updateSupplier({
    required String id,
    required String name,
    String? phone,
    String? address,
    String? notes,
  }) async {
    await update(
      'suppliers',
      {
        'name': name,
        'phone': phone,
        'address': address,
        'notes': notes,
      },
      'id = ?',
      [id],
    );
  }

  Future<void> deleteSupplier(String id) async {
    await update('suppliers', {'is_active': 0}, 'id = ?', [id]);
  }

  Future<void> updateCustomer({
    required String id,
    required String name,
    required String phone,
    String? address,
    String? area,
    String? notes,
  }) async {
    await update(
      'customers',
      {
        'name': name,
        'phone': phone,
        'address': address,
        'area': area,
        'notes': notes,
      },
      'id = ?',
      [id],
    );
  }

  Future<void> deleteCustomer(String id) async {
    await update('customers', {'is_active': 0}, 'id = ?', [id]);
  }

  Future<void> updateEmployee({
    required String id,
    required String name,
    String? phone,
    String? position,
    required double monthlySalary,
  }) async {
    await update(
      'employees',
      {
        'name': name,
        'phone': phone,
        'position': position,
        'monthly_salary': monthlySalary,
      },
      'id = ?',
      [id],
    );
  }

  Future<void> deleteEmployee(String id) async {
    await update('employees', {'is_active': 0}, 'id = ?', [id]);
  }

  // ═══════════════════════════════════════════════════════════════
  // 2) عملاء الدليفري
  // ═══════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getCustomers(
          {bool activeOnly = true, int? limit, int? offset}) =>
      query(
        'customers',
        where: activeOnly ? 'is_active = 1' : null,
        orderBy: 'name ASC',
        limit: limit,
        offset: offset,
      );

  Future<Map<String, dynamic>?> getCustomerById(String id) async {
    final rows =
        await query('customers', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<String> addCustomer({
    required String name,
    required String phone,
    String? address,
    String? area,
    String? notes,
  }) async {
    final id = generateId();
    await insert('customers', {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'area': area,
      'notes': notes,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
    return id;
  }

  Future<List<Map<String, dynamic>>> searchCustomerByPhone(String phone) =>
      query('customers', where: 'phone LIKE ?', whereArgs: ['%$phone%']);

  // ═══════════════════════════════════════════════════════════════
  // 3) شجرة الحسابات + الشيفتات (الورديات)
  // ═══════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getAccounts() =>
      query('accounts', orderBy: 'code ASC');

  Future<String?> getAccountIdByCode(Transaction txn, String code) async {
    final rows = await txn.query(
      'accounts',
      columns: ['id'],
      where: 'code = ?',
      whereArgs: [code],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id'] as String;
  }

  Future<String?> findAccountIdByCode(String code) async {
    final rows =
        await query('accounts', where: 'code = ?', whereArgs: [code], limit: 1);
    return rows.isEmpty ? null : rows.first['id'] as String;
  }

  Future<void> postJournalEntryInTransaction(
    Transaction txn, {
    required String accountId,
    double debit = 0,
    double credit = 0,
    String? description,
    String? refType,
    String? refId,
    String? shiftId,
    String? userId,
  }) async {
    await txn.insert('account_transactions', {
      'id': generateId(),
      'account_id': accountId,
      'debit': debit,
      'credit': credit,
      'description': description,
      'ref_type': refType,
      'ref_id': refId,
      'shift_id': shiftId,
      'user_id': userId,
      'created_at': DateTime.now().toIso8601String(),
    });
    await txn.rawUpdate(
      'UPDATE accounts SET balance = balance + ? - ? WHERE id = ?',
      [debit, credit, accountId],
    );
  }

  Future<void> postJournalEntry({
    required String accountId,
    double debit = 0,
    double credit = 0,
    String? description,
    String? refType,
    String? refId,
    String? shiftId,
    String? userId,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await postJournalEntryInTransaction(
        txn,
        accountId: accountId,
        debit: debit,
        credit: credit,
        description: description,
        refType: refType,
        refId: refId,
        shiftId: shiftId,
        userId: userId,
      );
    });
  }

  /// فتح شيفت جديد (لازم تقفل أي شيفت مفتوح الأول)
  Future<String> openShift({
    required String userId,
    required String userName,
    required double openingCash,
  }) async {
    final open = await query(
      'shifts',
      where: 'status = ?',
      whereArgs: ['open'],
    );
    if (open.isNotEmpty) {
      throw Exception('يوجد شيفت مفتوح بالفعل، لازم تقفله الأول');
    }
    final id = generateId();
    await insert('shifts', {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'opening_cash': openingCash,
      'status': 'open',
      'opened_at': DateTime.now().toIso8601String(),
    });
    return id;
  }

  Future<Map<String, dynamic>?> getCurrentShift() async {
    final res = await query('shifts', where: 'status = ?', whereArgs: ['open']);
    return res.isEmpty ? null : res.first;
  }

  /// ملخص المبيعات والدرج للشيفت (لحظي — تقدر تناديها في أي وقت والشيفت لسه مفتوح)
  Future<Map<String, dynamic>> getShiftSummary(String shiftId) async {
    final shift =
        (await query('shifts', where: 'id = ?', whereArgs: [shiftId])).first;

    final salesRows = await rawQuery('''
    SELECT payment_method, COUNT(*) as cnt, COALESCE(SUM(final_amount), 0) as total
    FROM orders WHERE shift_id = ? AND status = 'completed'
    GROUP BY payment_method
  ''', [shiftId]);

    double cash = 0, card = 0, other = 0;
    int ordersCount = 0;
    for (final row in salesRows) {
      final total = (row['total'] as num).toDouble();
      ordersCount += row['cnt'] as int;
      final method = row['payment_method'] as String;
      if (method == 'cash') {
        cash += total;
      } else if (method == 'card' || method == 'visa') {
        card += total;
      } else {
        other += total;
      }
    }

    final expenseRows = await rawQuery(
        "SELECT COALESCE(SUM(amount), 0) as total FROM expenses WHERE shift_id = ?",
        [shiftId]);
    final expensesTotal = (expenseRows.first['total'] as num).toDouble();

    // ── تكلفة البضاعة المباعة (COGS) خلال الشيفت ──────────────
    final itemRows = await rawQuery('''
    SELECT oi.product_id, oi.quantity, p.cost as direct_cost
    FROM order_items oi
    JOIN orders o ON o.id = oi.order_id
    LEFT JOIN products p ON p.id = oi.product_id
    WHERE o.shift_id = ? AND o.status = 'completed'
  ''', [shiftId]);

    double cogsTotal = 0;
    for (final row in itemRows) {
      final productId = row['product_id'] as String;
      final qty = (row['quantity'] as num).toDouble();
      final recipeCostRows = await rawQuery('''
      SELECT COALESCE(SUM(pr.quantity_used * rm.cost_per_unit), 0) as cost
      FROM product_recipes pr JOIN raw_materials rm ON rm.id = pr.raw_material_id
      WHERE pr.product_id = ?
    ''', [productId]);
      final recipeUnitCost = (recipeCostRows.first['cost'] as num).toDouble();
      final unitCost = recipeUnitCost > 0
          ? recipeUnitCost
          : ((row['direct_cost'] as num?)?.toDouble() ?? 0);
      cogsTotal += unitCost * qty;
    }

    final openingCash = (shift['opening_cash'] as num).toDouble();
    final totalSales = cash + card + other;
    final expectedDrawer = openingCash + cash - expensesTotal;
    final netProfit = totalSales - cogsTotal - expensesTotal;

    return {
      'shift': shift,
      'cash_sales': cash,
      'card_sales': card,
      'other_sales': other,
      'total_sales': totalSales,
      'orders_count': ordersCount,
      'expenses_total': expensesTotal,
      'expected_drawer_cash': expectedDrawer,
      'cogs_total': cogsTotal, // جديد
      'net_profit': netProfit, // جديد — سالب يعني خسارة
    };
  }

  /// قفل الشيفت بعد ما الكاشير يعد الدرج فعليًا — بيحسب الفرق (عجز/زيادة) تلقائيًا
  Future<Map<String, dynamic>> closeShift(
    String shiftId, {
    required double actualClosingCash,
    String? notes,
  }) async {
    final summary = await getShiftSummary(shiftId);
    final db = await database;
    await db.update(
      'shifts',
      {
        'closing_cash': actualClosingCash,
        'expected_cash': summary['expected_drawer_cash'],
        'cash_sales': summary['cash_sales'],
        'card_sales': summary['card_sales'],
        'other_sales': summary['other_sales'],
        'total_sales': summary['total_sales'],
        'total_expenses': summary['expenses_total'],
        'orders_count': summary['orders_count'],
        'status': 'closed',
        'closed_at': DateTime.now().toIso8601String(),
        'notes': notes,
      },
      where: 'id = ?',
      whereArgs: [shiftId],
    );
    final diff =
        actualClosingCash - (summary['expected_drawer_cash'] as double);
    return {
      ...summary,
      'actual_closing_cash': actualClosingCash,
      'difference': diff,
    };
  }

  Future<List<Map<String, dynamic>>> getShiftsHistory({int limit = 30}) =>
      query('shifts', orderBy: 'opened_at DESC', limit: limit);

  // ═══════════════════════════════════════════════════════════════
  // 4) الخامات + وصفة الصنف + حساب الربح + الجرد
  // ═══════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getRawMaterials({
    bool activeOnly = true,
    int? limit,
    int? offset,
  }) =>
      query(
        'raw_materials',
        where: activeOnly ? 'is_active = 1' : null,
        orderBy: 'name ASC',
        limit: limit,
        offset: offset,
      );

  Future<String> addRawMaterial({
    required String name,
    required String unit,
    double costPerUnit = 0,
    double minStock = 0,
    double initialStock = 0,
  }) async {
    final id = generateId();
    final now = DateTime.now().toIso8601String();
    await insert('raw_materials', {
      'id': id,
      'name': name,
      'unit': unit,
      'stock': initialStock,
      'min_stock': minStock,
      'cost_per_unit': costPerUnit,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<void> updateRawMaterial({
    required String id,
    required String name,
    required String unit,
    required double costPerUnit,
    required double minStock,
    required double stock,
  }) async {
    await update(
        'raw_materials',
        {
          'name': name,
          'unit': unit,
          'cost_per_unit': costPerUnit,
          'min_stock': minStock,
          'stock': stock,
          'updated_at': DateTime.now().toIso8601String(),
        },
        'id = ?',
        [id]);
  }

  Future<void> setRawMaterialActive(String id, bool active) async {
    await update(
        'raw_materials',
        {
          'is_active': active ? 1 : 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        'id = ?',
        [id]);
  }

  /// تحديد/تعديل وصفة (مكونات) الصنف — ingredients: [{raw_material_id, quantity_used}]
  Future<void> setProductRecipe(
    String productId,
    List<Map<String, dynamic>> ingredients,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'product_recipes',
        where: 'product_id = ?',
        whereArgs: [productId],
      );
      for (final ing in ingredients) {
        await txn.insert('product_recipes', {
          'id': generateId(),
          'product_id': productId,
          'raw_material_id': ing['raw_material_id'],
          'quantity_used': ing['quantity_used'],
        });
      }
    });
  }

  /// حساب تكلفة الصنف من الخامات وهامش الربح
  Future<Map<String, dynamic>> getProductCostAndProfit(String productId) async {
    final recipeRows = await rawQuery('''
    SELECT pr.quantity_used, rm.cost_per_unit, rm.name, rm.unit
    FROM product_recipes pr JOIN raw_materials rm ON rm.id = pr.raw_material_id
    WHERE pr.product_id = ?
  ''', [productId]);

    double totalCost = 0;
    for (final row in recipeRows) {
      totalCost +=
          (row['quantity_used'] as num) * (row['cost_per_unit'] as num);
    }

    final productRows =
        await query('products', where: 'id = ?', whereArgs: [productId]);
    final price = productRows.isNotEmpty
        ? (productRows.first['price'] as num).toDouble()
        : 0.0;

    // لو مفيش وصفة خامات، استخدم حقل cost المسجل يدويًا في الصنف نفسه
    if (recipeRows.isEmpty && productRows.isNotEmpty) {
      totalCost = (productRows.first['cost'] as num?)?.toDouble() ?? 0;
    }

    final profit = price - totalCost;
    final profitPercent = price > 0 ? (profit / price) * 100 : 0.0;
    return {
      'cost': totalCost,
      'price': price,
      'profit': profit,
      'profit_percent': profitPercent,
      'ingredients': recipeRows
    };
  }

  /// خصم الخامات المستخدمة من المخزون عند بيع الصنف
  /// نادِها جوه الـ transaction اللي بتنشئ الأوردر، لكل عنصر في السلة
  Future<void> consumeRawMaterialsForOrder(
    Transaction txn,
    String productId,
    double qtySold, {
    String? orderId,
  }) async {
    final now = DateTime.now().toIso8601String();
    final recipe = await txn.rawQuery(
      'SELECT raw_material_id, quantity_used FROM product_recipes WHERE product_id = ?',
      [productId],
    );

    for (final row in recipe) {
      final rmId = row['raw_material_id'] as String;
      final usedPerUnit = (row['quantity_used'] as num).toDouble();
      final totalUsed = usedPerUnit * qtySold;

      final rm = await txn.query(
        'raw_materials',
        where: 'id = ?',
        whereArgs: [rmId],
      );
      if (rm.isEmpty) continue;
      final before = (rm.first['stock'] as num).toDouble();
      final after = before - totalUsed;

      await txn.update(
        'raw_materials',
        {'stock': after, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [rmId],
      );
      await txn.insert('stock_movements', {
        'id': generateId(),
        'product_id': rmId,
        'product_name': rm.first['name'],
        'type': 'consumption',
        'item_type': 'raw_material',
        'quantity': totalUsed,
        'stock_before': before,
        'stock_after': after,
        'order_id': orderId,
        'reason': 'استهلاك عند البيع',
        'created_at': now,
      });
    }
  }

  /// إرجاع الخامات المستهلكة للمخزون عند إلغاء أوردر (عكس consumeRawMaterialsForOrder)
  Future<void> restoreRawMaterialsForOrder(
    Transaction txn,
    String productId,
    double qtyCancelled, {
    String? orderId,
    String? reason,
  }) async {
    final now = DateTime.now().toIso8601String();
    final recipe = await txn.rawQuery(
      'SELECT raw_material_id, quantity_used FROM product_recipes WHERE product_id = ?',
      [productId],
    );

    for (final row in recipe) {
      final rmId = row['raw_material_id'] as String;
      final usedPerUnit = (row['quantity_used'] as num).toDouble();
      final totalReturned = usedPerUnit * qtyCancelled;

      final rm = await txn.query(
        'raw_materials',
        where: 'id = ?',
        whereArgs: [rmId],
      );
      if (rm.isEmpty) continue;
      final before = (rm.first['stock'] as num).toDouble();
      final after = before + totalReturned;

      await txn.update(
        'raw_materials',
        {'stock': after, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [rmId],
      );
      await txn.insert('stock_movements', {
        'id': generateId(),
        'product_id': rmId,
        'product_name': rm.first['name'],
        'type': 'return',
        'item_type': 'raw_material',
        'quantity': totalReturned,
        'stock_before': before,
        'stock_after': after,
        'order_id': orderId,
        'reason': reason ?? 'إرجاع خامات بسبب إلغاء الطلب',
        'created_at': now,
      });
    }
  }

  /// بدء جرد جديد
  Future<String> startInventoryCount({String? title, String? userId}) async {
    final id = generateId();
    await insert('inventory_counts', {
      'id': id,
      'title': title,
      'user_id': userId,
      'status': 'open',
      'created_at': DateTime.now().toIso8601String(),
    });
    return id;
  }

  Future<void> addInventoryCountItem({
    required String countId,
    required String itemType,
    required String itemId,
    required String itemName,
    required double expectedQty,
    required double actualQty,
  }) async {
    await insert('inventory_count_items', {
      'id': generateId(),
      'count_id': countId,
      'item_type': itemType,
      'item_id': itemId,
      'item_name': itemName,
      'expected_qty': expectedQty,
      'actual_qty': actualQty,
      'difference': actualQty - expectedQty,
    });
  }

  /// قفل الجرد — بيحدّث المخزون الفعلي على حسب العدّ
  Future<void> closeInventoryCount(String countId) async {
    final db = await database;
    final items = await query(
      'inventory_count_items',
      where: 'count_id = ?',
      whereArgs: [countId],
    );
    await db.transaction((txn) async {
      for (final item in items) {
        final table =
            item['item_type'] == 'raw_material' ? 'raw_materials' : 'products';
        await txn.update(
          table,
          {'stock': item['actual_qty']},
          where: 'id = ?',
          whereArgs: [item['item_id']],
        );
      }
      await txn.update(
        'inventory_counts',
        {'status': 'closed', 'closed_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [countId],
      );
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // 5) الموظفين والرواتب (سلف / صرف / خصومات)
  // ═══════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getEmployees(
          {bool activeOnly = true, int? limit, int? offset}) =>
      query(
        'employees',
        where: activeOnly ? 'is_active = 1' : null,
        orderBy: 'name ASC',
        limit: limit,
        offset: offset,
      );

  Future<String> addEmployee({
    required String name,
    String? phone,
    String? position,
    required double monthlySalary,
    String? hireDate,
  }) async {
    final id = generateId();
    await insert('employees', {
      'id': id,
      'name': name,
      'phone': phone,
      'position': position,
      'monthly_salary': monthlySalary,
      'hire_date': hireDate,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
    return id;
  }

  /// تسجيل حركة على الموظف: سلفة / صرف مرتب / مكافأة / خصم
  Future<void> addEmployeeTransaction({
    required String employeeId,
    required String type, // advance | salary_payment | bonus | deduction
    required double amount,
    String? monthKey,
    String? notes,
    String? userId,
  }) async {
    final key = monthKey ??
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    await insert('employee_transactions', {
      'id': generateId(),
      'employee_id': employeeId,
      'type': type,
      'amount': amount,
      'month_key': key,
      'notes': notes,
      'user_id': userId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// كشف حساب الموظف لشهر معين: المرتب + المكافآت - (السلف + الصرف + الخصومات) = المتبقي
  Future<Map<String, dynamic>> getEmployeeMonthlyStatement(
    String employeeId, {
    String? monthKey,
  }) async {
    final key = monthKey ??
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    final emp = (await query(
      'employees',
      where: 'id = ?',
      whereArgs: [employeeId],
    ))
        .first;
    final salary = (emp['monthly_salary'] as num).toDouble();

    final rows = await query(
      'employee_transactions',
      where: 'employee_id = ? AND month_key = ?',
      whereArgs: [employeeId, key],
    );

    double advances = 0, payments = 0, bonuses = 0, deductions = 0;
    for (final r in rows) {
      final amount = (r['amount'] as num).toDouble();
      switch (r['type']) {
        case 'advance':
          advances += amount;
          break;
        case 'salary_payment':
          payments += amount;
          break;
        case 'bonus':
          bonuses += amount;
          break;
        case 'deduction':
          deductions += amount;
          break;
      }
    }

    final remaining = salary + bonuses - advances - payments - deductions;

    return {
      'employee': emp,
      'month': key,
      'monthly_salary': salary,
      'advances': advances,
      'payments': payments,
      'bonuses': bonuses,
      'deductions': deductions,
      'remaining': remaining,
    };
  }
// ═══════════════════════════════════════════════════════════════
// 6) أوردرات الكاشير + سجل التعديلات (Audit Log)
// ═══════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getOrdersByUser(
    String userId, {
    int? limit,
    int? offset,
  }) =>
      query(
        'orders',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
        limit: limit,
        offset: offset,
      );

  Future<List<Map<String, dynamic>>> getAllOrders({int? limit, int? offset}) =>
      query('orders', orderBy: 'created_at DESC', limit: limit, offset: offset);

  Future<List<Map<String, dynamic>>> getOrderItemsFor(String orderId) =>
      query('order_items', where: 'order_id = ?', whereArgs: [orderId]);

  Future<List<Map<String, dynamic>>> getOrderAuditLog({
    int? limit,
    int? offset,
  }) =>
      query('order_audit_log',
          orderBy: 'created_at DESC', limit: limit, offset: offset);

  Future<void> _logOrderAction(
    Transaction txn, {
    required String orderId,
    String? orderNumber,
    required String action,
    required String details,
    String? userId,
    String? userName,
  }) async {
    await txn.insert('order_audit_log', {
      'id': generateId(),
      'order_id': orderId,
      'order_number': orderNumber,
      'action': action,
      'details': details,
      'user_id': userId,
      'user_name': userName,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// تعديل كمية صنف داخل أوردر — بيرجّع الفرق للمخزون ويحدّث إجمالي الأوردر
  Future<void> updateOrderItemQuantity({
    required String orderId,
    required String orderItemId,
    required double newQuantity,
    required String userId,
    required String userName,
  }) async {
    if (newQuantity <= 0) {
      throw Exception(
          'الكمية لازم تكون أكبر من صفر — لو عايز تشيل الصنف احذف الأوردر أو قلل الكمية بدل الصفر');
    }
    final db = await database;
    final itemRows =
        await query('order_items', where: 'id = ?', whereArgs: [orderItemId]);
    if (itemRows.isEmpty) return;
    final item = itemRows.first;
    final oldQty = (item['quantity'] as num).toDouble();
    final diff = newQuantity - oldQty; // موجب = بيع أكتر = خصم إضافي من المخزون
    final productId = item['product_id'] as String;
    final unitPrice = (item['unit_price'] as num).toDouble();
    final newTotal = unitPrice * newQuantity;

    await db.transaction((txn) async {
      await txn.update(
        'order_items',
        {'quantity': newQuantity, 'total_price': newTotal},
        where: 'id = ?',
        whereArgs: [orderItemId],
      );

      if (diff != 0) {
        final productRows = await txn
            .query('products', where: 'id = ?', whereArgs: [productId]);
        if (productRows.isNotEmpty) {
          final before = (productRows.first['stock'] as num).toDouble();
          final after = before - diff;
          await txn.update(
            'products',
            {'stock': after, 'updated_at': DateTime.now().toIso8601String()},
            where: 'id = ?',
            whereArgs: [productId],
          );
          await txn.insert('stock_movements', {
            'id': generateId(),
            'product_id': productId,
            'product_name': item['product_name'],
            'type': diff > 0 ? 'sale_adjust_out' : 'sale_adjust_in',
            'item_type': 'product',
            'quantity': diff.abs(),
            'stock_before': before,
            'stock_after': after,
            'order_id': orderId,
            'reason': 'تعديل كمية داخل أوردر',
            'user_id': userId,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
        // تعديل استهلاك الخامات لو الصنف له وصفة
        if (diff > 0) {
          await consumeRawMaterialsForOrder(txn, productId, diff,
              orderId: orderId);
        } else {
          await restoreRawMaterialsForOrder(txn, productId, diff.abs(),
              orderId: orderId, reason: 'تعديل كمية داخل أوردر');
        }
      }

      final allItems = await txn
          .query('order_items', where: 'order_id = ?', whereArgs: [orderId]);
      double newSubtotal = 0;
      for (final it in allItems) {
        newSubtotal += (it['total_price'] as num).toDouble();
      }
      final orderRows =
          await txn.query('orders', where: 'id = ?', whereArgs: [orderId]);
      final discount = (orderRows.first['discount_amount'] as num).toDouble();
      final newFinal = (newSubtotal - discount).clamp(0, double.infinity);
      await txn.update(
        'orders',
        {'subtotal': newSubtotal, 'final_amount': newFinal},
        where: 'id = ?',
        whereArgs: [orderId],
      );

      await _logOrderAction(
        txn,
        orderId: orderId,
        orderNumber: orderRows.first['order_number'] as String?,
        action: 'edit',
        details: 'تعديل كمية "${item['product_name']}": $oldQty → $newQuantity',
        userId: userId,
        userName: userName,
      );
    });
  }

  /// إلغاء أوردر بالكامل — بيرجّع كل الكميات للمخزون (أصناف وخامات) ويسجّل السبب
  Future<void> cancelOrder({
    required String orderId,
    required String userId,
    required String userName,
    String? reason,
  }) async {
    final db = await database;
    final orderRows =
        await query('orders', where: 'id = ?', whereArgs: [orderId]);
    if (orderRows.isEmpty) return;
    final order = orderRows.first;
    if (order['status'] == 'cancelled') return;

    final items = await getOrderItemsFor(orderId);

    await db.transaction((txn) async {
      for (final item in items) {
        final productId = item['product_id'] as String;
        final qty = (item['quantity'] as num).toDouble();

        final productRows = await txn
            .query('products', where: 'id = ?', whereArgs: [productId]);
        if (productRows.isNotEmpty) {
          final before = (productRows.first['stock'] as num).toDouble();
          final after = before + qty;
          await txn.update(
            'products',
            {'stock': after, 'updated_at': DateTime.now().toIso8601String()},
            where: 'id = ?',
            whereArgs: [productId],
          );
          await txn.insert('stock_movements', {
            'id': generateId(),
            'product_id': productId,
            'product_name': item['product_name'],
            'type': 'return',
            'item_type': 'product',
            'quantity': qty,
            'stock_before': before,
            'stock_after': after,
            'order_id': orderId,
            'reason': 'إلغاء الطلب',
            'user_id': userId,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
        await restoreRawMaterialsForOrder(txn, productId, qty,
            orderId: orderId, reason: 'إلغاء الطلب');
      }

      await txn.update('orders', {'status': 'cancelled'},
          where: 'id = ?', whereArgs: [orderId]);

      await _logOrderAction(
        txn,
        orderId: orderId,
        orderNumber: order['order_number'] as String?,
        action: 'cancel',
        details: reason == null || reason.isEmpty
            ? 'إلغاء الطلب واسترجاع المخزون'
            : 'إلغاء الطلب: $reason',
        userId: userId,
        userName: userName,
      );
    });
  }

// ═══════════════════════════════════════════════════════════════
// 7) مصروف سريع أثناء الشيفت
// ═══════════════════════════════════════════════════════════════

  Future<void> addQuickExpense({
    required String category,
    required double amount,
    String? description,
    required String userId,
  }) async {
    final shift = await getCurrentShift();
    final now = DateTime.now().toIso8601String();
    await insert('expenses', {
      'id': generateId(),
      'category': category,
      'amount': amount,
      'description': description,
      'user_id': userId,
      'shift_id': shift?['id'],
      'date': now,
      'created_at': now,
    });
  }

  Future<void> closeDatabase() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
