import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/data_export_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/restart_app.dart';
import '../../../../core/services/restaurant_info_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseHelper.instance;
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDeletingSales = false;
  bool _isExporting = false;
  bool _isExportingJson = false;
  bool _isImportingJson = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    _nameCtrl.text = await _db.getSetting('restaurant_name') ?? '';
    _phoneCtrl.text = await _db.getSetting('restaurant_phone') ?? '';
    _addressCtrl.text = await _db.getSetting('restaurant_address') ?? '';
    _currencyCtrl.text =
        await _db.getSetting('currency') ?? AppStrings.currency;

    if (mounted) setState(() => _isLoading = false);
  }
  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    await _db.setSetting('restaurant_name', _nameCtrl.text.trim());
    await _db.setSetting('restaurant_phone', _phoneCtrl.text.trim());
    await _db.setSetting('restaurant_address', _addressCtrl.text.trim());
    await _db.setSetting('currency', _currencyCtrl.text.trim());

    RestaurantInfoService.instance.update(_nameCtrl.text.trim());

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.settingsSaved),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  // ─── حذف كل المبيعات ────────────────────────────────────────────────
  Future<void> _confirmDeleteAllSales() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: AppColors.error,
          size: 40,
        ),
        title: const Text('حذف كل المبيعات'),
        content: const Text(
          'هيتم حذف كل الطلبات وسجلات البيع نهائيًا من النظام.\n\n'
          'الأصناف والتصنيفات والمخزون الحالي مش هيتأثروا.\n\n'
          'الإجراء ده لا يمكن التراجع عنه، متأكد إنك عايز تكمل؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeletingSales = true);
    try {
      await _db.deleteAllSales();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف كل المبيعات بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء الحذف: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeletingSales = false);
    }
  }

  // ─── تصدير البيانات إلى Excel ──────────────────────────────────────────
  Future<void> _exportToExcel() async {
    setState(() => _isExporting = true);
    try {
      final path = await DataExportService.instance.exportAllToExcel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم التصدير بنجاح\n$path'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'موافق',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء التصدير: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ─── تصدير نسخة احتياطية كاملة (JSON) ──────────────────────────────────
  Future<void> _exportBackupJson() async {
    setState(() => _isExportingJson = true);
    try {
      final path = await DataExportService.instance.exportAllDataToJson();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم تصدير النسخة الاحتياطية بنجاح:\n$path'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'موافق',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء التصدير: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingJson = false);
    }
  }

  // ─── استيراد نسخة احتياطية (JSON) ─────────────────────────────────────
  Future<void> _importBackupJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: 'اختر ملف النسخة الاحتياطية (JSON)',
    );

    if (result == null || result.files.single.path == null) return;

    final filePath = result.files.single.path!;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.upload_file_rounded,
          color: AppColors.primary,
          size: 40,
        ),
        title: const Text('تأكيد استيراد البيانات'),
        content: const Text(
          'سيتم استيراد كافة البيانات المسجلة في ملف النسخة الاحتياطية وتحديث السجلات في النظام.\n\n'
          'هل تريد الاستمرار؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('استيراد الآن'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isImportingJson = true);
    try {
      final count =
          await DataExportService.instance.importAllDataFromJson(filePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم استيراد البيانات بنجاح ($count سجل)'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 5),
          ),
        );
        _loadSettings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء استيراد البيانات: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isImportingJson = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: AppStrings.settingsTitle),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.space32),
                child: Align(
                  alignment: Alignment.topRight,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─── بيانات المطعم ─────────────────────────────────
                        Text(
                          AppStrings.settingsRestaurant,
                          style: AppTypography.titleLarge,
                        ),
                        const SizedBox(height: AppDimensions.space16),
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.space24),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusMd,
                            ),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedBuilder(
                                animation: ThemeController.instance,
                                builder: (context, _) {
                                  final mode = ThemeController.instance.mode;

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'مظهر النظام',
                                        style: AppTypography.bodySmall.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: AppDimensions.space8),
                                      SegmentedButton<ThemeMode>(
                                        segments: const [
                                          ButtonSegment<ThemeMode>(
                                            value: ThemeMode.light,
                                            icon:
                                                Icon(Icons.light_mode_outlined),
                                            label: Text('فاتح'),
                                          ),
                                          ButtonSegment<ThemeMode>(
                                            value: ThemeMode.dark,
                                            icon:
                                                Icon(Icons.dark_mode_outlined),
                                            label: Text('داكن'),
                                          ),
                                        ],
                                        selected: {mode},
                                        onSelectionChanged: (selection) async {
                                          final newMode = selection.first;
                                          if (newMode == mode) return;

                                          final confirmed =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('تغيير المظهر'),
                                              content: Text(
                                                'هيتم تطبيق الوضع ${newMode == ThemeMode.dark ? "الداكن" : "الفاتح"} '
                                                'وإعادة تحميل الشاشات. تكمل؟',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  child: const Text('إلغاء'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  child: const Text('تأكيد'),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirmed != true) return;

                                          ThemeController.instance
                                              .setMode(newMode);
                                          if (context.mounted) {
                                            await AppRestartService
                                                .restartCompletely();
                                          }
                                        },
                                      ),
                                      const SizedBox(
                                          height: AppDimensions.space20),
                                    ],
                                  );
                                },
                              ),
                              _buildField(
                                AppStrings.settingsRestaurantName,
                                _nameCtrl,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'اسم المطعم مطلوب'
                                        : null,
                              ),
                              const SizedBox(height: 16),
                              _buildPhoneField(),
                              const SizedBox(height: 16),
                              _buildField(
                                AppStrings.settingsRestaurantAddress,
                                _addressCtrl,
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space32),

                        // ─── إعدادات النظام ────────────────────────────────
                        Text(
                          AppStrings.settingsSystem,
                          style: AppTypography.titleLarge,
                        ),
                        const SizedBox(height: AppDimensions.space16),
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.space24),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusMd,
                            ),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildField(
                                AppStrings.settingsCurrency,
                                _currencyCtrl,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'سيتم تطبيق التغييرات في النظام بالكامل. برجاء إعادة تشغيل التطبيق في حالة تغيير العملة.',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppDimensions.space32),

                        // زر الحفظ
                        SizedBox(
                          width: 200,
                          height: AppDimensions.buttonHeightLg,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveSettings,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded),
                            label: Text(
                              AppStrings.btnSave,
                              style: AppTypography.button,
                            ),
                          ),
                        ),

                        const SizedBox(height: AppDimensions.space32),

                        // ─── البيانات والنسخ الاحتياطي ──────────────────────
                        Text(
                          '📊 البيانات والنسخ الاحتياطي',
                          style: AppTypography.titleLarge,
                        ),
                        const SizedBox(height: AppDimensions.space16),
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.space24),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusMd),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── 1) النسخ الاحتياطي والاستيراد (JSON) ──────────
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.cloud_sync_rounded,
                                      color: AppColors.primary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'نسخة احتياطية واستيراد كامل للنظام (JSON)',
                                          style: AppTypography.titleMedium
                                              .copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          'تصدير كل جداول وبيانات النظام في ملف نسخ احتياطي، أو استيراد ملف سابق لاسترجاع كل شيء.',
                                          style:
                                              AppTypography.bodySmall.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 12,
                                runSpacing: 10,
                                children: [
                                  SizedBox(
                                    height: AppDimensions.buttonHeightLg,
                                    child: ElevatedButton.icon(
                                      onPressed: _isExportingJson
                                          ? null
                                          : _exportBackupJson,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 18),
                                      ),
                                      icon: _isExportingJson
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.backup_rounded),
                                      label: Text(
                                        _isExportingJson
                                            ? 'جاري التصدير...'
                                            : 'تصدير كل الداتا (Backup)',
                                        style: AppTypography.button,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: AppDimensions.buttonHeightLg,
                                    child: OutlinedButton.icon(
                                      onPressed: _isImportingJson
                                          ? null
                                          : _importBackupJson,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primaryLight,
                                        side: BorderSide(
                                            color: AppColors.primary),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 18),
                                      ),
                                      icon: _isImportingJson
                                          ? SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.primary,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.restore_page_rounded),
                                      label: Text(
                                        _isImportingJson
                                            ? 'جاري الاستيراد...'
                                            : 'استيراد كل الداتا (Restore)',
                                        style: AppTypography.button,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),
                              Divider(color: AppColors.divider),
                              const SizedBox(height: 20),

                              // ── 2) تصدير Excel ──────────────────────────────
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.success
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.table_chart_rounded,
                                      color: AppColors.success,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'تصدير كل البيانات كملف إكسيل (Excel)',
                                          style: AppTypography.titleMedium
                                              .copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          'يصدّر الطلبات، الأصناف، التصنيفات، المصروفات، الموردين، العملاء، حركات المخزون والشيفتات في أوراق عمل منفصلة.',
                                          style:
                                              AppTypography.bodySmall.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: AppDimensions.buttonHeightLg,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _isExporting ? null : _exportToExcel,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                  ),
                                  icon: _isExporting
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.download_rounded),
                                  label: Text(
                                    _isExporting
                                        ? 'جاري التصدير...'
                                        : 'تصدير إلى Excel (.xlsx)',
                                    style: AppTypography.button,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppDimensions.space32),

                        // ─── منطقة الخطر ────────────────────────────────────
                        Text(
                          'منطقة الخطر',
                          style: AppTypography.titleLarge.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space16),
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.space24),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusMd,
                            ),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.delete_forever_rounded,
                                    color: AppColors.error,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'حذف كل المبيعات',
                                    style: AppTypography.titleMedium.copyWith(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'هيمسح كل الطلبات وسجلات البيع نهائيًا. الأصناف والتصنيفات والمخزون '
                                'هيفضلوا زي ما هما من غير تأثير. الإجراء ده لا يمكن التراجع عنه.',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: AppDimensions.buttonHeightLg,
                                child: OutlinedButton.icon(
                                  onPressed: _isDeletingSales
                                      ? null
                                      : _confirmDeleteAllSales,
                                  icon: _isDeletingSales
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.error,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.delete_forever_rounded,
                                        ),
                                  label: Text(
                                    _isDeletingSales
                                        ? 'جاري الحذف...'
                                        : 'حذف كل المبيعات',
                                    style: AppTypography.button.copyWith(
                                      color: AppColors.error,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    side: BorderSide(
                                      color: AppColors.error,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.settingsRestaurantPhone,
          style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          maxLength: 11,
          style: AppTypography.bodyMedium,
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return null; // رقم الهاتف اختياري
            }
            // تحويل الأرقام العربية إلى إنجليزية
            const arabic = '٠١٢٣٤٥٦٧٨٩';
            var normalized = v.trim();
            for (var i = 0; i < arabic.length; i++) {
              normalized = normalized.replaceAll(arabic[i], '$i');
            }
            if (normalized.length != 11) {
              return 'رقم الهاتف يجب أن يكون 11 رقم بالضبط';
            }
            if (!normalized.startsWith('0')) {
              return 'رقم الهاتف يجب أن يبدأ بـ 0';
            }
            return null;
          },
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: AppColors.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              borderSide: BorderSide.none,
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              borderSide: BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              borderSide: BorderSide(color: AppColors.error, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: AppTypography.bodyMedium,
          validator: validator,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              borderSide: BorderSide.none,
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              borderSide: BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              borderSide: BorderSide(color: AppColors.error, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
