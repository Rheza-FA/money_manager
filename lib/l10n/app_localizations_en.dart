// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get overview => 'Overview';

  @override
  String get transactions => 'Transactions';

  @override
  String get today => 'Today';

  @override
  String get thisMonth => 'This Month';

  @override
  String get sixMonths => '6 Months';

  @override
  String get thisYear => 'This Year';

  @override
  String get noTransactions => 'No transactions found.';

  @override
  String get expenseTab => 'Expense';

  @override
  String get setBalanceTab => 'Set Balance';

  @override
  String get editTransaction => 'Edit Transaction';

  @override
  String get saveData => 'Save Data';

  @override
  String get updateData => 'Update Data';

  @override
  String get itemName => 'Item Name';

  @override
  String get quantity => 'Qty';

  @override
  String get unitPrice => 'Unit Price (Rp)';

  @override
  String get mainBalanceLabel => 'Main Balance This Month';

  @override
  String get totalBalanceInput => 'Total Balance (Rp)';

  @override
  String get dailyLimit => 'DAILY LIMIT';

  @override
  String get fourteenDays => '14 Days';

  @override
  String get fullMonth => 'Full Month';

  @override
  String get safeBudgetBiWeekly =>
      'Safe budget for today based on current cycle';

  @override
  String get safeBudgetMonthly => 'Safe budget for today based on full month';

  @override
  String get totalBalance => 'TOTAL BALANCE';

  @override
  String get tapToReveal => 'Tap to reveal';

  @override
  String get tapToHide => 'Tap to hide';
}
