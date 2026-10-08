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

  // Jika user belum menetapkan balance (0), tidak ada limit yang bisa dihitung.
  if (currentBalance <= 0) return 0.0;

  final now = DateTime.now();
  // Titik 00:00 hari ini. Sangat penting untuk mencegah "Shrinking Limit Bug".
  final todayStart = DateTime(now.year, now.month, now.day);
  
  // Algoritma Native Dart: Tepat mencari jumlah hari bulan berjalan tanpa package tambahan.
  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

  // 1. Tentukan Batas Waktu Siklus (Mencegah "Cycle Bleeding")
  DateTime cycleStart;
  int remainingDays;

  if (isBiWeekly) {
    if (now.day <= 14) {
      // Siklus 1: Tanggal 1 s.d 14
      cycleStart = DateTime(now.year, now.month, 1);
      remainingDays = 14 - now.day + 1;
    } else {
      // Siklus 2: Tanggal 15 s.d Akhir Bulan (Akurat mendeteksi 28/29/30/31)
      cycleStart = DateTime(now.year, now.month, 15);
      remainingDays = daysInMonth - now.day + 1;
    }
  } else {
    // Mode Bulanan: Tanggal 1 s.d Akhir Bulan
    cycleStart = DateTime(now.year, now.month, 1);
    remainingDays = daysInMonth - now.day + 1;
  }

  if (remainingDays <= 0) return 0.0; // Fail-safe (Divide by Zero Prevention)

  // 2. Hitung Pengeluaran Historis dalam Siklus, HANYA SEBELUM Hari Ini.
  // Ini menjadikan Daily Limit sebuah "Target Statis" untuk hari berjalan.
  double spentBeforeToday = 0.0;
  for (final e in expenses) {
    // Hitung hanya transaksi yang terjadi >= awal siklus DAN < jam 00:00 hari ini
    if (!e.date.isBefore(cycleStart) && e.date.isBefore(todayStart)) {
      spentBeforeToday += e.totalAmount;
    }
  }

  // 3. Kalkulasi Limit Harian yang Solid
  final remainingBudgetForToday = currentBalance - spentBeforeToday;

  // Jika sisa saldo sudah habis oleh pengeluaran kemarin, limit hari ini 0.
  if (remainingBudgetForToday <= 0) return 0.0;

  return remainingBudgetForToday / remainingDays;
});