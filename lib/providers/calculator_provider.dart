import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_provider.dart';

final maxDailySpendingProvider = Provider<double>((ref) {
  final expensesAsync = ref.watch(expenseListProvider);
  final balanceAsync = ref.watch(currentMonthBalanceProvider);

  // Jika database masih memuat, kembalikan 0
  if (expensesAsync.isLoading || balanceAsync.isLoading) return 0.0;

  final expenses = expensesAsync.value ?? [];
  final currentBalance = balanceAsync.value?.balance ?? 0.0;
  final now = DateTime.now();

  // 1. Filter pengeluaran yang HANYA terjadi di bulan ini
  final currentMonthExpenses = expenses.where((e) => 
      e.date.year == now.year && e.date.month == now.month).toList();

  // 2. Kalkulasi total yang sudah dihabiskan bulan ini (MENGGUNAKAN totalAmount)
  final totalSpent = currentMonthExpenses.fold(0.0, (sum, item) => sum + item.totalAmount);
  
  // 3. Sisa saldo bulanan
  final remainingBalance = currentBalance - totalSpent;

  // 4. Kalkulasi sisa hari dalam bulan ini (termasuk hari ini)
  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
  final remainingDays = daysInMonth - now.day + 1;

  // Jika saldo habis atau bulan berakhir, cegah nilai minus/infinity
  if (remainingDays <= 0 || remainingBalance <= 0) return 0.0;

  return remainingBalance / remainingDays;
});