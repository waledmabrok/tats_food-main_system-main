import 'package:flutter/material.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/app_colors.dart';

const _expenseCategories = [
  'مشتريات يومية',
  'صيانة',
  'مواصلات',
  'فواتير (كهرباء/مياه/نت)',
  'أخرى',
];

class AddExpenseDialog extends StatefulWidget {
  const AddExpenseDialog({super.key});

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  String _category = _expenseCategories.first;
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('اكتب مبلغ صحيح'),
            backgroundColor: AppColors.error),
      );
      return;
    }
    final user = SessionService.instance.currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    await DatabaseHelper.instance.addQuickExpense(
      category: _category,
      amount: amount,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      userId: user.id,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة مصروف'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: _expenseCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
              decoration: const InputDecoration(labelText: 'نوع المصروف'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'المبلغ', suffixText: 'ج.م'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'جاري الحفظ...' : 'حفظ'),
        ),
      ],
    );
  }
}
