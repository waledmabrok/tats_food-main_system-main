import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';

/// خدمة مركزية لاسم المطعم — أي widget يستمع إليها يتحدث تلقائيًا
class RestaurantInfoService {
  RestaurantInfoService._();
  static final RestaurantInfoService instance = RestaurantInfoService._();

  /// اسم المطعم الحالي (يبدأ بقيمة فارغة ويُحدَّث من DB)
  final ValueNotifier<String> restaurantName = ValueNotifier<String>('');

  /// يُنادى مرة عند بدء التطبيق لتحميل الاسم المحفوظ
  Future<void> loadFromDb() async {
    final name = await DatabaseHelper.instance.getSetting('restaurant_name');
    if (name != null && name.trim().isNotEmpty) {
      restaurantName.value = name.trim();
    }
  }

  /// يُنادى عند حفظ الإعدادات لتحديث الاسم فورًا في كل الشاشات
  void update(String name) {
    restaurantName.value = name.trim();
  }
}
