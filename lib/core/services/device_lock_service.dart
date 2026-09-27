import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../database/database_helper.dart';

/// نتيجة التحقق من ربط الجهاز
enum DeviceCheckResult {
  ok, // الجهاز مطابق أو تم تسجيله لأول مرة
  mismatch, // التطبيق منقول لجهاز مختلف عن الجهاز المسجل
}

/// خدمة بصمة الجهاز — تمنع نسخ فولدر التطبيق وتشغيله على جهاز آخر
class DeviceLockService {
  DeviceLockService._();
  static final DeviceLockService instance = DeviceLockService._();

  static const _settingKey = 'device_fingerprint_hash';

  /// الحصول على معرّف فريد للجهاز (UUID اللوحة الأم على Windows)
  Future<String> _getRawDeviceId() async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('wmic', ['csproduct', 'get', 'UUID']);
        if (result.exitCode == 0) {
          final lines = (result.stdout as String)
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty && l.toUpperCase() != 'UUID')
              .toList();
          if (lines.isNotEmpty &&
              lines.first != 'FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF') {
            return lines.first;
          }
        }
        // محاولة احتياطية: الرقم التسلسلي للـ BIOS
        final bios = await Process.run('wmic', ['bios', 'get', 'serialnumber']);
        if (bios.exitCode == 0) {
          final lines = (bios.stdout as String)
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty && l.toUpperCase() != 'SERIALNUMBER')
              .toList();
          if (lines.isNotEmpty) return lines.first;
        }
      }
    } catch (_) {
      // تجاهل وننتقل للـ fallback
    }
    // Fallback عام (لو ويندوز فشل أو نظام تشغيل تاني): اسم الجهاز + عدد المعالجات
    return '${Platform.localHostname}-${Platform.numberOfProcessors}-${Platform.operatingSystem}';
  }

  /// تجزئة (hash) المعرّف قبل التخزين — عشان محدش يقرأه مباشرة من الداتابيز
  String _hash(String raw) {
    return sha256.convert(utf8.encode(raw)).toString();
  }

  /// التحقق من ربط الجهاز عند بدء التشغيل.
  /// أول مرة: يسجل بصمة الجهاز الحالي كبصمة معتمدة ويرجع ok.
  /// المرات اللي بعدها: يقارن، ولو اختلفت يرجع mismatch.
  Future<DeviceCheckResult> checkDevice() async {
    final rawId = await _getRawDeviceId();
    final currentHash = _hash(rawId);

    final storedHash = await DatabaseHelper.instance.getSetting(_settingKey);

    if (storedHash == null || storedHash.isEmpty) {
      // أول تشغيل: سجّل بصمة الجهاز الحالي
      await DatabaseHelper.instance.setSetting(_settingKey, currentHash);
      return DeviceCheckResult.ok;
    }

    if (storedHash == currentHash) {
      return DeviceCheckResult.ok;
    }

    return DeviceCheckResult.mismatch;
  }
}
