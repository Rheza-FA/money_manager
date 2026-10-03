import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
// [INJEKSI LOKALISASI]
import '../l10n/app_localizations.dart';

import '../theme/app_colors.dart';
import '../providers/database_provider.dart';

class DailyLimitCard extends ConsumerStatefulWidget {
  final double maxDaily;

  const DailyLimitCard({super.key, required this.maxDaily});

  @override
  ConsumerState<DailyLimitCard> createState() => _DailyLimitCardState();
}

class _DailyLimitCardState extends ConsumerState<DailyLimitCard> with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;
  ScrollPosition? _scrollPosition;

  @override
  void initState() {
    super.initState();
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
        e.date.year == now.year &&
        e.date.month == now.month &&
        e.date.day == now.day);

    return !hasExpenseToday;
  }

  @override
  Widget build(BuildContext context) {
    // [BEST PRACTICE: Cache kamus]
    final l10n = AppLocalizations.of(context)!;
    
    final formattedAmount = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(widget.maxDaily);
    final isBiWeekly = ref.watch(appSettingsProvider).value?.isBiWeeklyMode ?? false;
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
                // Pass parameter l10n ke dalam fungsi build konten
                _buildCardContent(formattedAmount, isBiWeekly, l10n),

                if (isZero)
                  Positioned.fill(
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
                              begin: Alignment(alignVal - 1.0, alignVal - 1.0),
                              end: Alignment(alignVal + 1.0, alignVal + 1.0),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(String formattedAmount, bool isBiWeekly, AppLocalizations l10n) {
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
                  const Icon(Icons.monetization_on_rounded, color: AppColors.accentGreen, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    l10n.dailyLimit, // [INJEKSI LOKALISASI]
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
                  ref.read(databaseServiceProvider).toggleSpendingMode(!isBiWeekly);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                        isBiWeekly ? Icons.view_week_rounded : Icons.calendar_today_rounded,
                        color: AppColors.white.withValues(alpha: 0.9),
                        size: 12,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isBiWeekly ? l10n.fourteenDays : l10n.fullMonth, // [INJEKSI LOKALISASI]
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
                  text: "Rp ",
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
            isBiWeekly ? l10n.safeBudgetBiWeekly : l10n.safeBudgetMonthly, // [INJEKSI LOKALISASI]
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.white.withValues(alpha: 0.7), 
            ),
          ),
        ],
      ),
    );
  }
}