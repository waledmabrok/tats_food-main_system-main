import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../repositories/product_repository.dart';
import '../../../../models/product.dart';

class LowStockSection extends StatefulWidget {
  const LowStockSection({super.key});

  @override
  State<LowStockSection> createState() => _LowStockSectionState();
}

class _LowStockSectionState extends State<LowStockSection> {
  final _repo = ProductRepository();
  List<Product> _lowStock = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _repo.getLowStock();
    if (mounted) {
      setState(() {
        _lowStock = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCardHeader(
            title: AppStrings.lowStockTitle,
            subtitle: AppStrings.lowStockSubtitle,
            icon: Icons.warning_amber_rounded,
            iconColor: AppColors.warning,
            trailing: AppButton(
              label: AppStrings.navInventory,
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.sm,
              onPressed: () {
                // TODO: Navigate to Inventory
              },
            ),
          ),
          const Divider(height: 1),
          _isLoading 
              ? const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()))
              : _lowStock.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.inventory_2_outlined,
                      iconColor: AppColors.success,
                      title: AppStrings.lowStockEmpty,
                      description: AppStrings.lowStockEmptyDesc,
                      compact: true,
                    )

                  : SizedBox(
                      height: 220,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppDimensions.space16),
                        itemCount: _lowStock.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final p = _lowStock[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(child: Text(p.name, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600))),
                                Text('${p.stock.toStringAsFixed(0)} ${p.unit}', style: AppTypography.titleSmall.copyWith(color: AppColors.error)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ],
      ),
    );
  }
}
