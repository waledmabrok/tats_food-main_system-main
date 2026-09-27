import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/session_service.dart';

class SupplierDetailScreen extends StatefulWidget {
  const SupplierDetailScreen({super.key, required this.supplier});
  final Map<String, dynamic> supplier;

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  late Map<String, dynamic> _supplier = widget.supplier;
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _payments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final id = _supplier['id'] as String;
    final supplierRows = await DatabaseHelper.instance
        .query('suppliers', where: 'id = ?', whereArgs: [id]);
    final invoices = await DatabaseHelper.instance.getSupplierInvoices(id);
    final payments = await DatabaseHelper.instance.query(
      'supplier_payments',
      where: 'supplier_id = ?',
      whereArgs: [id],
      orderBy: 'created_at DESC',
    );
    if (mounted) {
      setState(() {
        _supplier = supplierRows.isNotEmpty ? supplierRows.first : _supplier;
        _invoices = invoices;
        _payments = payments;
        _loading = false;
      });
    }
  }

  Future<void> _payDialog() async {
    final balance = (_supplier['balance'] as num).toDouble();
    if (balance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مفيش مستحقات على المورد ده حاليًا')),
      );
      return;
    }

    final amountCtrl = TextEditingController(text: balance.toStringAsFixed(2));
    final notesCtrl = TextEditingController();
    String? selectedInvoiceId;
    final creditInvoices =
        _invoices.where((inv) => (inv['remaining_amount'] as num) > 0).toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('سداد دفعة للمورد'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المستحق حاليًا: ${balance.toStringAsFixed(2)} ج.م',
                  style: AppTypography.titleSmall.copyWith(
                      color: AppColors.warning, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'المبلغ المدفوع', suffixText: 'ج.م'),
                ),
                if (creditInvoices.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedInvoiceId,
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('سداد عام (بدون ربط بفاتورة)')),
                      ...creditInvoices.map(
                        (inv) => DropdownMenuItem<String?>(
                          value: inv['id'] as String,
                          child: Text(
                            '${inv['invoice_number']} — متبقي ${(inv['remaining_amount'] as num).toStringAsFixed(2)} ج.م',
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => selectedInvoiceId = v),
                    decoration: const InputDecoration(
                        labelText: 'ربط بفاتورة (اختياري)'),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration:
                      const InputDecoration(labelText: 'ملاحظات (اختياري)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('تأكيد السداد')),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final amount = double.tryParse(amountCtrl.text) ?? 0;
    if (amount <= 0) return;

    await DatabaseHelper.instance.paySupplier(
      supplierId: _supplier['id'] as String,
      amount: amount,
      invoiceId: selectedInvoiceId,
      paymentMethod: 'cash',
      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      userId: SessionService.instance.currentUser?.id,
    );

    // سجّل مصروف بقيمة السداد — الفلوس دي خرجت فعليًا من الدرج دلوقتي
    final shift = await DatabaseHelper.instance.getCurrentShift();
    await DatabaseHelper.instance.insert('expenses', {
      'id': DatabaseHelper.generateId(),
      'category': 'سداد مورد',
      'amount': amount,
      'description': selectedInvoiceId != null
          ? 'سداد لمورد ${_supplier['name']} — فاتورة مرتبطة'
          : 'سداد لمورد ${_supplier['name']}',
      'user_id': SessionService.instance.currentUser?.id,
      'shift_id': shift?['id'],
      'date': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('تم تسجيل سداد ${amount.toStringAsFixed(2)} ج.م'),
            backgroundColor: AppColors.success),
      );
    }
    _load();
  }

  Future<void> _showInvoiceItems(Map<String, dynamic> invoice) async {
    final items = await DatabaseHelper.instance.query(
      'purchase_invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [invoice['id']],
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('أصناف فاتورة ${invoice['invoice_number']}'),
        content: SizedBox(
          width: 420,
          child: items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(AppDimensions.space16),
                  child: Text('لا توجد أصناف'),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = items[i];
                    return ListTile(
                      dense: true,
                      title: Text(item['item_name'] as String),
                      subtitle: Text(
                        '${item['quantity']} × ${(item['unit_cost'] as num).toStringAsFixed(2)} ج.م',
                      ),
                      trailing: Text(
                          '${(item['total_cost'] as num).toStringAsFixed(2)} ج.م'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final balance = (_supplier['balance'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      appBar: AppTopBar(
        title: _supplier['name'] as String,
        onBack: () => Navigator.pop(context),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppDimensions.space20),
                children: [
                  // ─── بيانات المورد والمستحق ─────────────────
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.space16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMd),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((_supplier['phone'] as String?)?.isNotEmpty == true)
                          _infoRow(Icons.phone_outlined,
                              _supplier['phone'] as String),
                        if ((_supplier['address'] as String?)?.isNotEmpty ==
                            true)
                          _infoRow(Icons.location_on_outlined,
                              _supplier['address'] as String),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('المستحق عليه',
                                style: AppTypography.titleMedium),
                            Text(
                              '${balance.toStringAsFixed(2)} ج.م',
                              style: AppTypography.titleLarge.copyWith(
                                fontWeight: FontWeight.w800,
                                color: balance > 0
                                    ? AppColors.warning
                                    : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.space16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: balance > 0 ? _payDialog : null,
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('سداد دفعة'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space24),

                  // ─── فواتير الشراء ───────────────────────────
                  Text('فواتير الشراء', style: AppTypography.titleMedium),
                  const SizedBox(height: AppDimensions.space10),
                  if (_invoices.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppDimensions.space12),
                      child: Text('لا توجد فواتير شراء بعد',
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.textSecondary)),
                    )
                  else
                    ..._invoices.map((inv) => _invoiceTile(inv)),

                  const SizedBox(height: AppDimensions.space24),

                  // ─── سجل السداد ──────────────────────────────
                  Text('سجل السداد', style: AppTypography.titleMedium),
                  const SizedBox(height: AppDimensions.space10),
                  if (_payments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppDimensions.space12),
                      child: Text('لا توجد مدفوعات مسجلة بعد',
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.textSecondary)),
                    )
                  else
                    ..._payments.map((p) => _paymentTile(p)),
                ],
              ),
            ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(text, style: AppTypography.bodyMedium),
          ],
        ),
      );

  Widget _invoiceTile(Map<String, dynamic> inv) {
    final total = (inv['total_amount'] as num).toDouble();
    final paid = (inv['paid_amount'] as num).toDouble();
    final remaining = (inv['remaining_amount'] as num).toDouble();
    final isCredit = inv['payment_type'] == 'credit';

    return InkWell(
      onTap: () => _showInvoiceItems(inv),
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(AppDimensions.space12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.receipt_long_outlined,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(inv['invoice_number'] as String,
                      style: AppTypography.titleSmall),
                  Text(
                    _formatDate(inv['created_at'] as String),
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textDisabled),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${total.toStringAsFixed(2)} ج.م',
                    style: AppTypography.titleSmall
                        .copyWith(fontWeight: FontWeight.w700)),
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: isCredit
                        ? AppColors.warningLight
                        : AppColors.successLight,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusFull),
                  ),
                  child: Text(
                    isCredit
                        ? (remaining > 0
                            ? 'آجل — متبقي ${remaining.toStringAsFixed(0)}'
                            : 'آجل — مسدد')
                        : 'كاش',
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      color: isCredit ? AppColors.warning : AppColors.success,
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

  Widget _paymentTile(Map<String, dynamic> p) {
    final invoiceNumber = p['invoice_id'] == null
        ? 'سداد عام'
        : (_invoices
                .where((i) => i['id'] == p['invoice_id'])
                .firstOrNull?['invoice_number'] as String? ??
            'فاتورة محذوفة');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(AppDimensions.space12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded,
              color: AppColors.success, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invoiceNumber, style: AppTypography.titleSmall),
                if ((p['notes'] as String?)?.isNotEmpty == true)
                  Text(p['notes'] as String,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary)),
                Text(
                  _formatDate(p['created_at'] as String),
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textDisabled),
                ),
              ],
            ),
          ),
          Text(
            '${(p['amount'] as num).toStringAsFixed(2)} ج.م',
            style: AppTypography.titleSmall.copyWith(
                color: AppColors.success, fontWeight: FontWeight.w700),
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
}
