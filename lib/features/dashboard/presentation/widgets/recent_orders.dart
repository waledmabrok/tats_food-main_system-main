import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../repositories/order_repository.dart';
import '../../../../models/order.dart';

class RecentOrders extends StatefulWidget {
  const RecentOrders({super.key});

  @override
  State<RecentOrders> createState() => _RecentOrdersState();
}

class _RecentOrdersState extends State<RecentOrders> {
  final _repo = OrderRepository();
  List<Order> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _repo.getAll(limit: 5);
    if (mounted) {
      setState(() {
        _orders = data;
        _isLoading = false;
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
            title: AppStrings.recentOrdersTitle,
            subtitle: AppStrings.recentOrdersSubtitle,
            icon: Icons.receipt_long_outlined,
            iconColor: AppColors.statOrders,
            trailing: AppButton(
              label: AppStrings.btnViewAll,
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.sm,
              onPressed: () {
                // TODO: Navigate to Orders
              },
            ),
          ),
          const Divider(height: 1),
          _OrdersTableHeader(),
          const Divider(height: 1),
          _isLoading 
              ? const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()))
              : _orders.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.receipt_long_outlined,
                      iconColor: AppColors.textDisabled,
                      title: AppStrings.recentOrdersEmpty,
                      description: AppStrings.recentOrdersEmptyDesc,
                      compact: true,
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _orders.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (ctx, i) => _OrderRow(order: _orders[i]),
                    ),

        ],
      ),
    );
  }
}

class _OrdersTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceVariant,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.cardPadding,
        vertical: AppDimensions.space10,
      ),
      child: Row(
        children: [
          _HeaderCell(label: 'رقم الطلب', flex: 2),
          _HeaderCell(label: 'الوقت', flex: 2),
          _HeaderCell(label: 'الأصناف', flex: 2),
          _HeaderCell(label: 'المبلغ', flex: 2),
          _HeaderCell(label: 'طريقة الدفع', flex: 2),
          _HeaderCell(label: 'الحالة', flex: 2),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.label, this.flex = 1});
  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.cardPadding, vertical: AppDimensions.space12),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('#${order.orderNumber}', style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary))),
          Expanded(flex: 2, child: Text(_formatTime(order.createdAt), style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary))),
          Expanded(flex: 2, child: Text('${order.items.length} أصناف', style: AppTypography.bodySmall)),
          Expanded(flex: 2, child: Text('${order.finalAmount.toStringAsFixed(2)} ${AppStrings.currency}', style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600))),
          Expanded(flex: 2, child: Text(order.paymentMethod.label, style: AppTypography.bodySmall)),
          Expanded(flex: 2, child: _OrderStatusBadge(order.status)),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
        bg = AppColors.successLight; fg = AppColors.success;
      case OrderStatus.cancelled:
        bg = AppColors.errorLight; fg = AppColors.error;
      case OrderStatus.refunded:
        bg = AppColors.warningLight; fg = AppColors.warning;
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppDimensions.radiusFull)),
        child: Text(status.label, style: AppTypography.caption.copyWith(color: fg, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
