import 'package:flutter/material.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/printing_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../repositories/shift_repository.dart';

class ShiftHistoryScreen extends StatefulWidget {
  const ShiftHistoryScreen({super.key});

  @override
  State<ShiftHistoryScreen> createState() => _ShiftHistoryScreenState();
}

class _ShiftHistoryScreenState extends State<ShiftHistoryScreen> {
  final _repo = ShiftRepository();
  List<Map<String, dynamic>> _shifts = [];
  bool _isLoading = true;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final shifts = await _repo.getHistory(from: _from, to: _to);
    if (mounted) {
      setState(() {
        _shifts = shifts;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
    _load();
  }

  void _clearFilter() {
    setState(() {
      _from = null;
      _to = null;
    });
    _load();
  }

  double _totalSalesInRange() => _shifts.fold(
      0, (sum, s) => sum + ((s['total_sales'] as num?)?.toDouble() ?? 0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
          title: 'سجل الشيفتات', onBack: () => Navigator.pop(context)),
      body: Column(
        children: [
          // ─── فلتر التاريخ ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppDimensions.space16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(isFrom: true),
                        icon:
                            const Icon(Icons.calendar_today_rounded, size: 16),
                        label: Text(
                          _from == null ? 'من تاريخ' : _formatDate(_from!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(isFrom: false),
                        icon:
                            const Icon(Icons.calendar_today_rounded, size: 16),
                        label: Text(
                          _to == null ? 'لحد تاريخ' : _formatDate(_to!),
                        ),
                      ),
                    ),
                    if (_from != null || _to != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: _clearFilter,
                        icon: const Icon(Icons.clear_rounded),
                        tooltip: 'مسح الفلتر',
                      ),
                    ],
                  ],
                ),
                if (!_isLoading && _shifts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${_shifts.length} شيفت — إجمالي المبيعات: ${_totalSalesInRange().toStringAsFixed(2)} ج.م',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),

          // ─── القائمة ──────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _shifts.isEmpty
                    ? const EmptyStateWidget(
                        icon: Icons.history_rounded,
                        title: 'مفيش شيفتات في الفترة دي',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppDimensions.space16),
                        itemCount: _shifts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) => _ShiftHistoryTile(
                          shift: _shifts[i],
                          onTap: () => _showDetail(_shifts[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  void _showDetail(Map<String, dynamic> shift) {
    final isClosed = shift['status'] == 'closed';
    final expected = (shift['expected_cash'] as num?)?.toDouble();
    final closing = (shift['closing_cash'] as num?)?.toDouble();
    final diff = (isClosed && expected != null && closing != null)
        ? closing - expected
        : null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('شيفت ${shift['user_name']}'),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('الحالة', isClosed ? 'مغلق' : 'مفتوح'),
              _DetailRow(
                  'بدأ الساعة', _formatDateTime(shift['opened_at'] as String)),
              if (shift['closed_at'] != null)
                _DetailRow('اتقفل الساعة',
                    _formatDateTime(shift['closed_at'] as String)),
              const Divider(height: 20),
              _DetailRow('عدد الأوردرات', '${shift['orders_count'] ?? 0}'),
              _DetailRow('مبيعات كاش',
                  '${((shift['cash_sales'] as num?) ?? 0).toStringAsFixed(2)} ج.م'),
              _DetailRow('مبيعات فيزا/شبكة',
                  '${((shift['card_sales'] as num?) ?? 0).toStringAsFixed(2)} ج.م'),
              _DetailRow('المصروفات',
                  '${((shift['total_expenses'] as num?) ?? 0).toStringAsFixed(2)} ج.م'),
              const Divider(height: 20),
              _DetailRow(
                'إجمالي المبيعات',
                '${((shift['total_sales'] as num?) ?? 0).toStringAsFixed(2)} ج.م',
                bold: true,
              ),
              if (isClosed && diff != null) ...[
                const SizedBox(height: 4),
                _DetailRow(
                  diff == 0
                      ? 'الدرج مظبوط'
                      : (diff > 0 ? 'زيادة في الدرج' : 'عجز في الدرج'),
                  '${diff.abs().toStringAsFixed(2)} ج.م',
                  color: diff == 0
                      ? AppColors.success
                      : (diff > 0 ? AppColors.warning : AppColors.error),
                  bold: true,
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (isClosed)
            OutlinedButton.icon(
              onPressed: () => PrintingService.instance.printShiftClosingReport(
                userName: shift['user_name'] as String,
                result: {
                  'total_sales': (shift['total_sales'] as num?) ?? 0,
                  'cash_sales': (shift['cash_sales'] as num?) ?? 0,
                  'card_sales': (shift['card_sales'] as num?) ?? 0,
                  'other_sales': (shift['other_sales'] as num?) ?? 0,
                  'expenses_total': (shift['total_expenses'] as num?) ?? 0,
                  'orders_count': shift['orders_count'] ?? 0,
                  'expected_drawer_cash': expected ?? 0,
                  'actual_closing_cash': closing ?? 0,
                  'difference': diff ?? 0,
                },
              ),
              icon: const Icon(Icons.print_outlined),
              label: const Text('طباعة'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('تمام'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _ShiftHistoryTile extends StatelessWidget {
  const _ShiftHistoryTile({required this.shift, required this.onTap});
  final Map<String, dynamic> shift;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isClosed = shift['status'] == 'closed';
    final total = ((shift['total_sales'] as num?) ?? 0).toDouble();
    final opened = DateTime.tryParse(shift['opened_at'] as String);
    final dateLabel = opened == null
        ? ''
        : '${opened.year}/${opened.month.toString().padLeft(2, '0')}/${opened.day.toString().padLeft(2, '0')}  ${opened.hour.toString().padLeft(2, '0')}:${opened.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.space12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (isClosed ? AppColors.textSecondary : AppColors.success)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Icon(
                isClosed
                    ? Icons.lock_clock_rounded
                    : Icons.play_circle_outline_rounded,
                color: isClosed ? AppColors.textSecondary : AppColors.success,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shift['user_name'] as String,
                      style: AppTypography.titleSmall),
                  Text(dateLabel,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${total.toStringAsFixed(2)} ج.م',
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: (isClosed
                        ? AppColors.surfaceVariant
                        : AppColors.successLight),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusFull),
                  ),
                  child: Text(
                    isClosed ? 'مغلق' : 'مفتوح',
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      color: isClosed
                          ? AppColors.textSecondary
                          : AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value, {this.bold = false, this.color});
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? AppTypography.bodyMedium
            .copyWith(fontWeight: FontWeight.w700, color: color)
        : AppTypography.bodyMedium
            .copyWith(color: color ?? AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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
