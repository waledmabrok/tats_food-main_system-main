import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../models/product.dart';
import '../../../../models/stock_movement.dart';
import '../../../../repositories/product_repository.dart';
import '../../../../repositories/stock_repository.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _stockRepo = StockRepository();
  final _productRepo = ProductRepository();
  final ScrollController _scrollController = ScrollController();

  List<StockMovement> _movements = [];
  List<Product> _lowStockProducts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 50;

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
    try {
      final movements = await _stockRepo.getAll(limit: _limit, offset: _offset);
      final lowStock = await _productRepo.getLowStock(
          limit: 50); // Optional pagination for low stock
      if (mounted) {
        setState(() {
          _movements = movements;
          _lowStockProducts = lowStock;
          _hasMore = movements.length == _limit;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    _offset += _limit;
    try {
      final newMovements =
          await _stockRepo.getAll(limit: _limit, offset: _offset);
      if (mounted) {
        setState(() {
          _movements.addAll(newMovements);
          _hasMore = newMovements.length == _limit;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: AppStrings.inventoryTitle),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── جدول حركة المخزون (يمين) ────────────────────────
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.space16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border(
                              bottom: BorderSide(color: AppColors.divider)),
                        ),
                        child: Row(
                          children: [
                            Text(AppStrings.inventoryMovements,
                                style: AppTypography.titleMedium),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: () => _showAddStockDialog(),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text(AppStrings.inventoryAddStock),
                              style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(0, 40)),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _movements.isEmpty
                            ? const EmptyStateWidget(
                                icon: Icons.history_rounded,
                                title: 'لا توجد حركات',
                                description:
                                    'لم يتم تسجيل أي حركة في المخزون حتى الآن.',
                              )
                            : _buildMovementsTable(),
                      ),
                    ],
                  ),
                ),

                VerticalDivider(width: 1, color: AppColors.divider),

                // ─── نواقص المخزون (يسار) ────────────────────────────
                Expanded(
                  flex: 1,
                  child: Container(
                    color: AppColors.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(AppDimensions.space16),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: AppColors.warning),
                              const SizedBox(width: AppDimensions.space8),
                              Text(AppStrings.inventoryLowStock,
                                  style: AppTypography.titleMedium),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.errorLight,
                                  borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusFull),
                                ),
                                child: Text('${_lowStockProducts.length}',
                                    style: AppTypography.caption
                                        .copyWith(color: AppColors.error)),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: _lowStockProducts.isEmpty
                              ? const EmptyStateWidget(
                                  icon: Icons.check_circle_outline,
                                  title: 'المخزون مكتمل',
                                  description:
                                      'لا توجد أي نواقص في المخزون حالياً.',
                                  compact: true,
                                )
                              : ListView.separated(
                                  itemCount: _lowStockProducts.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (ctx, i) =>
                                      _LowStockTile(_lowStockProducts[i]),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMovementsTable() {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.space16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space16,
                vertical: AppDimensions.space10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppDimensions.radiusMd)),
              border: Border(
                top: BorderSide(color: AppColors.border),
                left: BorderSide(color: AppColors.border),
                right: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: const [
                Expanded(flex: 2, child: _TH('التاريخ')),
                Expanded(flex: 1, child: _TH('الوقت')),
                Expanded(flex: 3, child: _TH('الصنف')),
                Expanded(flex: 1, child: _TH('النوع')),
                Expanded(flex: 1, child: _TH('الكمية')),
                Expanded(flex: 1, child: _TH('المخزون (بعد)')),
                Expanded(flex: 2, child: _TH('السبب')),
                SizedBox(width: 40),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(AppDimensions.radiusMd)),
              ),
              child: ListView.separated(
                controller: _scrollController,
                itemCount: _movements.length + (_isLoadingMore ? 1 : 0),
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: AppColors.divider),
                itemBuilder: (ctx, i) {
                  if (i == _movements.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return _MovementRow(
                    _movements[i],
                    onDelete: () => _deleteMovement(_movements[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMovement(StockMovement movement) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.btnDelete, style: AppTypography.titleLarge),
        content: Text(
            'هل تريد حذف هذه الحركة نهائياً؟\nسيتم إخفاء هذا السجل فقط ولن يتم تعديل المخزون.',
            style: AppTypography.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.btnCancel, style: AppTypography.button),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.btnDelete, style: AppTypography.button),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _stockRepo.delete(movement.id);
      _loadInitialData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الحركة بنجاح')),
        );
      }
    }
  }

  void _showAddStockDialog() async {
    final products = await _productRepo.getAll(activeOnly: true);
    if (!mounted) return;

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب إضافة أصناف أولاً')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddStockDialog(
        products: products,
        onSaved: () {
          Navigator.pop(ctx);
          _loadInitialData();
        },
      ),
    );
  }
}

class _TH extends StatelessWidget {
  const _TH(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w600, color: AppColors.textSecondary));
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow(this.movement, {required this.onDelete});
  final StockMovement movement;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isOut = movement.type == StockMovementType.sale ||
        movement.type == StockMovementType.stockOut;
    final qtyColor = isOut ? AppColors.error : AppColors.success;
    final qtyPrefix = isOut ? '-' : '+';

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16, vertical: AppDimensions.space12),
      child: Row(
        children: [
          Expanded(
              flex: 2,
              child: Text(_formatDate(movement.createdAt),
                  style: AppTypography.bodySmall)),
          Expanded(
              flex: 1,
              child: Text(_formatTime(movement.createdAt),
                  style: AppTypography.bodySmall)),
          Expanded(
              flex: 3,
              child: Text(movement.productName,
                  style: AppTypography.bodySmall
                      .copyWith(fontWeight: FontWeight.w600))),
          Expanded(
              flex: 1,
              child: Text(isOut ? 'خارج' : 'داخل',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary))),
          Expanded(
              flex: 1,
              child: Text('$qtyPrefix${movement.quantity.toStringAsFixed(0)}',
                  style: AppTypography.bodySmall
                      .copyWith(color: qtyColor, fontWeight: FontWeight.w700))),
          Expanded(
              flex: 1,
              child: Text(movement.stockAfter.toStringAsFixed(0),
                  style: AppTypography.bodySmall)),
          Expanded(
              flex: 2,
              child: Text(movement.reason ?? '—',
                  style: AppTypography.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
          IconButton(
            icon: Icon(Icons.delete_outline, color: AppColors.error, size: 20),
            onPressed: onDelete,
            tooltip: 'حذف',
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatTime(DateTime dt) {
    int h = dt.hour;
    final ampm = h >= 12 ? 'م' : 'ص';
    if (h > 12) h -= 12;
    if (h == 0) h = 12;
    return '${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }
}

class _LowStockTile extends StatelessWidget {
  const _LowStockTile(this.product);
  final Product product;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16, vertical: AppDimensions.space12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Icon(Icons.warning_amber_rounded,
                size: 16, color: AppColors.warning),
          ),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: AppTypography.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                Text('الحد الأدنى: ${product.minStock}',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(
            '${product.stock.toStringAsFixed(0)} ${product.unit}',
            style: AppTypography.titleSmall.copyWith(color: AppColors.error),
          ),
        ],
      ),
    );
  }
}

// ─── نافذة إضافة مخزون ──────────────────────────────────────────────────
class _AddStockDialog extends StatefulWidget {
  const _AddStockDialog({required this.products, required this.onSaved});
  final List<Product> products;
  final VoidCallback onSaved;

  @override
  State<_AddStockDialog> createState() => _AddStockDialogState();
}

class _AddStockDialogState extends State<_AddStockDialog> {
  final _repo = ProductRepository();
  final _formKey = GlobalKey<FormState>();

  String? _selectedProductId;
  final _qtyCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController(text: 'شراء جديد');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.products.isNotEmpty)
      _selectedProductId = widget.products.first.id;
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedProductId == null)
      return;
    setState(() => _saving = true);

    await _repo.addStock(
      productId: _selectedProductId!,
      quantity: double.parse(_qtyCtrl.text),
      reason: _reasonCtrl.text.trim(),
      userId: AppStrings.currentUser,
    );

    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(AppStrings.inventoryAddStock,
                        style: AppTypography.headlineSmall),
                    const Spacer(),
                    IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 20),
                Text('الصنف',
                    style: AppTypography.bodySmall
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedProductId,
                  items: widget.products
                      .map((p) =>
                          DropdownMenuItem(value: p.id, child: Text(p.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedProductId = v),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusSm)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(AppStrings.inventoryQuantityToAdd,
                    style: AppTypography.bodySmall
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _qtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))
                  ],
                  validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusSm)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 16),
                Text(AppStrings.inventoryReason,
                    style: AppTypography.bodySmall
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _reasonCtrl,
                  validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusSm)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(AppStrings.btnCancel)),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text(AppStrings.btnSave),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
