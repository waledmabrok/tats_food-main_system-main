import 'package:flutter/material.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../models/category.dart';
import '../../../../repositories/category_repository.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _repo = CategoryRepository();
  List<Category> _categories = [];
  bool _isLoading = true;

  static const _colors = [
    '#3A86FF', '#FF6B6B', '#F39C12', '#8338EC',
    '#20C997', '#E91E63', '#00BCD4', '#FF9800',
    '#4CAF50', '#9C27B0', '#F44336', '#2196F3',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final cats = await _repo.getAll();
    if (mounted) setState(() { _categories = cats; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopBar(title: AppStrings.categoriesTitle),
      body: Column(
        children: [
          // شريط الأدوات
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space24,
              vertical: AppDimensions.space16,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space12,
                    vertical: AppDimensions.space6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.category_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        '${_categories.length} تصنيف',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showDialog(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(AppStrings.categoryAddNew),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.space20,
                      vertical: AppDimensions.space10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _categories.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.category_outlined,
                        title: AppStrings.categoryNoCategories,
                        description: AppStrings.categoryNoCategoriesDesc,
                        actionLabel: AppStrings.categoryAddNew,
                        action: () => _showDialog(),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(AppDimensions.space24),
                        child: LayoutBuilder(
                          builder: (ctx, constraints) {
                            final cols = constraints.maxWidth > 1100
                                ? 4
                                : constraints.maxWidth > 800
                                    ? 3
                                    : constraints.maxWidth > 500
                                        ? 2
                                        : 1;
                            return GridView.builder(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                crossAxisSpacing: AppDimensions.space16,
                                mainAxisSpacing: AppDimensions.space16,
                                childAspectRatio: 2.2,
                              ),
                              itemCount: _categories.length,
                              itemBuilder: (ctx, i) => _CategoryCard(
                                category: _categories[i],
                                onEdit: () => _showDialog(category: _categories[i]),
                                onToggle: () => _toggle(_categories[i]),
                                onDelete: () => _confirmDelete(_categories[i]),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(Category cat) async {
    await _repo.setActive(cat.id, !cat.isActive);
    _load();
  }

  Future<void> _confirmDelete(Category cat) async {
    // التحقق من وجود منتجات مرتبطة
    final productCount = await _repo.getProductCount(cat.id);

    if (!mounted) return;

    if (productCount > 0) {
      // إذا كانت هناك منتجات — عرض رسالة ونسأل إذا يريد التعطيل
      await showDialog(
        context: context,
        builder: (ctx) => _ConfirmDialog(
          title: 'لا يمكن الحذف',
          message:
              'يوجد $productCount منتج مرتبط بهذا التصنيف.\n\nهل تريد تعطيل التصنيف بدلاً من حذفه؟\n(المنتجات لن تُحذف)',
          confirmLabel: 'تعطيل',
          confirmColor: AppColors.warning,
          confirmIcon: Icons.toggle_off_rounded,
          onConfirm: () async {
            await _repo.setActive(cat.id, false);
            if (mounted) {
              Navigator.pop(ctx);
              _load();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم تعطيل "${cat.name}"'),
                  backgroundColor: AppColors.warning,
                ),
              );
            }
          },
        ),
      );
    } else {
      // لا توجد منتجات — حذف فعلي
      await showDialog(
        context: context,
        builder: (ctx) => _ConfirmDialog(
          title: 'حذف التصنيف',
          message: 'هل أنت متأكد من حذف التصنيف "${cat.name}"؟\n\nلن يمكن التراجع عن هذا الإجراء.',
          confirmLabel: 'حذف',
          confirmColor: AppColors.error,
          confirmIcon: Icons.delete_rounded,
          onConfirm: () async {
            await _repo.delete(cat.id);
            if (mounted) {
              Navigator.pop(ctx);
              _load();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم حذف "${cat.name}"'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          },
        ),
      );
    }
  }

  void _showDialog({Category? category}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CategoryDialog(
        category: category,
        availableColors: _colors,
        onSaved: () { Navigator.pop(ctx); _load(); },
      ),
    );
  }
}

// ─── Confirmation Dialog ───────────────────────────────────────────────────
class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    required this.confirmIcon,
    required this.onConfirm,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final IconData confirmIcon;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // أيقونة التحذير
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: confirmColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: confirmColor.withValues(alpha: 0.4)),
                ),
                child: Icon(confirmIcon, color: confirmColor, size: 30),
              ),
              const SizedBox(height: AppDimensions.space16),
              Text(
                title,
                style: AppTypography.titleLarge.copyWith(color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.space12),
              Text(
                message,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.space24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onConfirm,
                      style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(confirmIcon, size: 16),
                          const SizedBox(width: 6),
                          Text(confirmLabel),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Category Card ─────────────────────────────────────────────────────────
class _CategoryCard extends StatefulWidget {
  const _CategoryCard({
    required this.category,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });
  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _hovered = false;

  Color get _color {
    try {
      if (widget.category.colorHex == null) return AppColors.primary;
      return Color(int.parse('FF${widget.category.colorHex!.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.surfaceVariant : AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(
            color: _hovered ? _color.withValues(alpha: 0.6) : AppColors.border,
            width: _hovered ? 1.5 : 1,
          ),
          boxShadow: _hovered
              ? [BoxShadow(color: _color.withValues(alpha: 0.12), blurRadius: 12)]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space16,
            vertical: AppDimensions.space12,
          ),
          child: Row(
            children: [
              // أيقونة التصنيف
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  border: Border.all(color: _color.withValues(alpha: 0.4)),
                ),
                child: Icon(Icons.category_rounded, color: _color, size: 22),
              ),
              const SizedBox(width: AppDimensions.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      cat.name,
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: cat.isActive ? AppColors.success : AppColors.textDisabled,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            cat.isActive ? 'نشط' : 'معطل',
                            style: AppTypography.caption.copyWith(
                              color: cat.isActive ? AppColors.success : AppColors.textDisabled,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // أزرار الإجراءات — تظهر دائمًا
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // تعديل
                  Tooltip(
                    message: 'تعديل',
                    child: InkWell(
                      onTap: widget.onEdit,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        ),
                        child: Icon(Icons.edit_outlined, size: 16, color: AppColors.info),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space6),
                  // تفعيل/تعطيل
                  Tooltip(
                    message: cat.isActive ? 'تعطيل' : 'تفعيل',
                    child: InkWell(
                      onTap: widget.onToggle,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: (cat.isActive ? AppColors.success : AppColors.textDisabled)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        ),
                        child: Icon(
                          cat.isActive ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                          size: 18,
                          color: cat.isActive ? AppColors.success : AppColors.textDisabled,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space6),
                  // حذف
                  Tooltip(
                    message: 'حذف',
                    child: InkWell(
                      onTap: widget.onDelete,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        ),
                        child: Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Category Dialog ────────────────────────────────────────────────────────
class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({
    this.category,
    required this.availableColors,
    required this.onSaved,
  });
  final Category? category;
  final List<String> availableColors;
  final VoidCallback onSaved;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _repo = CategoryRepository();
  final _nameFocus = FocusNode();
  late final TextEditingController _nameCtrl;
  String _selectedColor = '#3A86FF';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.category?.name ?? '');
    _selectedColor = widget.category?.colorHex ?? '#3A86FF';
    // Auto-focus على حقل الاسم
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final cat = Category(
      id: widget.category?.id ?? DatabaseHelper.generateId(),
      name: _nameCtrl.text.trim(),
      colorHex: _selectedColor,
      isActive: widget.category?.isActive ?? true,
      createdAt: widget.category?.createdAt ?? DateTime.now(),
    );
    if (widget.category == null) {
      await _repo.insert(cat);
    } else {
      await _repo.update(cat);
    }
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // العنوان
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                    child: Icon(Icons.category_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: AppDimensions.space12),
                  Expanded(
                    child: Text(
                      widget.category == null
                          ? AppStrings.categoryAddNew
                          : AppStrings.categoryEdit,
                      style: AppTypography.titleLarge.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textSecondary,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.space24),

              // اسم التصنيف
              Text(
                'اسم التصنيف *',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppDimensions.space8),
              TextField(
                controller: _nameCtrl,
                focusNode: _nameFocus,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  hintText: 'مثال: مشروبات، وجبات رئيسية...',
                  prefixIcon: Icon(Icons.label_outline_rounded),
                ),
              ),
              const SizedBox(height: AppDimensions.space20),

              // اللون
              Text(
                'لون التصنيف',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppDimensions.space10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: widget.availableColors.map((hex) {
                  final color = Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
                  final selected = _selectedColor == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = hex),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.white : color.withValues(alpha: 0.3),
                          width: selected ? 3 : 1,
                        ),
                        boxShadow: selected
                            ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10)]
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppDimensions.space24),

              // أزرار
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(AppStrings.btnCancel),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(AppStrings.btnSave),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
