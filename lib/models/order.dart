/// أنواع طرق الدفع
enum PaymentMethod {
  cash('نقدي'),
  vodafone('فودافون كاش'),
  card('بطاقة'),
  other('أخرى');

  const PaymentMethod(this.label);
  final String label;

  static PaymentMethod fromString(String value) {
    return PaymentMethod.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PaymentMethod.cash,
    );
  }
}

/// حالات الطلب
enum OrderStatus {
  completed('مكتمل'),
  cancelled('ملغي'),
  refunded('مسترد');

  const OrderStatus(this.label);
  final String label;

  static OrderStatus fromString(String value) {
    return OrderStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => OrderStatus.completed,
    );
  }
}

enum OrderType {
  delivery('دليفري'),
  takeaway('تيك أواي');

  const OrderType(this.label);
  final String label;

  static OrderType fromString(String? value) {
    return OrderType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => OrderType.takeaway,
    );
  }
}

/// نموذج عنصر الطلب
class OrderItem {
  final String id;
  final String orderId;
  final String productId;
  final String productName;
  final double unitPrice;
  final double quantity;
  final double totalPrice;

  const OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.totalPrice,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as String,
      orderId: map['order_id'] as String,
      productId: map['product_id'] as String,
      productName: map['product_name'] as String,
      unitPrice: (map['unit_price'] as num).toDouble(),
      quantity: (map['quantity'] as num).toDouble(),
      totalPrice: (map['total_price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'product_name': productName,
      'unit_price': unitPrice,
      'quantity': quantity,
      'total_price': totalPrice,
    };
  }
}

/// نموذج الطلب
class Order {
  final String id;
  final String orderNumber;
  final String? userId;
  final String? userName;
  final double subtotal;
  final double discountAmount;
  final double finalAmount;
  final double paidAmount;
  final double changeAmount;
  final PaymentMethod paymentMethod;
  final OrderType orderType;
  final String? customerId;
  final String? deliveryAddress;
  final double deliveryFee;
  final String? paymentRef;
  final OrderStatus status;
  final String? notes;
  final List<OrderItem> items;
  final DateTime createdAt;

  const Order({
    required this.id,
    required this.orderNumber,
    this.userId,
    this.userName,
    required this.subtotal,
    this.discountAmount = 0,
    required this.finalAmount,
    required this.paidAmount,
    this.changeAmount = 0,
    required this.paymentMethod,
    this.orderType = OrderType.takeaway,
    this.customerId,
    this.deliveryAddress,
    this.deliveryFee = 0,
    this.paymentRef,
    this.status = OrderStatus.completed,
    this.notes,
    this.items = const [],
    required this.createdAt,
  });

  factory Order.fromMap(Map<String, dynamic> map, {List<OrderItem>? items}) {
    return Order(
      id: map['id'] as String,
      orderNumber: map['order_number'] as String,
      userId: map['user_id'] as String?,
      userName: map['user_name'] as String?,
      subtotal: (map['subtotal'] as num).toDouble(),
      discountAmount: (map['discount_amount'] as num).toDouble(),
      finalAmount: (map['final_amount'] as num).toDouble(),
      paidAmount: (map['paid_amount'] as num).toDouble(),
      changeAmount: (map['change_amount'] as num).toDouble(),
      paymentMethod: PaymentMethod.fromString(map['payment_method'] as String),
      orderType: OrderType.fromString(map['order_type'] as String?),
      customerId: map['customer_id'] as String?,
      deliveryAddress: map['delivery_address'] as String?,
      deliveryFee: (map['delivery_fee'] as num?)?.toDouble() ?? 0,
      paymentRef: map['payment_ref'] as String?,
      status: OrderStatus.fromString(map['status'] as String),
      notes: map['notes'] as String?,
      items: items ?? [],
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_number': orderNumber,
      'user_id': userId,
      'user_name': userName,
      'subtotal': subtotal,
      'discount_amount': discountAmount,
      'final_amount': finalAmount,
      'paid_amount': paidAmount,
      'change_amount': changeAmount,
      'payment_method': paymentMethod.name,
      'order_type': orderType.name,
      'customer_id': customerId,
      'delivery_address': deliveryAddress,
      'delivery_fee': deliveryFee,
      'payment_ref': paymentRef,
      'status': status.name,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
