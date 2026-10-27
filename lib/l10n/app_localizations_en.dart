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
  String get safeBudgetBiWeekly => 'Safe budget for today based on the cycle';

  @override
  String get safeBudgetMonthly => 'Safe budget for today based on full month';

  @override
  String get totalBalance => 'TOTAL BALANCE';

  @override
  String get tapToReveal => 'Tap to reveal';

  @override
  String get tapToHide => 'Tap to hide';

  @override
  String get analyticsByItem => 'By Item';

  @override
  String get analyticsByCategory => 'By Category';

  @override
  String get analyticsTotalSpent => 'TOTAL SPENT';

  @override
  String get analyticsNoActivity => 'No activity';

  @override
  String get analyticsSingleSource => '1 source';

  @override
  String analyticsMultipleSources(String count) {
    return '$count sources';
  }

  @override
  String get analyticsSpendingPace => 'SPENDING PACE';

  @override
  String analyticsPacePrefix(String date) {
    return 'PACE • $date';
  }

  @override
  String analyticsVsPrev(String delta) {
    return '$delta% vs prev';
  }

  @override
  String get analyticsFullMonth => 'Full Month';

  @override
  String get analyticsBiWeekly => '14 Days';

  @override
  String analyticsUnderSafeLimit(String diff, String limit) {
    return '$diff under safe limit ($limit)';
  }

  @override
  String analyticsOverSafeLimit(String diff, String limit) {
    return '$diff over safe limit ($limit)';
  }

  @override
  String analyticsAvgPerDay(String amount) {
    return 'Avg $amount/day across active period';
  }

  @override
  String get analyticsFilterToday => 'Today';

  @override
  String get analyticsFilterThisMonth => 'This Month';

  @override
  String get analyticsFilterSixMonths => '6 Months';

  @override
  String get analyticsTopItems => 'Top Items';

  @override
  String get analyticsCategories => 'Categories';

  @override
  String get analyticsEmptyTitle => 'No transactions found.';

  @override
  String get analyticsEmptySubtitle =>
      'Tap + below to add an expense or switch the time filter.';

  @override
  String get analyticsDefaultExpenseName => 'Expense';

  @override
  String get analyticsCategoryFood => 'Food & Meals';

  @override
  String get analyticsCategoryDrinks => 'Drinks & Coffee';

  @override
  String get analyticsCategoryTransport => 'Transport';

  @override
  String get analyticsCategoryBills => 'Bills & Utilities';

  @override
  String get analyticsCategoryHealth => 'Fitness & Health';

  @override
  String get analyticsCategoryShopping => 'Shopping & Lifestyle';

  @override
  String get analyticsCategoryEntertainment => 'Entertainment & Hobbies';

  @override
  String get analyticsCategoryEducation => 'Education & Work';

  @override
  String get analyticsCategoryOthers => 'General & Others';

  @override
  String get analyticsTodayShort => 'Today';

  @override
  String analyticsWeekShort(String number) {
    return 'W$number';
  }

  @override
  String analyticsPercentOfLimit(String percent) {
    return '$percent% of spending limit';
  }

  @override
  String analyticsLimitBenchmark(String amount) {
    return 'Limit $amount';
  }

  @override
  String get sharedReceiptTitle => 'Import Receipt';

  @override
  String get sharedReceiptScanningTitle => 'Reading receipt...';

  @override
  String get sharedReceiptScanningSubtitle =>
      'Extracting merchant, amount, and date on-device';

  @override
  String get sharedReceiptSaveButton => 'Save Transaction';

  @override
  String get sharedReceiptVerifyHint =>
      'Verify any missing details before saving.';

  @override
  String get sharedReceiptIncomingHint =>
      'Detected as incoming money — it will be added to your balance.';

  @override
  String get transactionTypeExpense => 'Expense';

  @override
  String get transactionTypeIncome => 'Income';

  @override
  String get transactionIncomeSubtitle => 'Money in';

  @override
  String dailySpentToday(String amount) {
    return 'Spent today $amount';
  }

  @override
  String dailyLeftToday(String amount) {
    return '$amount left';
  }

  @override
  String dailyOverToday(String amount) {
    return '$amount over';
  }

  @override
  String get balanceInputHint =>
      'Updates automatically as expenses and incoming transfers are recorded.';

  @override
  String get sharedReceiptViewRaw => 'Receipt text';

  @override
  String get sharedReceiptSuggestions => 'Quick name';

  @override
  String get sharedReceiptTotalLabel => 'Total to record';

  @override
  String get sharedReceiptReadError =>
      'Couldn\'t read that file automatically. You can still enter the transaction below.';

  @override
  String analyticsPercentOfTotal(String percent) {
    return '$percent% of total spent';
  }
}
