import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';

class BalanceOverviewCircle extends StatelessWidget {
  final double balance;

  const BalanceOverviewCircle({super.key, required this.balance});

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(150), // Bentuk melingkar/kapsul ekstrem
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.05),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        children: [
          // Placeholder Grafik fl_chart meniru gelombang referensi
          SizedBox(
            height: 100,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 3), FlSpot(1, 1.5), FlSpot(2, 4), 
                      FlSpot(3, 2), FlSpot(4, 5), FlSpot(5, 3.5),
                    ],
                    isCurved: true,
                    color: AppColors.accentGreen,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (spot, barData) => spot.x == 3, // Highlight 1 titik
                      getDotPainter: (spot, percent, barData, index) => 
                        FlDotCirclePainter(radius: 6, color: AppColors.primaryDark, strokeWidth: 2, strokeColor: AppColors.white),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.accentGreen.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            formatCurrency.format(balance),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Total Balance",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.greyText,
            ),
          ),
        ],
      ),
    );
  }
}