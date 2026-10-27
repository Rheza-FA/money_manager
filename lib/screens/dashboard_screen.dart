import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/expense.dart';
import '../theme/app_colors.dart';
import '../widgets/balance_overview_circle.dart';
import '../widgets/daily_limit_card.dart';
import '../widgets/transaction_card.dart';
import '../providers/database_provider.dart';
import '../providers/calculator_provider.dart';
import '../providers/history_provider.dart';
import '../widgets/input_bottom_sheet.dart';
import '../features/analytics/screens/analytics_screen.dart';
import '../features/receipt_share/models/shared_receipt.dart';
import '../features/receipt_share/services/receipt_share_service.dart';
import '../features/receipt_share/widgets/shared_receipt_sheet.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isShareSheetOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(receiptShareProvider.notifier).attachWhenReady();
    });
  }

  void _presentSharedReceiptSheet() {
    if (_isShareSheetOpen || !mounted) return;
    final BuildContext modalContext =
        appNavigatorKey.currentContext ?? context;
    _isShareSheetOpen = true;
    HapticFeedback.lightImpact();

    showModalBottomSheet<void>(
      context: modalContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SharedReceiptSheet(),
    ).whenComplete(() {
      _isShareSheetOpen = false;
      if (mounted) {
        ref.read(receiptShareProvider.notifier).clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ReceiptShareState>(
      receiptShareProvider,
      (ReceiptShareState? previous, ReceiptShareState next) {
        final int prevSession = previous?.sessionId ?? 0;
        if (next.isActive && next.sessionId != prevSession) {
          _presentSharedReceiptSheet();
        }
      },
    );
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final AsyncValue<dynamic> balanceAsync =
        ref.watch(currentMonthBalanceProvider);
    final double liveBalance = ref.watch(liveBalanceProvider);
    final double maxDailySpending = ref.watch(maxDailySpendingProvider);

    final TimeFilter activeFilter = ref.watch(timeFilterProvider);
    final List<Expense> filteredExpenses = ref.watch(filteredExpensesProvider);
    final double totalExpense = ref.watch(filteredTotalExpenseProvider);
    final double totalIncome = ref.watch(filteredTotalIncomeProvider);

    final NumberFormat formatCurrency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundTop,
      body: Stack(
        children: <Widget>[
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
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: balanceAsync.when(
                    data: (_) => BalanceOverviewCircle(
                      balance: liveBalance,
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
                          'Error: $e',
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
                      children: <Widget>[
                        Text(
                          l10n.transactions,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: _buildCashflowSummary(
                            formatCurrency: formatCurrency,
                            totalExpense: totalExpense,
                            totalIncome: totalIncome,
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
                children: <Widget>[
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
                        showModalBottomSheet<void>(
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
                    tooltip: 'Analytics',
                    icon: const Icon(
                      Icons.pie_chart_rounded,
                      color: AppColors.greyText,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
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

  Widget _buildCashflowSummary({
    required NumberFormat formatCurrency,
    required double totalExpense,
    required double totalIncome,
  }) {
    if (totalIncome <= 0) {
      return Text(
        '- ${formatCurrency.format(totalExpense)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.greyText,
        ),
      );
    }

    if (totalExpense <= 0) {
      return Text(
        '+ ${formatCurrency.format(totalIncome)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.incomeEmerald,
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: RichText(
        text: TextSpan(
          children: <TextSpan>[
            TextSpan(
              text: '+ ${formatCurrency.format(totalIncome)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.incomeEmerald,
              ),
            ),
            const TextSpan(
              text: '  •  ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.greyText,
              ),
            ),
            TextSpan(
              text: '- ${formatCurrency.format(totalExpense)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.greyText,
              ),
            ),
          ],
        ),
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
                children: <Widget>[
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
