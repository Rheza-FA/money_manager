import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/expense.dart';
import '../providers/database_provider.dart';
import '../services/app_haptics.dart';
import '../theme/app_colors.dart';
import 'input_bottom_sheet.dart';
import 'tactile_press.dart';

class TransactionCard extends ConsumerStatefulWidget {
  final Expense expense;

  const TransactionCard({super.key, required this.expense});

  @override
  ConsumerState<TransactionCard> createState() => _TransactionCardState();
}

class _TransactionCardState extends ConsumerState<TransactionCard> {
  static const double _kDismissThreshold = 0.4;

  final ValueNotifier<double> _swipeProgressNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> _isArmedNotifier = ValueNotifier<bool>(false);

  late final NumberFormat _formatCurrency;
  late final NumberFormat _formatPrice;
  late final DateFormat _formatTime;

  @override
  void initState() {
    super.initState();

    _formatCurrency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    _formatPrice = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );
    _formatTime = DateFormat('dd MMM, HH:mm');
  }

  @override
  void dispose() {
    _swipeProgressNotifier.dispose();
    _isArmedNotifier.dispose();
    super.dispose();
  }

  void _handleDismissUpdate(DismissUpdateDetails details) {
    _swipeProgressNotifier.value = details.progress;

    if (details.reached && !_isArmedNotifier.value) {
      _isArmedNotifier.value = true;
      AppHaptics.destructive();
    } else if (!details.reached && _isArmedNotifier.value) {
      _isArmedNotifier.value = false;
      AppHaptics.softDetent();
    }
  }

  void _handleDismissed(DismissDirection direction) {
    AppHaptics.destructive();
    ref.read(databaseServiceProvider).deleteExpense(widget.expense.id);
  }

  void _onTap() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InputBottomSheet(expenseToEdit: widget.expense),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool isIncome = widget.expense.isIncome;
    final String subtitleText = isIncome
        ? (widget.expense.quantity > 1
            ? '${l10n.transactionIncomeSubtitle} • ${widget.expense.quantity}x Rp ${_formatPrice.format(widget.expense.price)}'
            : l10n.transactionIncomeSubtitle)
        : '${widget.expense.quantity}x Rp ${_formatPrice.format(widget.expense.price)}';
    final String amountText = isIncome
        ? '+ ${_formatCurrency.format(widget.expense.totalAmount)}'
        : _formatCurrency.format(widget.expense.totalAmount);

    return Dismissible(
      key: Key(widget.expense.id.toString()),
      direction: DismissDirection.endToStart,
      dismissThresholds: const <DismissDirection, double>{
        DismissDirection.endToStart: _kDismissThreshold,
      },
      movementDuration: const Duration(milliseconds: 240),
      resizeDuration: const Duration(milliseconds: 240),
      onUpdate: _handleDismissUpdate,
      onDismissed: _handleDismissed,
      background: _SwipeDeleteCapsule(
        progressNotifier: _swipeProgressNotifier,
        isArmedNotifier: _isArmedNotifier,
      ),
      child: TactileTap(
        pressedScale: 0.97,
        onTap: _onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.05),
                blurRadius: 10.0,
                spreadRadius: 0,
                offset: const Offset(0, 4.0),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isIncome
                      ? AppColors.accentGreen.withValues(alpha: 0.20)
                      : AppColors.backgroundTop,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isIncome
                      ? Icons.south_west_rounded
                      : Icons.receipt_long_rounded,
                  color: AppColors.primaryDark,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.expense.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitleText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isIncome ? FontWeight.w600 : FontWeight.w500,
                        color: isIncome
                            ? AppColors.incomeEmerald
                            : AppColors.greyText,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amountText,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isIncome
                          ? AppColors.incomeEmerald
                          : AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime.format(widget.expense.date),
                    style: const TextStyle(
                      fontSize: 11,
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

/// Floating rounded destructive action capsule that expands organically in the
/// space revealed behind [TransactionCard], separated by a clean 12px breathing
/// gap so the card's rounded corners never collide with a flat clipped edge.
class _SwipeDeleteCapsule extends StatelessWidget {
  static const double _kCardRadius = 24.0;
  static const double _kBreathingGap = 12.0;

  final ValueNotifier<double> progressNotifier;
  final ValueNotifier<bool> isArmedNotifier;

  const _SwipeDeleteCapsule({
    required this.progressNotifier,
    required this.isArmedNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double maxWidth = constraints.maxWidth;

            return ValueListenableBuilder<double>(
              valueListenable: progressNotifier,
              builder: (BuildContext context, double progress, _) {
                if (progress <= 0.001 || maxWidth <= 0) {
                  return const SizedBox.shrink();
                }

                final double revealedWidth = maxWidth * progress;
                final double closeT =
                    ((progress - 0.76) / 0.24).clamp(0.0, 1.0);
                final double gap =
                    _kBreathingGap * (1.0 - Curves.easeInOut.transform(closeT));

                final double capsuleWidth =
                    (revealedWidth - gap).clamp(0.0, maxWidth);
                if (capsuleWidth < 4.0) {
                  return const SizedBox.shrink();
                }

                final double enterOpacity =
                    ((capsuleWidth - 4.0) / 28.0).clamp(0.0, 1.0);
                final double exitT =
                    ((progress - 0.88) / 0.12).clamp(0.0, 1.0);
                final double exitOpacity =
                    1.0 - Curves.easeInQuad.transform(exitT);
                final double capsuleOpacity =
                    (enterOpacity * exitOpacity).clamp(0.0, 1.0);

                if (capsuleOpacity <= 0.001) {
                  return const SizedBox.shrink();
                }

                final double iconReveal = Curves.easeOutCubic.transform(
                  ((capsuleWidth - 24.0) / 28.0).clamp(0.0, 1.0),
                );
                final double iconBaseScale = 0.72 + (0.28 * iconReveal);
                final double iconZoneWidth = capsuleWidth <= 72.0
                    ? capsuleWidth
                    : (72.0 + ((capsuleWidth - 72.0) * 0.18))
                        .clamp(72.0, maxWidth);

                return Align(
                  alignment: Alignment.centerRight,
                  child: Opacity(
                    opacity: capsuleOpacity,
                    child: SizedBox(
                      width: capsuleWidth,
                      height: double.infinity,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: isArmedNotifier,
                        builder: (BuildContext context, bool isArmed, _) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: isArmed
                                  ? AppColors.dangerCrimson
                                  : AppColors.dangerSurface,
                              borderRadius: BorderRadius.circular(_kCardRadius),
                              border: Border.all(
                                color: isArmed
                                    ? AppColors.dangerCrimson
                                    : AppColors.dangerBorder,
                                width: 1.5,
                              ),
                              boxShadow: isArmed
                                  ? <BoxShadow>[
                                      BoxShadow(
                                        color: AppColors.dangerCrimson
                                            .withValues(alpha: 0.18),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              width: iconZoneWidth,
                              child: Center(
                                child: OverflowBox(
                                  minWidth: 0,
                                  maxWidth: 32,
                                  minHeight: 0,
                                  maxHeight: 32,
                                  child: Opacity(
                                    opacity: iconReveal,
                                    child: Transform.scale(
                                      scale: iconBaseScale,
                                      child: AnimatedScale(
                                        scale: isArmed ? 1.15 : 1.0,
                                        duration:
                                            const Duration(milliseconds: 220),
                                        curve: isArmed
                                            ? Curves.easeOutBack
                                            : Curves.easeOutCubic,
                                        child: AnimatedSwitcher(
                                          duration:
                                              const Duration(milliseconds: 160),
                                          child: Icon(
                                            isArmed
                                                ? Icons.delete_rounded
                                                : Icons.delete_outline_rounded,
                                            key: ValueKey<bool>(isArmed),
                                            color: isArmed
                                                ? AppColors.white
                                                : AppColors.dangerCrimson,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
