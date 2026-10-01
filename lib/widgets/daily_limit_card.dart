import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';

class DailyLimitCard extends StatelessWidget {
  final double maxDaily;

  const DailyLimitCard({super.key, required this.maxDaily});

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
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
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.attach_money, color: AppColors.accentGreen, size: 16),
                    SizedBox(width: 4),
                    Text("Daily Limit", style: TextStyle(color: AppColors.accentGreen, fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
              ),
              const Text("Today", style: TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            formatCurrency.format(maxDaily),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Safe to spend per day",
            style: TextStyle(
              fontSize: 12,
              color: AppColors.greyText,
            ),
          ),
        ],
      ),
    );
  }
}