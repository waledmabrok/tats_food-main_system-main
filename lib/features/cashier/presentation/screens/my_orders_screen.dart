import 'package:flutter/material.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_top_bar.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final userId = SessionService.instance.currentUser?.id;
    if (userId == null) {
      setState(() {
        _orders = [];
        _loading = false;
      });
      return;
    }
    final orders =
        await DatabaseHelper.instance.getOrdersByUser(userId, limit: 100);
    if (mounted) {
      setState(() {
        _orders = orders;
        _loading = false;
      });
    }
  }

  Future<void> _openOrderDetail(Map<String, dynamic> order) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _OrderDetailDialog(order: order),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        title: 'أوردراتي',
        onBack: () => Navigator.pop(context),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 64, color: AppColors.textDisabled),
                      const SizedBox(height: AppDimensions.space12),
                      Text('لسه مفيش أوردرات مسجلة',
                          style: AppTypography.titleMedium),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppDimensions.space16),
                    itemCount: _orders.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppDimensions.space10),
                    itemBuilder: (_, i) => _OrderTile(
                      order: _orders[i],
                      onTap: () => _openOrderDetail(_orders[i]),
                    ),
                  ),
                ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.onTap});
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cancelled = order['status'] == 'cancelled';
    final amount = (order['final_amount'] as num).toDouble();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.space16),
        decoration: BoxDecoration(
          color: cancelled ? AppColors.errorLight : AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(
            color: cancelled ? AppColors.error : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              cancelled ? Icons.cancel_outlined : Icons.receipt_long_outlined,
              color: cancelled ? AppColors.error : AppColors.primary,
            ),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('#${order['order_number']}',
                      style: AppTypography.titleSmall),
                  Text(
                    '${order['created_at']}${cancelled ? ' — ملغي' : ''}',
                    style: AppTypography.caption.copyWith(
                      color:
                          cancelled ? AppColors.error : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${amount.toStringAsFixed(2)} ج.م',
              style: AppTypography.titleMedium.copyWith(
                color: cancelled ? AppColors.error : AppColors.primary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_left_rounded, color: AppColors.textDisabled),
          ],
        ),
      ),
    );
  }
}

class _OrderDetailDialog extends StatefulWidget {
  const _OrderDetailDialog({required this.order});
  final Map<String, dynamic> order;

  @override
  State<_OrderDetailDialog> createState() => _OrderDetailDialogState();
}

class _OrderDetailDialogState extends State<_OrderDetailDialog> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await DatabaseHelper.instance
        .getOrderItemsFor(widget.order['id'] as String);
    if (mounted)
      setState(() {
        _items = items;
        _loading = false;
      });
  }

  bool get _cancelled => widget.order['status'] == 'cancelled';

  Future<void> _editQuantity(Map<String, dynamic> item) async {
    final ctrl = TextEditingController(text: '${item['quantity']}');
    final newQty = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تعديل كمية ${item['product_name']}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'الكمية الجديدة'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text)),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (newQty == null || newQty <= 0) return;

    final user = SessionService.instance.currentUser;
    if (user == null) return;
    try {
      await DatabaseHelper.instance.updateOrderItemQuantity(
        orderId: widget.order['id'] as String,
        orderItemId: item['id'] as String,
        newQuantity: newQty,
        userId: user.id,
        userName: user.name,
      );
      _changed = true;
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _cancelOrder() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'هيتم استرجاع كل الكميات للمخزون. اكتب السبب (اختياري):'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'السبب'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('رجوع')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final user = SessionService.instance.currentUser;
    if (user == null) return;
    await DatabaseHelper.instance.cancelOrder(
      orderId: widget.order['id'] as String,
      userId: user.id,
      userName: user.name,
      reason: reasonCtrl.text.trim(),
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('تفاصيل #${widget.order['order_number']}'),
      content: SizedBox(
        width: 480,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_cancelled)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                          'هذا الطلب ملغي — المخزون تم استرجاعه بالفعل'),
                    ),
                  ..._items.map((item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item['product_name'] as String),
                        subtitle: Text(
                            'الكمية: ${item['quantity']} × ${item['unit_price']} ج.م'),
                        trailing: _cancelled
                            ? Text('${item['total_price']} ج.م')
                            : IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _editQuantity(item),
                              ),
                      )),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الإجمالي'),
                      Text('${widget.order['final_amount']} ج.م',
                          style: AppTypography.titleMedium),
                    ],
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _changed),
          child: const Text('إغلاق'),
        ),
        if (!_cancelled)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: _cancelOrder,
            child: const Text('إلغاء الطلب'),
          ),
      ],
    );
  }
}
