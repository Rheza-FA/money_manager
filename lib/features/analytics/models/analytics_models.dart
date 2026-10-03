import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:money_manager/l10n/app_localizations.dart';
import 'package:money_manager/models/app_settings.dart';
import 'package:money_manager/models/expense.dart';
import 'package:money_manager/models/monthly_balance.dart';
import 'package:money_manager/providers/history_provider.dart';

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

/// Fallback bridge pada AppLocalizations agar kode bebas error garis merah
/// bahkan sebelum `flutter gen-l10n` dijalankan. Saat `flutter gen-l10n` selesai
/// mencetak instance getter ke `lib/l10n/app_localizations.dart`, Dart otomatis
/// memprioritaskan instance getter hasil generate ARB.
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
  String get analyticsBiWeekly => 'Bi-Weekly';
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
  String get analyticsEmptyTitle => 'No transactions recorded';
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
}

/// Token warna yang diambil langsung dari anatomi visual halaman pertama.
class ForestTokens {
  const ForestTokens._();

  static const Color canvasMint = Color(0xFFEAF4EE);
  static const Color primaryForest = Color(0xFF0A332B);
  static const Color forestElevated = Color(0xFF134238);
  static const Color mintAccent = Color(0xFF84D696);
  static const Color mutedSage = Color(0xFF88A89E);
  static const Color greyText = Color(0xFF758A82);
  static const Color iconSurface = Color(0xFFF2F6F4);
  static const Color pureWhite = Colors.white;
  static const Color coralAlert = Color(0xFFFF8A71);

  /// Palet segmen Donut Chart bernuansa botanical & kontras tinggi.
  static const List< Color > segmentPalette = < Color >[
    Color(0xFF0A332B), // Deep Forest
    Color(0xFF40916C), // Emerald Leaf
    Color(0xFF84D696), // Soft Mint
    Color(0xFFD9A05B), // Warm Amber Gold
    Color(0xFF2D6A4F), // Pine Green
    Color(0xFFE07A5F), // Terra Coral
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
  final double previousSpent;
  final double dailyLimit;
  final bool isBiWeeklyMode;
  final int transactionCount;
  final int totalQuantity;
  final int activeDays;
  final List< AllocationSlice > itemSlices;
  final List< AllocationSlice > categorySlices;
  final List< PaceBarPoint > paceSeries;

  const AnalyticsSnapshot({
    required this.activeFilter,
    required this.anchorDate,
    required this.totalSpent,
    required this.previousSpent,
    required this.dailyLimit,
    required this.isBiWeeklyMode,
    required this.transactionCount,
    required this.totalQuantity,
    required this.activeDays,
    required this.itemSlices,
    required this.categorySlices,
    required this.paceSeries,
  });

  double get averageDailySpent =>
      activeDays > 0 ? totalSpent / activeDays : totalSpent;

  double? get deltaPercentage {
    if (previousSpent <= 0) return null;
    return ((totalSpent - previousSpent) / previousSpent) * 100;
  }

  List< AllocationSlice > slicesFor(BreakdownMode mode) =>
      mode == BreakdownMode.byItem ? itemSlices : categorySlices;

  double shareOf(double value) =>
      totalSpent > 0 ? (value / totalSpent) * 100 : 0.0;
}

class AnalyticsEngine {
  const AnalyticsEngine._();

  static AnalyticsSnapshot compute({
    required List< Expense > allExpenses,
    required MonthlyBalance? monthlyBalance,
    required AppSettings? settings,
    required TimeFilter filter,
    required DateTime? customDate,
    required AppLocalizations l10n,
  }) {
    final DateTime now = DateTime.now();
    final DateTime anchor = customDate ?? now;
    final bool isBiWeekly = settings?.isBiWeeklyMode ?? false;

    final double dailyLimit = _computeDailyLimit(
      allExpenses: allExpenses,
      monthlyBalance: monthlyBalance,
      isBiWeekly: isBiWeekly,
      now: now,
    );

    final ({
      DateTime start,
      DateTime end,
      DateTime prevStart,
      DateTime prevEnd,
      int days,
    }) range = _resolveRange(filter, anchor);

    final List< Expense > currentList = < Expense >[];
    final List< Expense > previousList = < Expense >[];

    for (final Expense e in allExpenses) {
      if (!e.date.isBefore(range.start) && e.date.isBefore(range.end)) {
        currentList.add(e);
      } else if (!e.date.isBefore(range.prevStart) &&
          e.date.isBefore(range.prevEnd)) {
        previousList.add(e);
      }
    }

    double totalSpent = 0.0;
    int totalQty = 0;
    for (final Expense e in currentList) {
      totalSpent += e.totalAmount;
      totalQty += _extractQty(e);
    }

    double previousSpent = 0.0;
    for (final Expense e in previousList) {
      previousSpent += e.totalAmount;
    }

    final List< AllocationSlice > itemSlices = _buildSlices(
      currentList,
      byCategory: false,
      l10n: l10n,
    );
    final List< AllocationSlice > categorySlices = _buildSlices(
      currentList,
      byCategory: true,
      l10n: l10n,
    );

    final List< PaceBarPoint > paceSeries = _buildPaceSeries(
      allExpenses: allExpenses,
      filter: filter,
      anchor: anchor,
      dailyLimit: dailyLimit,
      l10n: l10n,
    );

    return AnalyticsSnapshot(
      activeFilter: filter,
      anchorDate: anchor,
      totalSpent: totalSpent,
      previousSpent: previousSpent,
      dailyLimit: dailyLimit,
      isBiWeeklyMode: isBiWeekly,
      transactionCount: currentList.length,
      totalQuantity: totalQty,
      activeDays: range.days,
      itemSlices: itemSlices,
      categorySlices: categorySlices,
      paceSeries: paceSeries,
    );
  }

  static double _computeDailyLimit({
    required List< Expense > allExpenses,
    required MonthlyBalance? monthlyBalance,
    required bool isBiWeekly,
    required DateTime now,
  }) {
    final double initialBudget = monthlyBalance?.balance ?? 0.0;
    if (initialBudget <= 0) return 0.0;

    final DateTime todayStart = DateTime(now.year, now.month, now.day);
    double spentBeforeToday = 0.0;

    for (final Expense e in allExpenses) {
      if (e.date.year == now.year &&
          e.date.month == now.month &&
          e.date.isBefore(todayStart)) {
        spentBeforeToday += e.totalAmount;
      }
    }

    final double remainingBudget =
        math.max(0.0, initialBudget - spentBeforeToday);
    final int daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);

    if (isBiWeekly) {
      final int targetDay = now.day <= 15 ? 15 : daysInMonth;
      final int remainingDays = math.max(1, targetDay - now.day + 1);
      return remainingBudget / remainingDays;
    } else {
      final int remainingDays = math.max(1, daysInMonth - now.day + 1);
      return remainingBudget / remainingDays;
    }
  }

  static ({
    DateTime start,
    DateTime end,
    DateTime prevStart,
    DateTime prevEnd,
    int days,
  }) _resolveRange(TimeFilter filter, DateTime anchor) {
    final DateTime dayStart = DateTime(anchor.year, anchor.month, anchor.day);

    switch (filter) {
      case TimeFilter.daily:
      case TimeFilter.customDate:
        final DateTime end = dayStart.add(const Duration(days: 1));
        final DateTime prevStart = dayStart.subtract(const Duration(days: 1));
        return (
          start: dayStart,
          end: end,
          prevStart: prevStart,
          prevEnd: dayStart,
          days: 1,
        );

      case TimeFilter.monthly:
        final DateTime start = DateTime(anchor.year, anchor.month, 1);
        final DateTime end = DateTime(anchor.year, anchor.month + 1, 1);
        final DateTime prevStart = DateTime(anchor.year, anchor.month - 1, 1);
        final DateTime now = DateTime.now();
        final int elapsedDays =
            (anchor.year == now.year && anchor.month == now.month)
                ? math.max(1, now.day)
                : DateUtils.getDaysInMonth(anchor.year, anchor.month);
        return (
          start: start,
          end: end,
          prevStart: prevStart,
          prevEnd: start,
          days: elapsedDays,
        );

      case TimeFilter.sixMonths:
        final DateTime start =
            DateTime(anchor.year, anchor.month - 6, anchor.day);
        final DateTime end = dayStart.add(const Duration(days: 1));
        final DateTime prevStart =
            DateTime(anchor.year, anchor.month - 12, anchor.day);
        final int days = math.max(1, end.difference(start).inDays);
        return (
          start: start,
          end: end,
          prevStart: prevStart,
          prevEnd: start,
          days: days,
        );

      case TimeFilter.yearly:
        final DateTime start = DateTime(anchor.year, 1, 1);
        final DateTime end = DateTime(anchor.year + 1, 1, 1);
        final DateTime prevStart = DateTime(anchor.year - 1, 1, 1);
        final int days = math.max(1, DateTime.now().difference(start).inDays);
        return (
          start: start,
          end: end,
          prevStart: prevStart,
          prevEnd: start,
          days: days,
        );
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