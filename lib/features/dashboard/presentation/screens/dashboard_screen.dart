import 'package:flutter/material.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../repositories/order_repository.dart';
import '../../../../repositories/product_repository.dart';
import '../../../../models/order.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/summary_card.dart';
import '../widgets/sales_overview.dart';
import '../widgets/recent_orders.dart';
import '../widgets/low_stock_section.dart';
import 'order_audit_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _orderRepo = OrderRepository();
  final _productRepo = ProductRepository();

  double _salesToday = 0;
  int _ordersTotal = 0;
  int _itemsSold = 0;
  int _lowStockCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // المبيعات والطلبات اليوم
    final stats = await _orderRepo.getSalesStats(from: todayStart, to: now);
    _salesToday = (stats['total_sales'] as num).toDouble();
    _ordersTotal = (stats['order_count'] as num).toInt();
    _itemsSold = (stats['items_sold'] as num).toInt();

    // النواقص
    final lowStock = await DatabaseHelper.instance.getLowStockItems();
    _lowStockCount = lowStock.length;
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final summaryCards = [
      SummaryCardData(
        title: AppStrings.statSalesToday,
        value: _salesToday.toStringAsFixed(2),
        unit: AppStrings.currency,
        icon: Icons.payments_rounded,
        color: AppColors.statSales,
        trend: null,
      ),
      SummaryCardData(
        title: AppStrings.statOrdersTotal,
        value: _ordersTotal.toString(),
        unit: AppStrings.statOrder,
        icon: Icons.receipt_long_rounded,
        color: AppColors.statOrders,
        trend: null,
      ),
      SummaryCardData(
        title: AppStrings.statItemsSold,
        value: _itemsSold.toString(),
        unit: AppStrings.statItem,
        icon: Icons.shopping_bag_rounded,
        color: AppColors.statItems,
        trend: null,
      ),
      SummaryCardData(
        title: AppStrings.statLowStock,
        value: _lowStockCount.toString(),
        unit: AppStrings.statProduct,
        icon: Icons.warning_amber_rounded,
        color: AppColors.statStock,
        trend: null,
      ),
    ];

    return Scaffold(
      appBar: AppTopBar(
        title: AppStrings.dashboardTitle,
        action: SessionService.instance.isOwner
            ? IconButton(
                tooltip: 'سجل تعديلات وإلغاءات الأوردرات',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OrderAuditScreen()),
                ),
                icon: const Icon(Icons.fact_check_outlined),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DashboardHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppDimensions.space24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SummaryCardsGrid(cards: summaryCards),
                        const SizedBox(height: AppDimensions.sectionGap),
                        _SecondRow(),
                        const SizedBox(height: AppDimensions.sectionGap),
                        const RecentOrders(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SummaryCardsGrid extends StatelessWidget {
  const _SummaryCardsGrid({required this.cards});
  final List<SummaryCardData> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 600
                ? 2
                : 1;
        final itemWidth =
            (constraints.maxWidth - (AppDimensions.gridGap * (columns - 1))) /
                columns;

        return Wrap(
          spacing: AppDimensions.gridGap,
          runSpacing: AppDimensions.gridGap,
          children: cards.map((card) {
            return SizedBox(
              width: itemWidth,
              child: SummaryCard(data: card),
            );
          }).toList(),
        );
      },
    );
  }
}

class _SecondRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;

        if (isWide) {
          return const IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: SalesOverview()),
                SizedBox(width: AppDimensions.gridGap),
                Expanded(flex: 2, child: LowStockSection()),
              ],
            ),
          );
        }

        return const Column(
          children: [
            SalesOverview(),
            SizedBox(height: AppDimensions.gridGap),
            LowStockSection(),
          ],
        );
      },
    );
  }
}
