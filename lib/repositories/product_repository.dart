import '../core/database/database_helper.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';

class ProductRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<Product>> getAll({
    bool activeOnly = false,
    String? categoryId,
    int? limit,
    int? offset,
  }) async {
    String? where;
    List<dynamic>? whereArgs;

    if (activeOnly && categoryId != null) {
      where = 'is_active = 1 AND category_id = ?';
      whereArgs = [categoryId];
    } else if (activeOnly) {
      where = 'is_active = 1';
    } else if (categoryId != null) {
      where = 'category_id = ?';
      whereArgs = [categoryId];
    }

    final results = await _db.query(
      'products',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'name ASC',
      limit: limit,
      offset: offset,
    );
    return results.map(Product.fromMap).toList();
  }

  Future<List<Product>> search(String query, {int? limit, int? offset}) async {
    final results = await _db.query(
      'products',
      where: 'is_active = 1 AND name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name ASC',
      limit: limit,
      offset: offset,
    );
    return results.map(Product.fromMap).toList();
  }

  Future<List<Product>> getLowStock({int? limit, int? offset}) async {
    String sql = 'SELECT * FROM products WHERE is_active = 1 AND min_stock > 0 AND stock <= min_stock ORDER BY stock ASC';
    
    if (limit != null) {
      sql += ' LIMIT $limit';
      if (offset != null) {
        sql += ' OFFSET $offset';
      }
    }
    
    final results = await _db.rawQuery(sql);
    return results.map(Product.fromMap).toList();
  }

  Future<Product?> getById(String id) async {
    final results = await _db.query('products', where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;
    return Product.fromMap(results.first);
  }

  Future<void> insert(Product product) async {
    await _db.insert('products', product.toMap());
  }

  Future<void> _update(Product product) async {
    await _db.runTransaction((txn) async {
      await txn.update('products', product.toMap(), where: 'id = ?', whereArgs: [product.id]);
      await txn.update('stock_movements', {'product_name': product.name}, where: 'product_id = ?', whereArgs: [product.id]);
      await txn.update('order_items', {'product_name': product.name}, where: 'product_id = ?', whereArgs: [product.id]);
    });
  }

  Future<void> update(Product product) async {
    await _update(product);
  }

  Future<void> setActive(String id, bool isActive) async {
    await _db.update('products', {
      'is_active': isActive ? 1 : 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, 'id = ?', [id]);
  }

  Future<void> delete(String id) async {
    await _db.delete('products', 'id = ?', [id]);
  }

  /// خصم المخزون عند البيع مع تسجيل الحركة — ضمن Transaction
  Future<void> deductStockForOrder({
    required String orderId,
    required List<({String productId, double quantity})> items,
    required String? userId,
  }) async {
    await _db.runTransaction((txn) async {
      for (final item in items) {
        final productResults = await txn.query('products', where: 'id = ?', whereArgs: [item.productId]);
        if (productResults.isEmpty) continue;

        final product = Product.fromMap(productResults.first);
        final newStock = (product.stock - item.quantity).clamp(0, double.infinity);

        await txn.update(
          'products',
          {'stock': newStock, 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [item.productId],
        );

        await txn.insert('stock_movements', {
          'id': DatabaseHelper.generateId(),
          'product_id': item.productId,
          'product_name': product.name,
          'type': StockMovementType.sale.name,
          'quantity': item.quantity,
          'stock_before': product.stock,
          'stock_after': newStock,
          'order_id': orderId,
          'reason': 'بيع',
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  /// إضافة مخزون يدوياً
  Future<void> addStock({
    required String productId,
    required double quantity,
    required String reason,
    String? notes,
    String? userId,
  }) async {
    await _db.runTransaction((txn) async {
      final results = await txn.query('products', where: 'id = ?', whereArgs: [productId]);
      if (results.isEmpty) return;
      final product = Product.fromMap(results.first);
      final newStock = product.stock + quantity;

      await txn.update('products', {
        'stock': newStock,
        'updated_at': DateTime.now().toIso8601String(),
      }, where: 'id = ?', whereArgs: [productId]);

      await txn.insert('stock_movements', {
        'id': DatabaseHelper.generateId(),
        'product_id': productId,
        'product_name': product.name,
        'type': StockMovementType.stockIn.name,
        'quantity': quantity,
        'stock_before': product.stock,
        'stock_after': newStock,
        'reason': reason,
        'notes': notes,
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }
}
