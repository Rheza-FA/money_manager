import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../providers/database_provider.dart';

class DailyLimitCard extends ConsumerWidget {
  final double maxDaily;

  const DailyLimitCard({super.key, required this.maxDaily});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatCurrency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    
    // Membaca status setting saat ini secara real-time
    final settingsAsync = ref.watch(appSettingsProvider);
    final isBiWeekly = settingsAsync.value?.isBiWeeklyMode ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: AppColors.primaryDark.withOpacity(0.2), blurRadius: 24, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.accentGreen.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: const Row(
                  children: [
                    Icon(Icons.attach_money, color: AppColors.accentGreen, size: 16),
                    SizedBox(width: 4),
                    Text("Daily Limit", style: TextStyle(color: AppColors.accentGreen, fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
              ),
              
              // Toggle Button Modern
              GestureDetector(
                onTap: () => ref.read(databaseServiceProvider).toggleSpendingMode(!isBiWeekly),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(isBiWeekly ? Icons.rotate_right_rounded : Icons.calendar_today_rounded, color: AppColors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(isBiWeekly ? "14-Days Cycle" : "Full Month", style: const TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(formatCurrency.format(maxDaily), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.white)),
          const SizedBox(height: 4),
          Text(
            isBiWeekly ? "Safe to spend per day (This Cycle)" : "Safe to spend per day (This Month)", 
            style: const TextStyle(fontSize: 12, color: AppColors.greyText)
          ),
        ],
      ),
    );
  }
}