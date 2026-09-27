import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/session_service.dart';

const _monthNames = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

const _transactionTypes = [
  ('advance', 'سلفة'),
  ('salary_payment', 'صرف راتب'),
  ('bonus', 'مكافأة'),
  ('deduction', 'خصم'),
];

String _typeLabel(String type) => _transactionTypes
    .firstWhere((t) => t.$1 == type, orElse: () => (type, type))
    .$2;

/// كشف حساب موظف كامل — بيتنقل بين الشهور ويعرض كل حركة مالية حصلت
/// (سلف، صرف راتب، مكافآت، خصومات) لكل شهر على حدة.
class EmployeeStatementScreen extends StatefulWidget {
  const EmployeeStatementScreen({super.key, required this.employee});
  final Map<String, dynamic> employee;

  @override
  State<EmployeeStatementScreen> createState() =>
      _EmployeeStatementScreenState();
}

class _EmployeeStatementScreenState extends State<EmployeeStatementScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, dynamic>? _statement;
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;

  String get _monthKey =>
      '${_month.year}-${_month.month.toString().padLeft(2, '0')}';
  String get _monthLabel => '${_monthNames[_month.month - 1]} ${_month.year}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final id = widget.employee['id'] as String;
    final statement = await DatabaseHelper.instance
        .getEmployeeMonthlyStatement(id, monthKey: _monthKey);
    final transactions = await DatabaseHelper.instance.query(
      'employee_transactions',
      where: 'employee_id = ? AND month_key = ?',
      whereArgs: [id, _monthKey],
      orderBy: 'created_at DESC',
    );
    if (mounted) {
      setState(() {
        _statement = statement;
        _transactions = transactions;
        _loading = false;
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
    _load();
  }

  Future<void> _addTransaction() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _TransactionDialog(employee: widget.employee, initialMonth: _month),
    );
    if (saved == true) _load();
  }

  Future<void> _deleteTransaction(Map<String, dynamic> tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحركة'),
        content: Text(
            'هل تريد حذف حركة "${_typeLabel(tx['type'] as String)}" بقيمة ${tx['amount']} ج.م؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseHelper.instance
          .delete('employee_transactions', 'id = ?', [tx['id']]);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final statement = _statement;
    final remaining =
        statement == null ? 0.0 : (statement['remaining'] as num).toDouble();

    return Scaffold(
      appBar: AppTopBar(
        title: 'كشف حساب ${widget.employee['name']}',
        onBack: () => Navigator.pop(context),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ─── منتقي الشهر ─────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: AppDimensions.space8),
                  color: AppColors.surface,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () => _changeMonth(-1),
                        icon: const Icon(Icons.chevron_right_rounded),
                        tooltip: 'الشهر السابق',
                      ),
                      SizedBox(
                        width: 140,
                        child: Text(
                          _monthLabel,
                          textAlign: TextAlign.center,
                          style: AppTypography.titleMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _changeMonth(1),
                        icon: const Icon(Icons.chevron_left_rounded),
                        tooltip: 'الشهر التالي',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // ─── الملخص ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.space16),
                  child: Container(
                    padding: const EdgeInsets.all(AppDimensions.space16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMd),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _statRow(
                            'الراتب الأساسي', statement?['monthly_salary']),
                        _statRow('السلف', statement?['advances'],
                            color: AppColors.warning),
                        _statRow('المدفوع', statement?['payments'],
                            color: AppColors.textSecondary),
                        _statRow('المكافآت', statement?['bonuses'],
                            color: AppColors.success),
                        _statRow('الخصومات', statement?['deductions'],
                            color: AppColors.error),
                        const Divider(height: 24),
                        _statRow(
                          'المتبقي',
                          remaining,
                          bold: true,
                          color: remaining < 0
                              ? AppColors.error
                              : AppColors.success,
                        ),
                      ],
                    ),
                  ),
                ),

                // ─── عنوان القائمة ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.space16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('حركات الشهر', style: AppTypography.titleMedium),
                      TextButton.icon(
                        onPressed: _addTransaction,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('حركة جديدة'),
                      ),
                    ],
                  ),
                ),

                // ─── قائمة الحركات ────────────────────────────────
                Expanded(
                  child: _transactions.isEmpty
                      ? Center(
                          child: Text(
                            'لا توجد حركات في $_monthLabel',
                            style: AppTypography.bodyMedium
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppDimensions.space16),
                          itemCount: _transactions.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final tx = _transactions[i];
                            final amount = (tx['amount'] as num).toDouble();
                            final type = tx['type'] as String;
                            final isPositive = type == 'bonus';
                            return Container(
                              padding:
                                  const EdgeInsets.all(AppDimensions.space12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusSm),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isPositive
                                        ? Icons.add_circle_outline_rounded
                                        : Icons.remove_circle_outline_rounded,
                                    color: isPositive
                                        ? AppColors.success
                                        : AppColors.warning,
                                    size: 20,
                                  ),
                                  const SizedBox(width: AppDimensions.space10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(_typeLabel(type),
                                            style: AppTypography.titleSmall),
                                        if ((tx['notes'] as String?)
                                                ?.trim()
                                                .isNotEmpty ==
                                            true)
                                          Text(
                                            tx['notes'] as String,
                                            style: AppTypography.caption
                                                .copyWith(
                                                    color: AppColors
                                                        .textSecondary),
                                          ),
                                        Text(
                                          _formatDate(
                                              tx['created_at'] as String),
                                          style: AppTypography.caption.copyWith(
                                              color: AppColors.textDisabled),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${amount.toStringAsFixed(2)} ج.م',
                                    style: AppTypography.titleSmall
                                        .copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18),
                                    color: AppColors.error,
                                    onPressed: () => _deleteTransaction(tx),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Widget _statRow(String label, dynamic value,
      {bool bold = false, Color? color}) {
    final v = (value is num) ? value.toDouble() : 0.0;
    final style = bold
        ? AppTypography.titleMedium
            .copyWith(fontWeight: FontWeight.w800, color: color)
        : AppTypography.bodyMedium
            .copyWith(color: color ?? AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('${v.toStringAsFixed(2)} ج.م', style: style),
        ],
      ),
    );
  }
}

/// Dialog تسجيل حركة مالية لموظف — بيختار فيه المستخدم الشهر اللي
/// الحركة خاصة بيه (مش لازم يبقى الشهر الحالي، ممكن يسجل سلفة
/// لشهر فات مثلًا نسيها).
class _TransactionDialog extends StatefulWidget {
  const _TransactionDialog({required this.employee, DateTime? initialMonth})
      : initialMonth = initialMonth;
  final Map<String, dynamic> employee;
  final DateTime? initialMonth;

  @override
  State<_TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<_TransactionDialog> {
  String _type = 'advance';
  late DateTime _month;
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = widget.initialMonth ?? DateTime(now.year, now.month);
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  String get _monthKey =>
      '${_month.year}-${_month.month.toString().padLeft(2, '0')}';
  String get _monthLabel => '${_monthNames[_month.month - 1]} ${_month.year}';

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) return;
    setState(() => _saving = true);
    await DatabaseHelper.instance.addEmployeeTransaction(
      employeeId: widget.employee['id'] as String,
      type: _type,
      amount: amount,
      monthKey: _monthKey,
      notes: _notes.text.trim(),
      userId: SessionService.instance.currentUser?.id,
    );

    // سلفة / صرف راتب / مكافأة = فلوس خرجت فعليًا من الدرج → تتسجل كمصروف
    // الخصم فقط لا يُسجَّل، لأنه تخفيض من المستحق للموظف وليس خروج نقدية
    if (_type != 'deduction') {
      final shift = await DatabaseHelper.instance.getCurrentShift();
      await DatabaseHelper.instance.insert('expenses', {
        'id': DatabaseHelper.generateId(),
        'category': 'رواتب وسلف موظفين',
        'amount': amount,
        'description': '${_typeLabel(_type)} — ${widget.employee['name']}',
        'user_id': SessionService.instance.currentUser?.id,
        'shift_id': shift?['id'],
        'date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('حركة مالية - ${widget.employee['name']}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── اختيار الشهر ─────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => setState(
                      () => _month = DateTime(_month.year, _month.month - 1)),
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                ),
                Text('الشهر: $_monthLabel', style: AppTypography.bodyMedium),
                IconButton(
                  onPressed: () => setState(
                      () => _month = DateTime(_month.year, _month.month + 1)),
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.space16),
          DropdownButtonFormField<String>(
            initialValue: _type,
            items: _transactionTypes
                .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                .toList(),
            onChanged: (value) => setState(() => _type = value!),
            decoration: const InputDecoration(labelText: 'نوع الحركة'),
          ),
          const SizedBox(height: AppDimensions.space16),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration:
                const InputDecoration(labelText: 'المبلغ', suffixText: 'ج.م'),
          ),
          const SizedBox(height: AppDimensions.space16),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'جاري الحفظ...' : 'تسجيل'),
        ),
      ],
    );
  }
}
