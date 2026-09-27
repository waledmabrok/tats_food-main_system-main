import 'package:flutter/material.dart';
import 'dart:io';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// شاشة تظهر لو التطبيق اتنقل لجهاز غير مصرح له
class DeviceLockedScreen extends StatelessWidget {
  const DeviceLockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 72,
                color: AppColors.error,
              ),

              const SizedBox(height: 24),
              Text(
                'هذا التطبيق مرتبط بجهاز آخر',
                style: AppTypography.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'تم اكتشاف أن التطبيق تم نقله إلى جهاز مختلف عن الجهاز الذي تم تفعيله عليه.\n'
                'تواصل مع الدعم الفني لإعادة الترخيص على هذا الجهاز.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => exit(0),
                child: const Text('إغلاق التطبيق'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
