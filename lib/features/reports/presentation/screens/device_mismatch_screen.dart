import 'package:flutter/material.dart';
import 'dart:io';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_dimensions.dart';

class DeviceMismatchScreen extends StatelessWidget {
  const DeviceMismatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.space32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // أيقونة تحذير
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.gpp_bad_rounded,
                    size: 64,
                    color: AppColors.error,
                  ),

                ),
                const SizedBox(height: AppDimensions.space32),

                Text(
                  'الترخيص غير صالح لهذا الجهاز',
                  style: AppTypography.headlineMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                Text(
                  'هذا البرنامج مُفعّل على جهاز آخر. لا يمكن استخدام نفس الترخيص على أكثر من جهاز.\nيرجى التواصل مع الدعم الفني لنقل الترخيص أو تفعيل نسخة جديدة.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.space32),

                // زرار التواصل مع الدعم (اختياري - عدّل الرقم/الرابط حسب الحاجة)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // مثال: ممكن تفتح واتساب أو تعرض رقم تليفون
                      // أو تسيبها فاضية لو مش محتاجها دلوقتي
                    },
                    icon: const Icon(Icons.support_agent_rounded),
                    label: const Text('التواصل مع الدعم الفني'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMd,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // زرار إغلاق البرنامج
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => exit(0),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMd,
                        ),
                      ),
                    ),
                    child: const Text('إغلاق البرنامج'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
