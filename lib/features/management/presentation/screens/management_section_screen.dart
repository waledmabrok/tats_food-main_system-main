import 'package:flutter/material.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/database/database_helper.dart';
import '../../../Shift/screens/PurchaseReceiveScreen.dart';
import '../../../../models/product.dart';
import '../../../../repositories/product_repository.dart';
import 'employee_statement.dart';
import 'supplier_detail_screen.dart';

/// تحويل الأرقام العربية إلى إنجليزية
String _arabicToEnglish(String input) {
  const arabic = '\u0660\u0661\u0662\u0663\u0664\u0665\u0666\u0667\u0668\u0669';
  var result = input;
  for (var i = 0; i < arabic.length; i++) {
    result = result.replaceAll(arabic[i], '$i');
  }
  return result;
}

/// التحقق من رقم الهاتف: 11 رقم، يبدأ بـ 0
String? _validatePhone(String? v, {bool required = true}) {
  if (v == null || v.trim().isEmpty) {
    return required ? 'رقم الهاتف مطلوب' : null;
  }
  final normalized = _arabicToEnglish(v.trim());
  if (normalized.length != 11) return 'رقم الهاتف يجب أن يكون 11 رقم بالضبط';
  if (!normalized.startsWith('0')) return 'رقم الهاتف يجب أن يبدأ بـ 0';
  return null;
}

enum ManagementSection {
  suppliers,
  customers,
  shifts,
  rawMaterials,
  accounting,
  employees,
}

/// قائمة الوحدات الجاهزة للخامات — لو مش موجودة هنا يختار "أخرى" ويكتبها بنفسه
const rawMaterialUnits = [
  'كجم',
  'جم',
  'لتر',
  'مل',
  'قطعة',
  'علبة',
  'كيس',
  'دستة'
];

/// مجموعات الوحدات المتوافقة لكل وحدة أساسية، مع معامل التحويل من الوحدة
/// المختارة إلى الوحدة الأساسية المخزنة بها الخامة (مثال: الخامة أساسها كجم،
/// فلو اخترت "جم" هيتحول كل جرام تكتبه إلى 0.001 كجم قبل الحفظ وحساب التكلفة).
const Map<String, Map<String, double>> compatibleUnitFactors = {
  'كجم': {'كجم': 1, 'جم': 0.001},
  'جم': {'جم': 1, 'كجم': 1000},
  'لتر': {'لتر': 1, 'مل': 0.001},
  'مل': {'مل': 1, 'لتر': 1000},
  'دستة': {'دستة': 1, 'قطعة': 1 / 12},
  'قطعة': {'قطعة': 1, 'دستة': 12},
};

/// يرجع الوحدات المتاحة للاختيار عند إضافة الخامة للوصفة، بناءً على وحدة
/// تخزين الخامة الأساسية. لو مفيش وحدات متوافقة (مثل علبة/كيس) بترجع هي نفسها فقط.
List<String> compatibleUnitsFor(String baseUnit) {
  final map = compatibleUnitFactors[baseUnit];
  if (map == null) return [baseUnit];
  return map.keys.toList();
}

class ManagementSectionScreen extends StatelessWidget {
  const ManagementSectionScreen({super.key, required this.section});

  final ManagementSection section;

  @override
  Widget build(BuildContext context) {
    if (section == ManagementSection.suppliers) {
      return const _ManagementRecordsScreen(type: _RecordType.suppliers);
    }
    if (section == ManagementSection.customers) {
      return const _ManagementRecordsScreen(type: _RecordType.customers);
    }
    if (section == ManagementSection.rawMaterials) {
      return const _ManagementRecordsScreen(type: _RecordType.rawMaterials);
    }
    if (section == ManagementSection.employees) {
      return const _ManagementRecordsScreen(type: _RecordType.employees);
    }
    if (section == ManagementSection.accounting) {
      return const _AccountsScreen();
    }

    final content = _sectionContent(section);

    return Scaffold(
      appBar: AppTopBar(title: content.title),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.space24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content.subtitle, style: AppTypography.bodyMedium),
            const SizedBox(height: AppDimensions.space24),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 900 ? 3 : 1;
                return GridView.count(
                  crossAxisCount: columns,
                  crossAxisSpacing: AppDimensions.space16,
                  mainAxisSpacing: AppDimensions.space16,
                  childAspectRatio: columns == 1 ? 4.2 : 2.4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final card in content.cards) _SummaryCard(card: card),
                  ],
                );
              },
            ),
            const SizedBox(height: AppDimensions.space24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.space24),
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
                      Icon(content.icon, color: AppColors.primary),
                      const SizedBox(width: AppDimensions.space12),
                      Text(content.workflowTitle,
                          style: AppTypography.titleLarge),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.space16),
                  for (final step in content.steps) ...[
                    _WorkflowStep(step: step),
                    const SizedBox(height: AppDimensions.space12),
                  ],
                  const SizedBox(height: AppDimensions.space8),
                  FilledButton.icon(
                    onPressed: () => _showComingSoon(context, content.action),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(content.action),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('سيتم فتح نموذج $action بعد تجهيز قاعدة البيانات')),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.card});

  final _SummaryData card;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(card.icon, color: card.color, size: AppDimensions.iconLg),
          const SizedBox(width: AppDimensions.space12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(card.label, style: AppTypography.bodySmall),
              const SizedBox(height: AppDimensions.space4),
              Text(card.value, style: AppTypography.titleLarge),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkflowStep extends StatelessWidget {
  const _WorkflowStep({required this.step});

  final String step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
        const SizedBox(width: AppDimensions.space8),
        Text(step, style: AppTypography.bodyMedium),
      ],
    );
  }
}

class _SummaryData {
  const _SummaryData(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _SectionContent {
  const _SectionContent({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.workflowTitle,
    required this.action,
    required this.cards,
    required this.steps,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String workflowTitle;
  final String action;
  final List<_SummaryData> cards;
  final List<String> steps;
}

_SectionContent _sectionContent(ManagementSection section) {
  return switch (section) {
    ManagementSection.suppliers => _SectionContent(
        title: 'الموردون',
        subtitle: 'إدارة الموردين وفواتير الشراء والمدفوعات الآجلة.',
        icon: Icons.local_shipping_rounded,
        workflowTitle: 'دورة استلام البضاعة',
        action: 'إضافة مورد',
        cards: [
          _SummaryData('عدد الموردين', '0', Icons.people_alt_outlined,
              AppColors.primary),
          _SummaryData('مستحقات الموردين', '0 ج.م', Icons.credit_card_outlined,
              AppColors.warning),
          _SummaryData('فواتير هذا الشهر', '0', Icons.receipt_long_outlined,
              AppColors.success),
        ],
        steps: [
          'إنشاء بيانات المورد',
          'تسجيل فاتورة شراء نقدي أو آجل',
          'تسجيل السداد وكشف الحساب'
        ],
      ),
    ManagementSection.customers => _SectionContent(
        title: 'العملاء والدليفري',
        subtitle: 'حفظ بيانات العملاء وعناوينهم ومتابعة طلبات التوصيل.',
        icon: Icons.delivery_dining_rounded,
        workflowTitle: 'بيانات عميل الدليفري',
        action: 'إضافة عميل',
        cards: [
          _SummaryData('العملاء', '0', Icons.people_outline, AppColors.primary),
          _SummaryData('عناوين محفوظة', '0', Icons.location_on_outlined,
              AppColors.success),
          _SummaryData('طلبات توصيل اليوم', '0', Icons.delivery_dining_outlined,
              AppColors.warning),
        ],
        steps: [
          'الاسم ورقم الهاتف',
          'أكثر من عنوان مع ملاحظات التوصيل',
          'ربط العميل بالطلب والتحصيل'
        ],
      ),
    ManagementSection.shifts => _SectionContent(
        title: 'الشيفتات والدرج',
        subtitle: 'متابعة مبيعات كل شيفت ومطابقة النقد الموجود في الدرج.',
        icon: Icons.point_of_sale_rounded,
        workflowTitle: 'إقفال الشيفت',
        action: 'فتح شيفت',
        cards: [
          _SummaryData(
              'الشيفت الحالي', 'مغلق', Icons.lock_outline, AppColors.warning),
          _SummaryData(
              'مبيعات اليوم', '0 ج.م', Icons.trending_up, AppColors.success),
          _SummaryData('نقد الدرج المتوقع', '0 ج.م', Icons.payments_outlined,
              AppColors.primary),
        ],
        steps: [
          'تسجيل رصيد بداية الدرج',
          'تجميع المبيعات حسب طريقة الدفع',
          'إدخال النقد الفعلي وتسجيل العجز أو الزيادة'
        ],
      ),
    ManagementSection.rawMaterials => _SectionContent(
        title: 'الخامات والوصفات',
        subtitle: 'إدارة الخامات والوحدات والوصفات وحساب تكلفة الأصناف.',
        icon: Icons.science_rounded,
        workflowTitle: 'حساب تكلفة الصنف',
        action: 'إضافة خامة',
        cards: [
          _SummaryData(
              'الخامات', '0', Icons.inventory_2_outlined, AppColors.primary),
          _SummaryData(
              'وصفات مرتبطة', '0', Icons.menu_book_outlined, AppColors.success),
          _SummaryData('تنبيهات المخزون', '0', Icons.warning_amber_outlined,
              AppColors.warning),
        ],
        steps: [
          'تعريف الخامة ووحدة القياس',
          'ربط الكميات بالوصفة',
          'استهلاك الخامة عند البيع وإعادة حساب الربح'
        ],
      ),
    ManagementSection.accounting => _SectionContent(
        title: 'الحسابات',
        subtitle: 'دليل الحسابات والقيود والحركة النقدية والتقارير المالية.',
        icon: Icons.account_balance_rounded,
        workflowTitle: 'الدورة المحاسبية',
        action: 'إضافة حساب',
        cards: [
          _SummaryData('الحسابات الرئيسية', '0', Icons.account_tree_outlined,
              AppColors.primary),
          _SummaryData('قيود هذا الشهر', '0', Icons.receipt_long_outlined,
              AppColors.success),
          _SummaryData('صافي التدفق النقدي', '0 ج.م', Icons.currency_exchange,
              AppColors.warning),
        ],
        steps: [
          'بناء دليل حسابات هرمي',
          'إنشاء قيد من كل بيع أو شراء أو مصروف',
          'عرض الأرباح والخسائر والتدفق النقدي'
        ],
      ),
    ManagementSection.employees => _SectionContent(
        title: 'الموظفون والرواتب',
        subtitle: 'إدارة الموظفين والرواتب والسلف والمدفوعات المتبقية.',
        icon: Icons.badge_rounded,
        workflowTitle: 'حساب مستحق الموظف',
        action: 'إضافة موظف',
        cards: [
          _SummaryData(
              'الموظفون', '0', Icons.people_outline, AppColors.primary),
          _SummaryData('رواتب الشهر', '0 ج.م', Icons.payments_outlined,
              AppColors.success),
          _SummaryData('سلف مستحقة', '0 ج.م', Icons.request_quote_outlined,
              AppColors.warning),
        ],
        steps: [
          'تسجيل الراتب الأساسي وبيانات الموظف',
          'تسجيل السلف والخصومات',
          'صرف الراتب وإظهار المتبقي وكشف الحساب'
        ],
      ),
  };
}

enum _RecordType { suppliers, customers, rawMaterials, employees }

class _ManagementRecordsScreen extends StatefulWidget {
  const _ManagementRecordsScreen({required this.type});

  final _RecordType type;

  @override
  State<_ManagementRecordsScreen> createState() =>
      _ManagementRecordsScreenState();
}

class _ManagementRecordsScreenState extends State<_ManagementRecordsScreen> {
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _offset = 0;
  final int _limit = 20;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  String get _title => switch (widget.type) {
        _RecordType.suppliers => 'الموردون',
        _RecordType.customers => 'العملاء والدليفري',
        _RecordType.rawMaterials => 'الخامات',
        _RecordType.employees => 'الموظفون والرواتب',
      };

  IconData get _icon => switch (widget.type) {
        _RecordType.suppliers => Icons.local_shipping_outlined,
        _RecordType.customers => Icons.delivery_dining_outlined,
        _RecordType.rawMaterials => Icons.science_outlined,
        _RecordType.employees => Icons.badge_outlined,
      };

  String get _addLabel => switch (widget.type) {
        _RecordType.suppliers => 'إضافة مورد',
        _RecordType.customers => 'إضافة عميل',
        _RecordType.rawMaterials => 'إضافة خامة',
        _RecordType.employees => 'إضافة موظف',
      };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_loading && !_loadingMore && _hasMore) {
        _loadMore();
      }
    }
  }

  Future<void> _load({bool isLoadMore = false}) async {
    if (isLoadMore) {
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _offset = 0;
        _hasMore = true;
      });
    }

    final db = DatabaseHelper.instance;
    final records = switch (widget.type) {
      _RecordType.suppliers =>
        await db.getSuppliers(limit: _limit, offset: _offset),
      _RecordType.customers =>
        await db.getCustomers(limit: _limit, offset: _offset),
      _RecordType.rawMaterials =>
        await db.getRawMaterials(limit: _limit, offset: _offset),
      _RecordType.employees =>
        await db.getEmployees(limit: _limit, offset: _offset),
    };
    if (mounted) {
      setState(() {
        if (isLoadMore) {
          _records.addAll(records);
        } else {
          _records = records;
        }
        if (records.length < _limit) {
          _hasMore = false;
        } else {
          _offset += _limit;
        }
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _loadMore() => _load(isLoadMore: true);

  Future<void> _showAddDialog() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _RecordFormDialog(type: widget.type),
    );
    if (saved == true) _load();
  }

  Future<void> _hideRawMaterial(Map<String, dynamic> record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الخامة'),
        content: Text(
            'هل تريد حذف خامة ${record['name']}؟ ستظل محفوظة في الوصفات والحركات السابقة.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseHelper.instance
          .setRawMaterialActive(record['id'] as String, false);
      _load();
    }
  }

  Future<void> _editRecord(Map<String, dynamic> record) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _RecordFormDialog(type: widget.type, record: record),
    );
    if (saved == true) _load();
  }

  Future<void> _deleteSupplier(Map<String, dynamic> record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المورد'),
        content: Text('هل تريد حذف المورد "${record['name']}"؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseHelper.instance.deleteSupplier(record['id'] as String);
      _load();
    }
  }

  Future<void> _deleteCustomer(Map<String, dynamic> record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف العميل'),
        content: Text('هل تريد حذف العميل "${record['name']}"؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseHelper.instance.deleteCustomer(record['id'] as String);
      _load();
    }
  }

  Future<void> _deleteEmployee(Map<String, dynamic> record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الموظف'),
        content: Text('هل تريد حذف الموظف "${record['name']}"؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseHelper.instance.deleteEmployee(record['id'] as String);
      _load();
    }
  }

  Future<void> _openEmployeeStatement(Map<String, dynamic> record) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => EmployeeStatementScreen(employee: record)),
    );
    _load();
  }

  Future<void> _openSupplierDetail(Map<String, dynamic> record) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SupplierDetailScreen(supplier: record)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: _title),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.space16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Text('${_records.length} سجل', style: AppTypography.bodyMedium),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _showAddDialog,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(_addLabel),
                ),
                if (widget.type == _RecordType.rawMaterials) ...[
                  const SizedBox(width: AppDimensions.space8),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RecipesScreen()),
                    ),
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('الوصفات'),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_icon,
                                size: 64, color: AppColors.textDisabled),
                            const SizedBox(height: AppDimensions.space12),
                            Text('لا توجد بيانات بعد',
                                style: AppTypography.titleMedium),
                            const SizedBox(height: AppDimensions.space16),
                            OutlinedButton.icon(
                              onPressed: _showAddDialog,
                              icon: const Icon(Icons.add_rounded),
                              label: Text(_addLabel),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppDimensions.space24),
                        itemCount: _records.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppDimensions.space10),
                        itemBuilder: (_, index) {
                          if (index == _records.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return _recordTile(_records[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _recordTile(Map<String, dynamic> record) {
    final name = record['name'] as String? ?? 'بدون اسم';

    // بيانات منظمة لكل نوع (Label فوق Value)
    final List<_LabelValue> details = switch (widget.type) {
      _RecordType.suppliers => [
          _LabelValue('اسم المورد', name),
          _LabelValue('رقم الهاتف', record['phone'] as String? ?? 'بدون هاتف'),
          _LabelValue('العنوان', record['address'] as String? ?? 'بدون عنوان'),
        ],
      _RecordType.customers => [
          _LabelValue('اسم العميل', name),
          _LabelValue('رقم الهاتف', record['phone'] as String? ?? ''),
          _LabelValue('العنوان', record['address'] as String? ?? 'بدون عنوان'),
        ],
      _RecordType.rawMaterials => [
          _LabelValue('الخامة', name),
          _LabelValue('الوحدة', record['unit'] as String? ?? ''),
          _LabelValue('تكلفة الوحدة', '${record['cost_per_unit'] ?? 0} ج.م'),
        ],
      _RecordType.employees => [
          _LabelValue('الموظف', name),
          _LabelValue('رقم الهاتف', record['phone'] as String? ?? ''),
          _LabelValue('الوظيفة', record['position'] as String? ?? 'بدون وظيفة'),
          _LabelValue('الراتب الشهري', '${record['monthly_salary'] ?? 0} ج.م'),
        ],
    };

    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // البيانات بأسلوب Label فوق Value
          Wrap(
            spacing: AppDimensions.space24,
            runSpacing: AppDimensions.space8,
            children: details
                .map((d) => _LabelValueWidget(label: d.label, value: d.value))
                .toList(),
          ),
          const SizedBox(height: AppDimensions.space12),
          // الأزرار
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.type == _RecordType.suppliers) ...[
                TextButton.icon(
                  onPressed: () => _openSupplierDetail(record),
                  icon: const Icon(Icons.account_balance_wallet_outlined,
                      size: 18),
                  label: const Text('كشف الحساب'),
                ),
                const SizedBox(width: AppDimensions.space4),
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PurchaseReceiveScreen(
                          initialSupplierId: record['id'] as String?),
                    ),
                  ),
                  icon: const Icon(Icons.move_to_inbox_outlined, size: 18),
                  label: const Text('استلام بضاعة'),
                ),
                const SizedBox(width: AppDimensions.space4),
              ],
              if (widget.type == _RecordType.customers) ...[
                TextButton.icon(
                  onPressed: () => _showCustomerHistory(record),
                  icon: const Icon(Icons.history_rounded, size: 18),
                  label: const Text('سجل الطلبات'),
                ),
                const SizedBox(width: AppDimensions.space4),
              ],
              if (widget.type == _RecordType.employees) ...[
                TextButton.icon(
                  onPressed: () => _openEmployeeStatement(record),
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('كشف الحساب'),
                ),
                const SizedBox(width: AppDimensions.space4),
              ],
              // زرار تعديل وحذف لجميع الأنواع
              IconButton(
                tooltip: 'تعديل',
                onPressed: () => _editRecord(record),
                icon: const Icon(Icons.edit_outlined),
                color: AppColors.primary,
              ),
              IconButton(
                tooltip: 'حذف',
                onPressed: () {
                  switch (widget.type) {
                    case _RecordType.suppliers:
                      _deleteSupplier(record);
                    case _RecordType.customers:
                      _deleteCustomer(record);
                    case _RecordType.rawMaterials:
                      _hideRawMaterial(record);
                    case _RecordType.employees:
                      _deleteEmployee(record);
                  }
                },
                icon: Icon(Icons.delete_outline, color: AppColors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showCustomerHistory(Map<String, dynamic> customer) async {
    final orders = await DatabaseHelper.instance.rawQuery(
      '''
      SELECT o.order_number, o.created_at, o.final_amount, o.order_type,
             GROUP_CONCAT(oi.product_name || ' x' || oi.quantity, '، ') AS items
      FROM orders o
      LEFT JOIN order_items oi ON oi.order_id = o.id
      WHERE o.customer_id = ? AND o.status = 'completed'
      GROUP BY o.id
      ORDER BY o.created_at DESC
      ''',
      [customer['id']],
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('مشتريات ${customer['name']}'),
        content: SizedBox(
          width: 520,
          child: orders.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(AppDimensions.space16),
                  child: Text('لا توجد مشتريات مسجلة لهذا العميل'),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final order = orders[index];
                    return ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text(
                          '#${order['order_number']} • ${order['order_type'] == 'delivery' ? 'دليفري' : 'تيك أواي'}'),
                      subtitle: Text(
                          '${order['items'] ?? 'بدون أصناف'}\n${order['created_at']}'),
                      isThreeLine: true,
                      trailing: Text('${order['final_amount']} ج.م'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}

class _RecordFormDialog extends StatefulWidget {
  const _RecordFormDialog({required this.type, this.record});

  final _RecordType type;
  final Map<String, dynamic>? record;

  @override
  State<_RecordFormDialog> createState() => _RecordFormDialogState();
}

class _RecordFormDialogState extends State<_RecordFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _detail = TextEditingController(); // العنوان/الوظيفة، أو الوحدة "أخرى"
  final _amount = TextEditingController(); // يبدأ فارغاً
  final _minimum = TextEditingController(text: '0');
  final _initialStock = TextEditingController(text: '0');
  bool _saving = false;

  // ─── وحدة القياس للخامات ─────────────────────────
  String _unitChoice = rawMaterialUnits.first;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    if (record != null) {
      _name.text = record['name'] as String? ?? '';
      _phone.text = record['phone'] as String? ?? '';
      if (widget.type == _RecordType.rawMaterials) {
        final costVal = record['cost_per_unit'];
        _amount.text = (costVal != null && costVal != 0) ? '$costVal' : '';
        _minimum.text = '${record['min_stock'] ?? 0}';
        _initialStock.text = '${record['stock'] ?? 0}';
        final unit = record['unit'] as String? ?? '';
        if (rawMaterialUnits.contains(unit)) {
          _unitChoice = unit;
        } else if (unit.isNotEmpty) {
          _unitChoice = 'أخرى';
          _detail.text = unit;
        }
      } else if (widget.type == _RecordType.employees) {
        final salaryVal = record['monthly_salary'];
        _amount.text =
            (salaryVal != null && salaryVal != 0) ? '$salaryVal' : '';
        _detail.text = record['position'] as String? ?? '';
      } else {
        // suppliers / customers
        _detail.text = record['address'] as String? ?? '';
      }
    }
  }

  String get _title => switch (widget.type) {
        _RecordType.suppliers =>
          widget.record == null ? 'إضافة مورد' : 'تعديل مورد',
        _RecordType.customers =>
          widget.record == null ? 'إضافة عميل' : 'تعديل عميل',
        _RecordType.rawMaterials =>
          widget.record == null ? 'إضافة خامة' : 'تعديل خامة',
        _RecordType.employees =>
          widget.record == null ? 'إضافة موظف' : 'تعديل موظف',
      };

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _detail.dispose();
    _amount.dispose();
    _minimum.dispose();
    _initialStock.dispose();
    super.dispose();
  }

  String get _finalUnit =>
      _unitChoice == 'أخرى' ? _detail.text.trim() : _unitChoice;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.type == _RecordType.rawMaterials && _finalUnit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب وحدة القياس')),
      );
      return;
    }
    setState(() => _saving = true);
    final db = DatabaseHelper.instance;
    final amountNormalized = _arabicToEnglish(_amount.text.trim());
    final amount = double.tryParse(amountNormalized) ?? 0;
    final minimum = double.tryParse(_minimum.text) ?? 0;
    final initialStock = double.tryParse(_initialStock.text) ?? 0;
    final phoneNormalized = _arabicToEnglish(_phone.text.trim());
    switch (widget.type) {
      case _RecordType.suppliers:
        if (widget.record == null) {
          await db.addSupplier(
              name: _name.text.trim(),
              phone: phoneNormalized,
              address: _detail.text.trim());
        } else {
          await db.updateSupplier(
              id: widget.record!['id'] as String,
              name: _name.text.trim(),
              phone: phoneNormalized,
              address: _detail.text.trim());
        }
      case _RecordType.customers:
        if (widget.record == null) {
          await db.addCustomer(
              name: _name.text.trim(),
              phone: phoneNormalized,
              address: _detail.text.trim());
        } else {
          await db.updateCustomer(
              id: widget.record!['id'] as String,
              name: _name.text.trim(),
              phone: phoneNormalized,
              address: _detail.text.trim());
        }
      case _RecordType.rawMaterials:
        if (widget.record == null) {
          await db.addRawMaterial(
              name: _name.text.trim(),
              unit: _finalUnit,
              costPerUnit: amount,
              minStock: minimum,
              initialStock: initialStock);
        } else {
          await db.updateRawMaterial(
            id: widget.record!['id'] as String,
            name: _name.text.trim(),
            unit: _finalUnit,
            costPerUnit: amount,
            minStock: minimum,
            stock: initialStock,
          );
        }
      case _RecordType.employees:
        if (widget.record == null) {
          await db.addEmployee(
              name: _name.text.trim(),
              phone: phoneNormalized,
              position: _detail.text.trim(),
              monthlySalary: amount);
        } else {
          await db.updateEmployee(
              id: widget.record!['id'] as String,
              name: _name.text.trim(),
              phone: phoneNormalized,
              position: _detail.text.trim(),
              monthlySalary: amount);
        }
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final detailLabel = switch (widget.type) {
      _RecordType.suppliers => 'العنوان',
      _RecordType.customers => 'العنوان',
      _RecordType.rawMaterials => 'وحدة القياس',
      _RecordType.employees => 'الوظيفة',
    };
    final amountLabel = switch (widget.type) {
      _RecordType.rawMaterials => 'تكلفة الوحدة',
      _RecordType.employees => 'الراتب الشهري',
      _ => null,
    };
    return AlertDialog(
      title: Text(_title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'الاسم'),
                    validator: (v) => v!.trim().isEmpty ? 'الاسم مطلوب' : null),
                const SizedBox(height: AppDimensions.space16),
                if (widget.type != _RecordType.rawMaterials) ...[
                  TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration:
                          const InputDecoration(labelText: 'رقم الهاتف'),
                      validator: (v) => _validatePhone(v, required: true)),
                  const SizedBox(height: AppDimensions.space16),
                ],

                // ─── وحدة القياس (Dropdown) للخامات فقط ──────────
                if (widget.type == _RecordType.rawMaterials) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _unitChoice,
                    items: [...rawMaterialUnits, 'أخرى']
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) => setState(() => _unitChoice = v!),
                    decoration: const InputDecoration(labelText: 'وحدة القياس'),
                  ),
                  if (_unitChoice == 'أخرى') ...[
                    const SizedBox(height: AppDimensions.space16),
                    TextFormField(
                      controller: _detail,
                      decoration:
                          const InputDecoration(labelText: 'اكتب الوحدة'),
                    ),
                  ],
                  const SizedBox(height: AppDimensions.space16),
                ] else ...[
                  // ─── حقل العنوان/الوظيفة لباقي الأنواع ──────────
                  TextFormField(
                      controller: _detail,
                      maxLines: widget.type == _RecordType.employees ? 1 : 2,
                      decoration: InputDecoration(
                          labelText: detailLabel,
                          alignLabelWithHint:
                              widget.type != _RecordType.employees),
                      validator: (v) {
                        if ((widget.type == _RecordType.suppliers ||
                                widget.type == _RecordType.customers) &&
                            (v == null || v.trim().isEmpty)) {
                          return 'العنوان مطلوب';
                        }
                        return null;
                      }),
                  const SizedBox(height: AppDimensions.space16),
                ],

                if (amountLabel != null)
                  TextFormField(
                      controller: _amount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: amountLabel, hintText: '0'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return '$amountLabel مطلوب';
                        }
                        final n = _arabicToEnglish(v.trim());
                        if (double.tryParse(n) == null) {
                          return 'أدخل رقمًا صحيحًا';
                        }
                        return null;
                      }),
                if (amountLabel != null)
                  const SizedBox(height: AppDimensions.space16),
                if (widget.type == _RecordType.rawMaterials)
                  TextFormField(
                      controller: _initialStock,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'الكمية الحالية / الكمية الابتدائية',
                        helperText: 'اكتب الكمية الموجودة حاليًا من الخامة',
                      )),
                if (widget.type == _RecordType.rawMaterials)
                  const SizedBox(height: AppDimensions.space16),
                if (widget.type == _RecordType.rawMaterials)
                  TextFormField(
                      controller: _minimum,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'الحد الأدنى للمخزون')),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('إلغاء')),
        FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'جاري الحفظ...' : 'حفظ')),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// امسح _AccountsScreen و _AccountSummary القدام (وأي نسخة عملتها قبل كده)
// وحط الكود ده مكانهم. باقي الملف زي ما هو.
// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════
// امسح _AccountsScreen و _AccountSummary القدام (وأي نسخة عملتها قبل كده)
// وحط الكود ده مكانهم. باقي الملف زي ما هو.
// ═══════════════════════════════════════════════════════════════

class _AccountsScreen extends StatefulWidget {
  const _AccountsScreen();

  @override
  State<_AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<_AccountsScreen> {
  Map<String, dynamic> _o = {}; // ملخص الفترة
  Map<String, dynamic> _t = {}; // الدرج الأساسي
  List<Map<String, dynamic>> _movements = [];
  List<Map<String, dynamic>> _fixedAssets = [];
  bool _loading = true;

  DateTime? _from;
  DateTime? _to;
  String _filterName = 'الكل';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = DatabaseHelper.instance;
    await db.postAssetDepreciation(); // ترحيل إهلاك الشهور اللي عدت
    final assets = await db.getFixedAssets();
    final o = await db.getAccountsOverview(from: _from, to: _to);
    final t = await db.getTreasuryOverview();
    final m = await db.getTreasuryMovements(limit: 10);
    if (mounted) {
      setState(() {
        _o = o;
        _t = t;
        _movements = m;
        _fixedAssets = assets;
        _loading = false;
      });
    }
  }

  // ─── أدوات مساعدة ────────────────────────────────
  double _n(Map<String, dynamic> m, String k) =>
      (m[k] as num?)?.toDouble() ?? 0;
  String _two(int n) => n.toString().padLeft(2, '0');
  String _fmtDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
  String _fmtDateTime(String? iso) =>
      iso == null ? '' : iso.substring(0, 16).replaceFirst('T', ' ');
  String _money(num? v) => '${(v ?? 0).toDouble().toStringAsFixed(2)} ج.م';

  void _setRange(String name, DateTime? from, DateTime? to) {
    _filterName = name;
    _from = from;
    _to = to;
    _load();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day + 1),
      initialDateRange: _from != null && _to != null
          ? DateTimeRange(start: _from!, end: _to!)
          : null,
    );
    if (picked != null) {
      _setRange('${_fmtDate(picked.start)}  ←  ${_fmtDate(picked.end)}',
          picked.start, picked.end);
    }
  }

  String _mvMethodLabel(String? m) => switch (m) {
        'vodafone' => 'فودافون كاش',
        'card' => 'فيزا / شبكة',
        'other' => 'أخرى',
        _ => 'كاش',
      };
  Future<void> _moveMoney(String type) async {
    final amountC = TextEditingController();
    final notesC = TextEditingController();
    String method = 'cash';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(type == 'deposit' ? 'إيداع' : 'سحب'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'الطريقة'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('كاش (الدرج)')),
                    DropdownMenuItem(
                        value: 'vodafone', child: Text('فودافون كاش')),
                    DropdownMenuItem(value: 'card', child: Text('فيزا / شبكة')),
                    DropdownMenuItem(value: 'other', child: Text('أخرى')),
                  ],
                  onChanged: (v) => setLocal(() => method = v!),
                ),
                const SizedBox(height: AppDimensions.space16),
                TextField(
                  controller: amountC,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'المبلغ'),
                ),
                const SizedBox(height: AppDimensions.space16),
                TextField(
                  controller: notesC,
                  decoration: InputDecoration(
                    labelText: 'ملاحظات',
                    helperText: type == 'deposit'
                        ? 'مثال: رصيد افتتاحي / رأس مال'
                        : 'مثال: سحب أرباح',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حفظ')),
          ],
        ),
      ),
    );
    final amount = double.tryParse(_arabicToEnglish(amountC.text.trim())) ?? 0;
    final notes = notesC.text.trim();
    amountC.dispose();
    notesC.dispose();
    if (ok == true && amount > 0) {
      await DatabaseHelper.instance.addTreasuryMovement(
        type: type,
        amount: amount,
        method: method,
        notes: notes.isEmpty ? null : notes,
      );
      _load();
    }
  }

  // ─── مكونات الواجهة ──────────────────────────────
  Widget _row(String label, num? v,
      {Color? color, bool bold = false, String? text, double indent = 0}) {
    final style = bold ? AppTypography.titleMedium : AppTypography.bodyMedium;
    return Padding(
      padding: EdgeInsets.only(top: 6, bottom: 6, right: indent),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(text ?? _money(v), style: style.copyWith(color: color)),
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children,
      {Widget? trailing}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.space16),
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
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: AppDimensions.space8),
              Expanded(child: Text(title, style: AppTypography.titleLarge)),
              if (trailing != null) trailing,
            ],
          ),
          const Divider(height: AppDimensions.space24),
          ...children,
        ],
      ),
    );
  }

  Widget _filterBar() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    Widget chip(String label, VoidCallback onTap) => ChoiceChip(
          label: Text(label),
          selected: _filterName == label,
          onSelected: (_) => onTap(),
        );
    return Wrap(
      spacing: AppDimensions.space8,
      runSpacing: AppDimensions.space8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        chip('الكل', () => _setRange('الكل', null, null)),
        chip('اليوم', () => _setRange('اليوم', today, today)),
        chip(
            'آخر 7 أيام',
            () => _setRange(
                'آخر 7 أيام', today.subtract(const Duration(days: 6)), today)),
        chip(
            'هذا الشهر',
            () => _setRange(
                'هذا الشهر', DateTime(now.year, now.month, 1), today)),
        ActionChip(
          avatar: const Icon(Icons.date_range_rounded, size: 18),
          label: Text(_filterName.contains('←') ? _filterName : 'تاريخ محدد'),
          onPressed: _pickRange,
        ),
      ],
    );
  }

  // ─── 1) الدرج الأساسي ────────────────────────────
  Widget _treasurySection() {
    final balance = _n(_t, 'balance');
    final diff = _n(_t, 'shift_diff');
    return _section(
      'الدرج الأساسي (الخزينة)',
      Icons.savings_rounded,
      [
        Center(
          child: Column(
            children: [
              Text('الفلوس اللي معاك دلوقتي', style: AppTypography.bodySmall),
              const SizedBox(height: AppDimensions.space4),
              Text(_money(balance),
                  style: AppTypography.titleLarge.copyWith(
                      fontSize: 34,
                      color:
                          balance >= 0 ? AppColors.success : AppColors.error)),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.space12),
        Text('داخل', style: AppTypography.titleSmall),
        _row('مبيعات نقدي (كل الشيفتات)', _n(_t, 'cash_sales'), indent: 12),
        _row('إيداعات', _n(_t, 'deposits'), indent: 12),
        if (diff > 0) _row('زيادة في الشيفتات', diff, indent: 12),
        _row('إجمالي الداخل', _n(_t, 'total_in'),
            bold: true, color: AppColors.success),
        const SizedBox(height: AppDimensions.space8),
        Text('خارج', style: AppTypography.titleSmall),
        _row('مصاريف', _n(_t, 'expenses_cash'), indent: 12),
        _row('مشتريات وسداد موردين', _n(_t, 'purchases_cash'), indent: 12),
        _row('رواتب وسلف', _n(_t, 'payroll'), indent: 12),
        _row('شراء أصول ثابتة', _n(_t, 'assets_cash'), indent: 12),
        _row('سحوبات', _n(_t, 'withdrawals'), indent: 12),
        if (diff < 0) _row('عجز في الشيفتات', -diff, indent: 12),
        _row('إجمالي الخارج', _n(_t, 'total_out'),
            bold: true, color: AppColors.error),
        const SizedBox(height: AppDimensions.space8),
        Text('أرصدة الطرق الأخرى', style: AppTypography.titleSmall),
        if ((_t['method_balances'] as List? ?? []).isEmpty)
          Text('لا توجد حركات على فيزا / فودافون',
              style: AppTypography.bodySmall),
        for (final r in (_t['method_balances'] as List? ?? [])
            .cast<Map<String, dynamic>>())
          _row(
            _mvMethodLabel(r['method'] as String?),
            r['balance'] as num,
            indent: 12,
            color: (r['balance'] as num) >= 0
                ? AppColors.success
                : AppColors.error,
          ),
        const SizedBox(height: AppDimensions.space12),
        Row(
          children: [
            FilledButton.icon(
              onPressed: () => _moveMoney('deposit'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('إيداع'),
            ),
            const SizedBox(width: AppDimensions.space8),
            OutlinedButton.icon(
              onPressed: () => _moveMoney('withdraw'),
              icon: const Icon(Icons.remove_rounded),
              label: const Text('سحب'),
            ),
          ],
        ),
        if (_movements.isNotEmpty) ...[
          const Divider(height: AppDimensions.space24),
          Text('آخر الإيداعات والسحوبات', style: AppTypography.titleSmall),
          for (final m in _movements)
            Material(
              type: MaterialType.transparency,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  m['type'] == 'deposit'
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  color: m['type'] == 'deposit'
                      ? AppColors.success
                      : AppColors.error,
                ),
                title: Text(m['notes'] as String? ??
                    (m['type'] == 'deposit' ? 'إيداع' : 'سحب')),
                subtitle: Text(
                    '${_mvMethodLabel(m['method'] as String?)} • ${_fmtDateTime(m['created_at'] as String?)}'),
                trailing: Text(
                  '${m['type'] == 'deposit' ? '+' : '-'}${_money(m['amount'] as num)}',
                  style: AppTypography.bodyMedium.copyWith(
                      color: m['type'] == 'deposit'
                          ? AppColors.success
                          : AppColors.error),
                ),
              ),
            ),
        ],
      ],
    );
  }

  // ─── 2) الشيفتات ─────────────────────────────────
  Widget _shiftSection() {
    final hasOpen = _o['has_open_shift'] == true;
    final lastCash = _o['last_closing_cash'] as double?;
    return _section('الشيفتات', Icons.point_of_sale_rounded, [
      _row('الشيفت الحالي', null,
          text: hasOpen ? 'مفتوح' : 'مغلق',
          color: hasOpen ? AppColors.success : AppColors.warning),
      if (hasOpen) _row('المتوقع في درج الكاشير الآن', _n(_o, 'shift_drawer')),
      _row('آخر فلوس اتسلّمت عند قفل شيفت', null,
          text: lastCash == null ? 'لا يوجد' : _money(lastCash)),
      if (lastCash != null)
        Text(
            '${_fmtDateTime(_o['last_closing_at'] as String?)} • ${_o['last_closing_user'] ?? ''}',
            style: AppTypography.caption),
    ]);
  }

  // ─── الدخل حسب طريقة الدفع ───────────────────────
  String _methodLabel(String m) => switch (m.toLowerCase()) {
        'cash' => 'كاش',
        'card' => 'فيزا / شبكة',
        'visa' => 'فيزا',
        'network' || 'pos' || 'shabaka' => 'شبكة',
        'vodafone_cash' ||
        'vodafone' ||
        'vodafonecash' ||
        'wallet' ||
        'mobile_wallet' =>
          'فودافون كاش',
        'instapay' => 'إنستاباي',
        _ => m, // أي طريقة غير معروفة تظهر باسمها زي ما هي متخزنة
      };
  String _norm(String m) => switch (m.toLowerCase()) {
        'card' || 'visa' || 'network' || 'pos' || 'shabaka' => 'card',
        'vodafone_cash' ||
        'vodafone' ||
        'vodafonecash' ||
        'wallet' ||
        'mobile_wallet' =>
          'vodafone',
        final x => x,
      };
  IconData _methodIcon(String m) => switch (m.toLowerCase()) {
        'cash' => Icons.payments_outlined,
        'card' ||
        'visa' ||
        'network' ||
        'pos' ||
        'shabaka' =>
          Icons.credit_card_rounded,
        _ => Icons.phone_android_rounded,
      };

  Widget _paymentMethodsSection() {
    final rows =
        (_o['sales_by_method'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    rows.sort((a, b) => (b['total'] as num).compareTo(a['total'] as num));
    return _section('الدخل حسب طريقة الدفع — $_filterName',
        Icons.account_balance_wallet_outlined, [
      if (rows.isEmpty)
        Text('لا توجد مبيعات في الفترة دي', style: AppTypography.bodySmall),
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(_methodIcon(r['method'] as String),
                  color: AppColors.primary, size: 22),
              const SizedBox(width: AppDimensions.space12),
              Expanded(
                child: Text(
                    '${_methodLabel(r['method'] as String)}  (${r['cnt']} أوردر)',
                    style: AppTypography.bodyMedium),
              ),
              Text(_money(r['total'] as num),
                  style: AppTypography.titleMedium
                      .copyWith(color: AppColors.success)),
            ],
          ),
        ),
      const Divider(),
      _row('الإجمالي', _n(_o, 'total_sales'), bold: true),
    ]);
  }

  // ─── الدخل بعد المصروفات (نفس التقسيم حسب طريقة الدفع) ──
  Widget _afterExpensesSection() {
    final rows =
        ((_o['sales_by_method'] as List?)?.cast<Map<String, dynamic>>() ?? [])
            .toList();

    final expenses = _n(_o, 'expenses_total');
    final payroll = _n(_o, 'payroll');
    final suppliers = _n(_o, 'excluded_duplicates'); // مشتريات + سداد موردين
    final totalOut = expenses + payroll + suppliers;

    // مبيعات كل طريقة (بعد توحيد الأسماء)
    final totals = <String, double>{};
    for (final r in rows) {
      final k = _norm(r['method'] as String);
      totals[k] = (totals[k] ?? 0) + (r['total'] as num).toDouble();
    }
    // الإيداعات (+) والسحوبات (−)
    final mv = (_o['movements_by_method'] as Map?) ?? {};
    for (final e in mv.entries) {
      final k = _norm(e.key as String);
      totals[k] = (totals[k] ?? 0) + (e.value as num).toDouble();
    }
    // المصروفات بتتدفع من الدرج
    if (totalOut > 0) totals['cash'] = (totals['cash'] ?? 0) - totalOut;

    final entries = totals.entries
        .map((e) => MapEntry(
            e.key == 'cash' ? 'كاش (بعد المصروفات)' : _methodLabel(e.key),
            e.value))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final net = entries.fold<double>(0, (s, e) => s + e.value);

    return _section('الدخل بعد المصروفات — $_filterName',
        Icons.account_balance_wallet_rounded, [
      _row('− المصاريف', expenses, color: AppColors.warning),
      _row('− رواتب وسلف', payroll, color: AppColors.warning),
      _row('− مشتريات وسداد موردين', suppliers, color: AppColors.warning),
      _row('إجمالي المصروفات', totalOut, bold: true, color: AppColors.warning),
      Text('المصروفات بتتخصم من الكاش لأنها بتتدفع من الدرج',
          style: AppTypography.caption),
      const Divider(),
      for (final e in entries)
        _row(e.key, e.value,
            color: e.value < 0 ? AppColors.error : AppColors.success),
      const Divider(),
      _row('الإجمالي بعد المصروفات', net,
          bold: true, color: net >= 0 ? AppColors.success : AppColors.error),
    ]);
  }

  // ─── 3) الأرباح والخسائر للفترة ──────────────────
  Widget _profitSection() {
    final byCat =
        (_o['expenses_by_category'] as Map?)?.cast<String, double>() ?? {};
    final net = _n(_o, 'net_profit');
    return _section(
        'المبيعات والأرباح — $_filterName', Icons.bar_chart_rounded, [
      _row('إجمالي المبيعات (${_o['orders_count'] ?? 0} أوردر)',
          _n(_o, 'total_sales'),
          bold: true, color: AppColors.success),
      _row('− تكلفة البضاعة المباعة', _n(_o, 'cogs_total')),
      _row('= مجمل الربح', _n(_o, 'gross_profit'), bold: true),
      const Divider(),
      _row('− المصاريف', _n(_o, 'expenses_total'), color: AppColors.warning),
      for (final e in byCat.entries) _row(e.key, e.value, indent: 12),
      if (_n(_o, 'excluded_duplicates') > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
              'مستبعد ${_money(_n(_o, 'excluded_duplicates'))} (دفعات موردين/مشتريات متسجلة كمصروف — تكلفتها محسوبة في تكلفة البضاعة)',
              style: AppTypography.caption),
        ),
      Wrap(
        spacing: AppDimensions.space8,
        children: [
          TextButton.icon(
            onPressed: _showExpenses,
            icon: const Icon(Icons.list_alt_rounded, size: 18),
            label: const Text('عرض كل المصاريف'),
          ),
          /*  TextButton.icon(
            onPressed: _showDiagnostics,
            icon: const Icon(Icons.bug_report_outlined, size: 18),
            label: const Text('فحص البيانات'),
          ),*/
        ],
      ),
      _row('− رواتب وسلف', _n(_o, 'payroll'), color: AppColors.warning),
      const Divider(),
      _row('المبيعات − المصاريف والرواتب', null,
          text: _money(_n(_o, 'total_sales') -
              _n(_o, 'expenses_total') -
              _n(_o, 'payroll'))),
      _row('صافي الربح', net,
          bold: true, color: net >= 0 ? AppColors.success : AppColors.error),
    ]);
  }

  Future<void> _showDiagnostics() async {
    final d = await DatabaseHelper.instance.getDataDiagnostics();
    if (!mounted) return;
    const titles = {
      'expenses': 'جدول المصاريف (حسب النوع)',
      'employee_transactions': 'حركات الموظفين (حسب النوع)',
      'supplier_payments': 'سداد الموردين (حسب طريقة الدفع)',
    };
    String d16(Object? v) =>
        v == null ? '-' : v.toString().split('.').first.replaceFirst('T', ' ');
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('فحص البيانات المخزّنة'),
        content: SizedBox(
          width: 640,
          height: 460,
          child: ListView(
            children: [
              for (final e in d.entries) ...[
                Text(titles[e.key] ?? e.key, style: AppTypography.titleSmall),
                if (e.value.isEmpty)
                  Text('  (فاضي)', style: AppTypography.bodySmall),
                for (final r in e.value)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                        '• ${r['name']} — ${r['cnt']} حركة — ${_money(r['total'] as num)}\n   ${d16(r['min_d'])}  ←  ${d16(r['max_d'])}',
                        style: AppTypography.bodySmall),
                  ),
                const SizedBox(height: AppDimensions.space12),
              ],
            ],
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

  Future<void> _showExpenses() async {
    final rows =
        await DatabaseHelper.instance.getExpensesList(from: _from, to: _to);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('كل المصاريف — $_filterName'),
        content: SizedBox(
          width: 620,
          height: 460,
          child: rows.isEmpty
              ? const Center(child: Text('لا توجد مصاريف'))
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    final excluded = r['excluded'] == true;
                    return ListTile(
                      dense: true,
                      title: Text(
                          '${r['category']} — ${r['description'] ?? ''}',
                          style: excluded
                              ? AppTypography.bodyMedium
                                  .copyWith(color: AppColors.textDisabled)
                              : AppTypography.bodyMedium),
                      subtitle: Text(
                          '${_fmtDateTime(r['date'] as String?)}${excluded ? ' • مستبعد (دفعة مورد)' : ''}'),
                      trailing: Text(_money(r['amount'] as num)),
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

  // ─── الأصول الثابتة والإيجارات ───────────────────
  String _assetCategoryLabel(String c) => switch (c) {
        'rent' => 'إيجار',
        'equipment' => 'معدات',
        'furniture' => 'أثاث',
        _ => 'أصول ثابتة',
      };

  IconData _assetIcon(String c) => switch (c) {
        'rent' => Icons.home_work_outlined,
        'equipment' => Icons.kitchen_outlined,
        'furniture' => Icons.chair_alt_outlined,
        _ => Icons.business_center_outlined,
      };

  Widget _fixedAssetsSection() {
    return _section(
      'الأصول الثابتة والإيجارات',
      Icons.business_rounded,
      [
        if (_fixedAssets.isEmpty)
          Text('لا توجد أصول أو إيجارات مسجلة', style: AppTypography.bodySmall),
        for (final a in _fixedAssets) _assetTile(a),
      ],
      trailing: FilledButton.icon(
        onPressed: _addAsset,
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة أصل / إيجار'),
      ),
    );
  }

  Widget _assetTile(Map<String, dynamic> a) {
    final cat = a['category'] as String? ?? 'other';
    final recurring = (a['is_recurring'] as num?) == 1;
    final cost = (a['cost'] as num).toDouble();
    final acc = (a['accumulated_depreciation'] as num?)?.toDouble() ?? 0;
    final life = a['useful_life_months'] as int?;
    final last = a['last_processed_date'] as String?;
    final subtitle = recurring
        ? 'متكرر شهريًا: ${_money(cost)}${last != null ? ' • آخر دفعة: ${_fmtDateTime(last)}' : ' • لسه مفيش دفعات'}'
        : 'التكلفة: ${_money(cost)} • الإهلاك المتراكم: ${_money(acc)} • المدة: ${life ?? 12} شهر • ${a['payment_type'] == 'cash' ? 'نقدي' : 'آجل'}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(_assetIcon(cat), color: AppColors.primary),
      title: Text('${_assetCategoryLabel(cat)} — ${a['name']}'),
      subtitle: Text(subtitle, style: AppTypography.bodySmall),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (recurring)
            IconButton(
              tooltip: 'تسجيل دفعة شهرية',
              onPressed: () => _payRecurring(a),
              icon: const Icon(Icons.payments_outlined),
            ),
          IconButton(
            tooltip: 'حذف',
            onPressed: () => _deleteAsset(a),
            icon: Icon(Icons.delete_outline, color: AppColors.error),
          ),
        ],
      ),
    );
  }

  Future<void> _addAsset() async {
    final nameC = TextEditingController();
    final costC = TextEditingController();
    final lifeC = TextEditingController(text: '12');
    final notesC = TextEditingController();
    String category = 'rent';
    bool recurring = true;
    String paymentType = 'cash';
    String? error;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('إضافة أصل / إيجار'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameC,
                    decoration: const InputDecoration(
                        labelText: 'الاسم (مثال: إيجار المحل / فرن)'),
                  ),
                  const SizedBox(height: AppDimensions.space12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'النوع'),
                    items: const [
                      DropdownMenuItem(value: 'rent', child: Text('إيجار')),
                      DropdownMenuItem(
                          value: 'equipment', child: Text('معدات')),
                      DropdownMenuItem(value: 'furniture', child: Text('أثاث')),
                      DropdownMenuItem(
                          value: 'other', child: Text('أصول أخرى')),
                    ],
                    onChanged: (v) => setLocal(() {
                      category = v!;
                      recurring = v == 'rent';
                    }),
                  ),
                  const SizedBox(height: AppDimensions.space12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: recurring,
                    onChanged: (v) => setLocal(() => recurring = v),
                    title: const Text('مصروف متكرر شهريًا (زي الإيجار)'),
                    subtitle: Text(
                        recurring
                            ? 'كل دفعة بتتخصم كاملة من ربح الشهر'
                            : 'أصل بيتشترى مرة واحدة وبيتهلك على شهور',
                        style: AppTypography.caption),
                  ),
                  TextField(
                    controller: costC,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText:
                            recurring ? 'القيمة الشهرية' : 'التكلفة الكلية'),
                  ),
                  if (!recurring) ...[
                    const SizedBox(height: AppDimensions.space12),
                    TextField(
                      controller: lifeC,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'مدة الإهلاك (بالشهور)'),
                    ),
                    const SizedBox(height: AppDimensions.space12),
                    DropdownButtonFormField<String>(
                      initialValue: paymentType,
                      decoration:
                          const InputDecoration(labelText: 'طريقة الدفع'),
                      items: const [
                        DropdownMenuItem(
                            value: 'cash', child: Text('نقدي (من الدرج)')),
                        DropdownMenuItem(value: 'credit', child: Text('آجل')),
                      ],
                      onChanged: (v) => setLocal(() => paymentType = v!),
                    ),
                  ],
                  const SizedBox(height: AppDimensions.space12),
                  TextField(
                    controller: notesC,
                    decoration: const InputDecoration(labelText: 'ملاحظات'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: AppDimensions.space8),
                    Text(error!,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.error)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                final cost = double.tryParse(costC.text.trim()) ?? 0;
                if (nameC.text.trim().isEmpty || cost <= 0) {
                  setLocal(() => error = 'اكتب الاسم وقيمة أكبر من صفر');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await DatabaseHelper.instance.addFixedAsset(
      name: nameC.text.trim(),
      category: category,
      cost: double.tryParse(costC.text.trim()) ?? 0,
      isRecurring: recurring,
      usefulLifeMonths: int.tryParse(lifeC.text.trim()),
      paymentType: paymentType,
      notes: notesC.text.trim().isEmpty ? null : notesC.text.trim(),
    );
    _load();
  }

  Future<void> _payRecurring(Map<String, dynamic> asset) async {
    final amountC = TextEditingController(text: '${asset['cost']}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('دفعة شهرية — ${asset['name']}'),
        content: TextField(
          controller: amountC,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'المبلغ المدفوع'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تسجيل الدفعة')),
        ],
      ),
    );
    final amount = double.tryParse(amountC.text.trim()) ?? 0;
    if (ok != true || amount <= 0) return;
    await DatabaseHelper.instance.payRecurringAsset(
        assetId: asset['id'] as String, amountOverride: amount);
    _load();
  }

  Future<void> _deleteAsset(Map<String, dynamic> asset) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الأصل'),
        content: Text(
            'هتحذف "${asset['name']}"؟ لو كان أصل نقدي، مبلغ شرائه هيرجع للدرج الأساسي في الحساب. المصاريف اللي اتسجلت قبل كده (إهلاك/دفعات إيجار) هتفضل زي ما هي.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    await DatabaseHelper.instance.deleteFixedAsset(asset['id'] as String);
    _load();
  }

  // ─── منطقة الخطر: حذف كل البيانات ────────────────
  Widget _dangerSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.error),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Text(
                'حذف كل البيانات وتصفير الحسابات (بياخد نسخة احتياطية الأول)',
                style: AppTypography.bodyMedium),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: _resetAll,
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text('حذف كل حاجة'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetAll() async {
    bool includeMaster = false;
    final confirmC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error),
              const SizedBox(width: AppDimensions.space8),
              const Text('حذف كل البيانات'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'هيتحذف: كل الأوردرات والمصاريف والشيفتات وحركات الدرج الأساسي والمشتريات وسداد الموردين وحركات الموظفين وحركات المخزون والجرد والأصول الثابتة، وكل الأرصدة هتتصفّر.',
                      style: AppTypography.bodyMedium),
                  const SizedBox(height: AppDimensions.space8),
                  Text('هيفضل: المستخدمين والإعدادات.',
                      style: AppTypography.bodySmall),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: includeMaster,
                    onChanged: (v) =>
                        setLocal(() => includeMaster = v ?? false),
                    title: const Text(
                        'احذف كمان الأصناف والتصنيفات والخامات والوصفات والموردين والعملاء والموظفين'),
                  ),
                  Text('هيتاخد نسخة احتياطية من قاعدة البيانات قبل الحذف.',
                      style: AppTypography.caption),
                  const SizedBox(height: AppDimensions.space12),
                  TextField(
                    controller: confirmC,
                    onChanged: (_) => setLocal(() {}),
                    decoration: const InputDecoration(
                        labelText: 'اكتب كلمة "حذف" للتأكيد'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: confirmC.text.trim() == 'حذف'
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('احذف كل حاجة'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    String message;
    try {
      final db = DatabaseHelper.instance;
      final backup = await db.backupDatabase(); // لو فشلت مفيش حاجة بتتحذف
      await db.resetAllData(includeMasterData: includeMaster);
      message = 'تم الحذف. النسخة الاحتياطية: $backup';
    } catch (e) {
      message = 'حصل خطأ ومفيش حاجة اتحذفت: $e';
    }
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ─── 4) الموردين ─────────────────────────────────
  Widget _suppliersSection() {
    final suppliers =
        (_o['suppliers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return _section('ديون الموردين (علينا)', Icons.local_shipping_outlined, [
      _row('إجمالي الدين', _n(_o, 'suppliers_debt'),
          bold: true, color: AppColors.error),
      if (suppliers.isEmpty)
        Text('مفيش ديون على الموردين', style: AppTypography.bodySmall),
      for (final s in suppliers)
        _row(s['name'] as String, s['balance'] as num, indent: 12),
    ]);
  }

  // ─── 5) المخزون والأصول ──────────────────────────
  Widget _assetsSection() {
    final total = _n(_o, 'raw_stock_value') +
        _n(_o, 'product_stock_value') +
        _n(_o, 'fixed_assets_value');
    return _section('المخزون والأصول', Icons.inventory_2_outlined, [
      _row('مخزون الخامات', _n(_o, 'raw_stock_value')),
      _row('مخزون الأصناف', _n(_o, 'product_stock_value')),
      _row('الأصول الثابتة (بعد الإهلاك)', _n(_o, 'fixed_assets_value')),
      const Divider(),
      _row('الإجمالي', total, bold: true, color: AppColors.primary),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: AppDimensions.space16);
    return Scaffold(
      appBar: AppTopBar(
        title: 'الحسابات',
        action: IconButton(
          tooltip: 'تحديث',
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppDimensions.space24),
              children: [
                _treasurySection(),
                gap,
                _shiftSection(),
                gap,
                Text('تقارير الفترة', style: AppTypography.titleLarge),
                const SizedBox(height: AppDimensions.space8),
                _filterBar(),
                gap,
                _paymentMethodsSection(),
                gap,
                _afterExpensesSection(),
                gap,
                _profitSection(),
                gap,
                _suppliersSection(),
                gap,
                _assetsSection(),
                gap,
                _fixedAssetsSection(),
                gap,
                _dangerSection(),
              ],
            ),
    );
  }
}

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final _productsRepo = ProductRepository();
  List<Product> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final products = await _productsRepo.getAll(activeOnly: true, limit: 1000);
    if (mounted) {
      setState(() {
        _products = products;
        _loading = false;
      });
    }
  }

  Future<void> _edit(Product product) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _RecipeDialog(product: product),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        title: 'وصفات الأصناف وتكلفتها',
        onBack: () => Navigator.pop(context),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const Center(child: Text('لا توجد أصناف متاحة'))
              : ListView.separated(
                  padding: const EdgeInsets.all(AppDimensions.space24),
                  itemCount: _products.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppDimensions.space10),
                  itemBuilder: (_, index) {
                    final product = _products[index];
                    return FutureBuilder<Map<String, dynamic>>(
                      future: DatabaseHelper.instance
                          .getProductCostAndProfit(product.id),
                      builder: (context, snapshot) {
                        final data = snapshot.data;
                        return Container(
                          padding: const EdgeInsets.all(AppDimensions.space16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusMd),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Text(product.icon ?? '🍽️',
                                  style: const TextStyle(fontSize: 28)),
                              const SizedBox(width: AppDimensions.space12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(product.name,
                                        style: AppTypography.titleMedium),
                                    Text(
                                      data == null
                                          ? 'جاري حساب التكلفة...'
                                          : 'التكلفة: ${data['cost'].toStringAsFixed(2)} ج.م  •  الربح: ${data['profit'].toStringAsFixed(2)} ج.م (${data['profit_percent'].toStringAsFixed(1)}%)',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: data == null ||
                                                (data['profit'] as num) >= 0
                                            ? AppColors.success
                                            : AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'تعديل الوصفة',
                                onPressed: () => _edit(product),
                                icon: const Icon(Icons.edit_note_rounded),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

class _RecipeDialog extends StatefulWidget {
  const _RecipeDialog({required this.product});

  final Product product;

  @override
  State<_RecipeDialog> createState() => _RecipeDialogState();
}

class _RecipeDialogState extends State<_RecipeDialog> {
  List<Map<String, dynamic>> _materials = [];
  final Map<String, TextEditingController> _quantities = {};
  final Map<String, String> _selectedUnits = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final materials = await DatabaseHelper.instance.getRawMaterials();
    final existing = await DatabaseHelper.instance.rawQuery(
      'SELECT raw_material_id, quantity_used FROM product_recipes WHERE product_id = ?',
      [widget.product.id],
    );
    for (final material in materials) {
      final id = material['id'] as String;
      final baseUnit = material['unit'] as String? ?? '';
      final match =
          existing.where((row) => row['raw_material_id'] == id).firstOrNull;
      // الكمية المحفوظة دايمًا بوحدة تخزين الخامة الأساسية، فبنعرضها بنفس
      // الوحدة الأساسية، وبعدين المستخدم يقدر يغيّر وحدة الإدخال لو حابب.
      _quantities[id] = TextEditingController(
        text: match == null ? '' : '${match['quantity_used']}',
      );
      _selectedUnits[id] = baseUnit;
    }
    if (mounted) {
      setState(() {
        _materials = materials;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _quantities.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// معامل تحويل الكمية المكتوبة بالوحدة المختارة إلى وحدة تخزين الخامة
  /// الأساسية (اللي بيتحسب بيها المخزون والتكلفة).
  double _factorFor(String materialId, String baseUnit) {
    final selected = _selectedUnits[materialId] ?? baseUnit;
    if (selected == baseUnit) return 1;
    return compatibleUnitFactors[baseUnit]?[selected] ?? 1;
  }

  /// الكمية بوحدة تخزين الخامة الأساسية، بعد تحويلها من الوحدة اللي
  /// المستخدم كاتب بيها في الحقل.
  double _baseQuantityFor(Map<String, dynamic> material) {
    final id = material['id'] as String;
    final baseUnit = material['unit'] as String? ?? '';
    final entered = double.tryParse(_quantities[id]?.text ?? '') ?? 0;
    return entered * _factorFor(id, baseUnit);
  }

  double get _recipeCost {
    return _materials.fold(0, (total, material) {
      final baseQuantity = _baseQuantityFor(material);
      final unitCost = (material['cost_per_unit'] as num?)?.toDouble() ?? 0;
      return total + baseQuantity * unitCost;
    });
  }

  Future<void> _save() async {
    final ingredients = <Map<String, dynamic>>[];
    for (final material in _materials) {
      final quantity = _baseQuantityFor(material);
      if (quantity > 0) {
        ingredients.add({
          'raw_material_id': material['id'],
          'quantity_used': quantity,
        });
      }
    }
    await DatabaseHelper.instance
        .setProductRecipe(widget.product.id, ingredients);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('وصفة ${widget.product.name}'),
      content: SizedBox(
        width: 560,
        height: 520,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _materials.isEmpty
                ? const Center(child: Text('أضف خامات أولًا ثم عد إلى الوصفة.'))
                : Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'اكتب الكمية واختر الوحدة اللي بتستخدمها في وصفة الصنف، هتتحول تلقائيًا لوحدة تخزين الخامة',
                          style: AppTypography.bodySmall,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.space12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _materials.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final material = _materials[index];
                            final id = material['id'] as String;
                            final baseUnit = material['unit'] as String? ?? '';
                            final cost = (material['cost_per_unit'] as num?)
                                    ?.toDouble() ??
                                0;
                            final options = compatibleUnitsFor(baseUnit);
                            final hasValue =
                                _quantities[id]?.text.isNotEmpty ?? false;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.inventory_2_outlined,
                                color: hasValue
                                    ? AppColors.primary
                                    : AppColors.textDisabled,
                              ),
                              title: Text(material['name'] as String),
                              subtitle: Text(
                                'تخزين: $baseUnit • تكلفة الوحدة: ${cost.toStringAsFixed(2)} ج.م • المتاح: ${material['stock']}'
                                '${hasValue && _selectedUnits[id] != baseUnit ? ' • = ${_baseQuantityFor(material).toStringAsFixed(3)} $baseUnit' : ''}',
                                style: AppTypography.caption,
                              ),
                              trailing: SizedBox(
                                width: options.length > 1 ? 235 : 105,
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextField(
                                        controller: _quantities[id],
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        onChanged: (_) => setState(() {}),
                                        decoration: InputDecoration(
                                          labelText: 'الكمية',
                                          isDense: true,
                                          filled: true,
                                          fillColor: AppColors.surfaceVariant,
                                        ),
                                      ),
                                    ),
                                    if (options.length > 1) ...[
                                      const SizedBox(
                                          width: AppDimensions.space8),
                                      Expanded(
                                        flex: 4,
                                        child: DropdownButtonFormField<String>(
                                          initialValue:
                                              _selectedUnits[id] ?? baseUnit,
                                          isDense: true,
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            filled: true,
                                          ),
                                          items: options
                                              .map((u) => DropdownMenuItem(
                                                  value: u, child: Text(u)))
                                              .toList(),
                                          onChanged: (v) => setState(
                                              () => _selectedUnits[id] = v!),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('تكلفة الوصفة',
                              style: AppTypography.titleMedium),
                          Text(
                            '${_recipeCost.toStringAsFixed(2)} ج.م',
                            style: AppTypography.titleMedium
                                .copyWith(color: AppColors.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء')),
        FilledButton(
            onPressed: _loading ? null : _save,
            child: const Text('حفظ الوصفة')),
      ],
    );
  }
}

// ─── مساعدات عرض البيانات (Label فوق Value) ────────────────────────────────

class _LabelValue {
  const _LabelValue(this.label, this.value);
  final String label;
  final String value;
}

class _LabelValueWidget extends StatelessWidget {
  const _LabelValueWidget({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.isEmpty ? '—' : value,
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
