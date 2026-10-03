import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Filter periode yang identik dengan bahasa desain Dashboard utama.
enum AnalyticsFilterPeriod {
  today('Hari Ini', 'vs kemarin'),
  thisMonth('Bulan Ini', 'vs bulan lalu'),
  sixMonths('6 Bulan', 'vs 6 bln lalu'),
  customDate('Tanggal', 'vs hari sebelumnya');

  final String label;
  final String comparisonSuffix;
  const AnalyticsFilterPeriod(this.label, this.comparisonSuffix);
}

/// Mode pengelompokan distribusi pengeluaran.
enum BreakdownGroupMode {
  byItem('Per Item'),
  byCategory('Kategori');

  final String label;
  const BreakdownGroupMode(this.label);
}

/// Palet warna permukaan dan aksen yang selaras 1:1 dengan halaman pertama.
class ForestAnalyticsPalette {
  const ForestAnalyticsPalette._();

  static const Color scaffoldMint = Color(0xFFEAF4EE);
  static const Color deepForest = Color(0xFF0A332B);
  static const Color forestSurface = Color(0xFF124036);
  static const Color sageAccent = Color(0xFF76C893);
  static const Color mutedSageText = Color(0xFF88A89E);
  static const Color bodyGreyText = Color(0xFF72867E);
  static const Color iconBoxMint = Color(0xFFF0F6F2);
  static const Color cardWhite = Colors.white;
  static const Color warningCoral = Color(0xFFE07A5F);
  static const Color warmAmber = Color(0xFFE09F3E);

  /// Urutan warna segmen Donut Chart yang harmonis dengan estetika hijau forest.
  static const List< Color > chartSegments = < Color >[
    Color(0xFF0A332B), // Deep Forest
    Color(0xFF52B788), // Fresh Mint Leaf
    Color(0xFFE09F3E), // Warm Honey Amber
    Color(0xFF2D6A4F), // Emerald Pine
    Color(0xFFE07A5F), // Soft Terracotta
    Color(0xFF4D908E), // Muted Sea Teal
    Color(0xFF81B29A), // Sage Mist
  ];
}

/// Representasi transaksi yang sudah dinormalisasi dari koleksi Isar Expense.
@immutable
class NormalizedExpense {
  final String id;
  final String title;
  final double totalAmount;
  final double unitPrice;
  final int quantity;
  final DateTime date;
  final String autoCategory;
  final IconData categoryIcon;

  const NormalizedExpense({
    required this.id,
    required this.title,
    required this.totalAmount,
    required this.unitPrice,
    required this.quantity,
    required this.date,
    required this.autoCategory,
    required this.categoryIcon,
  });
}

/// Metrik untuk setiap segmen pada Donut Chart dan kartu Breakdown di bawahnya.
@immutable
class AllocationSlice {
  final String id;
  final String title;
  final double amount;
  final double previousAmount;
  final int totalQuantity;
  final int transactionCount;
  final IconData icon;
  final Color color;
  final DateTime latestDate;

  const AllocationSlice({
    required this.id,
    required this.title,
    required this.amount,
    required this.previousAmount,
    required this.totalQuantity,
    required this.transactionCount,
    required this.icon,
    required this.color,
    required this.latestDate,
  });

  double get averageUnitPrice =>
      totalQuantity > 0 ? amount / totalQuantity : amount;

  double? get deltaPercentage {
    if (previousAmount <= 0) return null;
    return ((amount - previousAmount) / previousAmount) * 100;
  }
}

/// Titik data untuk grafik batang tren pengeluaran vs batas aman (Daily Limit).
@immutable
class SpendingBarPoint {
  final String label;
  final String fullDateLabel;
  final double spent;
  final double safeBenchmark;
  final int transactionCount;
  final bool isCurrentHighlight;

  const SpendingBarPoint({
    required this.label,
    required this.fullDateLabel,
    required this.spent,
    required this.safeBenchmark,
    required this.transactionCount,
    this.isCurrentHighlight = false,
  });

  bool get isOverLimit => safeBenchmark > 0 && spent > safeBenchmark;
}

/// Snapshot komprehensif hasil olahan data riil Isar untuk ditampilkan di UI.
@immutable
class DynamicAnalyticsSnapshot {
  final AnalyticsFilterPeriod period;
  final DateTime anchorDate;
  final double totalSpent;
  final double previousPeriodSpent;
  final double dailyLimit;
  final double monthlyBudget;
  final double remainingMonthlyBalance;
  final bool isFullMonthMode;
  final int totalTransactions;
  final int totalItemsQuantity;
  final int previousItemsQuantity;
  final int activeDaysCount;
  final List< AllocationSlice > itemSlices;
  final List< AllocationSlice > categorySlices;
  final List< SpendingBarPoint > trendPoints;

  const DynamicAnalyticsSnapshot({
    required this.period,
    required this.anchorDate,
    required this.totalSpent,
    required this.previousPeriodSpent,
    required this.dailyLimit,
    required this.monthlyBudget,
    required this.remainingMonthlyBalance,
    required this.isFullMonthMode,
    required this.totalTransactions,
    required this.totalItemsQuantity,
    required this.previousItemsQuantity,
    required this.activeDaysCount,
    required this.itemSlices,
    required this.categorySlices,
    required this.trendPoints,
  });

  double? get periodDeltaPercentage {
    if (previousPeriodSpent <= 0) return null;
    return ((totalSpent - previousPeriodSpent) / previousPeriodSpent) * 100;
  }

  double get averageDailySpent =>
      activeDaysCount > 0 ? totalSpent / activeDaysCount : totalSpent;

  /// Benchmark batas aman sesuai periode yang sedang dipilih.
  double get periodSafeLimit {
    if (dailyLimit <= 0) return 0;
    switch (period) {
      case AnalyticsFilterPeriod.today:
      case AnalyticsFilterPeriod.customDate:
        return dailyLimit;
      case AnalyticsFilterPeriod.thisMonth:
        final int daysInMonth =
            DateUtils.getDaysInMonth(anchorDate.year, anchorDate.month);
        return monthlyBudget > 0 ? monthlyBudget : dailyLimit * daysInMonth;
      case AnalyticsFilterPeriod.sixMonths:
        return (monthlyBudget > 0 ? monthlyBudget : dailyLimit * 30) * 6;
    }
  }

  double get limitUsagePercentage {
    final double benchmark = (period == AnalyticsFilterPeriod.today ||
            period == AnalyticsFilterPeriod.customDate)
        ? dailyLimit
        : periodSafeLimit;
    if (benchmark <= 0) return 0;
    return (totalSpent / benchmark) * 100;
  }

  List< AllocationSlice > slicesForMode(BreakdownGroupMode mode) {
    return mode == BreakdownGroupMode.byItem ? itemSlices : categorySlices;
  }

  double shareOfTotal(double sliceAmount) {
    if (totalSpent <= 0) return 0;
    return (sliceAmount / totalSpent) * 100;
  }
}

/// Engine ekstraktor & pengolah data dinamis dari DatabaseProvider & HistoryProvider (Isar).
class AnalyticsDataBridge {
  const AnalyticsDataBridge._();

  static DynamicAnalyticsSnapshot buildFromProviders({
    required dynamic databaseProvider,
    required dynamic historyProvider,
    required AnalyticsFilterPeriod period,
    required DateTime? customDate,
  }) {
    final DateTime now = DateTime.now();
    final DateTime anchor = customDate ?? now;

    // 1. Ekstrak seluruh transaksi dari DatabaseProvider & HistoryProvider
    final List< dynamic > rawExpenses = _extractAllRawExpenses(
      databaseProvider: databaseProvider,
      historyProvider: historyProvider,
    );

    final List< NormalizedExpense > normalizedList = < NormalizedExpense >[];
    for (int i = 0; i < rawExpenses.length; i++) {
      final NormalizedExpense? norm = _normalizeExpense(rawExpenses[i], i);
      if (norm != null) {
        normalizedList.add(norm);
      }
    }

    // Urutkan dari terbaru ke terlama
    normalizedList.sort(
      (NormalizedExpense a, NormalizedExpense b) => b.date.compareTo(a.date),
    );

    // 2. Ekstrak Daily Limit, Monthly Budget, dan Mode Full Month
    final bool isFullMonth = _extractIsFullMonth(databaseProvider);
    final ({
      double dailyLimit,
      double monthlyBudget,
      double remainingBalance,
    }) budgetMetrics = _extractBudgetMetrics(
      databaseProvider: databaseProvider,
      allExpenses: normalizedList,
      now: now,
    );

    // 3. Tentukan rentang waktu periode aktif & periode pembanding sebelumnya
    final ({
      DateTime currentStart,
      DateTime currentEnd,
      DateTime previousStart,
      DateTime previousEnd,
      int elapsedDays,
    }) ranges = _resolvePeriodRanges(
      period: period,
      anchor: anchor,
    );

    final List< NormalizedExpense > currentExpenses = normalizedList
        .where((NormalizedExpense e) =>
            !e.date.isBefore(ranges.currentStart) &&
            e.date.isBefore(ranges.currentEnd))
        .toList();

    final List< NormalizedExpense > previousExpenses = normalizedList
        .where((NormalizedExpense e) =>
            !e.date.isBefore(ranges.previousStart) &&
            e.date.isBefore(ranges.previousEnd))
        .toList();

    double totalSpent = 0.0;
    int totalQty = 0;
    for (final NormalizedExpense e in currentExpenses) {
      totalSpent += e.totalAmount;
      totalQty += e.quantity;
    }

    double previousSpent = 0.0;
    int previousQty = 0;
    for (final NormalizedExpense e in previousExpenses) {
      previousSpent += e.totalAmount;
      previousQty += e.quantity;
    }

    // 4. Kelompokkan berdasarkan Item & Kategori
    final List< AllocationSlice > itemSlices = _buildSlices(
      current: currentExpenses,
      previous: previousExpenses,
      byCategory: false,
    );

    final List< AllocationSlice > categorySlices = _buildSlices(
      current: currentExpenses,
      previous: previousExpenses,
      byCategory: true,
    );

    // 5. Bangun seri grafik batang (Trend & Benchmark Daily Limit)
    final List< SpendingBarPoint > trendPoints = _buildTrendSeries(
      allExpenses: normalizedList,
      period: period,
      anchor: anchor,
      dailyLimit: budgetMetrics.dailyLimit,
    );

    return DynamicAnalyticsSnapshot(
      period: period,
      anchorDate: anchor,
      totalSpent: totalSpent,
      previousPeriodSpent: previousSpent,
      dailyLimit: budgetMetrics.dailyLimit,
      monthlyBudget: budgetMetrics.monthlyBudget,
      remainingMonthlyBalance: budgetMetrics.remainingBalance,
      isFullMonthMode: isFullMonth,
      totalTransactions: currentExpenses.length,
      totalItemsQuantity: totalQty,
      previousItemsQuantity: previousQty,
      activeDaysCount: ranges.elapsedDays,
      itemSlices: itemSlices,
      categorySlices: categorySlices,
      trendPoints: trendPoints,
    );
  }

  static List< dynamic > _extractAllRawExpenses({
    required dynamic databaseProvider,
    required dynamic historyProvider,
  }) {
    final List< dynamic > collected = < dynamic >[];
    final Set< String > seenSignatures = < String >{};

    void addCandidateList(dynamic candidate) {
      if (candidate == null) return;
      if (candidate is Iterable) {
        for (final dynamic item in candidate) {
          if (item == null) continue;
          final String sig = _itemSignature(item);
          if (seenSignatures.add(sig)) {
            collected.add(item);
          }
        }
      }
    }

    // Ambil dari DatabaseProvider (Isar)
    if (databaseProvider != null) {
      final List< dynamic Function() > dbGetters = < dynamic Function() >[
        () => databaseProvider.expenses,
        () => databaseProvider.allExpenses,
        () => databaseProvider.transactions,
        () => databaseProvider.allTransactions,
        () => databaseProvider.currentMonthExpenses,
        () => databaseProvider.expenseList,
      ];
      for (final dynamic Function() getter in dbGetters) {
        try {
          addCandidateList(getter());
        } catch (_) {}
      }
    }

    // Ambil dari HistoryProvider (Isar)
    if (historyProvider != null) {
      final List< dynamic Function() > histGetters = < dynamic Function() >[
        () => historyProvider.allExpenses,
        () => historyProvider.expenses,
        () => historyProvider.filteredExpenses,
        () => historyProvider.transactions,
        () => historyProvider.allTransactions,
      ];
      for (final dynamic Function() getter in histGetters) {
        try {
          addCandidateList(getter());
        } catch (_) {}
      }
    }

    return collected;
  }

  static String _itemSignature(dynamic item) {
    try {
      final dynamic id = item.id;
      if (id != null && id.toString().isNotEmpty) {
        return 'id_' + id.toString();
      }
    } catch (_) {}

    final String name = _readString(item, < dynamic Function(dynamic) >[
          (dynamic o) => o.title,
          (dynamic o) => o.name,
          (dynamic o) => o.itemName,
          (dynamic o) => o.description,
        ]) ??
        'item';
    final DateTime date =
        _readDateTime(item) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final double amount = _readDouble(item, < dynamic Function(dynamic) >[
          (dynamic o) => o.totalAmount,
          (dynamic o) => o.total,
          (dynamic o) => o.amount,
          (dynamic o) => o.price,
        ]) ??
        0.0;
    return name +
        '_' +
        date.millisecondsSinceEpoch.toString() +
        '_' +
        amount.toStringAsFixed(0);
  }

  static NormalizedExpense? _normalizeExpense(dynamic raw, int index) {
    final String title = _readString(raw, < dynamic Function(dynamic) >[
          (dynamic o) => o.title,
          (dynamic o) => o.name,
          (dynamic o) => o.itemName,
          (dynamic o) => o.item,
          (dynamic o) => o.description,
          (dynamic o) => o.note,
        ]) ??
        'Transaksi';

    final DateTime date = _readDateTime(raw) ?? DateTime.now();

    final int qty = _readInt(raw, < dynamic Function(dynamic) >[
          (dynamic o) => o.quantity,
          (dynamic o) => o.qty,
          (dynamic o) => o.count,
        ]) ??
        1;
    final int safeQty = qty > 0 ? qty : 1;

    final double? explicitTotal = _readDouble(raw, < dynamic Function(dynamic) >[
      (dynamic o) => o.totalAmount,
      (dynamic o) => o.totalPrice,
      (dynamic o) => o.total,
    ]);
    final double? rawAmount = _readDouble(raw, < dynamic Function(dynamic) >[
      (dynamic o) => o.amount,
    ]);
    final double? rawUnitPrice = _readDouble(raw, < dynamic Function(dynamic) >[
      (dynamic o) => o.unitPrice,
      (dynamic o) => o.price,
      (dynamic o) => o.itemPrice,
    ]);

    double totalAmount = 0.0;
    double unitPrice = 0.0;

    if (explicitTotal != null && explicitTotal > 0) {
      totalAmount = explicitTotal;
      unitPrice = rawUnitPrice ?? (totalAmount / safeQty);
    } else if (rawAmount != null && rawUnitPrice != null) {
      if ((rawUnitPrice * safeQty - rawAmount).abs() < 1.0) {
        totalAmount = rawAmount;
        unitPrice = rawUnitPrice;
      } else {
        totalAmount = rawAmount;
        unitPrice = rawAmount / safeQty;
      }
    } else if (rawAmount != null) {
      totalAmount = rawAmount;
      unitPrice = rawAmount / safeQty;
    } else if (rawUnitPrice != null) {
      unitPrice = rawUnitPrice;
      totalAmount = rawUnitPrice * safeQty;
    }

    if (totalAmount <= 0) return null;

    final String id = _readString(raw, < dynamic Function(dynamic) >[
          (dynamic o) => o.id?.toString(),
        ]) ??
        ('exp_' + index.toString() + '_' + date.millisecondsSinceEpoch.toString());

    final ({String categoryName, IconData icon}) classification =
        _classifyItem(title);

    return NormalizedExpense(
      id: id,
      title: title,
      totalAmount: totalAmount,
      unitPrice: unitPrice,
      quantity: safeQty,
      date: date,
      autoCategory: classification.categoryName,
      categoryIcon: classification.icon,
    );
  }

  static bool _extractIsFullMonth(dynamic db) {
    if (db != null) {
      final List< dynamic Function() > getters = < dynamic Function() >[
        () => db.isFullMonth,
        () => db.settings?.isFullMonth,
        () => db.appSettings?.isFullMonth,
        () => db.dailyLimitMode,
      ];
      for (final dynamic Function() getter in getters) {
        try {
          final dynamic val = getter();
          if (val is bool) return val;
          if (val != null &&
              val.toString().toLowerCase().contains('weekday')) {
            return false;
          }
        } catch (_) {}
      }
    }
    return true;
  }

  static ({
    double dailyLimit,
    double monthlyBudget,
    double remainingBalance,
  }) _extractBudgetMetrics({
    required dynamic databaseProvider,
    required List< NormalizedExpense > allExpenses,
    required DateTime now,
  }) {
    double? dailyLimit;
    double? monthlyBudget;
    double? remainingBalance;

    if (databaseProvider != null) {
      dailyLimit = _readDouble(databaseProvider, < dynamic Function(dynamic) >[
        (dynamic d) => d.dailyLimit,
        (dynamic d) => d.safeDailyLimit,
        (dynamic d) => d.todayLimit,
        (dynamic d) => d.currentDailyLimit,
      ]);

      remainingBalance =
          _readDouble(databaseProvider, < dynamic Function(dynamic) >[
        (dynamic d) => d.remainingBalance,
        (dynamic d) => d.currentBalance,
        (dynamic d) => d.balance,
        (dynamic d) => d.monthlyBalance?.remainingBalance,
        (dynamic d) => d.monthlyBalance?.balance,
        (dynamic d) => d.currentMonthlyBalance?.remainingBalance,
        (dynamic d) => d.currentMonthlyBalance?.balance,
      ]);

      monthlyBudget =
          _readDouble(databaseProvider, < dynamic Function(dynamic) >[
        (dynamic d) => d.initialBalance,
        (dynamic d) => d.monthlyBudget,
        (dynamic d) => d.totalBalance,
        (dynamic d) => d.budget,
        (dynamic d) => d.monthlyBalance?.initialBalance,
        (dynamic d) => d.monthlyBalance?.totalBalance,
        (dynamic d) => d.monthlyBalance?.amount,
        (dynamic d) => d.currentMonthlyBalance?.initialBalance,
        (dynamic d) => d.currentMonthlyBalance?.amount,
      ]);
    }

    double thisMonthSpent = 0.0;
    for (final NormalizedExpense e in allExpenses) {
      if (e.date.year == now.year && e.date.month == now.month) {
        thisMonthSpent += e.totalAmount;
      }
    }

    final int daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final int remainingDaysInMonth = math.max(1, daysInMonth - now.day + 1);

    double resolvedMonthlyBudget = monthlyBudget ?? 0.0;
    double resolvedRemaining = remainingBalance ?? 0.0;

    if (resolvedMonthlyBudget <= 0 && resolvedRemaining > 0) {
      resolvedMonthlyBudget = resolvedRemaining + thisMonthSpent;
    } else if (resolvedRemaining <= 0 && resolvedMonthlyBudget > 0) {
      resolvedRemaining = math.max(0.0, resolvedMonthlyBudget - thisMonthSpent);
    }

    double resolvedDailyLimit = dailyLimit ?? 0.0;
    if (resolvedDailyLimit <= 0) {
      if (resolvedRemaining > 0) {
        resolvedDailyLimit = resolvedRemaining / remainingDaysInMonth;
      } else if (resolvedMonthlyBudget > 0) {
        resolvedDailyLimit = resolvedMonthlyBudget / daysInMonth;
      }
    }

    return (
      dailyLimit: resolvedDailyLimit,
      monthlyBudget: resolvedMonthlyBudget,
      remainingBalance: resolvedRemaining,
    );
  }

  static ({
    DateTime currentStart,
    DateTime currentEnd,
    DateTime previousStart,
    DateTime previousEnd,
    int elapsedDays,
  }) _resolvePeriodRanges({
    required AnalyticsFilterPeriod period,
    required DateTime anchor,
  }) {
    final DateTime dayStart = DateTime(anchor.year, anchor.month, anchor.day);

    switch (period) {
      case AnalyticsFilterPeriod.today:
      case AnalyticsFilterPeriod.customDate:
        final DateTime currentStart = dayStart;
        final DateTime currentEnd = dayStart.add(const Duration(days: 1));
        final DateTime previousStart =
            dayStart.subtract(const Duration(days: 1));
        final DateTime previousEnd = currentStart;
        return (
          currentStart: currentStart,
          currentEnd: currentEnd,
          previousStart: previousStart,
          previousEnd: previousEnd,
          elapsedDays: 1,
        );

      case AnalyticsFilterPeriod.thisMonth:
        final DateTime currentStart = DateTime(anchor.year, anchor.month, 1);
        final DateTime currentEnd = DateTime(anchor.year, anchor.month + 1, 1);
        final DateTime previousStart =
            DateTime(anchor.year, anchor.month - 1, 1);
        final DateTime previousEnd = currentStart;
        final DateTime now = DateTime.now();
        final int elapsedDays =
            (anchor.year == now.year && anchor.month == now.month)
                ? math.max(1, now.day)
                : DateUtils.getDaysInMonth(anchor.year, anchor.month);
        return (
          currentStart: currentStart,
          currentEnd: currentEnd,
          previousStart: previousStart,
          previousEnd: previousEnd,
          elapsedDays: elapsedDays,
        );

      case AnalyticsFilterPeriod.sixMonths:
        final DateTime currentStart =
            DateTime(anchor.year, anchor.month - 5, 1);
        final DateTime currentEnd = DateTime(anchor.year, anchor.month + 1, 1);
        final DateTime previousStart =
            DateTime(anchor.year, anchor.month - 11, 1);
        final DateTime previousEnd = currentStart;
        final int elapsedDays =
            math.max(1, currentEnd.difference(currentStart).inDays);
        return (
          currentStart: currentStart,
          currentEnd: currentEnd,
          previousStart: previousStart,
          previousEnd: previousEnd,
          elapsedDays: elapsedDays,
        );
    }
  }

  static List< AllocationSlice > _buildSlices({
    required List< NormalizedExpense > current,
    required List< NormalizedExpense > previous,
    required bool byCategory,
  }) {
    final Map< String, List< NormalizedExpense > > groupedCurrent =
        < String, List< NormalizedExpense > >{};
    final Map< String, double > groupedPreviousAmount = < String, double >{};

    String keyOf(NormalizedExpense e) =>
        byCategory ? e.autoCategory : e.title.trim().toLowerCase();

    for (final NormalizedExpense item in current) {
      final String key = keyOf(item);
      groupedCurrent.putIfAbsent(key, () => < NormalizedExpense >[]).add(item);
    }

    for (final NormalizedExpense item in previous) {
      final String key = keyOf(item);
      groupedPreviousAmount[key] =
          (groupedPreviousAmount[key] ?? 0.0) + item.totalAmount;
    }

    final List< MapEntry< String, List< NormalizedExpense > > > entries =
        groupedCurrent.entries.toList();

    entries.sort(
      (
        MapEntry< String, List< NormalizedExpense > > a,
        MapEntry< String, List< NormalizedExpense > > b,
      ) {
        double sumA = 0.0;
        for (final NormalizedExpense e in a.value) {
          sumA += e.totalAmount;
        }
        double sumB = 0.0;
        for (final NormalizedExpense e in b.value) {
          sumB += e.totalAmount;
        }
        return sumB.compareTo(sumA);
      },
    );

    const List< Color > palette = ForestAnalyticsPalette.chartSegments;
    final List< AllocationSlice > slices = < AllocationSlice >[];

    for (int i = 0; i < entries.length; i++) {
      final String key = entries[i].key;
      final List< NormalizedExpense > items = entries[i].value;
      double totalAmount = 0.0;
      int totalQty = 0;
      for (final NormalizedExpense e in items) {
        totalAmount += e.totalAmount;
        totalQty += e.quantity;
      }
      final NormalizedExpense first = items.first;

      final String displayTitle =
          byCategory ? first.autoCategory : _toTitleCase(first.title);
      final IconData icon =
          byCategory ? first.categoryIcon : Icons.receipt_long_outlined;

      slices.add(
        AllocationSlice(
          id: key,
          title: displayTitle,
          amount: totalAmount,
          previousAmount: groupedPreviousAmount[key] ?? 0.0,
          totalQuantity: totalQty,
          transactionCount: items.length,
          icon: icon,
          color: palette[i % palette.length],
          latestDate: first.date,
        ),
      );
    }

    return slices;
  }

  static List< SpendingBarPoint > _buildTrendSeries({
    required List< NormalizedExpense > allExpenses,
    required AnalyticsFilterPeriod period,
    required DateTime anchor,
    required double dailyLimit,
  }) {
    const List< String > dayNames = < String >[
      'Sen',
      'Sel',
      'Rab',
      'Kam',
      'Jum',
      'Sab',
      'Min',
    ];
    const List< String > monthNames = < String >[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    if (period == AnalyticsFilterPeriod.today ||
        period == AnalyticsFilterPeriod.customDate) {
      final DateTime baseDay = DateTime(anchor.year, anchor.month, anchor.day);
      final List< SpendingBarPoint > points = < SpendingBarPoint >[];

      for (int i = 6; i >= 0; i--) {
        final DateTime d = baseDay.subtract(Duration(days: i));
        final DateTime nextD = d.add(const Duration(days: 1));
        double spent = 0.0;
        int txCount = 0;
        for (final NormalizedExpense e in allExpenses) {
          if (!e.date.isBefore(d) && e.date.isBefore(nextD)) {
            spent += e.totalAmount;
            txCount++;
          }
        }
        final String label = i == 0 ? 'Hari Ini' : dayNames[d.weekday - 1];
        final String fullLabel =
            d.day.toString().padLeft(2, '0') + ' ' + monthNames[d.month - 1];

        points.add(
          SpendingBarPoint(
            label: label,
            fullDateLabel: fullLabel,
            spent: spent,
            safeBenchmark: dailyLimit,
            transactionCount: txCount,
            isCurrentHighlight: i == 0,
          ),
        );
      }
      return points;
    } else if (period == AnalyticsFilterPeriod.thisMonth) {
      final int daysInMonth =
          DateUtils.getDaysInMonth(anchor.year, anchor.month);
      final List< SpendingBarPoint > points = < SpendingBarPoint >[];
      final DateTime now = DateTime.now();

      int startDay = 1;
      int weekIndex = 1;
      while (startDay <= daysInMonth) {
        final int endDay = math.min(startDay + 6, daysInMonth);
        final int bucketDays = endDay - startDay + 1;
        final DateTime bucketStart =
            DateTime(anchor.year, anchor.month, startDay);
        final DateTime bucketEnd = DateTime(anchor.year, anchor.month, endDay)
            .add(const Duration(days: 1));

        double spent = 0.0;
        int txCount = 0;
        for (final NormalizedExpense e in allExpenses) {
          if (!e.date.isBefore(bucketStart) && e.date.isBefore(bucketEnd)) {
            spent += e.totalAmount;
            txCount++;
          }
        }

        final bool isCurrentWeek = anchor.year == now.year &&
            anchor.month == now.month &&
            now.day >= startDay &&
            now.day <= endDay;

        points.add(
          SpendingBarPoint(
            label: 'Mgg ' + weekIndex.toString(),
            fullDateLabel: startDay.toString() +
                '-' +
                endDay.toString() +
                ' ' +
                monthNames[anchor.month - 1],
            spent: spent,
            safeBenchmark: dailyLimit > 0 ? dailyLimit * bucketDays : 0,
            transactionCount: txCount,
            isCurrentHighlight: isCurrentWeek,
          ),
        );

        startDay = endDay + 1;
        weekIndex++;
      }
      return points;
    } else {
      final List< SpendingBarPoint > points = < SpendingBarPoint >[];
      for (int i = 5; i >= 0; i--) {
        final DateTime mDate = DateTime(anchor.year, anchor.month - i, 1);
        final DateTime mNext = DateTime(mDate.year, mDate.month + 1, 1);
        final int daysInM = DateUtils.getDaysInMonth(mDate.year, mDate.month);

        double spent = 0.0;
        int txCount = 0;
        for (final NormalizedExpense e in allExpenses) {
          if (!e.date.isBefore(mDate) && e.date.isBefore(mNext)) {
            spent += e.totalAmount;
            txCount++;
          }
        }

        points.add(
          SpendingBarPoint(
            label: monthNames[mDate.month - 1],
            fullDateLabel:
                monthNames[mDate.month - 1] + ' ' + mDate.year.toString(),
            spent: spent,
            safeBenchmark: dailyLimit > 0 ? dailyLimit * daysInM : 0,
            transactionCount: txCount,
            isCurrentHighlight: i == 0,
          ),
        );
      }
      return points;
    }
  }

  static ({String categoryName, IconData icon}) _classifyItem(String rawTitle) {
    final String lower = rawTitle.toLowerCase();

    if (_matchesAny(lower, const < String >[
      'nasi',
      'ayam',
      'gorengan',
      'mie',
      'bakso',
      'soto',
      'makan',
      'warteg',
      'padang',
      'roti',
      'kue',
      'snack',
      'jajan',
      'telur',
      'ikan',
      'sayur',
      'bubur',
      'sate',
      'geprek',
      'pecel',
      'seblak',
      'martabak',
    ])) {
      return (
        categoryName: 'Makanan & Jajanan',
        icon: Icons.restaurant_outlined,
      );
    }

    if (_matchesAny(lower, const < String >[
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
      'galon',
    ])) {
      return (
        categoryName: 'Minuman & Kafe',
        icon: Icons.local_cafe_outlined,
      );
    }

    if (_matchesAny(lower, const < String >[
      'bensin',
      'pertalite',
      'pertamax',
      'parkir',
      'gojek',
      'grab',
      'maxim',
      'ojol',
      'tol',
      'kereta',
      'bus',
      'servis',
      'oli',
      'ban',
    ])) {
      return (
        categoryName: 'Transportasi',
        icon: Icons.directions_car_outlined,
      );
    }

    if (_matchesAny(lower, const < String >[
      'listrik',
      'token',
      'kuota',
      'pulsa',
      'wifi',
      'internet',
      'kos',
      'sewa',
      'pdam',
      'langganan',
      'spotify',
      'netflix',
    ])) {
      return (
        categoryName: 'Tagihan & Utilitas',
        icon: Icons.bolt_outlined,
      );
    }

    if (_matchesAny(lower, const < String >[
      'sabun',
      'shampo',
      'odol',
      'deterjen',
      'indomaret',
      'alfamart',
      'belanja',
      'baju',
      'buku',
      'alat',
      'obat',
      'vitamin',
    ])) {
      return (
        categoryName: 'Kebutuhan & Belanja',
        icon: Icons.shopping_bag_outlined,
      );
    }

    return (
      categoryName: 'Pengeluaran Lainnya',
      icon: Icons.receipt_long_outlined,
    );
  }

  static bool _matchesAny(String text, List< String > keywords) {
    for (final String kw in keywords) {
      if (text.contains(kw)) return true;
    }
    return false;
  }

  static String _toTitleCase(String input) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) return 'Transaksi';
    final List< String > words = trimmed.split(RegExp(r'\s+'));
    final List< String > capitalized = < String >[];
    for (final String word in words) {
      if (word.isNotEmpty) {
        capitalized.add(word[0].toUpperCase() + word.substring(1));
      }
    }
    return capitalized.join(' ');
  }

  static String? _readString(
    dynamic target,
    List< dynamic Function(dynamic) > getters,
  ) {
    if (target == null) return null;
    for (final dynamic Function(dynamic) g in getters) {
      try {
        final dynamic res = g(target);
        if (res is String && res.trim().isNotEmpty) {
          return res.trim();
        }
      } catch (_) {}
    }
    return null;
  }

  static double? _readDouble(
    dynamic target,
    List< dynamic Function(dynamic) > getters,
  ) {
    if (target == null) return null;
    for (final dynamic Function(dynamic) g in getters) {
      try {
        final dynamic res = g(target);
        if (res is num && !res.isNaN && !res.isInfinite) {
          return res.toDouble();
        }
      } catch (_) {}
    }
    return null;
  }

  static int? _readInt(
    dynamic target,
    List< dynamic Function(dynamic) > getters,
  ) {
    if (target == null) return null;
    for (final dynamic Function(dynamic) g in getters) {
      try {
        final dynamic res = g(target);
        if (res is int) return res;
        if (res is num) return res.toInt();
      } catch (_) {}
    }
    return null;
  }

  static DateTime? _readDateTime(dynamic target) {
    if (target == null) return null;
    final List< dynamic Function(dynamic) > getters =
        < dynamic Function(dynamic) >[
      (dynamic o) => o.date,
      (dynamic o) => o.timestamp,
      (dynamic o) => o.createdAt,
      (dynamic o) => o.dateTime,
      (dynamic o) => o.time,
    ];
    for (final dynamic Function(dynamic) g in getters) {
      try {
        final dynamic res = g(target);
        if (res is DateTime) return res;
        if (res is String) {
          final DateTime? parsed = DateTime.tryParse(res);
          if (parsed != null) return parsed;
        }
        if (res is int) {
          return DateTime.fromMillisecondsSinceEpoch(res);
        }
      } catch (_) {}
    }
    return null;
  }
}

/// Formatter angka Rupiah yang konsisten dengan tampilan halaman pertama.
class IdrFormatter {
  const IdrFormatter._();

  /// Menghasilkan angka dengan pemisah titik tanpa prefix "Rp", misal: "17.167"
  static String numberOnly(double value) {
    final String absVal = value.abs().round().toString();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < absVal.length; i++) {
      if (i > 0 && (absVal.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(absVal[i]);
    }
    return buffer.toString();
  }

  /// Menghasilkan format lengkap "Rp 17.000" atau "- Rp 17.000"
  static String format(double value, {bool withNegativePrefix = false}) {
    final String formatted = numberOnly(value);
    if ((withNegativePrefix && value > 0) || value < 0) {
      return '- Rp ' + formatted;
    }
    return 'Rp ' + formatted;
  }

  static String compact(double value) {
    final double absVal = value.abs();
    final String prefix = value < 0 ? '-Rp ' : 'Rp ';
    if (absVal >= 1000000000) {
      return prefix + (absVal / 1000000000).toStringAsFixed(1) + 'M';
    } else if (absVal >= 1000000) {
      final double jt = absVal / 1000000;
      final String jtText =
          jt == jt.roundToDouble() ? jt.toStringAsFixed(0) : jt.toStringAsFixed(1);
      return prefix + jtText + 'Jt';
    } else if (absVal >= 1000) {
      return prefix + (absVal / 1000).toStringAsFixed(0) + 'Rb';
    }
    return prefix + absVal.toStringAsFixed(0);
  }

  static String shortDateTime(DateTime dt) {
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
    final String day = dt.day.toString().padLeft(2, '0');
    final String month = months[dt.month - 1];
    final String hour = dt.hour.toString().padLeft(2, '0');
    final String min = dt.minute.toString().padLeft(2, '0');
    return day + ' ' + month + ', ' + hour + ':' + min;
  }
}