import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/app_colors.dart';

class ReceivePurchaseDialog extends StatefulWidget {
  const ReceivePurchaseDialog({super.key});

  @override
  State<ReceivePurchaseDialog> createState() => _ReceivePurchaseDialogState();
}

class _ReceivePurchaseDialogState extends State<ReceivePurchaseDialog> {
  final _db = DatabaseHelper.instance;

  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _rawMaterials = [];
  List<Map<String, dynamic>> _products = [];

  String? _supplierId;
  bool _isCredit = true;
  String _itemType = 'raw_material'; // raw_material | product
  String? _itemId;

  final _qtyCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _paidCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final List<Map<String, dynamic>> _lines = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    _paidCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final suppliers = await _db.getSuppliers();
    final raws = await _db.getRawMaterials();
    final products = await _db.query('products',
        where: 'is_active = 1', orderBy: 'name ASC');
    if (!mounted) return;
    setState(() {
      _suppliers = suppliers;
      _rawMaterials = raws;
      _products = products;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _currentItems =>
      _itemType == 'raw_material' ? _rawMaterials : _products;

  double get _total => _lines.fold(0.0,
      (s, l) => s + (l['quantity'] as double) * (l['unit_cost'] as double));

  double get _paid => double.tryParse(_paidCtrl.text) ?? 0;

  void _msg(String text, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? AppColors.error : AppColors.success,
    ));
  }

  void _addLine() {
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final cost = double.tryParse(_costCtrl.text) ?? 0;
    if (_itemId == null) return _msg('اختار الصنف الأول');
    if (qty <= 0) return _msg('اكتب كمية صحيحة');
    if (cost <= 0) return _msg('اكتب سعر الوحدة');

    final item = _currentItems.firstWhere((i) => i['id'] == _itemId);
    setState(() {
      _lines.add({
        'item_type': _itemType,
        'item_id': _itemId,
        'item_name': item['name'],
        'quantity': qty,
        'unit_cost': cost,
      });
      _itemId = null;
      _qtyCtrl.clear();
      _costCtrl.clear();
    });
  }

  Future<void> _addSupplierDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مورد جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'اسم المورد'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'رقم التليفون'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    final id = await _db.addSupplier(
      name: nameCtrl.text.trim(),
      phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
    );
    final suppliers = await _db.getSuppliers();
    if (!mounted) return;
    setState(() {
      _suppliers = suppliers;
      _supplierId = id;
    });
  }

  Future<void> _save() async {
    if (_supplierId == null) return _msg('اختار المورد');
    if (_lines.isEmpty) return _msg('ضيف صنف واحد على الأقل');
    if (_isCredit && _paid > _total) {
      return _msg('المدفوع أكبر من إجمالي الفاتورة');
    }

    setState(() => _saving = true);
    try {
      await _db.receivePurchase(
        supplierId: _supplierId!,
        items: _lines,
        paymentType: _isCredit ? 'credit' : 'cash',
        paidAmount: _isCredit ? _paid : _total,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        userId: SessionService.instance.currentUser?.id,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _msg('حصل خطأ: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining =
        _isCredit ? (_total - _paid).clamp(0, double.infinity) : 0;

    return AlertDialog(
      title: const Text('استلام بضاعة من مورد'),
      content: SizedBox(
        width: 560,
        child: _loading
            ? const SizedBox(
                height: 120, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── المورد ───
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey(
                                'sup-$_supplierId-${_suppliers.length}'),
                            initialValue: _supplierId,
                            items: _suppliers
                                .map((s) => DropdownMenuItem<String>(
                                      value: s['id'] as String,
                                      child: Text(s['name'] as String),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _supplierId = v),
                            decoration:
                                const InputDecoration(labelText: 'المورد'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'مورد جديد',
                          onPressed: _addSupplierDialog,
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ─── نوع الدفع ───
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('آجل')),
                        ButtonSegment(value: false, label: Text('كاش')),
                      ],
                      selected: {_isCredit},
                      onSelectionChanged: (s) =>
                          setState(() => _isCredit = s.first),
                    ),
                    const Divider(height: 28),

                    // ─── إضافة صنف ───
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'raw_material', label: Text('خامات')),
                        ButtonSegment(
                            value: 'product', label: Text('أصناف جاهزة')),
                      ],
                      selected: {_itemType},
                      onSelectionChanged: (s) => setState(() {
                        _itemType = s.first;
                        _itemId = null;
                        _costCtrl.clear();
                      }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey('item-$_itemType-$_itemId'),
                      initialValue: _itemId,
                      items: _currentItems
                          .map((i) => DropdownMenuItem<String>(
                                value: i['id'] as String,
                                child: Text(i['name'] as String),
                              ))
                          .toList(),
                      onChanged: (v) {
                        final item =
                            _currentItems.firstWhere((i) => i['id'] == v);
                        final defaultCost = _itemType == 'raw_material'
                            ? item['cost_per_unit']
                            : item['cost'];
                        setState(() {
                          _itemId = v;
                          final c = (defaultCost as num?)?.toDouble() ?? 0;
                          _costCtrl.text = c > 0 ? c.toString() : '';
                        });
                      },
                      decoration: const InputDecoration(labelText: 'الصنف'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _qtyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*')),
                            ],
                            decoration:
                                const InputDecoration(labelText: 'الكمية'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _costCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*')),
                            ],
                            decoration:
                                const InputDecoration(labelText: 'سعر الوحدة'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _addLine,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('إضافة'),
                        ),
                      ],
                    ),

                    // ─── الأصناف المضافة ───
                    if (_lines.isNotEmpty) ...[
                      const Divider(height: 28),
                      ..._lines.asMap().entries.map((e) {
                        final l = e.value;
                        final lineTotal = (l['quantity'] as double) *
                            (l['unit_cost'] as double);
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(l['item_name'] as String),
                          subtitle:
                              Text('${l['quantity']} × ${l['unit_cost']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${lineTotal.toStringAsFixed(2)} ج.م'),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 20),
                                color: AppColors.error,
                                onPressed: () =>
                                    setState(() => _lines.removeAt(e.key)),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    const Divider(height: 28),

                    // ─── الإجمالي والمدفوع ───
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('إجمالي الفاتورة'),
                        Text('${_total.toStringAsFixed(2)} ج.م',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    if (_isCredit) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _paidCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*')),
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'مدفوع مقدمًا (اختياري)',
                          suffixText: 'ج.م',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('المتبقي على المورد (آجل)'),
                          Text('${remaining.toStringAsFixed(2)} ج.م',
                              style: TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesCtrl,
                      decoration:
                          const InputDecoration(labelText: 'ملاحظات (اختياري)'),
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
          onPressed: _saving || _loading ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('تأكيد الاستلام'),
        ),
      ],
    );
  }
}
