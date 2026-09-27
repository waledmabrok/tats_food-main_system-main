import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../models/category.dart';
import '../../../../models/product.dart';
import '../../../../repositories/category_repository.dart';
import '../../../../repositories/product_repository.dart';
import '../../../management/presentation/screens/management_section_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _productRepo = ProductRepository();
  final _categoryRepo = CategoryRepository();
  final ScrollController _scrollController = ScrollController();

  List<Product> _products = [];
  List<Category> _categories = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 20;

  String _searchQuery = '';
  String? _selectedCategoryId;

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
      final categories = await _categoryRepo.getAll(activeOnly: true);
      List<Product> products;
      if (_searchQuery.isNotEmpty) {
        products = await _productRepo.search(_searchQuery,
            limit: _limit, offset: _offset);
      } else {
        products = await _productRepo.getAll(
            categoryId: _selectedCategoryId,
            activeOnly: true,
            limit: _limit,
            offset: _offset);
      }
      if (mounted) {
        setState(() {
          _products = products;
          _categories = categories;
          _hasMore = products.length == _limit;
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
      List<Product> newProducts;
      if (_searchQuery.isNotEmpty) {
        newProducts = await _productRepo.search(_searchQuery,
            limit: _limit, offset: _offset);
      } else {
        newProducts = await _productRepo.getAll(
            categoryId: _selectedCategoryId,
            activeOnly: true,
            limit: _limit,
            offset: _offset);
      }
      if (mounted) {
        setState(() {
          _products.addAll(newProducts);
          _hasMore = newProducts.length == _limit;
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
      appBar: AppTopBar(title: AppStrings.productsTitle),
      body: Column(
        children: [
          _ProductsToolbar(
            categories: _categories,
            selectedCategoryId: _selectedCategoryId,
            onCategoryChanged: (id) {
              setState(() => _selectedCategoryId = id);
              _loadInitialData();
            },
            onSearchChanged: (q) {
              setState(() => _searchQuery = q);
              _loadInitialData();
            },
            onAddProduct: () => _showProductDialog(context),
            onOpenRecipes: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecipesScreen()),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.fastfood_outlined,
                        title: AppStrings.productNoProducts,
                        description: AppStrings.productNoProductsDesc,
                        actionLabel: AppStrings.productAddNew,
                        action: () => _showProductDialog(context),
                      )
                    : _ProductTable(
                        products: _products,
                        categories: _categories,
                        scrollController: _scrollController,
                        isLoadingMore: _isLoadingMore,
                        onEdit: (p) => _showProductDialog(context, product: p),
                        onToggleActive: (p) => _toggleActive(p),
                        onDelete: (p) => _confirmDelete(context, p),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(Product product) async {
    await _productRepo.setActive(product.id, !product.isActive);
    _loadInitialData();
  }

  Future<void> _confirmDelete(BuildContext context, Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.btnDelete, style: AppTypography.titleLarge),
        content: Text(
            'هل تريد حذف "${product.name}"؟\n${AppStrings.msgDeleteConfirm}',
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
      try {
        await _productRepo.delete(product.id);
        _loadInitialData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف الصنف بنجاح')),
          );
        }
      } catch (e) {
        // Fallback to soft delete if there's a constraint error
        await _productRepo.setActive(product.id, false);
        _loadInitialData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'لا يمكن الحذف النهائي لأنه مرتبط بحركات أخرى، تم تعطيل الصنف بدلاً من ذلك')),
          );
        }
      }
    }
  }

  void _showProductDialog(BuildContext context, {Product? product}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ProductDialog(
        product: product,
        categories: _categories,
        onSaved: () {
          Navigator.pop(ctx);
          _loadInitialData();
        },
      ),
    );
  }
}

// ─── شريط الأدوات ─────────────────────────────────────────────────────────
class _ProductsToolbar extends StatefulWidget {
  const _ProductsToolbar({
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
    required this.onSearchChanged,
    required this.onAddProduct,
    required this.onOpenRecipes,
  });

  final List<Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAddProduct;
  final VoidCallback onOpenRecipes;

  @override
  State<_ProductsToolbar> createState() => _ProductsToolbarState();
}

class _ProductsToolbarState extends State<_ProductsToolbar> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          // ─── بحث ──────────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: AppStrings.productSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: AppDimensions.iconMd),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    borderSide:
                        BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
                onChanged: widget.onSearchChanged,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.space12),

          // ─── فلتر التصنيف ─────────────────────────────────────────
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 40,
              child: DropdownButtonFormField<String?>(
                initialValue: widget.selectedCategoryId,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSm)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
                hint: Text('كل التصنيفات', style: AppTypography.bodyMedium),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('كل التصنيفات')),
                  ...widget.categories.map((cat) => DropdownMenuItem(
                        value: cat.id,
                        child: Text(cat.name, style: AppTypography.bodyMedium),
                      )),
                ],
                onChanged: widget.onCategoryChanged,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.space12),

          // ─── أدوات الأصناف ────────────────────────────────────────
          OutlinedButton.icon(
            onPressed: widget.onOpenRecipes,
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('الوصفات والتكلفة'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
          ),
          const SizedBox(width: AppDimensions.space8),
          ElevatedButton.icon(
            onPressed: widget.onAddProduct,
            icon: const Icon(Icons.add_rounded),
            label: const Text(AppStrings.productAddNew),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── جدول الأصناف ─────────────────────────────────────────────────────────
class _ProductTable extends StatelessWidget {
  const _ProductTable({
    required this.products,
    required this.categories,
    required this.scrollController,
    required this.isLoadingMore,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final List<Product> products;
  final List<Category> categories;
  final ScrollController scrollController;
  final bool isLoadingMore;
  final ValueChanged<Product> onEdit;
  final ValueChanged<Product> onToggleActive;
  final ValueChanged<Product> onDelete;

  String _categoryName(String catId) {
    final cat = categories.firstWhere((c) => c.id == catId,
        orElse: () => Category(id: '', name: '—', createdAt: DateTime.now()));
    return cat.name;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── رأس الجدول ──────────────────────────────────────────
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
              children: [
                Expanded(flex: 4, child: _HeaderCell('اسم الصنف')),
                Expanded(flex: 2, child: _HeaderCell('التصنيف')),
                Expanded(flex: 2, child: _HeaderCell('سعر البيع')),
                Expanded(flex: 1, child: _HeaderCell('الحالة')),
                Expanded(flex: 2, child: _HeaderCell('إجراءات', center: true)),
              ],
            ),
          ),

          // ─── الصفوف ──────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(AppDimensions.radiusMd)),
              ),
              child: ListView.separated(
                controller: scrollController,
                itemCount: products.length + (isLoadingMore ? 1 : 0),
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: AppColors.divider),
                itemBuilder: (ctx, i) {
                  if (i == products.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return _ProductRow(
                    product: products[i],
                    categoryName: _categoryName(products[i].categoryId),
                    onEdit: () => onEdit(products[i]),
                    onToggleActive: () => onToggleActive(products[i]),
                    onDelete: () => onDelete(products[i]),
                  );
                },
              ),
            ),
          ),

          // ─── تذييل ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.space8),
            child: Text(
              '${products.length} صنف',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, {this.center = false});
  final String label;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: center ? TextAlign.center : null,
      style: AppTypography.bodySmall.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ─── صف منتج واحد ─────────────────────────────────────────────────────────
class _ProductRow extends StatefulWidget {
  const _ProductRow({
    required this.product,
    required this.categoryName,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final Product product;
  final String categoryName;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  State<_ProductRow> createState() => _ProductRowState();
}

class _ProductRowState extends State<_ProductRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hovered ? AppColors.surfaceVariant : Colors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space16, vertical: AppDimensions.space12),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                    child: Icon(Icons.fastfood_outlined,
                        size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: AppDimensions.space10),
                  Expanded(
                    child: Text(
                      p.name,
                      style: AppTypography.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (p.isLowStock)
                    Tooltip(
                      message: 'مخزون منخفض',
                      child: Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.all(2),
                        child: Icon(Icons.warning_amber_rounded,
                            size: 16, color: AppColors.warning),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(widget.categoryName,
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${p.price.toStringAsFixed(2)} ${AppStrings.currency}',
                style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            ),
            Expanded(
              flex: 1,
              child: _StatusBadge(p.isActive),
            ),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Tooltip(
                    message: AppStrings.btnEdit,
                    child: IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      color: AppColors.info,
                      onPressed: widget.onEdit,
                    ),
                  ),
                  Tooltip(
                    message: p.isActive
                        ? AppStrings.btnDeactivate
                        : AppStrings.btnActivate,
                    child: IconButton(
                      icon: Icon(
                        p.isActive
                            ? Icons.toggle_on_outlined
                            : Icons.toggle_off_outlined,
                        size: 18,
                        color: p.isActive
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                      onPressed: widget.onToggleActive,
                    ),
                  ),
                  Tooltip(
                    message: 'حذف',
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      color: AppColors.error,
                      onPressed: widget.onDelete,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.isActive);
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? AppColors.successLight : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Text(
        isActive ? AppStrings.productActive : AppStrings.productInactive,
        style: AppTypography.caption.copyWith(
          color: isActive ? AppColors.success : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Dialog إضافة / تعديل صنف ────────────────────────────────────────────
class ProductDialog extends StatefulWidget {
  const ProductDialog({
    super.key,
    this.product,
    required this.categories,
    required this.onSaved,
  });

  final Product? product;
  final List<Category> categories;
  final VoidCallback onSaved;

  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _productRepo = ProductRepository();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _stockCtrl;
  String? _selectedCategoryId;
  String _selectedIcon = '🍔'; // default icon
  bool _isActive = true;
  bool _saving = false;

  // helper: convert Arabic/Eastern-Arabic digits to Latin
  static String _toLatinDigits(String input) {
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var result = input;
    for (int i = 0; i < arabic.length; i++) {
      result = result.replaceAll(arabic[i], i.toString());
    }
    return result;
  }

  static const List<String> _icons = [
    '🍔', '🍕', '🍗', '🥪', '🌮', '🌯',
    '🥗', '🥑', '🍱', '🍜', '🍝', '🍣',
    '🥐', '🍳', '🍴', '🧆', '🍰', '🎂',
    '☕', '🍹', '🥤', '🍺', '🧃', '🧣',
    '🥩', '🐟', '🦐', '🦞', '🍎', '🍋',

    // 🍟 بطاطس وسندوتشات
    '🍟', // بطاطس
    '🧀', // شيدر / جبنة
    '🥪', // سندوتش
    '🌭', // هوت دوج
    '🥖', // ساندوتش/خبز
    '🥙', // ساندوتش عربي
    '🌯', // راب
    '🥓', // سندوتش بيكون
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _priceCtrl = TextEditingController(
        text: p != null ? p.price.toStringAsFixed(2) : '');
    _stockCtrl = TextEditingController(
        text: p != null ? p.stock.toStringAsFixed(0) : '0');
    _selectedCategoryId = p?.categoryId ??
        (widget.categories.isNotEmpty ? widget.categories.first.id : null);
    _selectedIcon = p?.icon ?? '🍔';
    _isActive = p?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار التصنيف')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final id = widget.product?.id ?? DatabaseHelper.generateId();

      final price = double.tryParse(_toLatinDigits(_priceCtrl.text.trim()));
      final stock = double.tryParse(_toLatinDigits(_stockCtrl.text.trim()));

      final product = Product(
        id: id,
        categoryId: _selectedCategoryId!,
        name: _nameCtrl.text.trim(),
        price: price ?? 0,
        cost: widget.product?.cost,
        stock: stock ?? 0,
        minStock: widget.product?.minStock ?? 0,
        unit: widget.product?.unit ?? 'وحدة',
        icon: _selectedIcon,
        isActive: _isActive,
        createdAt: widget.product?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.product == null) {
        await _productRepo.insert(product);
      } else {
        await _productRepo.update(product);
      }
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.msgError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── العنوان ────────────────────────────────────────
                Row(
                  children: [
                    Text(
                      isEdit
                          ? AppStrings.productEdit
                          : AppStrings.productAddNew,
                      style: AppTypography.headlineSmall,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.space24),

                // ─── الاسم + التصنيف ────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _FormField(
                        label: AppStrings.productName,
                        controller: _nameCtrl,
                        autofocus: true,
                        validator: (v) =>
                            v!.trim().isEmpty ? 'الاسم مطلوب' : null,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppStrings.productCategory,
                              style: AppTypography.bodySmall
                                  .copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedCategoryId,
                            items: widget.categories
                                .map((cat) => DropdownMenuItem(
                                      value: cat.id,
                                      child: Text(cat.name,
                                          style: AppTypography.bodyMedium),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedCategoryId = v),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusSm)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.space16),

                // ─── اختر ايقونة ────────────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('اختر أيقونة الصنف',
                        style: AppTypography.bodySmall
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMd),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _icons.map((icon) {
                          final isSelected = icon == _selectedIcon;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedIcon = icon),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.2)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(icon,
                                    style: const TextStyle(fontSize: 20)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.space16),

                // ─── السعر والكمية ────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _FormField(
                        label: AppStrings.productPrice,
                        controller: _priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'السعر مطلوب';
                          if (double.tryParse(_toLatinDigits(v)) == null) {
                            return 'أدخل رقم صحيح';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(
                      child: _FormField(
                        label: 'الكمية في المخزون',
                        controller: _stockCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'الكمية مطلوبة';
                          if (double.tryParse(_toLatinDigits(v)) == null) {
                            return 'أدخل رقم صحيح';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.space16),

                // ─── الحالة ──────────────────────────────────────────
                Row(
                  children: [
                    Switch(
                      value: _isActive,
                      activeThumbColor: AppColors.success,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                    const SizedBox(width: AppDimensions.space8),
                    Text(
                      _isActive
                          ? AppStrings.productActive
                          : AppStrings.productInactive,
                      style: AppTypography.bodyMedium.copyWith(
                        color: _isActive
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.space24),

                // ─── أزرار ───────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(AppStrings.btnCancel),
                    ),
                    const SizedBox(width: AppDimensions.space12),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
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

class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.validator,
    this.autofocus = false,
  }) : inputFormatters = null;

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          autofocus: autofocus,
          style: AppTypography.bodyMedium,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
          ),
        ),
      ],
    );
  }
}
