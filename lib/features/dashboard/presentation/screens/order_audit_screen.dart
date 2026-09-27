import 'package:flutter/material.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_top_bar.dart';

class OrderAuditScreen extends StatefulWidget {
  const OrderAuditScreen({super.key});

  @override
  State<OrderAuditScreen> createState() => _OrderAuditScreenState();
}

class _OrderAuditScreenState extends State<OrderAuditScreen> {
  List<Map<String, dynamic>> _log = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final log = await DatabaseHelper.instance.getOrderAuditLog(limit: 200);
    if (mounted) {
      setState(() {
        _log = log;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        title: 'سجل تعديلات وإلغاءات الأوردرات',
        onBack: () => Navigator.pop(context),
        action: IconButton(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _log.isEmpty
              ? Center(
                  child: Text('لا توجد عمليات تعديل أو إلغاء مسجلة',
                      style: AppTypography.titleMedium),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppDimensions.space16),
                  itemCount: _log.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppDimensions.space8),
                  itemBuilder: (_, i) {
                    final entry = _log[i];
                    final isCancel = entry['action'] == 'cancel';
                    return Container(
                      padding: const EdgeInsets.all(AppDimensions.space14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMd),
                        border: Border.all(
                          color: isCancel ? AppColors.error : AppColors.warning,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isCancel
                                ? Icons.cancel_outlined
                                : Icons.edit_outlined,
                            color:
                                isCancel ? AppColors.error : AppColors.warning,
                          ),
                          const SizedBox(width: AppDimensions.space12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '#${entry['order_number'] ?? '—'} — ${entry['user_name'] ?? 'غير معروف'}',
                                  style: AppTypography.titleSmall,
                                ),
                                Text(entry['details'] as String? ?? '',
                                    style: AppTypography.bodySmall),
                                Text(entry['created_at'] as String? ?? '',
                                    style: AppTypography.caption.copyWith(
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
