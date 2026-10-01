import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart';
import 'database_provider.dart';

enum TimeFilter { daily, monthly, sixMonths, yearly, customDate }

class TimeFilterNotifier extends Notifier<TimeFilter> {
  @override
  TimeFilter build() => TimeFilter.monthly;
  void setFilter(TimeFilter newFilter) => state = newFilter;
}

final timeFilterProvider = NotifierProvider<TimeFilterNotifier, TimeFilter>(TimeFilterNotifier.new);

// FIX: Menggunakan NotifierProvider modern pengganti StateProvider
class CustomDateNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;
  void setDate(DateTime? date) => state = date;
}

final customDateProvider = NotifierProvider<CustomDateNotifier, DateTime?>(CustomDateNotifier.new);

final filteredExpensesProvider = Provider<List<Expense>>((ref) {
  final filter = ref.watch(timeFilterProvider);
  final allExpensesAsync = ref.watch(expenseListProvider);
  final customDate = ref.watch(customDateProvider);
  
  if (allExpensesAsync.isLoading || !allExpensesAsync.hasValue) return [];
  
  final expenses = allExpensesAsync.value!;
  final now = DateTime.now();

  return expenses.where((e) {
    return switch (filter) {
      TimeFilter.daily => e.date.year == now.year && e.date.month == now.month && e.date.day == now.day,
      TimeFilter.monthly => e.date.year == now.year && e.date.month == now.month,
      TimeFilter.sixMonths => e.date.isAfter(DateTime(now.year, now.month - 6, now.day)),
      TimeFilter.yearly => e.date.year == now.year,
      TimeFilter.customDate => customDate != null 
          ? (e.date.year == customDate.year && e.date.month == customDate.month && e.date.day == customDate.day)
          : false,
    };
  }).toList();
});

final filteredTotalExpenseProvider = Provider<double>((ref) {
  final filteredList = ref.watch(filteredExpensesProvider);
  return filteredList.fold(0.0, (sum, item) => sum + item.totalAmount);
});