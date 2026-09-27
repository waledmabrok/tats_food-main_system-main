import 'package:flutter/material.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_top_bar.dart';

import '../../../../models/product.dart';
import '../../../../repositories/product_repository.dart';

import '../../../../repositories/supplier_repository.dart';
import '../../../repositories/RawMaterialRepository.dart';
import '../../dashboard/presentation/screens/manger_only.dart';

class _PurchaseRow {
  _PurchaseRow();
  String itemType = 'raw_material'; // raw_material | product
  String? itemId;
  String? itemName;
  final qtyCtrl = TextEditingController(text: '1');
  final costCtrl = TextEditingController(text: '0');

  double get quantity => double.tryParse(qtyCtrl.text) ?? 0;
  double get unitCost => double.tryParse(costCtrl.text) ?? 0;
  double get total => quantity * unitCost;
}

class PurchaseReceiveScreen extends StatefulWidget {
  const PurchaseReceiveScreen({super.key, this.initialSupplierId});

  final String? initialSupplierId;

  @override
  State<PurchaseReceiveScreen> createState() => _PurchaseReceiveScreenState();
}

class _PurchaseReceiveScreenState extends State<PurchaseReceiveScreen> {
  final _supplierRepo = SupplierRepository();
  final _rawMaterialRepo = RawMaterialRepository();
  final _productRepo = ProductRepository();

  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _rawMaterials = [];
  List<Product> _products = [];

  String? _selectedSupplierId;
  String _paymentType = 'cash'; // cash | credit
  final _paidCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  final List<_PurchaseRow> _rows = []; // يبدأ فارغاً — المستخدم يضيف الأصناف بنفسه

  bool _isLoading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final suppliers = await _supplierRepo.getAll();
    final rawMaterials = await _rawMaterialRepo.getAll();
    final products = await _productRepo.getAll(activeOnly: true, limit: 500);
    if (mounted) {
      setState(() {
        _suppliers = suppliers;
        _rawMaterials = rawMaterials;
        _products = products;
        // استخدم initialSupplierId إن وُجد، وإلا اختر الأول
        if (widget.initialSupplierId != null &&
            suppliers.any((s) => s['id'] == widget.initialSupplierId)) {
          _selectedSupplierId = widget.initialSupplierId;
        } else {
          _selectedSupplierId =
              suppliers.isNotEmpty ? suppliers.first['id'] as String : null;
        }
        _isLoading = false;
      });
    }
  }

  double get _total => _rows.fold(0, (sum, r) => sum + r.total);

  Future<void> _addSupplierDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مورد جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'اسم المورد')),
            const SizedBox(height: 12),
            TextField(
                controller: phoneCtrl,
                decoration:
                    const InputDecoration(labelText: 'تليفون (اختياري)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(AppStrings.btnCancel)),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final id = await _supplierRepo.addSupplier(
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim().isEmpty
                    ? null
                    : phoneCtrl.text.trim(),
              );
              _selectedSupplierId = id;
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text(AppStrings.btnSave),
          ),
        ],
      ),
    );
    if (saved == true) _load();
  }

  void _addRow() => setState(() => _rows.add(_PurchaseRow()));

  void _removeRow(int i) => setState(() => _rows.removeAt(i));

  Future<void> _submit() async {
    final user = SessionService.instance.currentUser;
    if (user == null || _selectedSupplierId == null) return;

    final validRows =
        _rows.where((r) => r.itemId != null && r.quantity > 0).toList();
    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('ضيف صنف واحد على الأقل'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _supplierRepo.receivePurchase(
        supplierId: _selectedSupplierId!,
        items: validRows
            .map((r) => {
                  'item_type': r.itemType,
                  'item_id': r.itemId,
                  'item_name': r.itemName,
                  'quantity': r.quantity,
                  'unit_cost': r.unitCost,
                })
            .toList(),
        paymentType: _paymentType,
        paidAmount: _paymentType == 'credit'
            ? (double.tryParse(_paidCtrl.text) ?? 0)
            : 0,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        userId: user.id,
      );

      // سجّل مصروف بقيمة المبلغ اللي خرج فعليًا كاش الآن فقط
      // (لو كاش: الإجمالي كله. لو آجل: المدفوع الآن بس، والباقي هيتسجل
      // كمصروف لما يتسدد لاحقًا من شاشة كشف حساب المورد)
      final paidNow = _paymentType == 'cash'
          ? _total
          : (double.tryParse(_paidCtrl.text) ?? 0);
      if (paidNow > 0) {
        final shift = await DatabaseHelper.instance.getCurrentShift();
        final supplierName = _suppliers.firstWhere(
            (s) => s['id'] == _selectedSupplierId,
            orElse: () => {'name': 'مورد'})['name'];
        await DatabaseHelper.instance.insert('expenses', {
          'id': DatabaseHelper.generateId(),
          'category': 'مشتريات من موردين',
          'amount': paidNow,
          'description': 'فاتورة شراء من $supplierName',
          'user_id': user.id,
          'shift_id': shift?['id'],
          'date': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('تم تسجيل الفاتورة وتحديث المخزون'),
            backgroundColor: AppColors.success),
      );
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('حصل خطأ: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ManagerOnlyScreen(
      child: Scaffold(
        appBar: AppTopBar(
          title: 'استلام بضاعة من مورد',
        ),
        /*  onBack: () => Navigator.pop(context)),*/
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppDimensions.space20),
                children: [
                  // ─── المورد ──────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedSupplierId,
                          items: _suppliers
                              .map((s) => DropdownMenuItem(
                                    value: s['id'] as String,
                                    child: Text(
                                        '${s['name']} ${((s['balance'] as num) > 0) ? "(مديون ${(s['balance'] as num).toStringAsFixed(0)})" : ""}'),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedSupplierId = v),
                          decoration:
                              const InputDecoration(labelText: 'المورد'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _addSupplierDialog,
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        tooltip: 'مورد جديد',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.space20),

                  // ─── الأصناف ─────────────────────────────────
                  Text('الأصناف المستلمة', style: AppTypography.titleMedium),
                  const SizedBox(height: 8),
                  ..._rows
                      .asMap()
                      .entries
                      .map((entry) => _buildRow(entry.key, entry.value)),
                  TextButton.icon(
                    onPressed: _addRow,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('إضافة صنف'),
                  ),
                  const SizedBox(height: AppDimensions.space16),

                  // ─── الإجمالي ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.space16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('إجمالي الفاتورة',
                            style: AppTypography.titleMedium),
                        Text(
                          '${_total.toStringAsFixed(2)} ج.م',
                          style: AppTypography.titleLarge.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space20),

                  // ─── طريقة الدفع ──────────────────────────────
                  Text('طريقة الدفع', style: AppTypography.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          value: 'cash',
                          groupValue: _paymentType,
                          onChanged: (v) => setState(() => _paymentType = v!),
                          title: const Text('كاش'),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          value: 'credit',
                          groupValue: _paymentType,
                          onChanged: (v) => setState(() => _paymentType = v!),
                          title: const Text('آجل'),
                        ),
                      ),
                    ],
                  ),
                  if (_paymentType == 'credit') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _paidCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'المدفوع الآن (اختياري)',
                        suffixText: 'ج.م',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _notesCtrl,
                    decoration:
                        const InputDecoration(labelText: 'ملاحظات (اختياري)'),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('تسجيل الفاتورة'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildRow(int index, _PurchaseRow row) {
    final items = row.itemType == 'raw_material' ? _rawMaterials : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(AppDimensions.space12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // نوع الصنف
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(
                  value: row.itemType,
                  isDense: true,
                  items: const [
                    DropdownMenuItem(
                        value: 'raw_material', child: Text('خامة')),
                    DropdownMenuItem(value: 'product', child: Text('صنف جاهز')),
                  ],
                  onChanged: (v) => setState(() {
                    row.itemType = v!;
                    row.itemId = null;
                    row.itemName = null;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              // اسم الصنف
              Expanded(
                child: row.itemType == 'raw_material'
                    ? DropdownButtonFormField<String>(
                        value: row.itemId,
                        isDense: true,
                        hint: const Text('اختار الخامة'),
                        items: (items ?? [])
                            .map((m) => DropdownMenuItem(
                                  value: m['id'] as String,
                                  child: Text('${m['name']} (${m['unit']})'),
                                ))
                            .toList(),
                        onChanged: (v) {
                          final m =
                              _rawMaterials.firstWhere((e) => e['id'] == v);
                          setState(() {
                            row.itemId = v;
                            row.itemName = m['name'] as String;
                          });
                        },
                      )
                    : DropdownButtonFormField<String>(
                        value: row.itemId,
                        isDense: true,
                        hint: const Text('اختار الصنف'),
                        items: _products
                            .map((p) => DropdownMenuItem(
                                value: p.id, child: Text(p.name)))
                            .toList(),
                        onChanged: (v) {
                          final p = _products.firstWhere((e) => e.id == v);
                          setState(() {
                            row.itemId = v;
                            row.itemName = p.name;
                          });
                        },
                      ),
              ),
              IconButton(
                onPressed: _rows.length > 1 ? () => _removeRow(index) : null,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: AppColors.error,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: row.qtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'الكمية', isDense: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: row.costCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'سعر الوحدة',
                      isDense: true,
                      suffixText: 'ج.م'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '= ${row.total.toStringAsFixed(2)} ج.م',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
