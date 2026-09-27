import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/constants/app_strings.dart';
import 'core/database/database_helper.dart';
import 'core/services/device_lock_service.dart';
import 'core/services/restaurant_info_service.dart';
import 'core/widgets/device_locked_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // السماح بتحميل الخطوط من الإنترنت
  GoogleFonts.config.allowRuntimeFetching = true;

  // تهيئة قاعدة البيانات المحلية (SQLite عبر FFI للـ Windows)
  await DatabaseHelper.instance.database;
  await ThemeController.instance.load();
  await RestaurantInfoService.instance.loadFromDb();

  // ─── التحقق من ربط الجهاز ────────────────────────────────────────
  final deviceCheck = await DeviceLockService.instance.checkDevice();

  runApp(FoodProApp(isDeviceLocked: deviceCheck == DeviceCheckResult.mismatch));
}

/// نقطة الدخول الرئيسية لنظام فود برو
class FoodProApp extends StatefulWidget {
  const FoodProApp({super.key, required this.isDeviceLocked});
  final bool isDeviceLocked;

  @override
  State<FoodProApp> createState() => _FoodProAppState();
}

class _FoodProAppState extends State<FoodProApp> {
  @override
  void initState() {
    super.initState();
    ThemeController.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar'), Locale('en')],
      locale: const Locale('ar'),

      // ─── الـ Theme المركزي ─────────────────────────────────
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeController.instance.mode,

      // منع Flutter من عمل interpolation بين TextStyles
      // المختلفة عند تغيير Light / Dark.
      themeAnimationDuration: Duration.zero,

      home: widget.isDeviceLocked
          ? const DeviceLockedScreen()
          : const LoginScreen(),
    );
  }
}
