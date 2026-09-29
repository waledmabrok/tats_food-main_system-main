import '../core/database/database_helper.dart';

class RawMaterialRepository {
  final _db = DatabaseHelper.instance;
  Future<List<Map<String, dynamic>>> getLowStock() async {
    final all = await _db.getRawMaterials(activeOnly: true);
    return all.where((r) {
      final min = (r['min_stock'] as num).toDouble();
      final stock = (r['stock'] as num).toDouble();
      return min > 0 && stock <= min;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getAll({bool activeOnly = true}) =>
      _db.getRawMaterials(activeOnly: activeOnly);

  Future<String> add({
    required String name,
    required String unit,
    double costPerUnit = 0,
    double minStock = 0,
  }) =>
      _db.addRawMaterial(
        name: name,
        unit: unit,
        costPerUnit: costPerUnit,
        minStock: minStock,
      );
}
