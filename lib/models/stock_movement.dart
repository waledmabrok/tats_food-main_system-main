/// أنواع حركة المخزون
enum StockMovementType {
  stockIn('إضافة مخزون'),
  stockOut('خصم مخزون'),
  sale('بيع'),
  adjustment('تعديل');

  const StockMovementType(this.label);
  final String label;

  static StockMovementType fromString(String value) {
    return StockMovementType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => StockMovementType.adjustment,
    );
  }
}

/// نموذج حركة المخزون
class StockMovement {
  final String id;
  final String productId;
  final String productName;
  final StockMovementType type;
  final double quantity;
  final double stockBefore;
  final double stockAfter;
  final String? orderId;
  final String? reason;
  final String? notes;
  final String? userId;
  final DateTime createdAt;

  const StockMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    required this.stockBefore,
    required this.stockAfter,
    this.orderId,
    this.reason,
    this.notes,
    this.userId,
    required this.createdAt,
  });

  factory StockMovement.fromMap(Map<String, dynamic> map) {
    return StockMovement(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      productName: map['product_name'] as String,
      type: StockMovementType.fromString(map['type'] as String),
      quantity: (map['quantity'] as num).toDouble(),
      stockBefore: (map['stock_before'] as num).toDouble(),
      stockAfter: (map['stock_after'] as num).toDouble(),
      orderId: map['order_id'] as String?,
      reason: map['reason'] as String?,
      notes: map['notes'] as String?,
      userId: map['user_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'type': type.name,
      'quantity': quantity,
      'stock_before': stockBefore,
      'stock_after': stockAfter,
      'order_id': orderId,
      'reason': reason,
      'notes': notes,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
