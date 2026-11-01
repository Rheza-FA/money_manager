import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/expense.dart';
import '../services/app_haptics.dart';
import '../theme/app_colors.dart';
import '../widgets/balance_overview_circle.dart';
import '../widgets/daily_limit_card.dart';
import '../widgets/tactile_press.dart';
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
  static const Cubic _kNavigationCurve = Cubic(0.22, 1.0, 0.36, 1.0);

  late final PageController _pageController = PageController();
  int _activePageIndex = 0;
  bool _isProgrammaticNavigation = false;
  int _navigationTicket = 0;
  bool _isShareSheetOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(receiptShareProvider.notifier).attachWhenReady();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _presentSharedReceiptSheet() {
    if (_isShareSheetOpen || !mounted) return;
    final BuildContext modalContext =
        appNavigatorKey.currentContext ?? context;
    _isShareSheetOpen = true;
    AppHaptics.primaryClick();

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

  void _openAddExpenseSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => const InputBottomSheet(),
    );
  }

  void _navigateToPage(int targetIndex, {bool playHaptic = false}) {
    if (!_pageController.hasClients) return;

    final double currentPage = _pageController.position.hasContentDimensions
        ? (_pageController.page ?? _activePageIndex.toDouble())
        : _activePageIndex.toDouble();
    final double distance = (targetIndex - currentPage).abs();
    if (distance < 0.001 && _activePageIndex == targetIndex) return;

    if (playHaptic) {
      AppHaptics.softDetent();
    }
    FocusManager.instance.primaryFocus?.unfocus();

    final int durationMs = (220 + (200 * distance.clamp(0.0, 1.0))).round();
    final int ticket = ++_navigationTicket;
    _isProgrammaticNavigation = true;

    if (_activePageIndex != targetIndex) {
      setState(() {
        _activePageIndex = targetIndex;
      });
    }

    _pageController
        .animateToPage(
          targetIndex,
          duration: Duration(milliseconds: durationMs),
          curve: _kNavigationCurve,
        )
        .whenComplete(() {
          if (mounted && _navigationTicket == ticket) {
            _isProgrammaticNavigation = false;
          }
        });
  }

  void _handlePageChanged(int index) {
    if (!_isProgrammaticNavigation && _activePageIndex != index) {
      AppHaptics.softDetent();
      FocusManager.instance.primaryFocus?.unfocus();
    }
    if (_activePageIndex != index) {
      setState(() {
        _activePageIndex = index;
      });
    }
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

    return PopScope(
      canPop: _activePageIndex == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && _activePageIndex != 0) {
          _navigateToPage(0, playHaptic: true);
        }
      },
      child: Scaffold(
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
            ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                overscroll: false,
              ),
              child: PageView(
                controller: _pageController,
                physics: const _LuxuryPageScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                onPageChanged: _handlePageChanged,
                children: <Widget>[
                  _WorkspacePageStage(
                    controller: _pageController,
                    index: 0,
                    child: const _DashboardViewport(),
                  ),
                  _WorkspacePageStage(
                    controller: _pageController,
                    index: 1,
                    child: const AnalyticsScreen(embedded: true),
                  ),
                ],
              ),
            ),
            _BottomNavigationPill(
              controller: _pageController,
              activeIndex: _activePageIndex,
              onSelectPage: _navigateToPage,
              onAddPressed: _openAddExpenseSheet,
            ),
          ],
        ),
      ),
    );
  }
}

class _LuxuryPageScrollPhysics extends PageScrollPhysics {
  const _LuxuryPageScrollPhysics({super.parent});

  static const SpringDescription _criticalSpring = SpringDescription(
    mass: 1.0,
    stiffness: 320.0,
    damping: 36.0,
  );

  @override
  _LuxuryPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _LuxuryPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => _criticalSpring;
}

class _WorkspacePageStage extends StatelessWidget {
  final PageController controller;
  final int index;
  final Widget child;

  const _WorkspacePageStage({
    required this.controller,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: controller,
        child: RepaintBoundary(child: child),
        builder: (BuildContext context, Widget? cachedChild) {
          double page = index.toDouble();
          if (controller.hasClients &&
              controller.position.hasContentDimensions) {
            page = controller.page ?? index.toDouble();
          }

          final double rawDelta = page - index;
          final bool isOuterBounce =
              (index == 0 && rawDelta < 0.0) || (index == 1 && rawDelta > 0.0);

          if (isOuterBounce || rawDelta.abs() < 0.0005) {
            return Transform.scale(
              scale: 1.0,
              alignment: Alignment.center,
              child: Opacity(
                opacity: 1.0,
                child: cachedChild,
              ),
            );
          }

          final double t = rawDelta.abs().clamp(0.0, 1.0);
          final double eased = Curves.easeOutQuad.transform(t);
          final double scale = 1.0 - (0.032 * eased);
          final double opacity = (1.0 - (0.36 * eased)).clamp(0.0, 1.0);

          return Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: Opacity(
              opacity: opacity,
              child: cachedChild,
            ),
          );
        },
      ),
    );
  }
}

class _BottomNavigationPill extends StatelessWidget {
  final PageController controller;
  final int activeIndex;
  final ValueChanged<int> onSelectPage;
  final VoidCallback onAddPressed;

  const _BottomNavigationPill({
    required this.controller,
    required this.activeIndex,
    required this.onSelectPage,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: RepaintBoundary(
        child: Container(
          height: 72,
          margin: const EdgeInsets.only(bottom: 24, left: 32, right: 32),
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(40),
            boxShadow: AppColors.softShadow,
          ),
          child: AnimatedBuilder(
            animation: controller,
            child: TactilePress(
              child: Container(
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
                  onPressed: onAddPressed,
                ),
              ),
            ),
            builder: (BuildContext context, Widget? addButton) {
              double progress = activeIndex.toDouble();
              if (controller.hasClients &&
                  controller.position.hasContentDimensions) {
                progress =
                    (controller.page ?? activeIndex.toDouble()).clamp(0.0, 1.0);
              }

              final Color homeColor =
                  Color.lerp(AppColors.white, AppColors.greyText, progress)!;
              final Color analyticsColor =
                  Color.lerp(AppColors.greyText, AppColors.white, progress)!;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  TactilePress(
                    child: IconButton(
                      icon: Icon(
                        Icons.home_filled,
                        color: homeColor,
                      ),
                      onPressed: () => onSelectPage(0),
                    ),
                  ),
                  addButton!,
                  TactilePress(
                    child: IconButton(
                      tooltip: 'Analytics',
                      icon: Icon(
                        Icons.pie_chart_rounded,
                        color: analyticsColor,
                      ),
                      onPressed: () => onSelectPage(1),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DashboardViewport extends ConsumerStatefulWidget {
  const _DashboardViewport();

  @override
  ConsumerState<_DashboardViewport> createState() => _DashboardViewportState();
}

class _DashboardViewportState extends ConsumerState<_DashboardViewport>
    with AutomaticKeepAliveClientMixin {
  late final NumberFormat _formatCurrency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final AsyncValue<dynamic> balanceAsync =
        ref.watch(currentMonthBalanceProvider);
    final double liveBalance = ref.watch(liveBalanceProvider);
    final double maxDailySpending = ref.watch(maxDailySpendingProvider);

    final TimeFilter activeFilter = ref.watch(timeFilterProvider);
    final List<Expense> filteredExpenses = ref.watch(filteredExpensesProvider);
    final double totalExpense = ref.watch(filteredTotalExpenseProvider);
    final double totalIncome = ref.watch(filteredTotalIncomeProvider);

    return SafeArea(
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
                      formatCurrency: _formatCurrency,
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
                  TactileTap(
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
    return TactileTap(
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
