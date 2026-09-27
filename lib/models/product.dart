/// نموذج الصنف (المنتج)
class Product {
  final String id;
  final String categoryId;
  final String name;
  final double price;
  final double? cost;
  final double stock;
  final double minStock;
  final String unit;
  final String? icon;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.price,
    this.cost,
    this.stock = 0,
    this.minStock = 0,
    this.unit = 'وحدة',
    this.icon,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      categoryId: map['category_id'] as String,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      cost: map['cost'] != null ? (map['cost'] as num).toDouble() : null,
      stock: (map['stock'] as num).toDouble(),
      minStock: (map['min_stock'] as num).toDouble(),
      unit: map['unit'] as String? ?? 'وحدة',
      icon: map['icon'] as String?,
      isActive: (map['is_active'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'price': price,
      'cost': cost,
      'stock': stock,
      'min_stock': minStock,
      'unit': unit,
      'icon': icon,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isLowStock => stock <= minStock && minStock > 0;

  Product copyWith({
    String? categoryId,
    String? name,
    double? price,
    double? cost,
    double? stock,
    double? minStock,
    String? unit,
    bool? isActive,
  }) {
    return Product(
      id: id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      unit: unit ?? this.unit,
      icon: icon ?? icon,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
