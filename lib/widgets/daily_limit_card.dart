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
    // Hanya memformat angkanya, "Rp" ditangani oleh RichText agar lebih efisien
    final formattedAmount = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(maxDaily);
    
    final isBiWeekly = ref.watch(appSettingsProvider).value?.isBiWeeklyMode ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.12),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER: Label & Utility Action ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Label Kiri
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.monetization_on_rounded, color: AppColors.accentGreen, size: 16),
                  SizedBox(width: 8),
                  Text(
                    "DAILY LIMIT",
                    style: TextStyle(
                      color: AppColors.accentGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              
              // Toggle Kanan (Minimalist & Intentional)
              GestureDetector(
                onTap: () => ref.read(databaseServiceProvider).toggleSpendingMode(!isBiWeekly),
                behavior: HitTestBehavior.opaque, // Memastikan area sentuh akurat
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isBiWeekly ? Icons.view_week_rounded : Icons.calendar_today_rounded,
                        color: AppColors.white.withOpacity(0.6),
                        size: 12,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isBiWeekly ? "14 Days" : "Full Month",
                        style: TextStyle(
                          color: AppColors.white.withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // --- BODY: Core Data (Optimized with RichText) ---
          RichText(
            text: TextSpan(
              // Menyelaraskan teks berbeda ukuran ke garis bawah (baseline) secara native
              style: const TextStyle(fontFamily: 'Montserrat'),
              children: [
                TextSpan(
                  text: "Rp ",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: AppColors.white.withOpacity(0.5),
                  ),
                ),
                TextSpan(
                  text: formattedAmount,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                    letterSpacing: -1.0,
                    height: 1.1,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 8),
          
          // --- FOOTER: Context ---
          Text(
            isBiWeekly ? "Safe budget for today based on current cycle" : "Safe budget for today based on full month",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.white.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}