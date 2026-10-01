import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../models/expense.dart';
import '../models/monthly_balance.dart';

// Menampung instance utama database
final isarProvider = Provider<Isar>((ref) => throw UnimplementedError());

// Memantau semua pengeluaran dan mengurutkannya dari yang terbaru
final expenseListProvider = StreamProvider<List<Expense>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar.expenses.where().sortByDateDesc().watch(fireImmediately: true);
});

// Memantau saldo utama khusus untuk bulan berjalan
final currentMonthBalanceProvider = StreamProvider<MonthlyBalance?>((ref) {
  final isar = ref.watch(isarProvider);
  final now = DateTime.now();
  final monthYear = "${now.month.toString().padLeft(2, '0')}-${now.year}";
  
  return isar.monthlyBalances
      .where()
      .monthYearEqualTo(monthYear)
      .watch(fireImmediately: true)
      .map((event) => event.isNotEmpty ? event.first : null);
});