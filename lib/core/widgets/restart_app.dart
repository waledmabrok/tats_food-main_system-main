import 'dart:io';
import 'package:flutter/foundation.dart';

/// إعادة تشغيل التطبيق بالكامل — بيقفل الـ process الحالي فعليًا
/// ويفتح نسخة جديدة تمامًا من البرنامج (زي قفل الـ exe وفتحه تاني بإيدك).
///
/// ده مختلف عن RestartWidget: RestartWidget بيعيد بناء شجرة الـ widgets
/// بس من غير ما يقفل البرنامج (سريع، بيحافظ على حالة العملية الجارية).
/// الدالة دي بتعمل قفل وفتح حقيقي للبرنامج بالكامل — استخدمها لما تحتاج
/// كل حاجة تترجع لحالتها الأولى تمامًا (اتصال قاعدة البيانات، إعدادات
/// الجهاز، أي متغيرات static اتحمّلت من الأول).
///
/// شغالة بس على Desktop (Windows/Linux/macOS) — مش متاحة على الويب
/// أو الموبايل، لأن مفهوم "process منفصل" مش موجود هناك.
class AppRestartService {
  AppRestartService._();

  static bool get isSupported =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  /// يفتح نسخة جديدة من نفس الـ .exe ويقفل النسخة الحالية فورًا.
  /// استدعيها كآخر حاجة تعملها — أي كود بعدها مش هيتنفذ.
  static Future<void> restartCompletely() async {
    if (!isSupported) return;

    final executable = Platform.resolvedExecutable;
    final arguments = Platform.executableArguments;
    final workingDirectory = File(executable).parent.path;

    // يفتح نسخة جديدة "منفصلة" (detached) — يعني هتفضل شغالة
    // حتى لو النسخة الحالية قفلت
    await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      mode: ProcessStartMode.detached,
    );

    // قفل النسخة الحالية بالكامل
    exit(0);
  }
}
