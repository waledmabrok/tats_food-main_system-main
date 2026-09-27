import '../core/database/database_helper.dart';
import '../models/category.dart';

class CategoryRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<Category>> getAll({bool activeOnly = false}) async {
    final results = await _db.query(
      'categories',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'created_at ASC',
    );
    return results.map(Category.fromMap).toList();
  }

  Future<Category?> getById(String id) async {
    final results = await _db.query('categories', where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;
    return Category.fromMap(results.first);
  }

  Future<void> insert(Category category) async {
    await _db.insert('categories', category.toMap());
  }

  Future<void> update(Category category) async {
    await _db.update('categories', category.toMap(), 'id = ?', [category.id]);
  }

  Future<void> setActive(String id, bool isActive) async {
    await _db.update('categories', {'is_active': isActive ? 1 : 0}, 'id = ?', [id]);
  }

  Future<void> delete(String id) async {
    await _db.delete('categories', 'id = ?', [id]);
  }

  /// عدد المنتجات المرتبطة بالتصنيف
  Future<int> getProductCount(String categoryId) async {
    final results = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM products WHERE category_id = ? AND is_active = 1',
      [categoryId],
    );
    if (results.isEmpty) return 0;
    return (results.first['cnt'] as int?) ?? 0;
  }
}

