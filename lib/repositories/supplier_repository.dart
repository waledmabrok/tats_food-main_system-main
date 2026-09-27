import '../core/database/database_helper.dart';

class SupplierRepository {
  final _db = DatabaseHelper.instance;

  Future<List<Map<String, dynamic>>> getAll({bool activeOnly = true}) =>
      _db.getSuppliers(activeOnly: activeOnly);

  Future<String> addSupplier({
    required String name,
    String? phone,
    String? address,
    String? notes,
  }) =>
      _db.addSupplier(name: name, phone: phone, address: address, notes: notes);

  /// items: [{item_type: 'raw_material'|'product', item_id, item_name, quantity, unit_cost}]
  Future<String> receivePurchase({
    required String supplierId,
    required List<Map<String, dynamic>> items,
    required String paymentType, // 'cash' | 'credit'
    double paidAmount = 0,
    String? notes,
    String? userId,
  }) => _db.receivePurchase(
    supplierId: supplierId,
    items: items,
    paymentType: paymentType,
    paidAmount: paidAmount,
    notes: notes,
    userId: userId,
  );

  Future<void> paySupplier({
    required String supplierId,
    required double amount,
    String? invoiceId,
    String paymentMethod = 'cash',
    String? notes,
    String? userId,
  }) => _db.paySupplier(
    supplierId: supplierId,
    amount: amount,
    invoiceId: invoiceId,
    paymentMethod: paymentMethod,
    notes: notes,
    userId: userId,
  );

  Future<List<Map<String, dynamic>>> getInvoices(String supplierId) =>
      _db.getSupplierInvoices(supplierId);
}
