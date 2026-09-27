import 'package:flutter/material.dart';
import '../core/constants/app_strings.dart';
import '../core/routing/app_router.dart';
import '../core/widgets/app_top_bar.dart';
import '../core/widgets/empty_state_widget.dart';
import '../core/theme/app_colors.dart';

/// شاشة Placeholder للأقسام التي لم تُبنَ بعد
/// تُعرض عند الضغط على أي قسم غير لوحة التحكم
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.route,
  });

  final String title;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: title),
      body: EmptyStateWidget(
        icon: _getIcon(route),
        iconColor: AppColors.textDisabled,
        title: AppStrings.msgUnderConstruction,
        description: AppStrings.msgUnderConstructionDesc,
      ),
    );
  }

  IconData _getIcon(String route) {
    return switch (route) {
      AppRoutes.cashier => Icons.point_of_sale_outlined,
      AppRoutes.products => Icons.inventory_2_outlined,
      AppRoutes.inventory => Icons.warehouse_outlined,
      AppRoutes.orders => Icons.receipt_long_outlined,
      AppRoutes.reports => Icons.bar_chart_outlined,
      AppRoutes.expenses => Icons.account_balance_wallet_outlined,
      AppRoutes.settings => Icons.settings_outlined,
      _ => Icons.construction_outlined,
    };
  }
}
