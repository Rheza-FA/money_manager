import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:money_manager/l10n/app_localizations.dart';
import 'package:money_manager/models/app_settings.dart';
import 'package:money_manager/models/expense.dart';
import 'package:money_manager/providers/history_provider.dart';
import 'package:money_manager/theme/app_colors.dart';

enum BreakdownMode {
  byItem,
  byCategory;

  String localizedLabel(AppLocalizations l10n) {
    switch (this) {
      case BreakdownMode.byItem:
        return l10n.analyticsByItem;
      case BreakdownMode.byCategory:
        return l10n.analyticsByCategory;
    }
  }
}

/// Fallback bridge pada AppLocalizations agar bebas error kompilasi.
extension AnalyticsLocalizationBridge on AppLocalizations {
  String get analyticsByItem => 'By Item';
  String get analyticsByCategory => 'By Category';
  String get analyticsTotalSpent => 'TOTAL SPENT';
  String get analyticsNoActivity => 'No activity';
  String get analyticsSingleSource => '1 source';
  String analyticsMultipleSources(String count) => count + ' sources';
  String get analyticsSpendingPace => 'SPENDING PACE';
  String analyticsPacePrefix(String date) => 'PACE • ' + date;
  String analyticsVsPrev(String delta) => delta + '% vs prev';
  String get analyticsFullMonth => 'Full Month';
  String get analyticsBiWeekly => '14 Days';
  String analyticsUnderSafeLimit(String diff, String limit) =>
      diff + ' under safe limit (' + limit + ')';
  String analyticsOverSafeLimit(String diff, String limit) =>
      diff + ' over safe limit (' + limit + ')';
  String analyticsAvgPerDay(String amount) =>
      'Avg ' + amount + '/day across active period';
  String get analyticsFilterToday => 'Today';
  String get analyticsFilterThisMonth => 'This Month';
  String get analyticsFilterSixMonths => '6 Months';
  String get analyticsTopItems => 'Top Items';
  String get analyticsCategories => 'Categories';
  String get analyticsEmptyTitle => 'No transactions found.';
  String get analyticsEmptySubtitle =>
      'Tap + below to add an expense or switch the time filter.';
  String get analyticsDefaultExpenseName => 'Expense';
  String get analyticsCategoryFood => 'Food & Meals';
  String get analyticsCategoryDrinks => 'Drinks & Coffee';
  String get analyticsCategoryTransport => 'Transport';
  String get analyticsCategoryBills => 'Bills & Utilities';
  String get analyticsCategoryOthers => 'General & Others';
  String get analyticsTodayShort => 'Today';
  String analyticsWeekShort(String number) => 'W' + number;
  String analyticsPercentOfLimit(String percent) =>
      percent + '% of spending limit';
  String analyticsLimitBenchmark(String amount) => 'Limit ' + amount;
  String analyticsPercentOfTotal(String percent) =>
      percent + '% of total spent';
}

/// Token warna yang mengacu langsung pada AppColors halaman pertama.
class ForestTokens {
  const ForestTokens._();

  static const Color canvasMint = AppColors.backgroundTop;
  static const Color primaryForest = AppColors.primaryDark;
  static const Color primaryLight = AppColors.primaryLight;
  static const Color mintAccent = Color(0xFF84D696);
  static const Color greyText = AppColors.greyText;
  static const Color iconSurface = Color(0xFFF2F6F4);
  static const Color pureWhite = AppColors.white;
  static const Color coralAlert = Color(0xFFE07A5F);

  static const List< Color > segmentPalette = < Color >[
    AppColors.primaryDark,
    Color(0xFF40916C),
    Color(0xFF84D696),
    Color(0xFFD9A05B),
    Color(0xFF2D6A4F),
    Color(0xFFE07A5F),
  ];
}

@immutable
class AllocationSlice {
  final String id;
  final String title;
  final double amount;
  final double unitPrice;
  final int totalQuantity;
  final int transactionCount;
  final IconData icon;
  final Color color;
  final DateTime latestDate;

  const AllocationSlice({
    required this.id,
    required this.title,
    required this.amount,
    required this.unitPrice,
    required this.totalQuantity,
    required this.transactionCount,
    required this.icon,
    required this.color,
    required this.latestDate,
  });
}

@immutable
class PaceBarPoint {
  final String label;
  final String contextTitle;
  final double spent;
  final double safeLimit;
  final int transactionCount;
  final bool isCurrent;

  const PaceBarPoint({
    required this.label,
    required this.contextTitle,
    required this.spent,
    required this.safeLimit,
    required this.transactionCount,
    this.isCurrent = false,
  });

  bool get isOverLimit => safeLimit > 0 && spent > safeLimit;
}

@immutable
class AnalyticsSnapshot {
  final TimeFilter activeFilter;
  final DateTime anchorDate;
  final double totalSpent;
  final double dailyLimit;
  final bool isBiWeeklyMode;
  final int transactionCount;
  final int totalQuantity;
  final int activeDays;
  final int distinctSpendingDays;
  final List< AllocationSlice > itemSlices;
  final List< AllocationSlice > categorySlices;
  final List< PaceBarPoint > paceSeries;

  const AnalyticsSnapshot({
    required this.activeFilter,
    required this.anchorDate,
    required this.totalSpent,
    required this.dailyLimit,
    required this.isBiWeeklyMode,
    required this.transactionCount,
    required this.totalQuantity,
    required this.activeDays,
    required this.distinctSpendingDays,
    required this.itemSlices,
    required this.categorySlices,
    required this.paceSeries,
  });

  double get averageDailySpent =>
      activeDays > 0 ? totalSpent / activeDays : totalSpent;

  List< AllocationSlice > slicesFor(BreakdownMode mode) =>
      mode == BreakdownMode.byItem ? itemSlices : categorySlices;

  double shareOf(double value) =>
      totalSpent > 0 ? (value / totalSpent) * 100 : 0.0;

  /// Menggunakan Daily Limit yang sama persis dengan halaman pertama (maxDailySpendingProvider).
  double get effectiveSpendingLimit {
    if (dailyLimit <= 0) return 0.0;
    if (activeFilter == TimeFilter.daily ||
        activeFilter == TimeFilter.customDate ||
        distinctSpendingDays <= 1) {
      return dailyLimit;
    }
    return dailyLimit * distinctSpendingDays;
  }

  double limitShareOf(double value) {
    final double limit = effectiveSpendingLimit;
    if (limit > 0) {
      return (value / limit) * 100;
    }
    return shareOf(value);
  }
}

class AnalyticsEngine {
  const AnalyticsEngine._();

  static AnalyticsSnapshot compute({
    required List< Expense > allExpenses,
    required List< Expense > filteredExpenses,
    required double totalFilteredExpense,
    required double exactDailyLimit,
    required AppSettings? settings,
    required TimeFilter filter,
    required DateTime? customDate,
    required AppLocalizations l10n,
  }) {
    final DateTime now = DateTime.now();
    final DateTime anchor = customDate ?? now;
    final bool isBiWeekly = settings?.isBiWeeklyMode ?? false;

    int totalQty = 0;
    final Set< int > uniqueDayKeys = < int >{};

    for (final Expense e in filteredExpenses) {
      totalQty += _extractQty(e);
      uniqueDayKeys.add(e.date.year * 10000 + e.date.month * 100 + e.date.day);
    }

    final int elapsedDays = _resolveElapsedDays(filter, anchor);

    final List< AllocationSlice > itemSlices = _buildSlices(
      filteredExpenses,
      byCategory: false,
      l10n: l10n,
    );
    final List< AllocationSlice > categorySlices = _buildSlices(
      filteredExpenses,
      byCategory: true,
      l10n: l10n,
    );

    final List< PaceBarPoint > paceSeries = _buildPaceSeries(
      allExpenses: allExpenses,
      filter: filter,
      anchor: anchor,
      dailyLimit: exactDailyLimit,
      l10n: l10n,
    );

    return AnalyticsSnapshot(
      activeFilter: filter,
      anchorDate: anchor,
      totalSpent: totalFilteredExpense,
      dailyLimit: exactDailyLimit,
      isBiWeeklyMode: isBiWeekly,
      transactionCount: filteredExpenses.length,
      totalQuantity: totalQty,
      activeDays: elapsedDays,
      distinctSpendingDays: math.max(1, uniqueDayKeys.length),
      itemSlices: itemSlices,
      categorySlices: categorySlices,
      paceSeries: paceSeries,
    );
  }

  static int _resolveElapsedDays(TimeFilter filter, DateTime anchor) {
    final DateTime now = DateTime.now();
    switch (filter) {
      case TimeFilter.daily:
      case TimeFilter.customDate:
        return 1;
      case TimeFilter.monthly:
        return (anchor.year == now.year && anchor.month == now.month)
            ? math.max(1, now.day)
            : DateUtils.getDaysInMonth(anchor.year, anchor.month);
      case TimeFilter.sixMonths:
        final DateTime start =
            DateTime(anchor.year, anchor.month - 6, anchor.day);
        return math.max(1, anchor.difference(start).inDays);
      case TimeFilter.yearly:
        final DateTime start = DateTime(anchor.year, 1, 1);
        return math.max(1, now.difference(start).inDays);
    }
  }

  static List< AllocationSlice > _buildSlices(
    List< Expense > expenses, {
    required bool byCategory,
    required AppLocalizations l10n,
  }) {
    final Map< String, List< Expense > > groups = < String, List< Expense > >{};

    for (final Expense e in expenses) {
      final String rawTitle = _extractTitle(e, l10n);
      final String key = byCategory
          ? _classifyCategory(rawTitle, l10n).name
          : rawTitle.trim().toLowerCase();
      groups.putIfAbsent(key, () => < Expense >[]).add(e);
    }

    final List< MapEntry< String, List< Expense > > > sortedEntries =
        groups.entries.toList()
          ..sort(
            (
              MapEntry< String, List< Expense > > a,
              MapEntry< String, List< Expense > > b,
            ) {
              final double sumA = a.value.fold< double >(
                0.0,
                (double s, Expense e) => s + e.totalAmount,
              );
              final double sumB = b.value.fold< double >(
                0.0,
                (double s, Expense e) => s + e.totalAmount,
              );
              return sumB.compareTo(sumA);
            },
          );

    const List< Color > palette = ForestTokens.segmentPalette;
    final List< AllocationSlice > result = < AllocationSlice >[];

    for (int i = 0; i < sortedEntries.length; i++) {
      final List< Expense > items = sortedEntries[i].value;
      double sumAmount = 0.0;
      int sumQty = 0;
      DateTime latest = items.first.date;

      for (final Expense e in items) {
        sumAmount += e.totalAmount;
        sumQty += _extractQty(e);
        if (e.date.isAfter(latest)) latest = e.date;
      }

      final String sampleTitle = _extractTitle(items.first, l10n);
      final ({String name, IconData icon}) cat =
          _classifyCategory(sampleTitle, l10n);
      final String displayTitle =
          byCategory ? cat.name : _formatTitleCase(sampleTitle, l10n);

      result.add(
        AllocationSlice(
          id: sortedEntries[i].key,
          title: displayTitle,
          amount: sumAmount,
          unitPrice: sumQty > 0 ? sumAmount / sumQty : sumAmount,
          totalQuantity: sumQty,
          transactionCount: items.length,
          icon: byCategory ? cat.icon : Icons.receipt_long_outlined,
          color: palette[i % palette.length],
          latestDate: latest,
        ),
      );
    }

    return result;
  }

  static List< PaceBarPoint > _buildPaceSeries({
    required List< Expense > allExpenses,
    required TimeFilter filter,
    required DateTime anchor,
    required double dailyLimit,
    required AppLocalizations l10n,
  }) {
    const List< String > shortDays = < String >[
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    const List< String > shortMonths = < String >[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    if (filter == TimeFilter.daily || filter == TimeFilter.customDate) {
      final DateTime baseDay = DateTime(anchor.year, anchor.month, anchor.day);
      final List< PaceBarPoint > points = < PaceBarPoint >[];

      for (int i = 6; i >= 0; i--) {
        final DateTime d = baseDay.subtract(Duration(days: i));
        final DateTime nextD = d.add(const Duration(days: 1));
        double spent = 0.0;
        int count = 0;

        for (final Expense e in allExpenses) {
          if (!e.date.isBefore(d) && e.date.isBefore(nextD)) {
            spent += e.totalAmount;
            count++;
          }
        }

        final String dayLabel =
            i == 0 ? l10n.analyticsTodayShort : shortDays[d.weekday - 1];
        final String fullDate =
            d.day.toString().padLeft(2, '0') + ' ' + shortMonths[d.month - 1];

        points.add(
          PaceBarPoint(
            label: dayLabel,
            contextTitle: fullDate,
            spent: spent,
            safeLimit: dailyLimit,
            transactionCount: count,
            isCurrent: i == 0,
          ),
        );
      }
      return points;
    }

    if (filter == TimeFilter.monthly) {
      final int daysInMonth =
          DateUtils.getDaysInMonth(anchor.year, anchor.month);
      final DateTime now = DateTime.now();
      final List< PaceBarPoint > points = < PaceBarPoint >[];

      int startDay = 1;
      int weekNum = 1;
      while (startDay <= daysInMonth) {
        final int endDay = math.min(startDay + 6, daysInMonth);
        final int spanDays = endDay - startDay + 1;
        final DateTime wStart = DateTime(anchor.year, anchor.month, startDay);
        final DateTime wEnd = DateTime(anchor.year, anchor.month, endDay)
            .add(const Duration(days: 1));

        double spent = 0.0;
        int count = 0;
        for (final Expense e in allExpenses) {
          if (!e.date.isBefore(wStart) && e.date.isBefore(wEnd)) {
            spent += e.totalAmount;
            count++;
          }
        }

        final bool isCurrentWeek = anchor.year == now.year &&
            anchor.month == now.month &&
            now.day >= startDay &&
            now.day <= endDay;

        points.add(
          PaceBarPoint(
            label: l10n.analyticsWeekShort(weekNum.toString()),
            contextTitle: startDay.toString() +
                '–' +
                endDay.toString() +
                ' ' +
                shortMonths[anchor.month - 1],
            spent: spent,
            safeLimit: dailyLimit > 0 ? dailyLimit * spanDays : 0.0,
            transactionCount: count,
            isCurrent: isCurrentWeek,
          ),
        );

        startDay = endDay + 1;
        weekNum++;
      }
      return points;
    }

    final List< PaceBarPoint > points = < PaceBarPoint >[];
    for (int i = 5; i >= 0; i--) {
      final DateTime mStart = DateTime(anchor.year, anchor.month - i, 1);
      final DateTime mEnd = DateTime(mStart.year, mStart.month + 1, 1);
      final int daysInM = DateUtils.getDaysInMonth(mStart.year, mStart.month);

      double spent = 0.0;
      int count = 0;
      for (final Expense e in allExpenses) {
        if (!e.date.isBefore(mStart) && e.date.isBefore(mEnd)) {
          spent += e.totalAmount;
          count++;
        }
      }

      points.add(
        PaceBarPoint(
          label: shortMonths[mStart.month - 1],
          contextTitle:
              shortMonths[mStart.month - 1] + ' ' + mStart.year.toString(),
          spent: spent,
          safeLimit: dailyLimit > 0 ? dailyLimit * daysInM : 0.0,
          transactionCount: count,
          isCurrent: i == 0,
        ),
      );
    }
    return points;
  }

  static String _extractTitle(Expense e, AppLocalizations l10n) {
    final dynamic dyn = e;
    for (final dynamic Function() getter in < dynamic Function() >[
      () => dyn.title,
      () => dyn.name,
      () => dyn.itemName,
      () => dyn.description,
    ]) {
      try {
        final dynamic val = getter();
        if (val is String && val.trim().isNotEmpty) return val.trim();
      } catch (_) {}
    }
    return l10n.analyticsDefaultExpenseName;
  }

  static int _extractQty(Expense e) {
    final dynamic dyn = e;
    for (final dynamic Function() getter in < dynamic Function() >[
      () => dyn.quantity,
      () => dyn.qty,
      () => dyn.count,
    ]) {
      try {
        final dynamic val = getter();
        if (val is int && val > 0) return val;
      } catch (_) {}
    }
    return 1;
  }

  static ({String name, IconData icon}) _classifyCategory(
    String rawTitle,
    AppLocalizations l10n,
  ) {
    final String lower = rawTitle.toLowerCase();

    const List< String > foodKeywords = < String >[
      'nasi',
      'ayam',
      'gorengan',
      'mie',
      'bakso',
      'soto',
      'makan',
      'warteg',
      'roti',
      'snack',
      'jajan',
      'telur',
      'ikan',
      'sayur',
      'sate',
      'geprek',
      'bubur',
      'food',
      'rice',
      'chicken',
    ];
    for (final String kw in foodKeywords) {
      if (lower.contains(kw)) {
        return (
          name: l10n.analyticsCategoryFood,
          icon: Icons.restaurant_outlined,
        );
      }
    }

    const List< String > drinkKeywords = < String >[
      'kopi',
      'es ',
      'teh',
      'jus',
      'minum',
      'cafe',
      'kafe',
      'boba',
      'susu',
      'air',
      'coffee',
      'tea',
      'drink',
    ];
    for (final String kw in drinkKeywords) {
      if (lower.contains(kw)) {
        return (
          name: l10n.analyticsCategoryDrinks,
          icon: Icons.local_cafe_outlined,
        );
      }
    }

    const List< String > transportKeywords = < String >[
      'bensin',
      'pertalite',
      'pertamax',
      'parkir',
      'gojek',
      'grab',
      'maxim',
      'tol',
      'servis',
      'oli',
      'fuel',
      'gas',
      'parking',
    ];
    for (final String kw in transportKeywords) {
      if (lower.contains(kw)) {
        return (
          name: l10n.analyticsCategoryTransport,
          icon: Icons.directions_car_outlined,
        );
      }
    }

    const List< String > billsKeywords = < String >[
      'listrik',
      'token',
      'kuota',
      'pulsa',
      'wifi',
      'kos',
      'tagihan',
      'bill',
      'internet',
      'rent',
    ];
    for (final String kw in billsKeywords) {
      if (lower.contains(kw)) {
        return (
          name: l10n.analyticsCategoryBills,
          icon: Icons.bolt_outlined,
        );
      }
    }

    return (
      name: l10n.analyticsCategoryOthers,
      icon: Icons.receipt_long_outlined,
    );
  }

  static String _formatTitleCase(String text, AppLocalizations l10n) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return l10n.analyticsDefaultExpenseName;
    return trimmed
        .split(RegExp(r'\s+'))
        .map((String w) =>
            w.isEmpty ? '' : (w[0].toUpperCase() + w.substring(1)))
        .join(' ');
  }
}

class IdrFormatter {
  const IdrFormatter._();

  static String numberOnly(double value) {
    final String raw = value.abs().round().toString();
    final StringBuffer buf = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) {
        buf.write('.');
      }
      buf.write(raw[i]);
    }
    return buf.toString();
  }

  static String format(double value, {bool negativePrefix = false}) {
    final String numStr = numberOnly(value);
    if ((negativePrefix && value > 0) || value < 0) {
      return '- Rp ' + numStr;
    }
    return 'Rp ' + numStr;
  }

  static String shortDate(DateTime dt) {
    const List< String > months = < String >[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final String d = dt.day.toString().padLeft(2, '0');
    final String m = months[dt.month - 1];
    final String h = dt.hour.toString().padLeft(2, '0');
    final String min = dt.minute.toString().padLeft(2, '0');
    return d + ' ' + m + ', ' + h + ':' + min;
  }
}