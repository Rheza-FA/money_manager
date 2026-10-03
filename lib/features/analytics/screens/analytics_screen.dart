import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/providers/database_provider.dart' as db;
import 'package:money_manager/providers/history_provider.dart' as hist;
import '../models/analytics_models.dart';
import '../widgets/cashflow_comparison_chart.dart';
import '../widgets/interactive_donut_chart.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onAddTransactionRequested;

  const AnalyticsScreen({
    super.key,
    this.onAddTransactionRequested,
  });

  @override
  ConsumerState< AnalyticsScreen > createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState< AnalyticsScreen > {
  AnalyticsFilterPeriod _selectedPeriod = AnalyticsFilterPeriod.today;
  BreakdownGroupMode _groupMode = BreakdownGroupMode.byItem;
  DateTime? _customSelectedDate;
  String? _selectedSliceId;

  void _selectPeriod(AnalyticsFilterPeriod period) {
    setState(() {
      _selectedPeriod = period;
      if (period != AnalyticsFilterPeriod.customDate) {
        _customSelectedDate = null;
      }
      _selectedSliceId = null;
    });
  }

  Future< void > _pickCustomDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _customSelectedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: ForestAnalyticsPalette.deepForest,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: ForestAnalyticsPalette.deepForest,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _customSelectedDate = picked;
        _selectedPeriod = AnalyticsFilterPeriod.customDate;
        _selectedSliceId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(db.expenseListProvider);
    final balanceAsync = ref.watch(db.currentMonthBalanceProvider);
    final settingsAsync = ref.watch(db.appSettingsProvider);
    final filteredExpenses = ref.watch(hist.filteredExpensesProvider);

    final dynamic dbProvider = (
      expenses: expensesAsync.hasValue ? expensesAsync.value! : const [],
      monthlyBudget:
          balanceAsync.hasValue ? (balanceAsync.value?.balance ?? 0.0) : 0.0,
      isFullMonth: settingsAsync.hasValue
          ? !(settingsAsync.value?.isBiWeeklyMode ?? false)
          : true,
    );
    final dynamic histProvider = (
      expenses: filteredExpenses,
    );

    final DynamicAnalyticsSnapshot snapshot =
        AnalyticsDataBridge.buildFromProviders(
      databaseProvider: dbProvider,
      historyProvider: histProvider,
      period: _selectedPeriod,
      customDate: _customSelectedDate,
    );

    final List< AllocationSlice > activeSlices =
        snapshot.slicesForMode(_groupMode);

    return Scaffold(
      backgroundColor: ForestAnalyticsPalette.scaffoldMint,
      body: Stack(
        children: < Widget >[
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: < Widget >[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(< Widget >[
                      // 1. Top Header Organik
                      _TopAnalyticsHeader(
                        transactionCount: snapshot.totalTransactions,
                        onBack: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(height: 18),

                      // 2. Hero Card Bergaya DailyLimitCard (#0A332B)
                      _ForestSpendingHeroCard(snapshot: snapshot),
                      const SizedBox(height: 18),

                      // 3. Baris Filter Pil Persis Halaman Pertama
                      _DashboardStyleFilterRow(
                        selectedPeriod: _selectedPeriod,
                        customDate: _customSelectedDate,
                        onPeriodSelected: _selectPeriod,
                        onCalendarTap: _pickCustomDate,
                      ),
                      const SizedBox(height: 22),

                      // 4. Kartu Distribusi Donut Chart + Switcher (Per Item / Kategori)
                      _DonutAllocationCard(
                        slices: activeSlices,
                        totalSpent: snapshot.totalSpent,
                        groupMode: _groupMode,
                        selectedSliceId: _selectedSliceId,
                        onGroupModeChanged: (BreakdownGroupMode mode) {
                          setState(() {
                            _groupMode = mode;
                            _selectedSliceId = null;
                          });
                        },
                        onSliceSelected: (String? id) {
                          setState(() {
                            _selectedSliceId = id;
                          });
                        },
                      ),
                      const SizedBox(height: 22),

                      // 5. Header Rincian Alokasi (Persis Gaya "Transactions   - Rp 17.000")
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: < Widget >[
                          Text(
                            _groupMode == BreakdownGroupMode.byItem
                                ? 'Top Items'
                                : 'Categories',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: ForestAnalyticsPalette.deepForest,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            IdrFormatter.format(
                              snapshot.totalSpent,
                              withNegativePrefix: snapshot.totalSpent > 0,
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: ForestAnalyticsPalette.bodyGreyText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 6. Daftar Kartu Item/Kategori (Bergaya TransactionCard)
                      if (activeSlices.isEmpty)
                        const _EmptyTransactionsStateCard()
                      else
                        ...activeSlices.map((AllocationSlice slice) {
                          final double share =
                              snapshot.shareOfTotal(slice.amount);
                          final bool isSelected = _selectedSliceId == slice.id;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TransactionStyleBreakdownCard(
                              slice: slice,
                              sharePercentage: share,
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
                        }),

                      const SizedBox(height: 12),

                      // 7. Grafik Tren & Garis Batas Daily Limit
                      _TrendBenchmarkSectionCard(snapshot: snapshot),
                      const SizedBox(height: 18),

                      // 8. Komparasi Head-to-Head Periode Ini vs Sebelumnya
                      _PeriodComparisonCard(snapshot: snapshot),
                    ]),
                  ),
                ),
              ],
            ),
          ),

          // 9. Floating Bottom Capsule Bar (Persis Halaman Pertama)
          Positioned(
            left: 24,
            right: 24,
            bottom: 22,
            child: SafeArea(
              top: false,
              child: _FloatingForestBottomBar(
                onHomeTap: () => Navigator.of(context).maybePop(),
                onAddTap: () {
                  if (widget.onAddTransactionRequested != null) {
                    Navigator.of(context).maybePop();
                    widget.onAddTransactionRequested!();
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopAnalyticsHeader extends StatelessWidget {
  final int transactionCount;
  final VoidCallback onBack;

  const _TopAnalyticsHeader({
    required this.transactionCount,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: < Widget >[
        Row(
          children: < Widget >[
            GestureDetector(
              onTap: onBack,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: < BoxShadow >[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: ForestAnalyticsPalette.deepForest,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Analytics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: ForestAnalyticsPalette.deepForest,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: < Widget >[
              const Icon(
                Icons.receipt_long_outlined,
                size: 15,
                color: ForestAnalyticsPalette.deepForest,
              ),
              const SizedBox(width: 6),
              Text(
                transactionCount.toString() + ' Transaksi',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: ForestAnalyticsPalette.deepForest,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Hero Card yang mengadopsi 100% DNA desain DailyLimitCard pada halaman pertama.
class _ForestSpendingHeroCard extends StatelessWidget {
  final DynamicAnalyticsSnapshot snapshot;

  const _ForestSpendingHeroCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final double? delta = snapshot.periodDeltaPercentage;
    final bool hasDailyLimit = snapshot.dailyLimit > 0;
    final bool isSingleDay = snapshot.period == AnalyticsFilterPeriod.today ||
        snapshot.period == AnalyticsFilterPeriod.customDate;

    String subtitleText;
    if (hasDailyLimit && isSingleDay) {
      final double remainingToday = snapshot.dailyLimit - snapshot.totalSpent;
      if (remainingToday >= 0) {
        subtitleText = 'Safe budget: sisa ' +
            IdrFormatter.format(remainingToday) +
            ' dari Daily Limit (' +
            IdrFormatter.format(snapshot.dailyLimit) +
            ')';
      } else {
        subtitleText = 'Melewati Daily Limit (' +
            IdrFormatter.format(snapshot.dailyLimit) +
            ') sebesar ' +
            IdrFormatter.format(remainingToday.abs());
      }
    } else if (hasDailyLimit) {
      subtitleText = 'Rata-rata ' +
          IdrFormatter.format(snapshot.averageDailySpent) +
          '/hari • Daily Limit ' +
          IdrFormatter.format(snapshot.dailyLimit);
    } else {
      subtitleText = 'Total ' +
          snapshot.totalItemsQuantity.toString() +
          ' item dari ' +
          snapshot.totalTransactions.toString() +
          ' transaksi tercatat';
    }

    String badgeLabel;
    IconData badgeIcon;
    if (delta != null) {
      final String sign = delta > 0 ? '+' : '';
      badgeLabel = sign +
          delta.toStringAsFixed(1) +
          '% ' +
          snapshot.period.comparisonSuffix;
      badgeIcon = delta <= 0
          ? Icons.trending_down_rounded
          : Icons.trending_up_rounded;
    } else {
      badgeLabel = snapshot.isFullMonthMode ? 'Full Month' : 'Weekdays';
      badgeIcon = Icons.calendar_today_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ForestAnalyticsPalette.deepForest,
        borderRadius: BorderRadius.circular(28),
        boxShadow: < BoxShadow >[
          BoxShadow(
            color: ForestAnalyticsPalette.deepForest.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: < Widget >[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: < Widget >[
              Row(
                children: < Widget >[
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: ForestAnalyticsPalette.sageAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.attach_money_rounded,
                      size: 15,
                      color: ForestAnalyticsPalette.deepForest,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'TOTAL SPENDING',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: ForestAnalyticsPalette.sageAccent,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: < Widget >[
                    Icon(
                      badgeIcon,
                      size: 13,
                      color: ForestAnalyticsPalette.sageAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      badgeLabel,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: < Widget >[
                const Text(
                  'Rp ',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: ForestAnalyticsPalette.mutedSageText,
                  ),
                ),
                Text(
                  IdrFormatter.numberOnly(snapshot.totalSpent),
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitleText,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: ForestAnalyticsPalette.mutedSageText,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 14),
          Row(
            children: < Widget >[
              Expanded(
                child: _HeroSubMetric(
                  label: 'DAILY LIMIT',
                  value: hasDailyLimit
                      ? IdrFormatter.format(snapshot.dailyLimit)
                      : 'Belum diatur',
                  valueColor: ForestAnalyticsPalette.sageAccent,
                ),
              ),
              Container(
                width: 1,
                height: 26,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _HeroSubMetric(
                  label:
                      isSingleDay ? 'PORSI LIMIT HARI INI' : 'RATA-RATA / HARI',
                  value: isSingleDay && hasDailyLimit
                      ? (snapshot.limitUsagePercentage.toStringAsFixed(1) +
                          '% terpakai')
                      : IdrFormatter.format(snapshot.averageDailySpent),
                  valueColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroSubMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _HeroSubMetric({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: < Widget >[
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: ForestAnalyticsPalette.mutedSageText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

/// Baris Filter Pil yang menyalin persis komponen filter pada halaman pertama.
class _DashboardStyleFilterRow extends StatelessWidget {
  final AnalyticsFilterPeriod selectedPeriod;
  final DateTime? customDate;
  final ValueChanged< AnalyticsFilterPeriod > onPeriodSelected;
  final VoidCallback onCalendarTap;

  const _DashboardStyleFilterRow({
    required this.selectedPeriod,
    required this.customDate,
    required this.onPeriodSelected,
    required this.onCalendarTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCustomActive =
        selectedPeriod == AnalyticsFilterPeriod.customDate;

    const List< AnalyticsFilterPeriod > standardPeriods =
        < AnalyticsFilterPeriod >[
      AnalyticsFilterPeriod.today,
      AnalyticsFilterPeriod.thisMonth,
      AnalyticsFilterPeriod.sixMonths,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: < Widget >[
          GestureDetector(
            onTap: onCalendarTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isCustomActive
                    ? ForestAnalyticsPalette.deepForest
                    : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: isCustomActive
                    ? Colors.white
                    : ForestAnalyticsPalette.deepForest,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ...standardPeriods.map((AnalyticsFilterPeriod period) {
            final bool isSelected = selectedPeriod == period;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => onPeriodSelected(period),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ForestAnalyticsPalette.deepForest
                        : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    period.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : ForestAnalyticsPalette.deepForest,
                    ),
                  ),
                ),
              ),
            );
          }),
          if (isCustomActive && customDate != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: ForestAnalyticsPalette.deepForest,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                customDate!.day.toString() +
                    '/' +
                    customDate!.month.toString() +
                    '/' +
                    customDate!.year.toString(),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kartu Putih Pembungkus Donut Chart + Switcher Mode (Per Item / Kategori).
class _DonutAllocationCard extends StatelessWidget {
  final List< AllocationSlice > slices;
  final double totalSpent;
  final BreakdownGroupMode groupMode;
  final String? selectedSliceId;
  final ValueChanged< BreakdownGroupMode > onGroupModeChanged;
  final ValueChanged< String? > onSliceSelected;

  const _DonutAllocationCard({
    required this.slices,
    required this.totalSpent,
    required this.groupMode,
    required this.selectedSliceId,
    required this.onGroupModeChanged,
    required this.onSliceSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: < BoxShadow >[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: < Widget >[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: < Widget >[
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: < Widget >[
                  Text(
                    'Distribusi Pengeluaran',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: ForestAnalyticsPalette.deepForest,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Sentuh segmen untuk fokus analisis',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: ForestAnalyticsPalette.bodyGreyText,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: ForestAnalyticsPalette.scaffoldMint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children:
                      BreakdownGroupMode.values.map((BreakdownGroupMode mode) {
                    final bool active = mode == groupMode;
                    return GestureDetector(
                      onTap: () => onGroupModeChanged(mode),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? ForestAnalyticsPalette.deepForest
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          mode.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: active
                                ? Colors.white
                                : ForestAnalyticsPalette.deepForest,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          InteractiveDonutChart(
            slices: slices,
            totalSpent: totalSpent,
            selectedSliceId: selectedSliceId,
            onSliceSelected: onSliceSelected,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Kartu Item Rincian yang mengadopsi 100% proporsi visual TransactionCard.
class _TransactionStyleBreakdownCard extends StatelessWidget {
  final AllocationSlice slice;
  final double sharePercentage;
  final bool isSelected;
  final bool isDimmed;
  final VoidCallback onTap;

  const _TransactionStyleBreakdownCard({
    required this.slice,
    required this.sharePercentage,
    required this.isSelected,
    required this.isDimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isDimmed ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? ForestAnalyticsPalette.deepForest
                  : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: < BoxShadow >[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: < Widget >[
              Row(
                children: < Widget >[
                  Stack(
                    clipBehavior: Clip.none,
                    children: < Widget >[
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: ForestAnalyticsPalette.iconBoxMint,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          slice.icon,
                          size: 22,
                          color: ForestAnalyticsPalette.deepForest,
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            color: slice.color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
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
                            color: ForestAnalyticsPalette.deepForest,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          slice.totalQuantity.toString() +
                              'x Rp ' +
                              IdrFormatter.numberOnly(slice.averageUnitPrice),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: ForestAnalyticsPalette.bodyGreyText,
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
                          color: ForestAnalyticsPalette.deepForest,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sharePercentage.toStringAsFixed(1) +
                            '% • ' +
                            IdrFormatter.shortDateTime(slice.latestDate),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: ForestAnalyticsPalette.bodyGreyText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: (sharePercentage / 100).clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: ForestAnalyticsPalette.scaffoldMint,
                  valueColor: AlwaysStoppedAnimation< Color >(slice.color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendBenchmarkSectionCard extends StatelessWidget {
  final DynamicAnalyticsSnapshot snapshot;

  const _TrendBenchmarkSectionCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    String title;
    String subtitle;
    String benchmarkLabel;

    switch (snapshot.period) {
      case AnalyticsFilterPeriod.today:
      case AnalyticsFilterPeriod.customDate:
        title = 'Ritme 7 Hari vs Daily Limit';
        subtitle = 'Perbandingan pengeluaran harian terhadap batas aman';
        benchmarkLabel = 'Daily Limit';
        break;
      case AnalyticsFilterPeriod.thisMonth:
        title = 'Tren Mingguan Bulan Ini';
        subtitle = 'Perbandingan pengeluaran per minggu di bulan berjalan';
        benchmarkLabel = 'Batas Aman';
        break;
      case AnalyticsFilterPeriod.sixMonths:
        title = 'Tren 6 Bulan Terakhir';
        subtitle = 'Perbandingan total pengeluaran lintas bulan';
        benchmarkLabel = 'Budget Bulanan';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: < BoxShadow >[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: < Widget >[
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: ForestAnalyticsPalette.deepForest,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: ForestAnalyticsPalette.bodyGreyText,
            ),
          ),
          const SizedBox(height: 16),
          SpendingBenchmarkChart(
            points: snapshot.trendPoints,
            benchmarkLabel: benchmarkLabel,
          ),
        ],
      ),
    );
  }
}

/// Kartu Komparasi Langsung (Periode Ini vs Periode Sebelumnya).
class _PeriodComparisonCard extends StatelessWidget {
  final DynamicAnalyticsSnapshot snapshot;

  const _PeriodComparisonCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final double diffAmount =
        snapshot.totalSpent - snapshot.previousPeriodSpent;
    final bool isMoreFrugal = diffAmount <= 0;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: < Widget >[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: < Widget >[
              const Text(
                'Komparasi Periode',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: ForestAnalyticsPalette.deepForest,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: ForestAnalyticsPalette.iconBoxMint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  snapshot.period.label +
                      ' ' +
                      snapshot.period.comparisonSuffix,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ForestAnalyticsPalette.deepForest,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: < Widget >[
              Expanded(
                child: _ComparisonBox(
                  label: 'Periode Ini',
                  amount: snapshot.totalSpent,
                  subLabel:
                      snapshot.totalItemsQuantity.toString() + ' item tercatat',
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ComparisonBox(
                  label: 'Periode Lalu',
                  amount: snapshot.previousPeriodSpent,
                  subLabel: snapshot.previousItemsQuantity.toString() +
                      ' item tercatat',
                  isPrimary: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: ForestAnalyticsPalette.scaffoldMint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: < Widget >[
                Icon(
                  isMoreFrugal
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  size: 18,
                  color: ForestAnalyticsPalette.deepForest,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    snapshot.previousPeriodSpent <= 0
                        ? 'Belum ada catatan pengeluaran pada periode pembanding sebelumnya.'
                        : (isMoreFrugal
                            ? ('Pengeluaran lebih hemat ' +
                                IdrFormatter.format(diffAmount.abs()) +
                                ' dibanding periode lalu.')
                            : ('Pengeluaran bertambah ' +
                                IdrFormatter.format(diffAmount.abs()) +
                                ' dibanding periode lalu.')),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ForestAnalyticsPalette.deepForest,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonBox extends StatelessWidget {
  final String label;
  final double amount;
  final String subLabel;
  final bool isPrimary;

  const _ComparisonBox({
    required this.label,
    required this.amount,
    required this.subLabel,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPrimary
            ? ForestAnalyticsPalette.deepForest
            : ForestAnalyticsPalette.iconBoxMint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: < Widget >[
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isPrimary
                  ? ForestAnalyticsPalette.mutedSageText
                  : ForestAnalyticsPalette.bodyGreyText,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              IdrFormatter.format(amount),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isPrimary
                    ? Colors.white
                    : ForestAnalyticsPalette.deepForest,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isPrimary
                  ? ForestAnalyticsPalette.sageAccent
                  : ForestAnalyticsPalette.bodyGreyText,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTransactionsStateCard extends StatelessWidget {
  const _EmptyTransactionsStateCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        children: < Widget >[
          Icon(
            Icons.receipt_long_outlined,
            size: 32,
            color: ForestAnalyticsPalette.bodyGreyText,
          ),
          SizedBox(height: 10),
          Text(
            'Belum ada transaksi pada periode ini',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ForestAnalyticsPalette.deepForest,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Catat transaksi melalui tombol + atau ganti filter periode di atas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: ForestAnalyticsPalette.bodyGreyText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating Bottom Bar yang menyalin 1:1 kapsul navigasi bawah pada halaman pertama.
class _FloatingForestBottomBar extends StatelessWidget {
  final VoidCallback onHomeTap;
  final VoidCallback onAddTap;

  const _FloatingForestBottomBar({
    required this.onHomeTap,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: ForestAnalyticsPalette.deepForest,
        borderRadius: BorderRadius.circular(40),
        boxShadow: < BoxShadow >[
          BoxShadow(
            color: ForestAnalyticsPalette.deepForest.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: < Widget >[
          IconButton(
            icon: const Icon(
              Icons.home_filled,
              size: 26,
              color: ForestAnalyticsPalette.mutedSageText,
            ),
            onPressed: onHomeTap,
          ),
          GestureDetector(
            onTap: onAddTap,
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 28,
                color: ForestAnalyticsPalette.deepForest,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.pie_chart_rounded,
              size: 26,
              color: Colors.white,
            ),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}