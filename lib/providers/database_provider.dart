import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../models/expense.dart';
import '../models/monthly_balance.dart';
import '../models/app_settings.dart';

class DatabaseService {
  final Isar isar;
  DatabaseService(this.isar);

  // --- CRUD EXPENSE ---
  Future<void> saveExpense(Expense expense) async {
    await isar.writeTxn(() async {
      await isar.expenses.put(expense); // Insert atau Update (jika ID sudah ada)
    });
  }

  Future<void> deleteExpense(int id) async {
    await isar.writeTxn(() async {
      await isar.expenses.delete(id);
    });
  }

  // --- CRUD BALANCE ---
  Future<void> setMonthlyBalance(String monthYear, double balanceAmount) async {
    final balance = MonthlyBalance()
      ..monthYear = monthYear
      ..balance = balanceAmount;

    await isar.writeTxn(() async {
      await isar.monthlyBalances.put(balance);
    });
  }

  // --- SETTINGS ---
  Future<void> toggleSpendingMode(bool isBiWeekly) async {
    final settings = await isar.appSettings.get(0) ?? AppSettings();
    settings.isBiWeeklyMode = isBiWeekly;
    
    await isar.writeTxn(() async {
      await isar.appSettings.put(settings);
    });
  }
}

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService(ref.watch(isarProvider));
});

final isarProvider = Provider<Isar>((ref) => throw UnimplementedError());

final expenseListProvider = StreamProvider<List<Expense>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar.expenses.where().sortByDateDesc().watch(fireImmediately: true);
});

final currentMonthBalanceProvider = StreamProvider<MonthlyBalance?>((ref) {
  final isar = ref.watch(isarProvider);
  final now = DateTime.now();
  final monthYear = "${now.month.toString().padLeft(2, '0')}-${now.year}";
  
  return isar.monthlyBalances.where().monthYearEqualTo(monthYear).watch(fireImmediately: true)
      .map((event) => event.isNotEmpty ? event.first : null);
});

// Memantau perubahan mode limit secara real-time
final appSettingsProvider = StreamProvider<AppSettings?>((ref) {
  final isar = ref.watch(isarProvider);
  return isar.appSettings.watchObject(0, fireImmediately: true);
});