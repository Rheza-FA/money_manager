import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';

class BalanceOverviewCircle extends StatelessWidget {
  final double balance;

  const BalanceOverviewCircle({super.key, required this.balance});

  @override
  Widget build(BuildContext context) {
    final formatNumber = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      // Memaksa aspek rasio 1:1 agar tercipta lingkaran sempurna
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            boxShadow: AppColors.softShadow,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // --- Bagian Atas: Aksen Badge Bulat ---
              Positioned(
                top: 24,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryDark,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.attach_money, color: AppColors.white, size: 16),
                ),
              ),

              // --- Bagian Tengah: Grafik Gradient ---
              Positioned(
                top: 80,
                left: 32,
                right: 32,
                height: 80,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: const [
                          FlSpot(0, 2), FlSpot(1, 1), FlSpot(2, 3.5), 
                          FlSpot(3, 1.5), FlSpot(4, 4), FlSpot(5, 3),
                        ],
                        isCurved: true,
                        // Gradien garis grafik meniru referensi
                        gradient: const LinearGradient(
                          colors: [AppColors.backgroundTop, AppColors.accentGreen, AppColors.primaryDark],
                        ),
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          checkToShowDot: (spot, barData) => spot.x == 3, // Titik fokus
                          getDotPainter: (spot, percent, barData, index) => 
                            FlDotCirclePainter(radius: 5, color: AppColors.primaryDark, strokeWidth: 3, strokeColor: AppColors.white),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.accentGreen.withOpacity(0.2),
                              AppColors.white.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- Bagian Bawah Tengah: Tipografi Saldo ---
              Positioned(
                bottom: 80,
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Rp ",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.greyText, height: 1.5),
                        ),
                        Text(
                          formatNumber.format(balance),
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w600, // Tidak terlalu tebal, lebih elegan
                            color: AppColors.primaryDark,
                            letterSpacing: -1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Total Balance",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.greyText),
                    ),
                  ],
                ),
              ),

              // --- Bagian Paling Bawah: Deretan Action Buttons melengkung ---
              Positioned(
                bottom: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSmallActionButton(Icons.candlestick_chart_rounded, isDark: false),
                    const SizedBox(width: 12),
                    _buildSmallActionButton(Icons.pie_chart_rounded, isDark: false),
                    const SizedBox(width: 12),
                    _buildSmallActionButton(Icons.insights_rounded, isDark: true), // Active state
                    const SizedBox(width: 12),
                    _buildSmallActionButton(Icons.receipt_long_rounded, isDark: false),
                    const SizedBox(width: 12),
                    _buildSmallActionButton(Icons.account_balance_wallet_rounded, isDark: false),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // Komponen kecil untuk deretan tombol di bawah lingkaran
  Widget _buildSmallActionButton(IconData icon, {required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.primaryDark : AppColors.backgroundTop,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon, 
        size: 16, 
        color: isDark ? AppColors.white : AppColors.primaryDark
      ),
    );
  }
}