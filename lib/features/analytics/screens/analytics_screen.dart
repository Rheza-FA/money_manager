import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/l10n/app_localizations.dart';
import 'package:money_manager/models/app_settings.dart';
import 'package:money_manager/models/expense.dart';
import 'package:money_manager/providers/calculator_provider.dart';
import 'package:money_manager/providers/database_provider.dart';
import 'package:money_manager/providers/history_provider.dart';
import 'package:money_manager/theme/app_colors.dart';
import 'package:money_manager/widgets/input_bottom_sheet.dart';
import '../models/analytics_models.dart';
import '../widgets/cashflow_comparison_chart.dart';
import '../widgets/interactive_donut_chart.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState< AnalyticsScreen > createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState< AnalyticsScreen > {
  BreakdownMode _breakdownMode = BreakdownMode.byItem;
  String? _selectedSliceId;

  Future< void > _selectCustomDate() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: ref.read(customDateProvider) ?? DateTime.now(),
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

    if (date != null && mounted) {
      ref.read(customDateProvider.notifier).setDate(date);
      ref.read(timeFilterProvider.notifier).setFilter(TimeFilter.customDate);
      setState(() => _selectedSliceId = null);
    }
  }

  void _openAddExpenseSheet() {
    showModalBottomSheet< void >(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => const InputBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    // Single Source of Truth yang sama persis dengan DashboardScreen
    final double maxDailySpending = ref.watch(maxDailySpendingProvider);
    final TimeFilter activeFilter = ref.watch(timeFilterProvider);
    final DateTime? customDate = ref.watch(customDateProvider);
    final List< Expense > filteredExpenses =
        ref.watch(filteredExpensesProvider);
    final double totalExpense = ref.watch(filteredTotalExpenseProvider);

    final AsyncValue< List< Expense > > expensesAsync =
        ref.watch(expenseListProvider);
    final AsyncValue< AppSettings? > settingsAsync =
        ref.watch(appSettingsProvider);

    final List< Expense > allExpenses =
        expensesAsync.hasValue ? expensesAsync.value! : const < Expense >[];
    final AppSettings? settings =
        settingsAsync.hasValue ? settingsAsync.value : null;

    final AnalyticsSnapshot snapshot = AnalyticsEngine.compute(
      allExpenses: allExpenses,
      filteredExpenses: filteredExpenses,
      totalFilteredExpense: totalExpense,
      exactDailyLimit: maxDailySpending,
      settings: settings,
      filter: activeFilter,
      customDate: customDate,
      l10n: l10n,
    );

    final List< AllocationSlice > activeSlices =
        snapshot.slicesFor(_breakdownMode);
    final double activeLimit = snapshot.effectiveSpendingLimit;

    return Scaffold(
      backgroundColor: AppColors.backgroundTop,
      body: Stack(
        children: < Widget >[
          // Latar Gradien Identik DashboardScreen
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
                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // 1. Mode Switcher (By Item | By Category)
                SliverToBoxAdapter(
                  child: Center(
                    child: _BreakdownModePill(
                      selected: _breakdownMode,
                      l10n: l10n,
                      onChanged: (BreakdownMode mode) {
                        setState(() {
                          _breakdownMode = mode;
                          _selectedSliceId = null;
                        });
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 18)),

                // 2. Interactive Donut Pedestal
                SliverToBoxAdapter(
                  child: InteractiveDonutChart(
                    slices: activeSlices,
                    totalSpent: snapshot.totalSpent,
                    selectedSliceId: _selectedSliceId,
                    onSliceSelected: (String? id) {
                      setState(() => _selectedSliceId = id);
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),

                // 3. ForestPaceHeroCard (Sinkron dengan DailyLimitCard)
                SliverToBoxAdapter(
                  child: ForestPaceHeroCard(
                    snapshot: snapshot,
                    onToggleSpendingMode: () {
                      ref
                          .read(databaseServiceProvider)
                          .toggleSpendingMode(!snapshot.isBiWeeklyMode);
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),

                // 4. Filter Row (100% Identik dengan DashboardScreen)
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: < Widget >[
                        GestureDetector(
                          onTap: _selectCustomDate,
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
                          l10n.today,
                          TimeFilter.daily,
                          activeFilter,
                        ),
                        _buildFilterChip(
                          l10n.thisMonth,
                          TimeFilter.monthly,
                          activeFilter,
                        ),
                        _buildFilterChip(
                          l10n.sixMonths,
                          TimeFilter.sixMonths,
                          activeFilter,
                        ),
                        _buildFilterChip(
                          l10n.thisYear,
                          TimeFilter.yearly,
                          activeFilter,
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // 5. Section Header (100% Identik dengan DashboardScreen)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: < Widget >[
                        Text(
                          _breakdownMode == BreakdownMode.byItem
                              ? l10n.analyticsTopItems
                              : l10n.analyticsCategories,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        Text(
                          '- ' + IdrFormatter.format(totalExpense),
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

                // 6. Daftar Kartu Rincian dengan Horizontal Limit Chart
                if (activeSlices.isEmpty)
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
                        (BuildContext context, int index) {
                          final AllocationSlice slice = activeSlices[index];
                          final double limitShare =
                              snapshot.limitShareOf(slice.amount);
                          final bool isSelected =
                              _selectedSliceId == slice.id;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _NativeBreakdownCard(
                              slice: slice,
                              limitSharePercentage: limitShare,
                              effectiveLimit: activeLimit,
                              l10n: l10n,
                              isSelected: isSelected,
                              isDimmed:
                                  _selectedSliceId != null && !isSelected,
                              onTap: () {
                                setState(() {
                                  _selectedSliceId =
                                      isSelected ? null : slice.id;
                                });
                              },
                            ),
                          );
                        },
                        childCount: activeSlices.length,
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),

          // 7. Bottom Navigation Bar (100% Identik dengan DashboardScreen)
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
                      color: AppColors.greyText,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
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
                      onPressed: _openAddExpenseSheet,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.pie_chart_rounded,
                      color: AppColors.white,
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
    String label,
    TimeFilter filter,
    TimeFilter activeFilter,
  ) {
    final bool isActive = filter == activeFilter;
    return GestureDetector(
      onTap: () {
        ref.read(timeFilterProvider.notifier).setFilter(filter);
        setState(() => _selectedSliceId = null);
      },
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

class _BreakdownModePill extends StatelessWidget {
  final BreakdownMode selected;
  final AppLocalizations l10n;
  final ValueChanged< BreakdownMode > onChanged;

  const _BreakdownModePill({
    required this.selected,
    required this.l10n,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.white, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: BreakdownMode.values.map((BreakdownMode mode) {
          final bool isActive = mode == selected;
          return GestureDetector(
            onTap: () => onChanged(mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primaryDark : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isActive ? AppColors.softShadow : null,
              ),
              child: Text(
                mode.localizedLabel(l10n),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isActive ? AppColors.white : AppColors.primaryLight,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NativeBreakdownCard extends StatelessWidget {
  final AllocationSlice slice;
  final double limitSharePercentage;
  final double effectiveLimit;
  final AppLocalizations l10n;
  final bool isSelected;
  final bool isDimmed;
  final VoidCallback onTap;

  const _NativeBreakdownCard({
    required this.slice,
    required this.limitSharePercentage,
    required this.effectiveLimit,
    required this.l10n,
    required this.isSelected,
    required this.isDimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasLimit = effectiveLimit > 0;
    final bool isOverLimit = hasLimit && limitSharePercentage > 100.0;
    final Color activeBarColor =
        isOverLimit ? ForestTokens.coralAlert : slice.color;
    final double clampedFactor = limitSharePercentage <= 0
        ? 0.0
        : (limitSharePercentage / 100.0).clamp(0.03, 1.0);

    final String percentageText = limitSharePercentage >= 100
        ? limitSharePercentage.toStringAsFixed(0)
        : limitSharePercentage.toStringAsFixed(1);

    final String leftCaption = hasLimit
        ? l10n.analyticsPercentOfLimit(percentageText)
        : l10n.analyticsPercentOfTotal(percentageText);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: isDimmed ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppColors.softShadow,
            border: Border.all(
              color: isSelected ? AppColors.primaryDark : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: < Widget >[
              // 1. Baris Atas: Proporsi & Tipografi Identik TransactionCard
              Row(
                children: < Widget >[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: ForestTokens.iconSurface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      slice.icon,
                      size: 22,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: < Widget >[
                        Text(
                          slice.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          slice.totalQuantity.toString() +
                              'x Rp ' +
                              IdrFormatter.numberOnly(slice.unitPrice),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: AppColors.greyText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: < Widget >[
                      Text(
                        IdrFormatter.format(slice.amount),
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        IdrFormatter.shortDate(slice.latestDate),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppColors.greyText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. Horizontal Limit Spending Gauge
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double maxBarWidth = constraints.maxWidth;
                  return TweenAnimationBuilder< double >(
                    tween: Tween< double >(begin: 0.0, end: clampedFactor),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    builder: (BuildContext context, double factor, _) {
                      return Container(
                        width: maxBarWidth,
                        height: 6,
                        decoration: BoxDecoration(
                          color: ForestTokens.canvasMint,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: maxBarWidth * factor,
                          height: 6,
                          decoration: BoxDecoration(
                            color: activeBarColor,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 7),

              // 3. Baris Mikro-Konteks Limit
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: < Widget >[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: < Widget >[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: activeBarColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        leftCaption,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isOverLimit
                              ? ForestTokens.coralAlert
                              : AppColors.greyText,
                        ),
                      ),
                    ],
                  ),
                  if (hasLimit)
                    Text(
                      l10n.analyticsLimitBenchmark(
                        IdrFormatter.format(effectiveLimit),
                      ),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.greyText,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}