import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/expense.dart';
import 'database_provider.dart';

/// Pure budgeting rules, kept free of Riverpod/Isar so they are unit-testable.
///
/// **Daily limit semantics — a locked daily allowance.**
/// Today's limit is the budget still available at the start of today, spread
/// evenly over the remaining days of the active cycle:
///
/// ```
/// available = opening balance + income − spending
///             (month start ≤ date < today 00:00, recorded before today)
/// limit     = max(0, available) / remaining days in cycle (incl. today)
/// ```
///
/// Anything recorded *today* — today's purchases, incoming money, or a past
/// receipt imported today — never moves today's figure. It is folded in at the
/// next day's recalculation, so under-spending rolls forward as a higher limit
/// and over-spending as a lower one. Live progress within the day is surfaced
/// separately via [spentOn].
abstract final class BudgetMath {
  static DateTime _startOfDay(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Records saved before this field existed were always saved at their [date].
  static DateTime _recordedAt(Expense e) => e.recordedAt ?? e.date;

  static int _remainingDaysInCycle(
    DateTime now, {
    required bool isBiWeekly,
  }) {
    final int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    if (isBiWeekly && now.day <= 14) {
      // Cycle 1: Day 1 through Day 14
      return 15 - now.day;
    }
    // Cycle 2 (Day 15..end of month) or Full Month mode (Day 1..end of month)
    return daysInMonth - now.day + 1;
  }

  static double dailyLimit({
    required Iterable<Expense> records,
    required double openingBalance,
    required bool isBiWeekly,
    required DateTime now,
  }) {
    final DateTime monthStart = DateTime(now.year, now.month, 1);
    final DateTime todayStart = _startOfDay(now);
    final int remainingDays = _remainingDaysInCycle(now, isBiWeekly: isBiWeekly);
    if (remainingDays <= 0) return 0.0;

    double available = openingBalance;
    for (final Expense e in records) {
      final bool settledBeforeToday = !e.date.isBefore(monthStart) &&
          e.date.isBefore(todayStart) &&
          _recordedAt(e).isBefore(todayStart);
      if (!settledBeforeToday) continue;
      available += e.isIncome ? e.totalAmount : -e.totalAmount;
    }

    if (available <= 0) return 0.0;
    return available / remainingDays;
  }

  /// Total spending (income excluded) dated on the calendar day of [day].
  static double spentOn(Iterable<Expense> records, DateTime day) {
    final DateTime start = _startOfDay(day);
    final DateTime end = DateTime(start.year, start.month, start.day + 1);
    double total = 0.0;
    for (final Expense e in records) {
      if (!e.isIncome && !e.date.isBefore(start) && e.date.isBefore(end)) {
        total += e.totalAmount;
      }
    }
    return total;
  }

  /// Net signed cashflow (`+income - spending`) for the calendar month of [now].
  static double monthNetDelta(Iterable<Expense> records, DateTime now) {
    double delta = 0.0;
    for (final Expense e in records) {
      if (e.date.year != now.year || e.date.month != now.month) continue;
      delta += e.isIncome ? e.totalAmount : -e.totalAmount;
    }
    return delta;
  }

  /// Live balance for the month of [now]: opening balance plus every income
  /// and minus every expense dated in that month, applied immediately.
  static double liveBalance({
    required Iterable<Expense> records,
    required double openingBalance,
    required DateTime now,
  }) {
    return openingBalance + monthNetDelta(records, now);
  }
}

final maxDailySpendingProvider = Provider<double>((ref) {
  final expensesAsync = ref.watch(expenseListProvider);
  final balanceAsync = ref.watch(currentMonthBalanceProvider);
  final settingsAsync = ref.watch(appSettingsProvider);

  if (expensesAsync.isLoading || balanceAsync.isLoading) return 0.0;

  return BudgetMath.dailyLimit(
    records: expensesAsync.value ?? const <Expense>[],
    openingBalance: balanceAsync.value?.balance ?? 0.0,
    isBiWeekly: settingsAsync.value?.isBiWeeklyMode ?? false,
    now: DateTime.now(),
  );
});

/// Spending dated today (live; drives the intraday progress indicator).
final todaySpendingProvider = Provider<double>((ref) {
  final List<Expense> records =
      ref.watch(expenseListProvider).value ?? const <Expense>[];
  return BudgetMath.spentOn(records, DateTime.now());
});

/// Opening balance of the month adjusted live by this month's income and spending.
final liveBalanceProvider = Provider<double>((ref) {
  final List<Expense> records =
      ref.watch(expenseListProvider).value ?? const <Expense>[];
  final double opening =
      ref.watch(currentMonthBalanceProvider).value?.balance ?? 0.0;
  return BudgetMath.liveBalance(
    records: records,
    openingBalance: opening,
    now: DateTime.now(),
  );
});
