import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart';
import 'database_provider.dart';

enum TimeFilter { daily, monthly, sixMonths, yearly }

// 1. Menggunakan NotifierProvider (Standar Modern Riverpod)
class TimeFilterNotifier extends Notifier<TimeFilter> {
  @override
  TimeFilter build() => TimeFilter.monthly;

  // Metode khusus untuk mengubah state secara aman
  void setFilter(TimeFilter newFilter) {
    state = newFilter;
  }
}

final timeFilterProvider = NotifierProvider<TimeFilterNotifier, TimeFilter>(TimeFilterNotifier.new);

// 2. Logika Filter Tanpa Bloat
final filteredExpensesProvider = Provider<List<Expense>>((ref) {
  final filter = ref.watch(timeFilterProvider);
  final allExpensesAsync = ref.watch(expenseListProvider);
  
  if (allExpensesAsync.isLoading || !allExpensesAsync.hasValue) return [];
  
  final expenses = allExpensesAsync.value!;
  final now = DateTime.now();

  return expenses.where((e) {
    // Switch Expression Dart 3: Elegan, cepat, dan anti-bocor (exhaustive)
    return switch (filter) {
      TimeFilter.daily => e.date.year == now.year && e.date.month == now.month && e.date.day == now.day,
      TimeFilter.monthly => e.date.year == now.year && e.date.month == now.month,
      TimeFilter.sixMonths => e.date.isAfter(DateTime(now.year, now.month - 6, now.day)),
      TimeFilter.yearly => e.date.year == now.year,
    };
  }).toList();
});

// 3. Kalkulasi Total
final filteredTotalExpenseProvider = Provider<double>((ref) {
  final filteredList = ref.watch(filteredExpensesProvider);
  return filteredList.fold(0.0, (sum, item) => sum + item.totalAmount);
});