import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_provider.dart';

final maxDailySpendingProvider = Provider<double>((ref) {
  final expensesAsync = ref.watch(expenseListProvider);
  final balanceAsync = ref.watch(currentMonthBalanceProvider);
  final settingsAsync = ref.watch(appSettingsProvider);

  if (expensesAsync.isLoading || balanceAsync.isLoading) return 0.0;

  final expenses = expensesAsync.value ?? [];
  final currentBalance = balanceAsync.value?.balance ?? 0.0;
  final isBiWeekly = settingsAsync.value?.isBiWeeklyMode ?? false;
  final now = DateTime.now();

  // Ambil pengeluaran bulan ini
  final currentMonthExpenses = expenses.where((e) => 
      e.date.year == now.year && e.date.month == now.month).toList();

  final totalSpent = currentMonthExpenses.fold(0.0, (sum, item) => sum + item.totalAmount);
  final remainingBalance = currentBalance - totalSpent;

  if (remainingBalance <= 0) return 0.0;

  int remainingDays;

  // LOGIKA ENTERPRISE: Siklus Dinamis Timeproof
  if (isBiWeekly) {
    if (now.day <= 14) {
      // Siklus 1: Tanggal 1 s.d 14
      remainingDays = 14 - now.day + 1;
    } else {
      // Siklus 2: Tanggal 15 s.d Akhir Bulan (Otomatis mendeteksi 28/29/30/31 hari)
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      remainingDays = daysInMonth - now.day + 1;
    }
  } else {
    // Mode Bulanan Penuh
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    remainingDays = daysInMonth - now.day + 1;
  }

  if (remainingDays <= 0) return 0.0; // Fail-safe Divide by Zero
  return remainingBalance / remainingDays;
});