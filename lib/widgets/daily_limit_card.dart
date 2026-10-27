import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
// [INJEKSI LOKALISASI]
import '../l10n/app_localizations.dart';

import '../providers/calculator_provider.dart';
import '../providers/database_provider.dart';
import '../theme/app_colors.dart';

class DailyLimitCard extends ConsumerStatefulWidget {
  final double maxDaily;

  const DailyLimitCard({super.key, required this.maxDaily});

  @override
  ConsumerState<DailyLimitCard> createState() => _DailyLimitCardState();
}

class _DailyLimitCardState extends ConsumerState<DailyLimitCard>
    with SingleTickerProviderStateMixin {
  static const Color _overLimitCoral = Color(0xFFE07A5F);

  late final AnimationController _shimmerController;
  late final NumberFormat _numberOnlyFormat;
  late final NumberFormat _currencyFormat;
  ScrollPosition? _scrollPosition;

  @override
  void initState() {
    super.initState();
    _numberOnlyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );
    _currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final position = Scrollable.maybeOf(context)?.position;
      if (_scrollPosition != position) {
        setState(() {
          _scrollPosition = position;
        });
      }
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  bool _isZeroExpenseToday() {
    final expensesAsync = ref.watch(expenseListProvider);
    if (!expensesAsync.hasValue) return true;

    final expenses = expensesAsync.value!;
    if (expenses.isEmpty) return true;

    final now = DateTime.now();
    final hasExpenseToday = expenses.any((e) =>
        !e.isIncome &&
        e.date.year == now.year &&
        e.date.month == now.month &&
        e.date.day == now.day);

    return !hasExpenseToday;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final formattedAmount = _numberOnlyFormat.format(widget.maxDaily);
    final isBiWeekly =
        ref.watch(appSettingsProvider).value?.isBiWeeklyMode ?? false;
    final double todaySpent = ref.watch(todaySpendingProvider);
    final isZero = _isZeroExpenseToday();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedBuilder(
        animation: _scrollPosition ?? const AlwaysStoppedAnimation(0.0),
        builder: (context, child) {
          final offset = _scrollPosition?.pixels ?? 0.0;
          final translateY = (offset * 0.10).clamp(-15.0, 15.0);

          return Transform.translate(
            offset: Offset(0, translateY),
            child: child,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.12),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Stack(
              children: [
                _buildCardContent(
                  formattedAmount: formattedAmount,
                  isBiWeekly: isBiWeekly,
                  todaySpent: todaySpent,
                  l10n: l10n,
                ),
                if (isZero)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, child) {
                          final progress = _shimmerController.value;
                          if (progress > 0.25) return const SizedBox.shrink();

                          final sweepPos = (progress / 0.25);
                          final alignVal = -2.0 + (sweepPos * 4.0);

                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  AppColors.white.withValues(alpha: 0.15),
                                  Colors.transparent,
                                ],
                                stops: const [0.3, 0.5, 0.7],
                                begin:
                                    Alignment(alignVal - 1.0, alignVal - 1.0),
                                end: Alignment(alignVal + 1.0, alignVal + 1.0),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent({
    required String formattedAmount,
    required bool isBiWeekly,
    required double todaySpent,
    required AppLocalizations l10n,
  }) {
    final bool showIntradayPacing = widget.maxDaily > 0 && todaySpent > 0;
    final bool isOver = showIntradayPacing && todaySpent > widget.maxDaily;
    final double remaining = widget.maxDaily - todaySpent;
    final double progressRatio = showIntradayPacing
        ? (todaySpent / widget.maxDaily).clamp(0.03, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(28),
      color: AppColors.primaryDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.monetization_on_rounded,
                    color: AppColors.accentGreen,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.dailyLimit,
                    style: TextStyle(
                      color: AppColors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref
                      .read(databaseServiceProvider)
                      .toggleSpendingMode(!isBiWeekly);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.white.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isBiWeekly
                            ? Icons.view_week_rounded
                            : Icons.calendar_today_rounded,
                        color: AppColors.white.withValues(alpha: 0.9),
                        size: 12,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isBiWeekly ? l10n.fourteenDays : l10n.fullMonth,
                        style: TextStyle(
                          color: AppColors.white.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          RichText(
            text: TextSpan(
              style: const TextStyle(),
              children: [
                TextSpan(
                  text: 'Rp ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white.withValues(alpha: 0.7),
                  ),
                ),
                TextSpan(
                  text: formattedAmount,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                    letterSpacing: -1.0,
                    height: 1.1,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            isBiWeekly ? l10n.safeBudgetBiWeekly : l10n.safeBudgetMonthly,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.white.withValues(alpha: 0.7),
            ),
          ),
          if (showIntradayPacing) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: Container(
                height: 4,
                width: double.infinity,
                color: AppColors.white.withValues(alpha: 0.12),
                alignment: Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: progressRatio),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return FractionallySizedBox(
                      widthFactor: value,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: isOver
                              ? _overLimitCoral
                              : AppColors.accentGreen,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.dailySpentToday(_currencyFormat.format(todaySpent)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.white.withValues(alpha: 0.68),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isOver
                          ? l10n.dailyOverToday(
                              _currencyFormat.format(remaining.abs()),
                            )
                          : l10n.dailyLeftToday(
                              _currencyFormat.format(remaining),
                            ),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isOver ? _overLimitCoral : AppColors.accentGreen,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
