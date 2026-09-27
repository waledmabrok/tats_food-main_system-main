/// نموذج تصنيف الأصناف
class Category {
  final String id;
  final String name;
  final String? colorHex;
  final bool isActive;
  final DateTime createdAt;

  const Category({
    required this.id,
    required this.name,
    this.colorHex,
    this.isActive = true,
    required this.createdAt,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      colorHex: map['color_hex'] as String?,
      isActive: (map['is_active'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color_hex': colorHex,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Category copyWith({
    String? name,
    String? colorHex,
    bool? isActive,
  }) {
    return Category(
      id: id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
}
