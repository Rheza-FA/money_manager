import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../widgets/balance_overview_circle.dart';
import '../widgets/daily_limit_card.dart';
import '../providers/database_provider.dart';
import '../providers/calculator_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Membaca state dari Riverpod
    final balanceAsync = ref.watch(currentMonthBalanceProvider);
    final maxDailySpending = ref.watch(maxDailySpendingProvider);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.bgGradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // Header Typography
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Your Balance\nOverview",
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                        height: 1.1,
                        letterSpacing: -1,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Track spending, limits, and insights",
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.greyText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              
              // Tengah: Sirkuler Saldo
              balanceAsync.when(
                data: (balanceData) => BalanceOverviewCircle(
                  balance: balanceData?.balance ?? 0.0,
                ),
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryDark)),
                error: (e, st) => Center(child: Text("Error: $e")),
              ),

              const Spacer(), // Mendorong kartu hijau ke bawah
              
              // Bawah: Kartu Max Spending
              DailyLimitCard(maxDaily: maxDailySpending),
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      // Floating Action Button meniru kapsul nav bawah
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 64),
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.home_rounded, color: AppColors.white),
              onPressed: () {},
            ),
            Container(
              decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(Icons.add, color: AppColors.primaryDark),
                onPressed: () {
                  // TODO: Navigasi ke Halaman Input Pengeluaran
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.pie_chart_outline, color: AppColors.greyText),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}