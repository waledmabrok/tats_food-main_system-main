/// أدوار المستخدمين
enum UserRole {
  manager('مدير النظام'),
  cashier('كاشير');

  const UserRole(this.label);
  final String label;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => UserRole.cashier,
    );
  }
}

/// نموذج المستخدم
class AppUser {
  final String id;
  final String name;
  final String username;
  final String pin; // 4-digit PIN
  final UserRole role;
  final bool isActive;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.name,
    required this.username,
    required this.pin,
    required this.role,
    this.isActive = true,
    required this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      name: map['name'] as String,
      username: map['username'] as String,
      pin: map['pin'] as String,
      role: UserRole.fromString(map['role'] as String),
      isActive: (map['is_active'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'pin': pin,
      'role': role.name,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isManager => role == UserRole.manager;

  AppUser copyWith({
    String? name,
    String? username,
    String? pin,
    UserRole? role,
    bool? isActive,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      username: username ?? this.username,
      pin: pin ?? this.pin,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
}
