/// نموذج المصروف
class Expense {
  final String id;
  final String category;
  final double amount;
  final String? description;
  final String? userId;
  final DateTime date;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.category,
    required this.amount,
    this.description,
    this.userId,
    required this.date,
    required this.createdAt,
  });

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String?,
      userId: map['user_id'] as String?,
      date: DateTime.parse(map['date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'amount': amount,
      'description': description,
      'user_id': userId,
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// تصنيفات المصروفات المتاحة
abstract final class ExpenseCategories {
  static const List<String> all = [
    'كهرباء',
    'مياه',
    'إيجار',
    'رواتب',
    'مشتريات خامات',
    'صيانة',
    'تسويق',
    'أخرى',
  ];
}
