import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/l10n/app_localizations.dart';
import 'package:money_manager/models/app_settings.dart';
import 'package:money_manager/models/expense.dart';
import 'package:money_manager/models/monthly_balance.dart';
import 'package:money_manager/providers/database_provider.dart' as db;
import 'package:money_manager/providers/history_provider.dart' as hist;
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

  Future< void > _selectCustomDate(DateTime? currentCustomDate) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentCustomDate ?? now,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: ForestTokens.primaryForest,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: ForestTokens.primaryForest,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      ref.read(hist.customDateProvider.notifier).setDate(picked);
      ref
          .read(hist.timeFilterProvider.notifier)
          .setFilter(hist.TimeFilter.customDate);
      setState(() => _selectedSliceId = null);
    }
  }

  void _openAddExpenseSheet() {
    showModalBottomSheet< void >(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const InputBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final AsyncValue< List< Expense > > expensesAsync =
        ref.watch(db.expenseListProvider);
    final AsyncValue< MonthlyBalance? > balanceAsync =
        ref.watch(db.currentMonthBalanceProvider);
    final AsyncValue< AppSettings? > settingsAsync =
        ref.watch(db.appSettingsProvider);
    final hist.TimeFilter activeFilter = ref.watch(hist.timeFilterProvider);
    final DateTime? customDate = ref.watch(hist.customDateProvider);

    final List< Expense > allExpenses =
        expensesAsync.hasValue ? expensesAsync.value! : const < Expense >[];
    final MonthlyBalance? monthlyBalance =
        balanceAsync.hasValue ? balanceAsync.value : null;
    final AppSettings? settings =
        settingsAsync.hasValue ? settingsAsync.value : null;

    final AnalyticsSnapshot snapshot = AnalyticsEngine.compute(
      allExpenses: allExpenses,
      monthlyBalance: monthlyBalance,
      settings: settings,
      filter: activeFilter,
      customDate: customDate,
      l10n: l10n,
    );

    final List< AllocationSlice > activeSlices =
        snapshot.slicesFor(_breakdownMode);

    return Scaffold(
      backgroundColor: ForestTokens.canvasMint,
      body: Stack(
        children: < Widget >[
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: < Widget >[
                  // 1. Mode Switcher Ringkas di Atas Pedestal Circle
                  Center(
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
                  const SizedBox(height: 18),

                  // 2. Top Visual Stage: Interactive Donut Pedestal
                  InteractiveDonutChart(
                    slices: activeSlices,
                    totalSpent: snapshot.totalSpent,
                    selectedSliceId: _selectedSliceId,
                    onSliceSelected: (String? id) {
                      setState(() => _selectedSliceId = id);
                    },
                  ),
                  const SizedBox(height: 24),

                  // 3. Middle Hero Stage: Dark Forest Pace & Comparison Card
                  ForestPaceHeroCard(snapshot: snapshot),
                  const SizedBox(height: 20),

                  // 4. Filter Pills Row (Tersuplai dari AppLocalizations)
                  _SyncedFilterPillsRow(
                    activeFilter: activeFilter,
                    customDate: customDate,
                    l10n: l10n,
                    onFilterSelected: (hist.TimeFilter f) {
                      ref.read(hist.timeFilterProvider.notifier).setFilter(f);
                      setState(() => _selectedSliceId = null);
                    },
                    onCalendarTap: () => _selectCustomDate(customDate),
                  ),
                  const SizedBox(height: 24),

                  // 5. Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: < Widget >[
                      Text(
                        _breakdownMode == BreakdownMode.byItem
                            ? l10n.analyticsTopItems
                            : l10n.analyticsCategories,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: ForestTokens.primaryForest,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        IdrFormatter.format(
                          snapshot.totalSpent,
                          negativePrefix: snapshot.totalSpent > 0,
                        ),
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: ForestTokens.greyText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 6. Daftar Kartu Rincian
                  if (activeSlices.isEmpty)
                    _EmptyAnalyticsCard(l10n: l10n)
                  else
                    ...activeSlices.map((AllocationSlice slice) {
                      final double share = snapshot.shareOf(slice.amount);
                      final bool isSelected = _selectedSliceId == slice.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _NativeBreakdownCard(
                          slice: slice,
                          sharePercentage: share,
                          isSelected: isSelected,
                          isDimmed: _selectedSliceId != null && !isSelected,
                          onTap: () {
                            setState(() {
                              _selectedSliceId =
                                  isSelected ? null : slice.id;
                            });
                          },
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),

          // 7. Bottom Navigation Bar (Identik DashboardScreen)
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: ForestTokens.primaryForest,
                borderRadius: BorderRadius.circular(36),
                boxShadow: < BoxShadow >[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: < Widget >[
                  IconButton(
                    icon: const Icon(
                      Icons.home_filled,
                      color: ForestTokens.greyText,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  GestureDetector(
                    onTap: _openAddExpenseSheet,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add,
                        color: ForestTokens.primaryForest,
                        size: 28,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.pie_chart_rounded,
                      color: Colors.white,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: BreakdownMode.values.map((BreakdownMode mode) {
          final bool isActive = mode == selected;
          return GestureDetector(
            onTap: () => onChanged(mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? ForestTokens.primaryForest
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                mode.localizedLabel(l10n),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? Colors.white
                      : ForestTokens.primaryForest,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SyncedFilterPillsRow extends StatelessWidget {
  final hist.TimeFilter activeFilter;
  final DateTime? customDate;
  final AppLocalizations l10n;
  final ValueChanged< hist.TimeFilter > onFilterSelected;
  final VoidCallback onCalendarTap;

  const _SyncedFilterPillsRow({
    required this.activeFilter,
    required this.customDate,
    required this.l10n,
    required this.onFilterSelected,
    required this.onCalendarTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCustom = activeFilter == hist.TimeFilter.customDate;

    final List< ({hist.TimeFilter filter, String label}) > items =
        < ({hist.TimeFilter filter, String label}) >[
      (filter: hist.TimeFilter.daily, label: l10n.analyticsFilterToday),
      (filter: hist.TimeFilter.monthly, label: l10n.analyticsFilterThisMonth),
      (filter: hist.TimeFilter.sixMonths, label: l10n.analyticsFilterSixMonths),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: < Widget >[
          GestureDetector(
            onTap: onCalendarTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isCustom ? ForestTokens.primaryForest : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: isCustom ? Colors.white : ForestTokens.primaryForest,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ...items.map((({hist.TimeFilter filter, String label}) item) {
            final bool isSelected = activeFilter == item.filter;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => onFilterSelected(item.filter),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ForestTokens.primaryForest
                        : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : ForestTokens.primaryForest,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _NativeBreakdownCard extends StatelessWidget {
  final AllocationSlice slice;
  final double sharePercentage;
  final bool isSelected;
  final bool isDimmed;
  final VoidCallback onTap;

  const _NativeBreakdownCard({
    required this.slice,
    required this.sharePercentage,
    required this.isSelected,
    required this.isDimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: isDimmed ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? ForestTokens.primaryForest
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: < Widget >[
              Container(
                width: 4,
                height: 36,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: slice.color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
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
                  color: ForestTokens.primaryForest,
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
                        fontWeight: FontWeight.w800,
                        color: ForestTokens.primaryForest,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      slice.totalQuantity.toString() +
                          'x Rp ' +
                          IdrFormatter.numberOnly(slice.unitPrice),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: ForestTokens.greyText,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: < Widget >[
                  Text(
                    IdrFormatter.format(slice.amount),
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: ForestTokens.primaryForest,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sharePercentage.toStringAsFixed(1) +
                        '% • ' +
                        IdrFormatter.shortDate(slice.latestDate),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: ForestTokens.greyText,
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

class _EmptyAnalyticsCard extends StatelessWidget {
  final AppLocalizations l10n;

  const _EmptyAnalyticsCard({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: < Widget >[
          const Icon(
            Icons.receipt_long_outlined,
            size: 30,
            color: ForestTokens.greyText,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.analyticsEmptyTitle,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: ForestTokens.primaryForest,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.analyticsEmptySubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: ForestTokens.greyText,
            ),
          ),
        ],
      ),
    );
  }
}