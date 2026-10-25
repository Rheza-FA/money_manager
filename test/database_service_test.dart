import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:money_manager/models/app_settings.dart';
import 'package:money_manager/models/expense.dart';
import 'package:money_manager/models/monthly_balance.dart';
import 'package:money_manager/providers/database_provider.dart';

/// Persistence contract tests for [DatabaseService] and the stream providers,
/// executed against the real Isar native core (downloaded on first run).
void main() {
  late Directory tempDir;
  late Isar isar;
  late ProviderContainer container;

  Expense buildExpense(String name, int qty, double price, DateTime date) =>
      Expense()
        ..name = name
        ..quantity = qty
        ..price = price
        ..totalAmount = qty * price
        ..date = date;

  // Riverpod 3 pauses providers that have no listeners, so a subscription is
  // held (as widgets do through ref.watch) before awaiting the first value.
  Future<T> readAsync<T>(ProviderListenable<Future<T>> provider) =>
      container.listen(provider, (_, _) {}).read();

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('money_manager_isar_');
    isar = await Isar.open(
      [ExpenseSchema, MonthlyBalanceSchema, AppSettingsSchema],
      directory: tempDir.path,
    );
    container = ProviderContainer(
      overrides: [isarProvider.overrideWithValue(isar)],
    );
  });

  tearDown(() async {
    container.dispose();
    await isar.close(deleteFromDisk: true);
    await tempDir.delete(recursive: true);
  });

  test('saveExpense inserts and updates, deleteExpense removes', () async {
    final db = container.read(databaseServiceProvider);

    final older = buildExpense('Nasi goreng', 2, 15000, DateTime(2026, 10, 1));
    final newer = buildExpense('Kopi susu', 1, 18000, DateTime(2026, 10, 3));
    await db.saveExpense(older);
    await db.saveExpense(newer);
    expect(older.id, isNot(Isar.autoIncrement));

    // Update an existing row by id (edit flow in InputBottomSheet).
    await db.saveExpense(older
      ..quantity = 3
      ..totalAmount = 3 * 15000);
    expect(await isar.expenses.count(), 2);
    expect((await isar.expenses.get(older.id))!.totalAmount, 45000);

    await db.deleteExpense(newer.id);
    expect(await isar.expenses.get(newer.id), isNull);
  });

  test('expenseListProvider emits expenses sorted by date descending', () async {
    final db = container.read(databaseServiceProvider);
    await db.saveExpense(buildExpense('A', 1, 1000, DateTime(2026, 9, 28)));
    await db.saveExpense(buildExpense('B', 1, 2000, DateTime(2026, 10, 14)));
    await db.saveExpense(buildExpense('C', 1, 3000, DateTime(2026, 10, 1)));

    final expenses = await readAsync(expenseListProvider.future);
    expect(expenses.map((e) => e.name), ['B', 'C', 'A']);
  });

  test('setMonthlyBalance upserts a single row per month', () async {
    final db = container.read(databaseServiceProvider);
    final now = DateTime.now();
    final monthYear = '${now.month.toString().padLeft(2, '0')}-${now.year}';

    await db.setMonthlyBalance(monthYear, 3000000);
    await db.setMonthlyBalance(monthYear, 4500000);
    await db.setMonthlyBalance('01-2000', 100);

    expect(await isar.monthlyBalances.count(), 2);
    final current = await readAsync(currentMonthBalanceProvider.future);
    expect(current?.monthYear, monthYear);
    expect(current?.balance, 4500000);
  });

  test('toggleSpendingMode persists the AppSettings singleton', () async {
    final db = container.read(databaseServiceProvider);
    expect(await isar.appSettings.get(0), isNull);

    await db.toggleSpendingMode(true);
    await db.toggleSpendingMode(true);
    expect(await isar.appSettings.count(), 1);
    expect(
      (await readAsync(appSettingsProvider.future))?.isBiWeeklyMode,
      isTrue,
    );

    await db.toggleSpendingMode(false);
    expect((await isar.appSettings.get(0))?.isBiWeeklyMode, isFalse);
  });
}
