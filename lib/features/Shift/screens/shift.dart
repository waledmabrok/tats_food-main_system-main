import 'package:flutter/material.dart';
import 'package:system_casher/features/Shift/screens/shift_history.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/services/printing_service.dart';

import '../../../../repositories/shift_repository.dart';
import '../../../core/database/database_helper.dart';
import '../../dashboard/presentation/screens/manger_only.dart';

class ShiftScreen extends StatefulWidget {
  const ShiftScreen({super.key});

  @override
  State<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends State<ShiftScreen> {
  final _repo = ShiftRepository();
  Map<String, dynamic>? _currentShift;
  Map<String, dynamic>? _summary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final shift = await _repo.getCurrentShift();
    Map<String, dynamic>? summary;
    if (shift != null) {
      summary = await _repo.getShiftSummary(shift['id'] as String);
    }
    if (mounted) {
      setState(() {
        _currentShift = shift;
        _summary = summary;
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getCashierUsers() async {
    return DatabaseHelper.instance.query(
      'users',
      where: 'role = ? AND is_active = 1',
      whereArgs: ['cashier'],
      orderBy: 'name ASC',
    );
  }

  Future<void> _openShiftDialog() async {
    final cashiers = await _getCashierUsers();

    if (cashiers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('مفيش يوزر كاشير متاح لفتح شيفت')),
        );
      }
      return;
    }

    final ctrl = TextEditingController(text: '0');
    String? selectedUserId = cashiers.first['id'] as String;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('فتح شيفت جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: selectedUserId,
                decoration: const InputDecoration(labelText: 'الكاشير'),
                items: cashiers
                    .map((u) => DropdownMenuItem<String>(
                          value: u['id'] as String,
                          child: Text(u['name'] as String),
                        ))
                    .toList(),
                onChanged: (val) => setDialogState(() => selectedUserId = val),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'رصيد الدرج الافتتاحي',
                  suffixText: 'ج.م',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(AppStrings.btnCancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedUserId == null) return;
                final user = cashiers.firstWhere(
                  (u) => u['id'] == selectedUserId,
                );
                Navigator.pop(ctx, {
                  'user': user,
                  'cash': double.tryParse(ctrl.text) ?? 0,
                });
              },
              child: const Text('فتح الشيفت'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    final user = result['user'] as Map<String, dynamic>;
    final cash = result['cash'] as double;

    try {
      await _repo.openShift(
        userId: user['id'] as String,
        userName: user['name'] as String,
        openingCash: cash,
      );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _closeShiftDialog() async {
    final shift = _currentShift;
    final summary = _summary;
    if (shift == null || summary == null) return;

    final expected = (summary['expected_drawer_cash'] as double);
    final ctrl = TextEditingController(text: expected.toStringAsFixed(2));

    final actual = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('قفل الشيفت'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المتوقع في الدرج: ${expected.toStringAsFixed(2)} ج.م'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'المبلغ الفعلي بعد العدّ',
                suffixText: 'ج.م',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppStrings.btnCancel),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(ctrl.text) ?? expected),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('تأكيد القفل'),
          ),
        ],
      ),
    );

    if (actual == null) return;

    final result = await _repo.closeShift(
      shift['id'] as String,
      actualClosingCash: actual,
    );
    final diff = result['difference'] as double;

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تم قفل الشيفت'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'إجمالي المبيعات: ${(result['total_sales'] as double).toStringAsFixed(2)} ج.م',
            ),
            Text(
              'إجمالي المصروفات: ${(result['expenses_total'] as double).toStringAsFixed(2)} ج.م',
            ),
            const SizedBox(height: 8),
            Text(
              diff == 0
                  ? 'الدرج مظبوط تمامًا ✓'
                  : diff > 0
                      ? 'زيادة في الدرج: ${diff.toStringAsFixed(2)} ج.م'
                      : 'عجز في الدرج: ${diff.abs().toStringAsFixed(2)} ج.م',
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
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => PrintingService.instance.printShiftClosingReport(
              userName: shift['user_name'] as String,
              result: result,
            ),
            icon: const Icon(Icons.print_outlined),
            label: const Text('طباعة تقرير الإقفال'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('تمام'),
          ),
        ],
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        title: 'الشيفت',
        action: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShiftHistoryScreen()),
              ),
              icon: const Icon(Icons.history_rounded),
              tooltip: 'سجل الشيفتات',
            ),
            if (SessionService.instance.isOwner && _currentShift != null)
              OutlinedButton.icon(
                onPressed: _closeShiftDialog,
                icon: const Icon(Icons.lock_clock_rounded),
                label: const Text('قفل الشيفت'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error),
                ),
              ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppDimensions.space24),
                children: [
                  if (_currentShift == null)
                    _NoShiftCard(onOpen: _openShiftDialog),
                  if (_currentShift != null && _summary != null) ...[
                    _ShiftSummaryCard(
                      shift: _currentShift!,
                      summary: _summary!,
                    ),
                    const SizedBox(height: AppDimensions.space24),
                    ManagerOnly(
                      fallback: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'قفل الشيفت متاح للمدير فقط',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _closeShiftDialog,
                          icon: const Icon(Icons.lock_clock_rounded),
                          label: const Text('قفل الشيفت'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _NoShiftCard extends StatelessWidget {
  const _NoShiftCard({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.point_of_sale_rounded,
            size: 48,
            color: AppColors.textDisabled,
          ),
          const SizedBox(height: 12),
          Text('مفيش شيفت مفتوح دلوقتي', style: AppTypography.titleMedium),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: const Text('فتح شيفت جديد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShiftSummaryCard extends StatelessWidget {
  const _ShiftSummaryCard({required this.shift, required this.summary});
  final Map<String, dynamic> shift;
  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final cash = summary['cash_sales'] as double;
    final card = summary['card_sales'] as double;
    final other = summary['other_sales'] as double;
    final expenses = summary['expenses_total'] as double;
    final expected = summary['expected_drawer_cash'] as double;
    final ordersCount = summary['orders_count'] as int;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.space20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.badge_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'الشيفت الحالي — ${shift['user_name']}',
                style: AppTypography.titleMedium,
              ),
            ],
          ),
          const Divider(height: 24),
          _Row('عدد الأوردرات', '$ordersCount'),
          _Row('مبيعات كاش', '${cash.toStringAsFixed(2)} ج.م'),
          _Row('مبيعات فيزا/شبكة', '${card.toStringAsFixed(2)} ج.م'),
          if (other > 0) _Row('مبيعات أخرى', '${other.toStringAsFixed(2)} ج.م'),
          _Row(
            'المصروفات',
            '${expenses.toStringAsFixed(2)} ج.م',
            color: AppColors.error,
          ),
          const Divider(height: 24),
          _Row(
            'فلوس الدرج المتوقعة',
            '${expected.toStringAsFixed(2)} ج.م',
            bold: true,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.bold = false, this.color});
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          )
        : AppTypography.bodyMedium.copyWith(
            color: color ?? AppColors.textSecondary,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
