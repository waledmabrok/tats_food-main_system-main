import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_colors.dart';

class CloseShiftDialog extends StatefulWidget {
  const CloseShiftDialog({super.key});

  @override
  State<CloseShiftDialog> createState() => _CloseShiftDialogState();
}

class _CloseShiftDialogState extends State<CloseShiftDialog> {
  final _db = DatabaseHelper.instance;
  final _cashCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  Map<String, dynamic>? _summary;
  String? _shiftId;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cashCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final shift = await _db.getCurrentShift();
    if (shift == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final id = shift['id'] as String;
    final summary = await _db.getShiftSummary(id);
    if (!mounted) return;
    setState(() {
      _shiftId = id;
      _summary = summary;
      _loading = false;
    });
  }

  double get _expected =>
      (_summary?['expected_drawer_cash'] as num?)?.toDouble() ?? 0;
  double? get _actual => double.tryParse(_cashCtrl.text);

  Future<void> _close() async {
    final actual = _actual;
    if (actual == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('اكتب المبلغ الفعلي اللي في الدرج'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      await _db.closeShift(
        _shiftId!,
        actualClosingCash: actual,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('حصل خطأ: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Widget _row(String label, double v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('${v.toStringAsFixed(2)} ج.م',
                style: TextStyle(
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    final diff = _actual == null ? null : _actual! - _expected;

    return AlertDialog(
      title: const Text('قفل الشيفت'),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const SizedBox(
                height: 100, child: Center(child: CircularProgressIndicator()))
            : s == null
                ? const Text('مفيش شيفت مفتوح')
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _row('عدد الأوردرات',
                            (s['orders_count'] as int).toDouble()),
                        _row('رصيد أول الشيفت',
                            (s['shift']['opening_cash'] as num).toDouble()),
                        _row('مبيعات كاش', (s['cash_sales'] as num).toDouble()),
                        _row(
                            'مبيعات فيزا', (s['card_sales'] as num).toDouble()),
                        _row(
                            'مصروفات', (s['expenses_total'] as num).toDouble()),
                        const Divider(),
                        _row('المتوقع في الدرج', _expected, bold: true),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _cashCtrl,
                          autofocus: true,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*')),
                          ],
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'المبلغ الفعلي في الدرج',
                            suffixText: 'ج.م',
                          ),
                        ),
                        if (diff != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            diff == 0
                                ? 'مطابق ✅'
                                : diff > 0
                                    ? 'زيادة: ${diff.toStringAsFixed(2)} ج.م'
                                    : 'عجز: ${(-diff).toStringAsFixed(2)} ج.م',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: diff == 0
                                  ? AppColors.success
                                  : diff > 0
                                      ? AppColors.warning
                                      : AppColors.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextField(
                          controller: _notesCtrl,
                          decoration: const InputDecoration(
                              labelText: 'ملاحظات (اختياري)'),
                        ),
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _saving || _loading || s == null ? null : _close,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('قفل الشيفت'),
        ),
      ],
    );
  }
}
