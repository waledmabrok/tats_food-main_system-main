import '../core/database/database_helper.dart';

class ShiftRepository {
  final _db = DatabaseHelper.instance;

  Future<Map<String, dynamic>?> getCurrentShift() => _db.getCurrentShift();

  Future<String> openShift({
    required String userId,
    required String userName,
    required double openingCash,
  }) =>
      _db.openShift(
          userId: userId, userName: userName, openingCash: openingCash);

  /// ملخص لحظي (يُستخدم للعرض والشيفت لسه مفتوح)
  Future<Map<String, dynamic>> getShiftSummary(String shiftId) =>
      _db.getShiftSummary(shiftId);

  /// قفل الشيفت بعد عدّ الدرج فعليًا — بيرجع الملخص + الفرق (عجز/زيادة)
  Future<Map<String, dynamic>> closeShift(
    String shiftId, {
    required double actualClosingCash,
    String? notes,
  }) =>
      _db.closeShift(shiftId,
          actualClosingCash: actualClosingCash, notes: notes);

  /// سجل الشيفتات، مع إمكانية فلترة بالتاريخ (based on opened_at)
  Future<List<Map<String, dynamic>>> getHistory({
    DateTime? from,
    DateTime? to,
    int limit = 200,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];

    if (from != null) {
      conditions.add("date(opened_at) >= date(?)");
      args.add(from.toIso8601String());
    }
    if (to != null) {
      conditions.add("date(opened_at) <= date(?)");
      args.add(to.toIso8601String());
    }

    return _db.query(
      'shifts',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'opened_at DESC',
      limit: limit,
    );
  }
}
