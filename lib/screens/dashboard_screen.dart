import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../widgets/balance_overview_circle.dart';
import '../widgets/daily_limit_card.dart';
import '../widgets/transaction_card.dart';
import '../providers/database_provider.dart';
import '../providers/calculator_provider.dart';
import '../providers/history_provider.dart';
import '../widgets/input_bottom_sheet.dart';
import '../features/analytics/screens/analytics_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final AsyncValue< dynamic > balanceAsync =
        ref.watch(currentMonthBalanceProvider);
    final double maxDailySpending = ref.watch(maxDailySpendingProvider);

    final TimeFilter activeFilter = ref.watch(timeFilterProvider);
    final List< dynamic > filteredExpenses =
        ref.watch(filteredExpensesProvider);
    final double totalExpense = ref.watch(filteredTotalExpenseProvider);

    final NumberFormat formatCurrency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundTop,
      body: Stack(
        children: < Widget >[
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
              slivers: < Widget >[
                SliverToBoxAdapter(
                  child: balanceAsync.when(
                    data: (dynamic balanceData) => BalanceOverviewCircle(
                      balance: (balanceData?.balance as double?) ?? 0.0,
                    ),
                    loading: () => const SizedBox(
                      height: 300,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    error: (Object e, StackTrace st) => SizedBox(
                      height: 300,
                      child: Center(
                        child: Text(
                          'Error: ' + e.toString(),
                          style: const TextStyle(color: AppColors.primaryDark),
                        ),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
                SliverToBoxAdapter(
                  child: DailyLimitCard(maxDaily: maxDailySpending),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),

                // Filter Row yang rata sempurna dengan batas kiri & kanan kartu (horizontal: 24)
                SliverToBoxAdapter(
                  child: _buildAlignedFilterBar(
                    context: context,
                    ref: ref,
                    l10n: l10n,
                    activeFilter: activeFilter,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: < Widget >[
                        Text(
                          l10n.transactions,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        Text(
                          '- ' + formatCurrency.format(totalExpense),
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
                if (filteredExpenses.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text(
                          l10n.noTransactions,
                          style: const TextStyle(
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
                        (BuildContext context, int index) =>
                            TransactionCard(expense: filteredExpenses[index]),
                        childCount: filteredExpenses.length,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
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
                children: < Widget >[
                  IconButton(
                    icon: const Icon(
                      Icons.home_filled,
                      color: AppColors.white,
                    ),
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
                        showModalBottomSheet< void >(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (BuildContext context) =>
                              const InputBottomSheet(),
                        );
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Analitik & Laporan',
                    icon: const Icon(
                      Icons.pie_chart_rounded,
                      color: AppColors.greyText,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute< void >(
                          builder: (_) => const AnalyticsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlignedFilterBar({
    required BuildContext context,
    required WidgetRef ref,
    required AppLocalizations l10n,
    required TimeFilter activeFilter,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          const double calendarSize = 40.0;
          const double gap = 8.0;
          // Sisa ruang tepat untuk 3 chip utama (Today, This Month, 6 Months)
          // agar tepi kanan "6 Months" jatuh persis di batas kanan kartu.
          final double availableForThreeChips =
              constraints.maxWidth - calendarSize - (gap * 3);

          final double todayWidth = availableForThreeChips * 0.27;
          final double thisMonthWidth = availableForThreeChips * 0.38;
          final double sixMonthsWidth = availableForThreeChips * 0.35;
          final double thisYearWidth = availableForThreeChips * 0.35;

          final bool isCustomDate = activeFilter == TimeFilter.customDate;

          return ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: < Widget >[
                  GestureDetector(
                    onTap: () async {
                      final DateTime? date = await showDatePicker(
                        context: context,
                        initialDate:
                            ref.read(customDateProvider) ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (BuildContext context, Widget? child) {
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
                        ref.read(customDateProvider.notifier).setDate(date);
                        ref
                            .read(timeFilterProvider.notifier)
                            .setFilter(TimeFilter.customDate);
                      }
                    },
                    child: Container(
                      width: calendarSize,
                      height: calendarSize,
                      decoration: BoxDecoration(
                        color: isCustomDate
                            ? AppColors.primaryDark
                            : AppColors.white.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCustomDate
                              ? Colors.transparent
                              : AppColors.white,
                          width: 1.5,
                        ),
                        boxShadow: isCustomDate ? AppColors.softShadow : null,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.calendar_month_rounded,
                        size: 18,
                        color: isCustomDate
                            ? AppColors.white
                            : AppColors.primaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(width: gap),
                  _buildFilterChip(
                    ref: ref,
                    label: l10n.today,
                    filter: TimeFilter.daily,
                    activeFilter: activeFilter,
                    width: todayWidth,
                  ),
                  const SizedBox(width: gap),
                  _buildFilterChip(
                    ref: ref,
                    label: l10n.thisMonth,
                    filter: TimeFilter.monthly,
                    activeFilter: activeFilter,
                    width: thisMonthWidth,
                  ),
                  const SizedBox(width: gap),
                  _buildFilterChip(
                    ref: ref,
                    label: l10n.sixMonths,
                    filter: TimeFilter.sixMonths,
                    activeFilter: activeFilter,
                    width: sixMonthsWidth,
                  ),
                  const SizedBox(width: gap),
                  _buildFilterChip(
                    ref: ref,
                    label: l10n.thisYear,
                    filter: TimeFilter.yearly,
                    activeFilter: activeFilter,
                    width: thisYearWidth,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required WidgetRef ref,
    required String label,
    required TimeFilter filter,
    required TimeFilter activeFilter,
    required double width,
  }) {
    final bool isActive = filter == activeFilter;
    return GestureDetector(
      onTap: () => ref.read(timeFilterProvider.notifier).setFilter(filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: width,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
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
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              color: isActive ? AppColors.white : AppColors.primaryLight,
            ),
          ),
        ),
      ),
    );
  }
}