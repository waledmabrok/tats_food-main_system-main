import '../core/database/database_helper.dart';
import '../models/stock_movement.dart';

class StockRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<StockMovement>> getAll({
    String? productId,
    DateTime? from,
    DateTime? to,
    int? limit,
    int? offset,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];

    if (productId != null) {
      conditions.add('product_id = ?');
      args.add(productId);
    }
    if (from != null) {
      conditions.add("date(created_at) >= date(?)");
      args.add(from.toIso8601String());
    }
    if (to != null) {
      conditions.add("date(created_at) <= date(?)");
      args.add(to.toIso8601String());
    }

    final results = await _db.query(
      'stock_movements',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return results.map(StockMovement.fromMap).toList();
  }

  Future<void> delete(String id) async {
    await _db.delete('stock_movements', 'id = ?', [id]);
  }
}
