import '../core/database/database_helper.dart';
import '../models/app_user.dart';

class UserRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<AppUser>> getAll() async {
    final results = await _db.query('users', orderBy: 'created_at ASC');
    return results.map(AppUser.fromMap).toList();
  }

  Future<AppUser?> authenticate(String username, String pin) async {
    final results = await _db.query(
      'users',
      where: 'username = ? AND pin = ? AND is_active = 1',
      whereArgs: [username, pin],
    );
    if (results.isEmpty) return null;
    return AppUser.fromMap(results.first);
  }

  Future<AppUser?> getById(String id) async {
    final results = await _db.query('users', where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;
    return AppUser.fromMap(results.first);
  }

  Future<void> insert(AppUser user) async {
    await _db.insert('users', user.toMap());
  }

  Future<void> update(AppUser user) async {
    await _db.update('users', user.toMap(), 'id = ?', [user.id]);
  }

  Future<void> setActive(String id, bool isActive) async {
    await _db.update('users', {'is_active': isActive ? 1 : 0}, 'id = ?', [id]);
  }

  Future<bool> changePin({
    required String userId,
    required String currentPin,
    required String newPin,
  }) async {
    final results = await _db.query(
      'users',
      where: 'id = ? AND pin = ? AND is_active = 1',
      whereArgs: [userId, currentPin],
    );
    if (results.isEmpty) return false;
    await _db.update('users', {'pin': newPin}, 'id = ?', [userId]);
    return true;
  }

  Future<bool> usernameExists(String username, {String? excludeId}) async {
    final results = await _db.query(
      'users',
      where: excludeId != null ? 'username = ? AND id != ?' : 'username = ?',
      whereArgs: excludeId != null ? [username, excludeId] : [username],
    );
    return results.isNotEmpty;
  }
}
