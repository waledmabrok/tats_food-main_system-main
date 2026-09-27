import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'database_helper.dart';

class DeviceIdHelper {
  /// جلب الرقم التسلسلي للوحة الأم
  static Future<String> _getMotherboardSerial() async {
    try {
      final result = await Process.run('wmic', [
        'baseboard',
        'get',
        'serialnumber',
      ], runInShell: true);
      return _extractValue(result.stdout.toString());
    } catch (e) {
      return '';
    }
  }

  /// جلب معرف المعالج
  static Future<String> _getCpuId() async {
    try {
      final result = await Process.run('wmic', [
        'cpu',
        'get',
        'processorid',
      ], runInShell: true);
      return _extractValue(result.stdout.toString());
    } catch (e) {
      return '';
    }
  }

  /// جلب الرقم التسلسلي للهاردسك (اختياري لزيادة الدقة)
  static Future<String> _getDiskSerial() async {
    try {
      final result = await Process.run('wmic', [
        'diskdrive',
        'get',
        'serialnumber',
      ], runInShell: true);
      return _extractValue(result.stdout.toString());
    } catch (e) {
      return '';
    }
  }

  static String _extractValue(String output) {
    final lines = output
        .split('\n')
        .map((l) => l.trim())
        .where(
          (l) =>
              l.isNotEmpty &&
              !l.toLowerCase().contains('serialnumber') &&
              !l.toLowerCase().contains('processorid'),
        )
        .toList();
    return lines.isNotEmpty ? lines.first : '';
  }

  /// الدالة الرئيسية: بصمة الجهاز النهائية (Hashed)
  static Future<String> getDeviceFingerprint() async {
    final motherboard = await _getMotherboardSerial();
    final cpu = await _getCpuId();
    final disk = await _getDiskSerial();

    final raw = '$motherboard-$cpu-$disk';
    final bytes = utf8.encode(raw);
    final hash = sha256.convert(bytes);

    return hash.toString();
  }
}

class LicenseGuard {
  static Future<bool> validateDevice() async {
    final currentFingerprint = await DeviceIdHelper.getDeviceFingerprint();
    final savedFingerprint = await DatabaseHelper.instance.getSavedDeviceId();

    if (savedFingerprint == null) {
      // أول تشغيل: احفظ البصمة
      await DatabaseHelper.instance.saveDeviceId(currentFingerprint);
      return true;
    }

    return savedFingerprint == currentFingerprint;
  }
}
