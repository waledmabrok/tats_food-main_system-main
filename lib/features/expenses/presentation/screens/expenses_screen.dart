import 'package:flutter/material.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../models/expense.dart';
import '../../../../repositories/expense_repository.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _repo = ExpenseRepository();
  List<Expense> _expenses = [];
  bool _isLoading = true;
  DateTimeRange? _dateRange;

  double get _totalExpenses => _expenses.fold(0, (sum, e) => sum + e.amount);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final expenses =
        await _repo.getAll(from: _dateRange?.start, to: _dateRange?.end);
    if (mounted) {
      setState(() {
        _expenses = expenses;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: AppStrings.expensesTitle),
      body: Column(
        children: [
          // ─── شريط الفلتر والأدوات ──────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space16,
                vertical: AppDimensions.space12),
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
                      style: AppTypography.bodySmall),
                  style:
                      OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
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
                const SizedBox(width: AppDimensions.space24),

                // الإجمالي
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Row(
                    children: [
                      Text('الإجمالي: ',
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.error)),
                      Text(
                          '${_totalExpenses.toStringAsFixed(2)} ${AppStrings.currency}',
                          style: AppTypography.titleSmall
                              .copyWith(color: AppColors.error)),
                    ],
                  ),
                ),

                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showDialog(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(AppStrings.expenseAddNew),
                  style:
                      ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
                ),
              ],
            ),
          ),

          // ─── الجدول ────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _expenses.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.account_balance_wallet_outlined,
                        title: AppStrings.expenseNoExpenses,
                        description: AppStrings.expenseNoExpensesDesc,
                        actionLabel: AppStrings.expenseAddNew,
                        action: () => _showDialog(),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(AppDimensions.space24),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppDimensions.space16,
                                  vertical: AppDimensions.space10),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(
                                        AppDimensions.radiusMd)),
                                border: Border(
                                  top: BorderSide(color: AppColors.border),
                                  left: BorderSide(color: AppColors.border),
                                  right: BorderSide(color: AppColors.border),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Expanded(flex: 2, child: _TH('التاريخ')),
                                  Expanded(flex: 3, child: _TH('التصنيف')),
                                  Expanded(flex: 4, child: _TH('الوصف')),
                                  Expanded(flex: 2, child: _TH('المبلغ')),
                                  SizedBox(width: 80),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: const BorderRadius.vertical(
                                      bottom: Radius.circular(
                                          AppDimensions.radiusMd)),
                                ),
                                child: ListView.separated(
                                  itemCount: _expenses.length,
                                  separatorBuilder: (_, __) => Divider(
                                      height: 1, color: AppColors.divider),
                                  itemBuilder: (ctx, i) => _ExpenseRow(

                                    expense: _expenses[i],
                                    onEdit: () =>
                                        _showDialog(expense: _expenses[i]),
                                    onDelete: () => _delete(_expenses[i]),
                                  ),
                                ),
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

  void _showDialog({Expense? expense}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ExpenseDialog(
        expense: expense,
        onSaved: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  Future<void> _delete(Expense expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المصروف'),
        content: Text(
            'هل أنت متأكد من حذف هذا المصروف؟\nالمبلغ: ${expense.amount} ${AppStrings.currency}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(AppStrings.btnCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(AppStrings.btnDelete),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _repo.delete(expense.id);
      _load();
    }
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
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

class _ExpenseRow extends StatefulWidget {
  const _ExpenseRow(
      {required this.expense, required this.onEdit, required this.onDelete});
  final Expense expense;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_ExpenseRow> createState() => _ExpenseRowState();
}

class _ExpenseRowState extends State<_ExpenseRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.expense;
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
                flex: 2,
                child:
                    Text(_formatDate(e.date), style: AppTypography.bodySmall)),
            Expanded(
                flex: 3,
                child: Text(e.category,
                    style: AppTypography.bodySmall
                        .copyWith(fontWeight: FontWeight.w600))),
            Expanded(
                flex: 4,
                child: Text(e.description ?? '—',
                    style: AppTypography.bodySmall,
                    overflow: TextOverflow.ellipsis)),
            Expanded(
                flex: 2,
                child: Text(
                    '${e.amount.toStringAsFixed(2)} ${AppStrings.currency}',
                    style: AppTypography.bodySmall.copyWith(
                        color: AppColors.error, fontWeight: FontWeight.w700))),
            SizedBox(
              width: 80,
              child: _hovered
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: AppColors.info,
                            onPressed: widget.onEdit),
                        const SizedBox(width: 8),
                        IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: AppColors.error,
                            onPressed: widget.onDelete),
                      ],
                    )
                  : const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

class _ExpenseDialog extends StatefulWidget {
  const _ExpenseDialog({this.expense, required this.onSaved});
  final Expense? expense;
  final VoidCallback onSaved;

  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final _repo = ExpenseRepository();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _catCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _descCtrl;
  bool _saving = false;

  /// تحويل الأرقام العربية/الهندية إلى إنجليزية
  String _normalizeDigits(String input) {
    const arabic = '\u0660\u0661\u0662\u0663\u0664\u0665\u0666\u0667\u0668\u0669';
    var result = input;
    for (var i = 0; i < arabic.length; i++) {
      result = result.replaceAll(arabic[i], '$i');
    }
    return result;
  }

  final List<String> _commonCategories = [
    'مشتريات خامات',
    'رواتب',
    'كهرباء ومياه',
    'إيجار',
    'صيانة',
    'نثريات'
  ];

  @override
  void initState() {
    super.initState();
    _catCtrl = TextEditingController(text: widget.expense?.category ?? '');
    _amountCtrl =
        TextEditingController(text: widget.expense?.amount.toString() ?? '');
    _descCtrl = TextEditingController(text: widget.expense?.description ?? '');
  }

  @override
  void dispose() {
    _catCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final now = DateTime.now();
    final normalized = _normalizeDigits(_amountCtrl.text.trim());
    final expense = Expense(
      id: widget.expense?.id ?? DatabaseHelper.generateId(),
      category: _catCtrl.text.trim(),
      amount: double.parse(normalized),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      userId: AppStrings.currentUser,
      date: widget.expense?.date ?? now,
      createdAt: widget.expense?.createdAt ?? now,
    );

    try {
      if (widget.expense == null) {
        await _repo.insert(expense);
      } else {
        await _repo.update(expense);
      }
    } on StateError catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
      return;
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
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                        widget.expense == null
                            ? AppStrings.expenseAddNew
                            : AppStrings.expenseEdit,
                        style: AppTypography.headlineSmall),
                    const Spacer(),
                    IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 20),
                Text(AppStrings.expenseAmount,
                    style: AppTypography.bodySmall
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'مطلوب';
                    final normalized = _normalizeDigits(v.trim());
                    if (double.tryParse(normalized) == null) return 'أدخل رقمًا صحيحًا';
                    return null;
                  },
                  style: AppTypography.titleLarge,
                  decoration: InputDecoration(
                    suffixText: AppStrings.currency,
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusSm)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(AppStrings.expenseCategory,
                    style: AppTypography.bodySmall
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Autocomplete<String>(
                  initialValue: TextEditingValue(text: _catCtrl.text),
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) return _commonCategories;
                    return _commonCategories
                        .where((c) => c.contains(textEditingValue.text));
                  },
                  onSelected: (v) => _catCtrl.text = v,
                  fieldViewBuilder: (context, textEditingController, focusNode,
                      onFieldSubmitted) {
                    if (textEditingController.text.isEmpty &&
                        _catCtrl.text.isNotEmpty) {
                      textEditingController.text = _catCtrl.text;
                    }
                    _catCtrl.text = textEditingController.text;
                    textEditingController.addListener(() {
                      _catCtrl.text = textEditingController.text;
                    });

                    return TextFormField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      decoration: InputDecoration(
                        hintText: 'مثال: مشتريات، رواتب، كهرباء',
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusSm)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(AppStrings.expenseDescription,
                    style: AppTypography.bodySmall
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'ملاحظات تفصيلية حول المصروف...',
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusSm)),
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
