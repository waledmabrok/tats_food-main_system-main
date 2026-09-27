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

class _AccountsScreen extends StatefulWidget {
  const _AccountsScreen();

  @override
  State<_AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<_AccountsScreen> {
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _assets = [];
  Map<String, dynamic>? _profitLoss;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await DatabaseHelper.instance.postAssetDepreciation();
    final accounts = await DatabaseHelper.instance.getAccounts();
    final assets = await DatabaseHelper.instance.getFixedAssets();
    final pl = await DatabaseHelper.instance.getProfitLossReport();
    if (mounted) {
      setState(() {
        _accounts = accounts;
        _assets = assets;
        _profitLoss = pl;
        _loading = false;
      });
    }
  }

  String _typeLabel(String type) => switch (type) {
        'asset' => 'أصل',
        'liability' => 'التزام',
        'equity' => 'حقوق ملكية',
        'revenue' => 'إيراد',
        'expense' => 'مصروف',
        _ => type,
      };

  List<Map<String, dynamic>> get _orderedAccounts {
    final result = <Map<String, dynamic>>[];
    void addChildren(String? parentId, int level) {
      final children = _accounts
          .where((account) => account['parent_id'] == parentId)
          .toList();
      for (final account in children) {
        result.add({...account, '_level': level});
        addChildren(account['id'] as String, level + 1);
      }
    }

    addChildren(null, 0);
    return result;
  }

  double _sumByType(String type) =>
      _accounts.where((account) => account['type'] == type).fold(0,
          (sum, account) => sum + (account['balance'] as num).toDouble().abs());

  Future<void> _showTransactions(Map<String, dynamic> account) async {
    final rows = await DatabaseHelper.instance.rawQuery(
      '''SELECT created_at, debit, credit, description, ref_type
         FROM account_transactions WHERE account_id = ?
         ORDER BY created_at DESC LIMIT 100''',
      [account['id']],
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('حركات ${account['name']}'),
        content: SizedBox(
          width: 620,
          height: 460,
          child: rows.isEmpty
              ? const Center(child: Text('لا توجد حركات على هذا الحساب'))
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final row = rows[index];
                    final debit = (row['debit'] as num).toDouble();
                    final credit = (row['credit'] as num).toDouble();
                    return ListTile(
                      title:
                          Text(row['description'] as String? ?? 'حركة محاسبية'),
                      subtitle: Text(
                          '${row['created_at']} • ${row['ref_type'] ?? ''}'),
                      trailing: Text(
                        debit > 0
                            ? '+${debit.toStringAsFixed(2)} مدين'
                            : '-${credit.toStringAsFixed(2)} دائن',
                        style: AppTypography.bodySmall.copyWith(
                          color:
                              debit > 0 ? AppColors.success : AppColors.error,
                        ),
                      ),
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

  Future<void> _addAssetDialog() async {
    final nameCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final lifeCtrl = TextEditingController(text: '12');
    String category = 'rent';
    bool isRecurring = true; // الإيجار افتراضيًا متكرر

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
                title: const Text('إضافة أصل / مصروف ثابت'),
                content: SizedBox(
                    width: 400,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                              labelText: 'الاسم (إيجار المحل، فرن...)')),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: category,
                        items: const [
                          DropdownMenuItem(value: 'rent', child: Text('إيجار')),
                          DropdownMenuItem(
                              value: 'equipment', child: Text('معدات')),
                          DropdownMenuItem(
                              value: 'furniture', child: Text('أثاث')),
                          DropdownMenuItem(value: 'other', child: Text('أخرى')),
                        ],
                        onChanged: (v) => setD(() {
                          category = v!;
                          isRecurring = category ==
                              'rent'; // اقتراح تلقائي، والمستخدم يقدر يغيّره
                        }),
                        decoration: const InputDecoration(labelText: 'النوع'),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('مصروف متكرر شهريًا؟'),
                        subtitle: Text(isRecurring
                            ? 'زي الإيجار — هتسجل دفعة كل شهر بنفسك'
                            : 'زي المعدات — بيتخصم تدريجيًا (إهلاك) على مدة عمره الافتراضي'),
                        value: isRecurring,
                        onChanged: (v) => setD(() => isRecurring = v),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                          controller: costCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                              labelText: isRecurring
                                  ? 'القيمة الشهرية'
                                  : 'التكلفة الكلية',
                              suffixText: 'ج.م')),
                      if (!isRecurring) ...[
                        const SizedBox(height: 12),
                        TextField(
                            controller: lifeCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'العمر الافتراضي بالشهور',
                                helperText:
                                    'هيتخصم من الأرباح تدريجيًا على المدة دي')),
                      ],
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('إلغاء')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('حفظ')),
                ],
              )),
    );
    if (saved != true) return;
    final cost = double.tryParse(costCtrl.text.trim()) ?? 0;
    final life = int.tryParse(lifeCtrl.text.trim()) ?? 12;
    if (nameCtrl.text.trim().isEmpty || cost <= 0) return;

    await DatabaseHelper.instance.addFixedAsset(
        name: nameCtrl.text.trim(),
        category: category,
        cost: cost,
        isRecurring: isRecurring,
        usefulLifeMonths: life,
        userId: SessionService.instance.currentUser?.id);
    _load();
  }

  Widget _profitLossCard() {
    if (_profitLoss == null) return const SizedBox.shrink();
    final netProfit = (_profitLoss!['net_profit'] as num).toDouble();
    final totalSales = (_profitLoss!['total_sales'] as num).toDouble();
    final cogsTotal = (_profitLoss!['cogs_total'] as num).toDouble();
    final expensesTotal = (_profitLoss!['expenses_total'] as num).toDouble();
    final isProfit = netProfit >= 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(AppDimensions.space24, 0,
          AppDimensions.space24, AppDimensions.space16),
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: isProfit
            ? AppColors.successLight
            : AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: isProfit ? AppColors.success : AppColors.error,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isProfit ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: isProfit ? AppColors.success : AppColors.error,
            size: 28,
          ),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('صافي الربح (من بداية النشاط)',
                    style: AppTypography.bodySmall),
                Text(
                  '${netProfit.toStringAsFixed(2)} ج.م',
                  style: AppTypography.headlineSmall.copyWith(
                    color: isProfit ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'مبيعات ${totalSales.toStringAsFixed(0)} ج.م  •  '
                  'تكلفة بضاعة ${cogsTotal.toStringAsFixed(0)} ج.م  •  '
                  'مصاريف ${expensesTotal.toStringAsFixed(0)} ج.م',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _assetsSection() {
    if (_assets.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppDimensions.space24, 0,
          AppDimensions.space24, AppDimensions.space16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('الأصول والمصاريف الثابتة', style: AppTypography.titleMedium),
        const SizedBox(height: AppDimensions.space10),
        ..._assets.map((asset) {
          final isRecurring = (asset['is_recurring'] as int) == 1;
          final cost = (asset['cost'] as num).toDouble();
          final accumulated =
              (asset['accumulated_depreciation'] as num?)?.toDouble() ?? 0;
          final remaining = cost - accumulated;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(AppDimensions.space12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              Icon(
                  isRecurring
                      ? Icons.repeat_rounded
                      : Icons.inventory_2_outlined,
                  color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(asset['name'] as String,
                          style: AppTypography.titleSmall),
                      Text(
                        isRecurring
                            ? 'متكرر شهريًا — ${cost.toStringAsFixed(0)} ج.م/شهر'
                            : 'مُهلَك: ${accumulated.toStringAsFixed(0)} من ${cost.toStringAsFixed(0)} ج.م '
                                '(متبقي ${remaining.toStringAsFixed(0)})',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ]),
              ),
              if (isRecurring)
                TextButton.icon(
                  onPressed: () async {
                    await DatabaseHelper.instance.payRecurringAsset(
                        assetId: asset['id'] as String,
                        userId: SessionService.instance.currentUser?.id);
                    _load();
                  },
                  icon: const Icon(Icons.add_card_outlined, size: 18),
                  label: const Text('تسجيل دفعة الشهر'),
                ),
            ]),
          );
        }),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        title: 'دليل الحسابات',
        action: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
              tooltip: 'إضافة أصل ثابت',
              onPressed: _addAssetDialog,
              icon: const Icon(Icons.add_business_rounded)),
          IconButton(
              tooltip: 'تحديث',
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded)),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppDimensions.space24,
                        AppDimensions.space20,
                        AppDimensions.space24,
                        AppDimensions.space8),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth > 900 ? 3 : 1;
                        return GridView.count(
                          crossAxisCount: columns,
                          crossAxisSpacing: AppDimensions.space12,
                          mainAxisSpacing: AppDimensions.space12,
                          childAspectRatio: columns == 1 ? 5.5 : 2.8,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _AccountSummary(
                                label: 'الأصول',
                                value: _sumByType('asset'),
                                color: AppColors.primary),
                            _AccountSummary(
                                label: 'الإيرادات',
                                value: _sumByType('revenue'),
                                color: AppColors.success),
                            _AccountSummary(
                                label: 'المصروفات',
                                value: _sumByType('expense'),
                                color: AppColors.warning),
                          ],
                        );
                      },
                    ),
                  ),
                  _profitLossCard(),
                  _assetsSection(),
                  /*     ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.space24),
                    itemCount: _orderedAccounts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final account = _orderedAccounts[index];
                      final level = account['_level'] as int;
                      return ListTile(
                        contentPadding:
                            EdgeInsets.only(left: 8, right: 8 + level * 24.0),
                        leading: Icon(
                          level == 0
                              ? Icons.account_tree_rounded
                              : Icons.subdirectory_arrow_left_rounded,
                          color: level == 0
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        title: Text(account['name'] as String,
                            style: level == 0
                                ? AppTypography.titleMedium
                                : AppTypography.bodyMedium),
                        subtitle: Text(
                            '${account['code']} • ${_typeLabel(account['type'] as String)}',
                            style: AppTypography.bodySmall),
                        trailing: Text(
                            '${(account['balance'] as num).abs().toStringAsFixed(2)} ج.م',
                            style: AppTypography.titleSmall.copyWith(
                              color: account['type'] == 'revenue'
                                  ? AppColors.success
                                  : AppColors.textPrimary,
                            )),
                        onTap: () => _showTransactions(account),
                      );
                    },
                  ),*/
                  const SizedBox(height: AppDimensions.space24),
                ],
              ),
            ),
    );
  }
}

class _AccountSummary extends StatelessWidget {
  const _AccountSummary(
      {required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_outlined, color: color),
          const SizedBox(width: AppDimensions.space8),
          Text(label, style: AppTypography.bodySmall),
          const Spacer(),
          Text('${value.toStringAsFixed(2)} ج.م',
              style: AppTypography.titleSmall.copyWith(color: color)),
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
