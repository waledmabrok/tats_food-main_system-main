import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> load() async {
    final value = await DatabaseHelper.instance.getSetting('theme_mode');
    _mode = value == 'light' ? ThemeMode.light : ThemeMode.dark;
  }


  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    await DatabaseHelper.instance.setSetting(
      'theme_mode',
      mode == ThemeMode.light ? 'light' : 'dark',
    );
    notifyListeners();
  }
}
