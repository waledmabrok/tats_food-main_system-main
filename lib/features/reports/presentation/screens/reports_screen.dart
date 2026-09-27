import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../repositories/expense_repository.dart';
import '../../../../repositories/order_repository.dart';
import '../../../../models/order.dart';

// ─── بيانات يوم واحد في الرسم البياني ───────────────────────────────────
class _DaySales {
  const _DaySales(this.label, this.amount);
  final String label;
  final double amount;
}

// ─── بيانات صنف مبيعات ───────────────────────────────────────────────────
class _TopProduct {
  const _TopProduct(this.name, this.qty, this.revenue);
  final String name;
  final double qty;
  final double revenue;
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _orderRepo = OrderRepository();
  final _expenseRepo = ExpenseRepository();

  bool _isLoading = true;
  DateTimeRange? _dateRange;

  double _totalSales = 0;
  double _totalExpenses = 0;
  int _ordersCount = 0;
  double _avgOrderValue = 0;
  double get _netProfit => _totalSales - _totalExpenses;

  List<_DaySales> _dailySales = [];
  List<_TopProduct> _topProducts = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    // المبيعات
    final orders = await _orderRepo.getAll(
      from: _dateRange?.start,
      to: _dateRange?.end,
      status: OrderStatus.completed,
    );
    _totalSales = orders.fold(0.0, (sum, o) => sum + o.finalAmount);
    _ordersCount = orders.length;
    _avgOrderValue = _ordersCount > 0 ? _totalSales / _ordersCount : 0;

    // المصروفات
    final expenses = await _expenseRepo.getAll(
      from: _dateRange?.start,
      to: _dateRange?.end,
    );
    _totalExpenses = expenses.fold(0.0, (sum, e) => sum + e.amount);

    // مبيعات يومية للرسم البياني (آخر 7 أيام)
    _dailySales = _buildDailySales(orders);

    // أكثر المنتجات مبيعاً
    _topProducts = await _buildTopProducts(orders);

    if (mounted) setState(() => _isLoading = false);
  }

  List<_DaySales> _buildDailySales(List<Order> orders) {
    final now = DateTime.now();
    final days = <_DaySales>[];
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayOrders = orders.where((o) =>
          o.createdAt.year == day.year &&
          o.createdAt.month == day.month &&
          o.createdAt.day == day.day);
      final total = dayOrders.fold(0.0, (sum, o) => sum + o.finalAmount);
      final dayNames = ['أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'];
      days.add(_DaySales(dayNames[day.weekday % 7], total));
    }
    return days;
  }

  Future<List<_TopProduct>> _buildTopProducts(List<Order> orders) async {
    // تجميع الأصناف المباعة من كل الطلبات
    final Map<String, double> qtyMap = {};
    final Map<String, double> revenueMap = {};
    final Map<String, String> nameMap = {};

    for (final order in orders) {
      // نجيب تفاصيل الطلب
      final full = await _orderRepo.getById(order.id);
      if (full == null) continue;
      for (final item in full.items) {
        qtyMap[item.productId] = (qtyMap[item.productId] ?? 0) + item.quantity;
        revenueMap[item.productId] = (revenueMap[item.productId] ?? 0) + item.totalPrice;
        nameMap[item.productId] = item.productName;
      }
    }

    final sorted = qtyMap.keys.toList()
      ..sort((a, b) => (qtyMap[b] ?? 0).compareTo(qtyMap[a] ?? 0));

    return sorted.take(5).map((id) => _TopProduct(
      nameMap[id] ?? id,
      qtyMap[id] ?? 0,
      revenueMap[id] ?? 0,
    )).toList();
  }

  void _setQuickDate(int days) {
    final now = DateTime.now();
    DateTime start, end;
    if (days == 0) {
      start = DateTime(now.year, now.month, now.day);
      end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (days == 1) {
      final yesterday = now.subtract(const Duration(days: 1));
      start = DateTime(yesterday.year, yesterday.month, yesterday.day);
      end = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
    } else if (days == 30) {
      start = DateTime(now.year, now.month, 1);
      end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    } else {
      start = now.subtract(Duration(days: days));
      end = now;
    }
    setState(() => _dateRange = DateTimeRange(start: start, end: end));
    _load();
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      locale: const Locale('ar'),
    );
    if (range != null) {
      setState(() => _dateRange = range);
      _load();
    }
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: AppStrings.reportsTitle),
      body: Column(
        children: [
          // ─── شريط الفلتر ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space16, vertical: AppDimensions.space12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),

            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range_outlined, size: 18),
                  label: Text(
                    _dateRange == null
                        ? 'كل التواريخ'
                        : '${_formatDate(_dateRange!.start)} — ${_formatDate(_dateRange!.end)}',
                    style: AppTypography.bodySmall,
                  ),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
                ),
                if (_dateRange != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      setState(() => _dateRange = null);
                      _load();
                    },
                  ),
                ],
                const SizedBox(width: AppDimensions.space16),
                TextButton(onPressed: () => _setQuickDate(0), child: const Text('اليوم')),
                TextButton(onPressed: () => _setQuickDate(1), child: const Text('أمس')),
                TextButton(onPressed: () => _setQuickDate(7), child: const Text('آخر 7 أيام')),
                TextButton(onPressed: () => _setQuickDate(30), child: const Text('هذا الشهر')),
              ],
            ),
          ),

          // ─── المحتوى ──────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(AppDimensions.space24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─── بطاقات الملخص ───────────────────────────
                        LayoutBuilder(builder: (ctx, constraints) {
                          final w = constraints.maxWidth;
                          final cols = w > 900 ? 4 : w > 600 ? 2 : 1;
                          return GridView.count(
                            crossAxisCount: cols,
                            crossAxisSpacing: AppDimensions.space16,
                            mainAxisSpacing: AppDimensions.space16,
                            childAspectRatio: w > 900 ? 2.0 : 2.2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _StatCard(
                                title: 'إجمالي المبيعات',
                                value: '${_totalSales.toStringAsFixed(2)} ${AppStrings.currency}',
                                icon: Icons.point_of_sale_rounded,
                                color: AppColors.primary,
                                subtitle: '$_ordersCount طلب',
                              ),
                              _StatCard(
                                title: 'متوسط الطلب',
                                value: '${_avgOrderValue.toStringAsFixed(2)} ${AppStrings.currency}',
                                icon: Icons.analytics_rounded,
                                color: AppColors.info,
                                subtitle: 'لكل طلب',
                              ),
                              _StatCard(
                                title: 'إجمالي المصروفات',
                                value: '${_totalExpenses.toStringAsFixed(2)} ${AppStrings.currency}',
                                icon: Icons.account_balance_wallet_rounded,
                                color: AppColors.warning,
                                subtitle: 'هذه الفترة',
                              ),
                              _StatCard(
                                title: 'صافي الربح',
                                value: '${_netProfit.toStringAsFixed(2)} ${AppStrings.currency}',
                                icon: _netProfit >= 0
                                    ? Icons.trending_up_rounded
                                    : Icons.trending_down_rounded,
                                color: _netProfit >= 0 ? AppColors.success : AppColors.error,
                                subtitle: _netProfit >= 0 ? 'ربح' : 'خسارة',
                              ),
                            ],
                          );
                        }),

                        const SizedBox(height: AppDimensions.space32),

                        // ─── الرسم البياني + الأصناف ──────────────────
                        LayoutBuilder(builder: (ctx, constraints) {
                          final wide = constraints.maxWidth > 700;
                          if (wide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: _buildBarChart()),
                                const SizedBox(width: AppDimensions.space24),
                                Expanded(flex: 2, child: _buildTopProductsCard()),
                              ],
                            );
                          }
                          return Column(children: [
                            _buildBarChart(),
                            const SizedBox(height: AppDimensions.space24),
                            _buildTopProductsCard(),
                          ]);
                        }),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('مبيعات آخر 7 أيام', style: AppTypography.titleMedium),
            ],
          ),
          const SizedBox(height: AppDimensions.space24),
          SizedBox(
            height: 220,
            child: _dailySales.isEmpty || _dailySales.every((d) => d.amount == 0)
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bar_chart_outlined, size: 48, color: AppColors.textDisabled),
                        const SizedBox(height: 8),

                        Text(
                          'لا توجد مبيعات في هذه الفترة',
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : CustomPaint(
                    size: const Size(double.infinity, 220),
                    painter: _BarChartPainter(
                      data: _dailySales,
                      barColor: AppColors.primary,
                      labelColor: AppColors.textSecondary,
                      gridColor: AppColors.divider,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsCard() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Text('الأصناف الأكثر مبيعاً', style: AppTypography.titleMedium),
            ],
          ),

          const SizedBox(height: AppDimensions.space16),
          if (_topProducts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'لا توجد مبيعات لعرضها',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...List.generate(_topProducts.length, (i) {
              final p = _topProducts[i];
              final maxQty = _topProducts.map((x) => x.qty).reduce(math.max);
              final ratio = maxQty > 0 ? p.qty / maxQty : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.space12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _rankColor(i).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: AppTypography.caption.copyWith(
                                color: _rankColor(i),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            p.name,
                            style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${p.qty.toStringAsFixed(0)} وحدة',
                          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: ratio),
                        duration: const Duration(milliseconds: 600),
                        builder: (ctx, val, _) => LinearProgressIndicator(
                          value: val,
                          backgroundColor: AppColors.surfaceVariant,
                          valueColor: AlwaysStoppedAnimation(_rankColor(i)),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${p.revenue.toStringAsFixed(2)} ${AppStrings.currency}',
                        style: AppTypography.caption.copyWith(
                          color: _rankColor(i),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Color _rankColor(int i) {
    final colors = [
      const Color(0xFFF59E0B), // ذهبي
      const Color(0xFF94A3B8), // فضي
      const Color(0xFFCD7F32), // برونزي
      AppColors.primary,
      AppColors.info,
    ];
    return colors[i % colors.length];
  }

}

// ─── BarChart CustomPainter ────────────────────────────────────────────────
class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.data,
    required this.barColor,
    required this.labelColor,
    required this.gridColor,
  });

  final List<_DaySales> data;
  final Color barColor;
  final Color labelColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxVal = data.map((d) => d.amount).reduce(math.max);
    if (maxVal == 0) return;

    const paddingBottom = 36.0;
    const paddingTop = 16.0;
    const paddingLeft = 8.0;
    const paddingRight = 8.0;

    final chartH = size.height - paddingBottom - paddingTop;
    final chartW = size.width - paddingLeft - paddingRight;
    final barCount = data.length;
    final barWidth = (chartW / barCount) * 0.55;
    final gap = (chartW / barCount) * 0.45;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    final barPaint = Paint()..color = barColor;

    final textPainter = TextPainter(textDirection: TextDirection.rtl);

    // خطوط الشبكة
    for (int i = 0; i <= 4; i++) {
      final y = paddingTop + chartH - (chartH * i / 4);
      canvas.drawLine(
        Offset(paddingLeft, y),
        Offset(size.width - paddingRight, y),
        gridPaint,
      );

      // قيمة Y
      final val = (maxVal * i / 4).toStringAsFixed(0);
      textPainter.text = TextSpan(
        text: val,
        style: TextStyle(
          color: labelColor,
          fontSize: 9,
          fontFamily: 'Tajawal',
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(paddingLeft, y - 10));
    }

    // الأعمدة
    for (int i = 0; i < barCount; i++) {
      final d = data[i];
      final barH = chartH * (d.amount / maxVal);
      final x = paddingLeft + i * (barWidth + gap) + gap / 2;
      final y = paddingTop + chartH - barH;

      // العمود
      final rRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, barWidth, barH),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      canvas.drawRRect(rRect, barPaint);

      // القيمة فوق العمود
      if (d.amount > 0) {
        textPainter.text = TextSpan(
          text: d.amount >= 1000
              ? '${(d.amount / 1000).toStringAsFixed(1)}k'
              : d.amount.toStringAsFixed(0),
          style: TextStyle(
            color: barColor,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            fontFamily: 'Tajawal',
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x + barWidth / 2 - textPainter.width / 2, y - 14),
        );
      }

      // اسم اليوم
      textPainter.text = TextSpan(
        text: d.label,
        style: TextStyle(
          color: labelColor,
          fontSize: 10,
          fontFamily: 'Tajawal',
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          x + barWidth / 2 - textPainter.width / 2,
          size.height - paddingBottom + 6,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) => old.data != data;
}

// ─── بطاقة إحصاء ─────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTypography.titleLarge.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: AppTypography.caption.copyWith(color: AppColors.textDisabled),
            ),
        ],
      ),
    );
  }
}
