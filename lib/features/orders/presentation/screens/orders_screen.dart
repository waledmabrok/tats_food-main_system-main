import 'package:flutter/material.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../models/order.dart';
import '../../../../repositories/order_repository.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _repo = OrderRepository();
  final ScrollController _scrollController = ScrollController();
  List<Order> _orders = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 50;

  DateTimeRange? _dateRange;
  OrderStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _offset = 0;
      _hasMore = true;
    });
    final orders = await _repo.getAll(
      from: _dateRange?.start,
      to: _dateRange?.end,
      status: _statusFilter,
      limit: _limit,
      offset: _offset,
    );
    if (mounted) {
      setState(() {
        _orders = orders;
        _hasMore = orders.length == _limit;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    _offset += _limit;
    final newOrders = await _repo.getAll(
      from: _dateRange?.start,
      to: _dateRange?.end,
      status: _statusFilter,
      limit: _limit,
      offset: _offset,
    );
    if (mounted) {
      setState(() {
        _orders.addAll(newOrders);
        _hasMore = newOrders.length == _limit;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: AppStrings.ordersTitle),
      body: Column(
        children: [
          // ─── شريط الفلتر ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space16,
              vertical: AppDimensions.space12,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                // فلتر الحالة
                DropdownButtonHideUnderline(
                  child: DropdownButton<OrderStatus?>(
                    value: _statusFilter,
                    hint: Text('كل الحالات', style: AppTypography.bodyMedium),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('كل الحالات'),
                      ),
                      ...OrderStatus.values.map(
                        (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _statusFilter = v);
                      _loadInitialData();
                    },
                  ),
                ),
                const SizedBox(width: AppDimensions.space16),

                // فلتر التاريخ
                OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range_outlined, size: 18),
                  label: Text(
                    _dateRange == null
                        ? 'كل التواريخ'
                        : '${_formatDate(_dateRange!.start)} — ${_formatDate(_dateRange!.end)}',
                    style: AppTypography.bodySmall,
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                  ),
                ),
                if (_dateRange != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      setState(() => _dateRange = null);
                      _loadInitialData();
                    },
                  ),
                ],

                const Spacer(),
                Text(
                  '${_orders.length} طلب',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // ─── الجدول ────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                    ? const EmptyStateWidget(
                        icon: Icons.receipt_long_outlined,
                        title: AppStrings.orderNoOrders,
                        description: AppStrings.orderNoOrdersDesc,
                      )
                    : _buildTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.space24),
      child: Column(
        children: [
          // رأس الجدول
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space16,
              vertical: AppDimensions.space10,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDimensions.radiusMd),
              ),
              border: Border(
                top: BorderSide(color: AppColors.border),
                left: BorderSide(color: AppColors.border),
                right: BorderSide(color: AppColors.border),
              ),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: _TH('رقم الطلب')),
                Expanded(flex: 2, child: _TH('التاريخ')),
                Expanded(flex: 1, child: _TH('الوقت')),
                Expanded(flex: 2, child: _TH('الكاشير')),
                Expanded(flex: 2, child: _TH('الإجمالي')),
                Expanded(flex: 2, child: _TH('طريقة الدفع')),
                Expanded(flex: 2, child: _TH('الحالة')),
                SizedBox(width: 80),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppDimensions.radiusMd),
                ),
              ),
              child: ListView.separated(
                controller: _scrollController,
                itemCount: _orders.length + (_isLoadingMore ? 1 : 0),
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: AppColors.divider),
                itemBuilder: (ctx, i) {
                  if (i == _orders.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return _OrderRow(
                    order: _orders[i],
                    onView: () => _showOrderDetails(_orders[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(Order order) async {
    // تحميل تفاصيل الطلب
    final fullOrder = await _repo.getById(order.id);
    if (!mounted || fullOrder == null) return;
    final changed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _OrderDetailDialog(order: fullOrder),
    );
    // لو الطلب اتلغى من جوه الديالوج، حدّث الجدول عشان الحالة والإحصائيات تتحدث
    if (changed == true) {
      _loadInitialData();
    }
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
      _loadInitialData();
    }
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

class _TH extends StatelessWidget {
  const _TH(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTypography.bodySmall.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _OrderRow extends StatefulWidget {
  const _OrderRow({required this.order, required this.onView});
  final Order order;
  final VoidCallback onView;

  @override
  State<_OrderRow> createState() => _OrderRowState();
}

class _OrderRowState extends State<_OrderRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hovered ? AppColors.surfaceVariant : Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical: AppDimensions.space12,
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                '#${o.orderNumber}',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _formatDateLocal(o.createdAt),
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                _formatTimeLocal(o.createdAt),
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(o.userName ?? '—', style: AppTypography.bodySmall),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${o.finalAmount.toStringAsFixed(2)} ${AppStrings.currency}',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                o.paymentMethod.label,
                style: AppTypography.bodySmall,
              ),
            ),
            Expanded(flex: 2, child: _OrderStatusBadge(o.status)),
            SizedBox(
              width: 80,
              child: TextButton(
                onPressed: widget.onView,
                child: const Text('عرض', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateLocal(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatTimeLocal(DateTime dt) {
    int h = dt.hour;
    final ampm = h >= 12 ? 'م' : 'ص';
    if (h > 12) h -= 12;
    if (h == 0) h = 12;
    final hour = h.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $ampm';
  }
}

class _OrderStatusBadge extends StatelessWidget {
  const _OrderStatusBadge(this.status);
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final Color bg, fg;
    switch (status) {
      case OrderStatus.completed:
        bg = AppColors.successLight;
        fg = AppColors.success;
      case OrderStatus.cancelled:
        bg = AppColors.errorLight;
        fg = AppColors.error;
      case OrderStatus.refunded:
        bg = AppColors.warningLight;
        fg = AppColors.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Text(
        status.label,
        style: AppTypography.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── نافذة تفاصيل الطلب ──────────────────────────────────────────────────
class _OrderDetailDialog extends StatefulWidget {
  const _OrderDetailDialog({required this.order});
  final Order order;

  @override
  State<_OrderDetailDialog> createState() => _OrderDetailDialogState();
}

class _OrderDetailDialogState extends State<_OrderDetailDialog> {
  bool _isCancelling = false;

  Order get order => widget.order;

  Future<void> _confirmCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد إلغاء الطلب'),
        content: Text(
          'هل تريد إلغاء الطلب #${order.orderNumber}؟\n'
          'سيتم إرجاع كل الأصناف للمخزون، ولن يتم احتساب المبلغ ضمن المبيعات.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isCancelling = true);
    try {
      await OrderRepository().cancelOrder(order.id);
      if (mounted) {
        Navigator.pop(
          context,
          true,
        ); // اقفل الديالوج وابعت إشارة إن الطلب اتغيّر
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCancelling = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حصل خطأ أثناء الإلغاء: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'تفاصيل الطلب #${order.orderNumber}',
                    style: AppTypography.headlineSmall,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // معلومات الطلب
                      _InfoRow('الكاشير', order.userName ?? '—'),
                      _InfoRow('التاريخ', _formatDateTime(order.createdAt)),
                      _InfoRow('نوع الطلب', order.orderType.label),
                      if (order.deliveryAddress != null)
                        _InfoRow('بيانات التوصيل', order.deliveryAddress!),
                      _InfoRow('طريقة الدفع', order.paymentMethod.label),
                      if (order.paymentRef != null)
                        _InfoRow('الرقم المرجعي', order.paymentRef!),
                      _InfoRow('الحالة', order.status.label),
                      const SizedBox(height: 16),

                      // الأصناف
                      Text('الأصناف', style: AppTypography.titleMedium),
                      const SizedBox(height: 8),
                      ...order.items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.productName,
                                  style: AppTypography.bodyMedium,
                                ),
                              ),
                              Text(
                                '× ${item.quantity.toStringAsFixed(0)}',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '${item.totalPrice.toStringAsFixed(2)} ${AppStrings.currency}',
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Divider(),
                      if (order.discountAmount > 0)
                        _InfoRow(
                          AppStrings.posDiscount,
                          '-${order.discountAmount.toStringAsFixed(2)} ${AppStrings.currency}',
                        ),
                      _InfoRow(
                        AppStrings.posTotal,
                        '${order.finalAmount.toStringAsFixed(2)} ${AppStrings.currency}',
                        bold: true,
                      ),
                      if (order.changeAmount > 0)
                        _InfoRow(
                          AppStrings.paymentChange,
                          '${order.changeAmount.toStringAsFixed(2)} ${AppStrings.currency}',
                          color: AppColors.success,
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              const SizedBox(height: 8),
              // ─── زرار الإلغاء ─────────────────────────────────────
              if (order.status != OrderStatus.cancelled)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _isCancelling ? null : _confirmCancel,
                    icon: _isCancelling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.cancel_outlined,
                            color: AppColors.error,
                            size: 18,
                          ),
                    label: Text(
                      _isCancelling ? 'جاري الإلغاء...' : 'إلغاء الطلب',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _InfoRow(
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final date = '${dt.day}/${dt.month}/${dt.year}';
    int h = dt.hour;
    final ampm = h >= 12 ? 'م' : 'ص';
    if (h > 12) h -= 12;
    if (h == 0) h = 12;
    final hour = h.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$date $hour:$min $ampm';
  }
}
