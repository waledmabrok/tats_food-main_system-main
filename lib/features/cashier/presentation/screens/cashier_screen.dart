import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:system_casher/features/cashier/presentation/screens/receive_purchase_dialog.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../models/category.dart';
import '../../../../models/order.dart';
import '../../../../models/product.dart';
import '../../../../repositories/category_repository.dart';
import '../../../../repositories/order_repository.dart';
import '../../../../repositories/product_repository.dart';
import '../../../../core/services/printing_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../products/presentation/screens/products_screen.dart';
import 'add_expense_dialog.dart';
import 'my_orders_screen.dart';
import 'close_shift_dialog.dart';

// ─── عنصر في السلة ────────────────────────────────────────────────────────
class _CartItem {
  _CartItem({required this.product}) : quantity = 1;

  final Product product;
  int quantity;

  double get totalPrice => product.price * quantity;
}

class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  final _productRepo = ProductRepository();
  final _categoryRepo = CategoryRepository();
  final _orderRepo = OrderRepository();
  final ScrollController _scrollController = ScrollController();
  bool _canCloseShift = false;
  List<Product> _products = [];
  List<Category> _categories = [];
  final List<_CartItem> _cart = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 20;

  String _searchQuery = '';
  String _selectedCategoryId = ''; // '' = الكل
  double _discount = 0;
  bool _hasEnoughStock(Product product, int requestedQty) {
    return requestedQty <= product.stock;
  }

  void _showStockLimitMessage(Product product) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'الكمية المتاحة من "${product.name}" هي ${product.stock.toStringAsFixed(0)} ${product.unit} بس',
        ),
        backgroundColor: AppColors.warning,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    DatabaseHelper.instance.getSetting('cashier_can_close_shift').then((v) {
      if (mounted) setState(() => _canCloseShift = v == '1');
    });
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
      final categories = await _categoryRepo.getAll(activeOnly: true);
      List<Product> products;
      if (_searchQuery.isNotEmpty) {
        products = await _productRepo.search(
          _searchQuery,
          limit: _limit,
          offset: _offset,
        );
      } else {
        products = await _productRepo.getAll(
          categoryId: _selectedCategoryId.isEmpty ? null : _selectedCategoryId,
          activeOnly: true,
          limit: _limit,
          offset: _offset,
        );
      }
      if (mounted) {
        setState(() {
          _products = products;
          _categories = categories;
          _hasMore = products.length == _limit;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    _offset += _limit;
    try {
      List<Product> newProducts;
      if (_searchQuery.isNotEmpty) {
        newProducts = await _productRepo.search(
          _searchQuery,
          limit: _limit,
          offset: _offset,
        );
      } else {
        newProducts = await _productRepo.getAll(
          categoryId: _selectedCategoryId.isEmpty ? null : _selectedCategoryId,
          activeOnly: true,
          limit: _limit,
          offset: _offset,
        );
      }
      if (mounted) {
        setState(() {
          _products.addAll(newProducts);
          _hasMore = newProducts.length == _limit;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // ─── عمليات السلة ──────────────────────────────────────────────────
  void _addToCart(Product product) {
    final existing = _cart.where((c) => c.product.id == product.id).firstOrNull;
    final currentQty = existing?.quantity ?? 0;
    final newQty = currentQty + 1;

    if (!_hasEnoughStock(product, newQty)) {
      _showStockLimitMessage(product);
      return;
    }

    setState(() {
      if (existing != null) {
        existing.quantity++;
      } else {
        _cart.add(_CartItem(product: product));
      }
    });
  }

  void _increaseQty(int idx) {
    final item = _cart[idx];
    final newQty = item.quantity + 1;

    if (!_hasEnoughStock(item.product, newQty)) {
      _showStockLimitMessage(item.product);
      return;
    }

    setState(() => item.quantity++);
  }

  void _decreaseQty(int idx) {
    setState(() {
      if (_cart[idx].quantity > 1) {
        _cart[idx].quantity--;
      }
    });
  }

  void _removeItem(int idx) => setState(() => _cart.removeAt(idx));

  void _clearCart() => setState(() {
        _cart.clear();
        _discount = 0;
      });

  void _showAddProductDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ProductDialog(
        categories: _categories,
        onSaved: () {
          Navigator.pop(ctx);
          _loadInitialData(); // reload products
        },
      ),
    );
  }

  int _getQty(Product p) {
    final item = _cart.where((c) => c.product.id == p.id).firstOrNull;
    return item?.quantity ?? 0;
  }

  void _decreaseQtyByProduct(Product p) {
    final idx = _cart.indexWhere((c) => c.product.id == p.id);
    if (idx != -1) _decreaseQty(idx);
  }

  // ─── الإجماليات ────────────────────────────────────────────────────
  double get _subtotal => _cart.fold(0, (sum, item) => sum + item.totalPrice);
  double get _total => (_subtotal - _discount).clamp(0, double.infinity);

  // ─── إتمام الطلب ───────────────────────────────────────────────────
  void _showPaymentDialog() {
    if (_cart.isEmpty) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PaymentDialog(
        subtotal: _subtotal,
        discount: _discount,
        total: _total,
        onDiscount: (d) => setState(() => _discount = d),
        onConfirm: (method, paidAmount, ref, orderType, address, phone,
                customerId, customerName) =>
            _processPayment(
          ctx,
          method,
          paidAmount,
          ref,
          orderType,
          address,
          phone,
          customerId,
          customerName,
        ),
      ),
    );
  }

  Future<void> _processPayment(
    BuildContext dialogCtx,
    PaymentMethod method,
    double paidAmount,
    String? ref,
    OrderType orderType,
    String? address,
    String? phone,
    String? selectedCustomerId,
    String? customerName,
  ) async {
    try {
      String? customerId = selectedCustomerId;
      if (orderType == OrderType.delivery && customerId == null) {
        customerId = await DatabaseHelper.instance.addCustomer(
          name: customerName!.isEmpty ? 'عميل دليفري' : customerName,
          phone: phone!,
          address: address,
        );
      }
      final orderNumber = await DatabaseHelper.instance.generateOrderNumber();
      final orderId = DatabaseHelper.generateId();
      final now = DateTime.now();

      final items = _cart
          .map(
            (c) => OrderItem(
              id: DatabaseHelper.generateId(),
              orderId: orderId,
              productId: c.product.id,
              productName: c.product.name,
              unitPrice: c.product.price,
              quantity: c.quantity.toDouble(),
              totalPrice: c.totalPrice,
            ),
          )
          .toList();

      final order = Order(
        id: orderId,
        orderNumber: orderNumber,
        userId: SessionService.instance.currentUser?.id,
        userName: SessionService.instance.currentUser?.name,
        subtotal: _subtotal,
        discountAmount: _discount,
        finalAmount: _total,
        paidAmount: paidAmount,
        changeAmount: (paidAmount - _total).clamp(0, double.infinity),
        paymentMethod: method,
        orderType: orderType,
        customerId: customerId,
        deliveryAddress: orderType == OrderType.delivery
            ? [phone, address]
                .whereType<String>()
                .where((v) => v.isNotEmpty)
                .join(' - ')
            : null,
        paymentRef: ref,
        createdAt: now,
        items: items,
      );

      await _orderRepo.createOrder(order: order, items: items);

      // خصم المخزون
      await _productRepo.deductStockForOrder(
        orderId: orderId,
        items: _cart
            .map(
              (c) => (productId: c.product.id, quantity: c.quantity.toDouble()),
            )
            .toList(),
        userId: null,
      );

      if (!mounted) return;
      Navigator.pop(dialogCtx);

      // عرض رسالة نجاح + إعادة تعيين السلة
      _showSuccessDialog(order);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(AppStrings.msgError),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _closeShift() async {
    final closed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CloseShiftDialog(),
    );
    if (closed != true || !mounted) return;

    SessionService.instance.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showSuccessDialog(Order order) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.space32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: AppColors.success,
                    size: 40,
                  ),
                ),
                const SizedBox(height: AppDimensions.space16),
                Text(
                  AppStrings.paymentSuccess,
                  style: AppTypography.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.space8),
                Text(
                  'رقم الطلب: #${order.orderNumber}',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppDimensions.space4),
                Text(
                  'الإجمالي: ${order.finalAmount.toStringAsFixed(2)} ${AppStrings.currency}',
                  style: AppTypography.titleLarge.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                if (order.changeAmount > 0) ...[
                  const SizedBox(height: AppDimensions.space4),
                  Text(
                    'الباقي للعميل: ${order.changeAmount.toStringAsFixed(2)} ${AppStrings.currency}',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ],
                const SizedBox(height: AppDimensions.space24),
                // ─── أزرار الطباعة ──────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      // طباعة للعميل
                      InkWell(
                        onTap: () => PrintingService.instance
                            .printCustomerReceipt(order),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppDimensions.radiusMd),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.print_rounded,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'فاتورة العميل',
                                      style: AppTypography.titleSmall.copyWith(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'طباعة فاتورة مفصلة مع السعر',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_left_rounded,
                                color: AppColors.textSecondary,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(height: 1, color: AppColors.border),
                      // طباعة للمطبخ
                      InkWell(
                        onTap: () =>
                            PrintingService.instance.printKitchenTicket(order),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(AppDimensions.radiusMd),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.receipt_long_rounded,
                                  color: AppColors.success,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ورقة المطبخ',
                                      style: AppTypography.titleSmall.copyWith(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'طباعة أوراق التجهيز بدون أسعار',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_left_rounded,
                                color: AppColors.textSecondary,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _clearCart();
                      _loadInitialData();
                    },
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                    label: const Text('طلب جديد'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        title: AppStrings.posTitle,
        action: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_canCloseShift)
              IconButton(
                tooltip: 'قفل الشيفت',
                onPressed: _closeShift,
                icon: const Icon(Icons.lock_clock_rounded),
              ),
            IconButton(
              tooltip: 'استلام بضاعة',
              onPressed: () async {
                final saved = await showDialog<bool>(
                  context: context,
                  builder: (_) => const ReceivePurchaseDialog(),
                );
                if (saved == true && mounted) {
                  _loadInitialData(); // عشان مخزون الأصناف الجاهزة يتحدّث
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تسجيل استلام البضاعة')),
                  );
                }
              },
              icon: const Icon(Icons.local_shipping_outlined),
            ),
            IconButton(
              tooltip: 'إضافة مصروف',
              onPressed: () async {
                final saved = await showDialog<bool>(
                  context: context,
                  builder: (_) => const AddExpenseDialog(),
                );
                if (saved == true && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تسجيل المصروف')),
                  );
                }
              },
              icon: const Icon(Icons.receipt_outlined),
            ),
            IconButton(
              tooltip: 'أوردراتي',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
              ),
              icon: const Icon(Icons.list_alt_rounded),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // ─── منطقة الأصناف (يمين) ─────────────────────────
                Expanded(
                  flex: 3,
                  child: _ProductsPanel(
                    products: _products,
                    categories: _categories,
                    selectedCategoryId: _selectedCategoryId,
                    scrollController: _scrollController,
                    isLoadingMore: _isLoadingMore,
                    onCategoryChanged: (id) {
                      setState(() => _selectedCategoryId = id);
                      _loadInitialData();
                    },
                    onSearchChanged: (q) {
                      setState(() => _searchQuery = q);
                      _loadInitialData();
                    },
                    onProductIncrease: _addToCart,
                    onProductDecrease: _decreaseQtyByProduct,
                    getQty: _getQty,
                    onAddProduct: _showAddProductDialog,
                  ),
                ),

                // ─── فاصل ─────────────────────────────────────────
                VerticalDivider(width: 1, color: AppColors.divider),

                // ─── السلة (يسار) ─────────────────────────────────
                SizedBox(
                  width: 360,
                  child: _CartPanel(
                    items: _cart,
                    subtotal: _subtotal,
                    discount: _discount,
                    total: _total,
                    onIncrease: _increaseQty,
                    onDecrease: _decreaseQty,
                    onRemove: _removeItem,
                    onClear: _clearCart,
                    onCheckout: _showPaymentDialog,
                    onDiscountChanged: (d) => setState(() => _discount = d),
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── لوحة الأصناف ─────────────────────────────────────────────────────────
class _ProductsPanel extends StatefulWidget {
  const _ProductsPanel({
    required this.products,
    required this.categories,
    required this.selectedCategoryId,
    required this.scrollController,
    required this.isLoadingMore,
    required this.onCategoryChanged,
    required this.onSearchChanged,
    required this.onProductIncrease,
    required this.onProductDecrease,
    required this.getQty,
    required this.onAddProduct,
  });

  final List<Product> products;
  final List<Category> categories;
  final String selectedCategoryId;
  final ScrollController scrollController;
  final bool isLoadingMore;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Product> onProductIncrease;
  final ValueChanged<Product> onProductDecrease;
  final int Function(Product) getQty;
  final VoidCallback onAddProduct;

  @override
  State<_ProductsPanel> createState() => _ProductsPanelState();
}

class _ProductsPanelState extends State<_ProductsPanel> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ─── شريط البحث والفلتر ──────────────────────────────────
        Container(
          padding: const EdgeInsets.all(AppDimensions.space16),
          color: AppColors.surface,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: AppStrings.posSearchProducts,
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                  ),
                  onChanged: widget.onSearchChanged,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: widget.onAddProduct,
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة صنف'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),

        // ─── التصنيفات ────────────────────────────────────────────
        Container(
          height: 48,
          color: AppColors.surface,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space16,
              vertical: 6,
            ),
            children: [
              _CategoryChip(
                label: AppStrings.posAllCategories,
                isSelected: widget.selectedCategoryId.isEmpty,
                onTap: () => widget.onCategoryChanged(''),
              ),
              ...widget.categories.map(
                (cat) => _CategoryChip(
                  label: cat.name,
                  isSelected: widget.selectedCategoryId == cat.id,
                  onTap: () => widget.onCategoryChanged(cat.id),
                  colorHex: cat.colorHex,
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // ─── شبكة الأصناف ────────────────────────────────────────
        Expanded(
          child: widget.products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 64,
                        color: AppColors.textDisabled,
                      ),
                      const SizedBox(height: AppDimensions.space12),
                      Text(
                        'لا توجد أصناف',
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.all(AppDimensions.space16),
                  itemCount:
                      widget.products.length + (widget.isLoadingMore ? 1 : 0),
                  separatorBuilder: (ctx, i) =>
                      const SizedBox(height: AppDimensions.space12),
                  itemBuilder: (ctx, i) {
                    if (i == widget.products.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final p = widget.products[i];
                    return _ProductCard(
                      product: p,
                      quantity: widget.getQty(p),
                      onIncrease: () => widget.onProductIncrease(p),
                      onDecrease: () => widget.onProductDecrease(p),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.colorHex,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final String? colorHex;

  Color _parseColor() {
    if (colorHex == null) return AppColors.primary;
    try {
      return Color(int.parse('FF${colorHex!.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor();
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? color : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              border: Border.all(color: isSelected ? color : AppColors.border),
            ),
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── كارت صنف في الشبكة ───────────────────────────────────────────────────
class _ProductCard extends StatefulWidget {
  const _ProductCard({
    required this.product,
    required this.quantity,
    required this.onIncrease,
    required this.onDecrease,
  });
  final Product product;
  final int quantity;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final outOfStock = p.stock <= 0;
    final hasQty = widget.quantity > 0;

    return MouseRegion(
      cursor: outOfStock ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: outOfStock ? null : widget.onIncrease,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: hasQty
                ? AppColors.primary.withValues(alpha: 0.04)
                : (_hovered && !outOfStock
                    ? AppColors.surfaceVariant
                    : AppColors.surface),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(
              color: hasQty
                  ? AppColors.primary
                  : (_hovered && !outOfStock
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : AppColors.border),
              width: hasQty ? 1.5 : 1,
            ),
            boxShadow: _hovered && !outOfStock && !hasQty
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Opacity(
            opacity: outOfStock ? 0.45 : 1.0,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space12,
                vertical: 8,
              ),
              child: Row(
                children: [
                  // أيقونة
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSm,
                      ),
                    ),
                    child: p.icon != null
                        ? Center(
                            child: Text(
                              p.icon!,
                              style: const TextStyle(fontSize: 24),
                            ),
                          )
                        : Icon(
                            Icons.fastfood_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                  ),
                  const SizedBox(width: 12),

                  // الاسم والسعر
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          p.name,
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${p.price.toStringAsFixed(2)} ${AppStrings.currency}',
                          style: AppTypography.caption.copyWith(
                            color: outOfStock
                                ? AppColors.textDisabled
                                : AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // حالة المخزون أو التحكم في الكمية
                  if (outOfStock)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusFull,
                        ),
                      ),
                      child: Text(
                        AppStrings.posOutOfStock,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.error,
                          fontSize: 10,
                        ),
                      ),
                    )
                  else if (hasQty)
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _QtyBtn(
                            icon: Icons.remove_rounded,
                            onTap: widget.onDecrease,
                            color: AppColors.error,
                          ),
                          Container(
                            constraints: const BoxConstraints(minWidth: 28),
                            alignment: Alignment.center,
                            child: Text(
                              '${widget.quantity}',
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _QtyBtn(
                            icon: Icons.add_rounded,
                            onTap: widget.onIncrease,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 4),
                          // ─── الكمية المتاحة دايمًا ────────────────────────
                          Text(
                            'متاح: ${(p.stock - widget.quantity).clamp(0, double.infinity).toStringAsFixed(0)} ${p.unit}',
                            style: AppTypography.caption.copyWith(
                              color: p.isLowStock
                                  ? AppColors.warning
                                  : AppColors.textDisabled,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (p.isLowStock)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusFull,
                        ),
                      ),
                      child: Text(
                        '${p.stock.toStringAsFixed(0)} ${p.unit}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.warning,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── لوحة السلة ───────────────────────────────────────────────────────────
class _CartPanel extends StatelessWidget {
  const _CartPanel({
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
    required this.onClear,
    required this.onCheckout,
    required this.onDiscountChanged,
  });

  final List<_CartItem> items;
  final double subtotal;
  final double discount;
  final double total;
  final ValueChanged<int> onIncrease;
  final ValueChanged<int> onDecrease;
  final ValueChanged<int> onRemove;
  final VoidCallback onClear;
  final VoidCallback onCheckout;
  final ValueChanged<double> onDiscountChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          // ─── رأس السلة ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space16,
              vertical: AppDimensions.space12,
            ),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Text(AppStrings.posCart, style: AppTypography.titleLarge),
                const Spacer(),
                if (items.isNotEmpty)
                  TextButton.icon(
                    onPressed: onClear,
                    icon: const Icon(Icons.clear_all_rounded, size: 16),
                    label: const Text('إفراغ'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
              ],
            ),
          ),

          // ─── عناصر السلة ────────────────────────────────────────
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 56,
                          color: AppColors.textDisabled,
                        ),
                        const SizedBox(height: AppDimensions.space12),
                        Text(
                          AppStrings.posCartEmpty,
                          style: AppTypography.titleSmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppStrings.posCartEmptyDesc,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textDisabled,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppDimensions.space12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => _CartItemTile(
                      item: items[i],
                      onIncrease: () => onIncrease(i),
                      onDecrease: () => onDecrease(i),
                      onRemove: () => onRemove(i),
                    ),
                  ),
          ),

          // ─── ملخص الطلب ─────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ─── صف المجموع الفرعي والخصم ─────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppStrings.posSubtotal,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${subtotal.toStringAsFixed(2)} ${AppStrings.currency}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _DiscountRow(
                        discount: discount,
                        onChanged: onDiscountChanged,
                      ),
                    ],
                  ),
                ),

                // ─── الإجمالي ─────────────────────────────────────
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.15),
                        AppColors.primaryDark.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppStrings.posTotal,
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${total.toStringAsFixed(2)} ${AppStrings.currency}',
                        style: AppTypography.titleLarge.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── زر الدفع ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: items.isEmpty ? null : onCheckout,
                      icon: Icon(
                        items.isEmpty
                            ? Icons.shopping_cart_outlined
                            : Icons.payment_rounded,
                        size: 20,
                      ),
                      label: Text(
                        items.isEmpty
                            ? AppStrings.posCheckout
                            : '${AppStrings.posCheckout}  •  ${total.toStringAsFixed(2)} ${AppStrings.currency}',
                        style: AppTypography.button.copyWith(fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: items.isEmpty
                            ? AppColors.surfaceVariant
                            : AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledForegroundColor: AppColors.textDisabled,
                        disabledBackgroundColor: AppColors.surfaceVariant,
                        elevation: items.isEmpty ? 0 : 4,
                        shadowColor: AppColors.primary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusMd,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  final _CartItem item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // الاسم
          Expanded(
            flex: 2,
            child: Text(
              item.product.name,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(width: 8),

          // السعر
          Expanded(
            flex: 1,
            child: Text(
              '${item.product.price.toStringAsFixed(2)} ${AppStrings.currency}',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(width: 8),

          // التحكم في الكمية والحذف
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QtyBtn(
                icon: Icons.add_rounded,
                onTap: onIncrease,
                color: AppColors.primary,
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 28),
                alignment: Alignment.center,
                child: Text(
                  '${item.quantity}',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _QtyBtn(
                icon: Icons.remove_rounded,
                onTap: item.quantity > 1 ? onDecrease : onRemove,
                color: item.quantity > 1 ? AppColors.warning : AppColors.error,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: AppColors.error,
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({required this.icon, required this.onTap, required this.color});
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.color,
  });
  final String label;
  final double value;
  final bool isBold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = isBold
        ? AppTypography.titleLarge.copyWith(color: color)
        : AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(
          '${value.toStringAsFixed(2)} ${AppStrings.currency}',
          style: style,
        ),
      ],
    );
  }
}

class _DiscountRow extends StatefulWidget {
  const _DiscountRow({required this.discount, required this.onChanged});
  final double discount;
  final ValueChanged<double> onChanged;

  @override
  State<_DiscountRow> createState() => _DiscountRowState();
}

class _DiscountRowState extends State<_DiscountRow> {
  bool _editing = false;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.discount > 0 ? widget.discount.toString() : '';
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          AppStrings.posDiscount,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        _editing
            ? SizedBox(
                width: 100,
                height: 32,
                child: TextField(
                  controller: _ctrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  autofocus: true,
                  style: AppTypography.bodyMedium,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    suffixText: AppStrings.currency,
                  ),
                  onSubmitted: (v) {
                    widget.onChanged(double.tryParse(v) ?? 0);
                    setState(() => _editing = false);
                  },
                  onTapOutside: (_) {
                    widget.onChanged(double.tryParse(_ctrl.text) ?? 0);
                    setState(() => _editing = false);
                  },
                ),
              )
            : GestureDetector(
                onTap: () => setState(() => _editing = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderLight),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.discount > 0
                        ? '${widget.discount.toStringAsFixed(2)} ${AppStrings.currency}'
                        : 'لا خصم',
                    style: AppTypography.bodySmall.copyWith(
                      color: widget.discount > 0
                          ? AppColors.success
                          : AppColors.textDisabled,
                    ),
                  ),
                ),
              ),
      ],
    );
  }
}

// ─── Dialog الدفع ─────────────────────────────────────────────────────────
class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.onDiscount,
    required this.onConfirm,
  });

  final double subtotal;
  final double discount;
  final double total;
  final ValueChanged<double> onDiscount;
  final Function(PaymentMethod, double, String?, OrderType, String?, String?,
      String?, String?) onConfirm;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  PaymentMethod _method = PaymentMethod.cash;
  OrderType _orderType = OrderType.takeaway;
  final _paidCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _customerNameCtrl = TextEditingController();
  List<Map<String, dynamic>> _customers = [];
  String? _selectedCustomerId;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _paidCtrl.text = widget.total.toStringAsFixed(2);
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final customers = await DatabaseHelper.instance.getCustomers();
    if (mounted) setState(() => _customers = customers);
  }

  void _selectCustomer(String? id) {
    final customer = _customers.where((item) => item['id'] == id).firstOrNull;
    setState(() {
      _selectedCustomerId = id;
      if (customer != null) {
        _customerNameCtrl.text = customer['name'] as String? ?? '';
        _phoneCtrl.text = customer['phone'] as String? ?? '';
        _addressCtrl.text = customer['address'] as String? ?? '';
      }
    });
  }

  @override
  void dispose() {
    _paidCtrl.dispose();
    _refCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _customerNameCtrl.dispose();
    super.dispose();
  }

  double get _paid => double.tryParse(_paidCtrl.text) ?? 0;
  double get _change => (_paid - widget.total).clamp(0, double.infinity);

  Future<void> _confirm() async {
    if (_orderType == OrderType.delivery &&
        (_customerNameCtrl.text.trim().isEmpty ||
            _phoneCtrl.text.trim().isEmpty ||
            _addressCtrl.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('اكتب رقم العميل وعنوان التوصيل أولًا'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_paid < widget.total && _method == PaymentMethod.cash) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('المبلغ المدفوع أقل من الإجمالي'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _processing = true);
    final finalPaidAmount =
        _method == PaymentMethod.cash ? _paid : widget.total;
    await widget.onConfirm(
      _method,
      finalPaidAmount,
      _refCtrl.text.isNotEmpty ? _refCtrl.text : null,
      _orderType,
      _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null,
      _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
      _selectedCustomerId,
      _customerNameCtrl.text.trim(),
    );
  }

  void _addQuickCash(double amount) {
    final current = double.tryParse(_paidCtrl.text) ?? 0;
    _paidCtrl.text = (current + amount).toStringAsFixed(2);
    setState(() {});
  }

  void _exactAmount() {
    _paidCtrl.text = widget.total.toStringAsFixed(2);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, minHeight: 600),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── الجانب الأيمن (تفاصيل الدفع والمبالغ) ─────────────────────────
            Expanded(
              flex: 6,
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.space32),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إتمام الدفع', style: AppTypography.headlineMedium),
                      const SizedBox(height: AppDimensions.space32),

                      Text(
                        'نوع الطلب',
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<OrderType>(
                        segments: const [
                          ButtonSegment(
                            value: OrderType.takeaway,
                            icon: Icon(Icons.shopping_bag_outlined),
                            label: Text('تيك أواي'),
                          ),
                          ButtonSegment(
                            value: OrderType.delivery,
                            icon: Icon(Icons.delivery_dining_outlined),
                            label: Text('دليفري'),
                          ),
                        ],
                        selected: {_orderType},
                        onSelectionChanged: (selected) => setState(
                          () => _orderType = selected.first,
                        ),
                      ),
                      if (_orderType == OrderType.delivery) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCustomerId,
                          items: _customers
                              .map(
                                (customer) => DropdownMenuItem<String>(
                                  value: customer['id'] as String,
                                  child: Text(customer['name'] as String),
                                ),
                              )
                              .toList(),
                          onChanged: _selectCustomer,
                          decoration: InputDecoration(
                            labelText: 'العميل المحفوظ',
                            prefixIcon: const Icon(Icons.person_outline),
                            filled: true,
                            fillColor: AppColors.surface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _customerNameCtrl,
                          decoration: InputDecoration(
                            labelText: 'اسم العميل',
                            prefixIcon: const Icon(Icons.badge_outlined),
                            filled: true,
                            fillColor: AppColors.surface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'رقم العميل',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            filled: true,
                            fillColor: AppColors.surface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _addressCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'عنوان التوصيل',
                            prefixIcon: const Icon(Icons.location_on_outlined),
                            filled: true,
                            fillColor: AppColors.surface,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppDimensions.space24),

                      // طريقة الدفع
                      Text(
                        AppStrings.paymentMethod,
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: PaymentMethod.values.map((m) {
                          final isSelected = _method == m;
                          IconData icon;
                          switch (m) {
                            case PaymentMethod.cash:
                              icon = Icons.payments_rounded;
                              break;
                            case PaymentMethod.card:
                              icon = Icons.credit_card_rounded;
                              break;
                            case PaymentMethod.vodafone:
                              icon = Icons.phone_iphone_rounded;
                              break;
                            case PaymentMethod.other:
                              icon = Icons.receipt_long_rounded;
                              break;
                          }
                          return Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: InkWell(
                                onTap: () => setState(() {
                                  _method = m;
                                  if (m != PaymentMethod.cash) _exactAmount();
                                }),
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusMd,
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.surface,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.border,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusMd,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color:
                                                  AppColors.primary.withValues(
                                                alpha: 0.2,
                                              ),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        icon,
                                        size: 32,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        m.label,
                                        style:
                                            AppTypography.titleSmall.copyWith(
                                          color: isSelected
                                              ? Colors.white
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppDimensions.space32),

                      // إدخال المبالغ
                      if (_method == PaymentMethod.cash) ...[
                        Text(
                          'المبلغ المستلم',
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _paidCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                          style: AppTypography.statNumberMedium.copyWith(
                            color: AppColors.primary,
                          ),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.surface,
                            suffixText: AppStrings.currency,
                            suffixStyle: AppTypography.titleLarge.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            _QuickBtn('50', () => _addQuickCash(50)),
                            _QuickBtn('100', () => _addQuickCash(100)),
                            _QuickBtn('200', () => _addQuickCash(200)),
                            _QuickBtn(
                              'الضبط',
                              _exactAmount,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          _method == PaymentMethod.vodafone
                              ? AppStrings.paymentPhoneNumber
                              : AppStrings.paymentRef,
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _refCtrl,
                          style: AppTypography.headlineSmall,
                          decoration: InputDecoration(
                            hintText: _method == PaymentMethod.vodafone
                                ? '01xxxxxxxxx'
                                : 'رقم العملية (اختياري)',
                            filled: true,
                            fillColor: AppColors.surface,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // ─── الجانب الأيسر (ملخص الطلب والإجراءات) ─────────────────────────
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.space32),
                decoration: BoxDecoration(
                  color: AppColors.sidebarBg,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(AppDimensions.radiusLg),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ملخص الحساب',
                      style: AppTypography.headlineMedium.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space32),

                    _DarkSummaryRow('الإجمالي الفرعي', widget.subtotal),
                    if (widget.discount > 0) ...[
                      const SizedBox(height: 12),
                      _DarkSummaryRow(
                        'الخصم',
                        -widget.discount,
                        color: AppColors.success,
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Divider(
                        color: AppColors.sidebarDivider,
                        thickness: 2,
                      ),
                    ),
                    _DarkSummaryRow(
                      'الإجمالي',
                      widget.total,
                      isTotal: true,
                      color: AppColors.accent,
                    ),

                    if (_method == PaymentMethod.cash) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _change >= 0
                              ? AppColors.success.withValues(alpha: 0.1)
                              : AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusMd,
                          ),
                          border: Border.all(
                            color: _change >= 0
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'الباقي للعميل',
                              style: AppTypography.titleMedium.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${_change.toStringAsFixed(2)} ${AppStrings.currency}',
                              style: AppTypography.headlineSmall.copyWith(
                                color: _change >= 0
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const Spacer(),

                    // أزرار التحكم
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: AppColors.sidebarText,
                              ),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                            ),
                            child: const Text('إلغاء'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _processing ? null : _confirm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                            ),
                            child: _processing
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : Text(
                                    'تأكيد الدفع',
                                    style: AppTypography.titleLarge.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  const _QuickBtn(this.label, this.onTap, {this.color});
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: color ?? AppColors.surface,
          border: Border.all(color: color ?? AppColors.border, width: 1.5),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          boxShadow: color != null
              ? [
                  BoxShadow(
                    color: color!.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label == 'الضبط' ? label : '+$label',
          style: AppTypography.titleMedium.copyWith(
            color: color != null ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _DarkSummaryRow extends StatelessWidget {
  const _DarkSummaryRow(
    this.label,
    this.value, {
    this.isTotal = false,
    this.color,
  });
  final String label;
  final double value;
  final bool isTotal;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = isTotal
        ? AppTypography.headlineMedium.copyWith(color: color ?? Colors.white)
        : AppTypography.titleMedium.copyWith(
            color: color ?? AppColors.sidebarText,
          );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: style.copyWith(
              color: isTotal ? (color ?? Colors.white) : AppColors.sidebarText,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${value.toStringAsFixed(2)} ${AppStrings.currency}',
          style: style,
        ),
      ],
    );
  }
}
