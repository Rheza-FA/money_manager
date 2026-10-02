import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../widgets/balance_overview_circle.dart';
import '../widgets/daily_limit_card.dart';
import '../widgets/transaction_card.dart';
import '../providers/database_provider.dart';
import '../providers/calculator_provider.dart';
import '../providers/history_provider.dart';
import '../widgets/input_bottom_sheet.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(currentMonthBalanceProvider);
    final maxDailySpending = ref.watch(maxDailySpendingProvider);

    final activeFilter = ref.watch(timeFilterProvider);
    final filteredExpenses = ref.watch(filteredExpensesProvider);
    final totalExpense = ref.watch(filteredTotalExpenseProvider);

    final formatCurrency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundTop,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: AppColors.bgGradient,
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 2. Main Balance Circle
                SliverToBoxAdapter(
                  child: balanceAsync.when(
                    data: (balanceData) => BalanceOverviewCircle(
                      balance: balanceData?.balance ?? 0.0,
                    ),
                    loading: () => const SizedBox(
                      height: 300,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    error: (e, st) => SizedBox(
                      height: 300,
                      child: Center(
                        child: Text(
                          "Error: $e",
                          style: const TextStyle(color: AppColors.primaryDark),
                        ),
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),

                // 3. Daily Limit Card
                SliverToBoxAdapter(
                  child: DailyLimitCard(maxDaily: maxDailySpending),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),

                // 4. Integrated Filter Chips
                // 4. Integrated Filter Chips & Calendar
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        // Tombol Kalender Melayang
                        GestureDetector(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate:
                                  ref.read(customDateProvider) ??
                                  DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(), // Memblokir seleksi masa depan
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: AppColors.primaryDark,
                                      onPrimary: AppColors.white,
                                      onSurface: AppColors.primaryDark,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (date != null) {
                              // UBAH BARIS INI: Gunakan .setDate(date)
                              ref
                                  .read(customDateProvider.notifier)
                                  .setDate(date);
                              ref
                                  .read(timeFilterProvider.notifier)
                                  .setFilter(TimeFilter.customDate);
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: activeFilter == TimeFilter.customDate
                                  ? AppColors.primaryDark
                                  : AppColors.white.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: activeFilter == TimeFilter.customDate
                                    ? Colors.transparent
                                    : AppColors.white,
                                width: 1.5,
                              ),
                              boxShadow: activeFilter == TimeFilter.customDate
                                  ? AppColors.softShadow
                                  : null,
                            ),
                            child: Icon(
                              Icons.calendar_month_rounded,
                              size: 18,
                              color: activeFilter == TimeFilter.customDate
                                  ? AppColors.white
                                  : AppColors.primaryLight,
                            ),
                          ),
                        ),

                        _buildFilterChip(
                          context,
                          ref,
                          "Hari Ini",
                          TimeFilter.daily,
                          activeFilter,
                        ),
                        _buildFilterChip(
                          context,
                          ref,
                          "Bulan Ini",
                          TimeFilter.monthly,
                          activeFilter,
                        ),
                        _buildFilterChip(
                          context,
                          ref,
                          "6 Bulan",
                          TimeFilter.sixMonths,
                          activeFilter,
                        ),
                        _buildFilterChip(
                          context,
                          ref,
                          "Tahun Ini",
                          TimeFilter.yearly,
                          activeFilter,
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // 5. Section Header & Dynamic Total
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          "Transactions",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        Text(
                          "- ${formatCurrency.format(totalExpense)}",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.greyText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // 6. Fluid Transaction List (No nested scroll constraints)
                if (filteredExpenses.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text(
                          "No transactions found.",
                          style: TextStyle(
                            color: AppColors.greyText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            TransactionCard(expense: filteredExpenses[index]),
                        childCount: filteredExpenses.length,
                      ),
                    ),
                  ),

                // Spacer to avoid bottom nav bar collision
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),

          // 7. Floating Bottom Navigation Bar
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 72,
              margin: const EdgeInsets.only(bottom: 24, left: 32, right: 32),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(40),
                boxShadow: AppColors.softShadow,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.home_filled, color: AppColors.white),
                    onPressed: () {},
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.add_rounded,
                        color: AppColors.primaryDark,
                      ),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true, // Wajib true agar modal bisa membesar saat keyboard muncul
                          backgroundColor: Colors.transparent, // Transparan agar border radius modal terlihat
                          builder: (context) => const InputBottomSheet(),
                        );
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.pie_chart_rounded,
                      color: AppColors.greyText,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    WidgetRef ref,
    String label,
    TimeFilter filter,
    TimeFilter activeFilter,
  ) {
    final isActive = filter == activeFilter;
    return GestureDetector(
      onTap: () => ref.read(timeFilterProvider.notifier).setFilter(filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primaryDark
              : AppColors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive ? Colors.transparent : AppColors.white,
            width: 1.5,
          ),
          boxShadow: isActive ? AppColors.softShadow : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            color: isActive ? AppColors.white : AppColors.primaryLight,
          ),
        ),
      ),
    );
  }
}
