import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../repositories/order_repository.dart';
import '../../../../models/order.dart';

class SalesOverview extends StatefulWidget {
  const SalesOverview({super.key});

  @override
  State<SalesOverview> createState() => _SalesOverviewState();
}

class _SalesOverviewState extends State<SalesOverview> {
  final _orderRepo = OrderRepository();
  bool _isLoading = true;
  List<double> _weeklySales = List.filled(7, 0.0);
  final List<String> _days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
  double _maxSales = 100.0;

  @override
  void initState() {
    super.initState();
    _loadSalesData();
  }

  Future<void> _loadSalesData() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // إحضار المبيعات لآخر 7 أيام
    final start = today.subtract(const Duration(days: 6));
    final orders = await _orderRepo.getAll(from: start, status: OrderStatus.completed);

    final List<double> sales = List.filled(7, 0.0);
    for (var o in orders) {
      final daysDiff = o.createdAt.difference(start).inDays;
      if (daysDiff >= 0 && daysDiff < 7) {
        sales[daysDiff] += o.finalAmount;
      }
    }

    double maxVal = 0;
    for (var s in sales) {
      if (s > maxVal) maxVal = s;
    }
    
    // ترتيب الأيام عشان آخر يوم هو اليوم
    final List<String> sortedDays = [];
    for (int i = 0; i < 7; i++) {
      final date = start.add(Duration(days: i));
      sortedDays.add(_days[date.weekday % 7]);
    }

    if (mounted) {
      setState(() {
        _weeklySales = sales;
        _maxSales = maxVal == 0 ? 100 : maxVal;
        _isLoading = false;
        // نسخ الأيام
        for(int i = 0; i < 7; i++) {
          _days[i] = sortedDays[i];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCardHeader(
            title: AppStrings.salesOverviewTitle,
            subtitle: 'آخر 7 أيام',
            icon: Icons.show_chart_rounded,
            iconColor: AppColors.primary,
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppDimensions.cardPadding),
            child: _isLoading 
                ? const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()))
                : _RealBarChart(values: _weeklySales, maxVal: _maxSales, days: _days),
          ),
        ],
      ),
    );
  }
}

class _RealBarChart extends StatelessWidget {
  const _RealBarChart({required this.values, required this.maxVal, required this.days});
  final List<double> values;
  final double maxVal;
  final List<String> days;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final barWidth = (constraints.maxWidth - (7 * 16)) / 7;
          final availableWidth = barWidth > 40 ? 40.0 : barWidth;
          
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final ratio = values[i] / maxVal;
              final isToday = i == 6; // آخر يوم هو اليوم
              
              return Tooltip(
                message: '${values[i].toStringAsFixed(2)} ${AppStrings.currency}',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      values[i] > 0 ? values[i].toStringAsFixed(0) : '',
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary, fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: availableWidth,
                      height: (constraints.maxHeight - 50) * ratio + 4, // 4 min height
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            isToday ? AppColors.accent : AppColors.primary,
                            isToday ? AppColors.accent.withValues(alpha: 0.7) : AppColors.primary.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          if (isToday || values[i] > 0)
                            BoxShadow(
                              color: (isToday ? AppColors.accent : AppColors.primary).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      days[i],
                      style: AppTypography.caption.copyWith(
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                        color: isToday ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
