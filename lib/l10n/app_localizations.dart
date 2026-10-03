import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Header title for the overview section
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// Header title for the transactions list
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// Filter tab label for today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// Filter tab label for this month
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonth;

  /// Filter tab label for six months
  ///
  /// In en, this message translates to:
  /// **'6 Months'**
  String get sixMonths;

  /// Filter tab label for this year
  ///
  /// In en, this message translates to:
  /// **'This Year'**
  String get thisYear;

  /// Empty state message when there are no transactions
  ///
  /// In en, this message translates to:
  /// **'No transactions found.'**
  String get noTransactions;

  /// Bottom sheet tab label for adding an expense
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expenseTab;

  /// Bottom sheet tab label for setting the main balance
  ///
  /// In en, this message translates to:
  /// **'Set Balance'**
  String get setBalanceTab;

  /// Bottom sheet title when editing an existing transaction
  ///
  /// In en, this message translates to:
  /// **'Edit Transaction'**
  String get editTransaction;

  /// Button text to save a new entry
  ///
  /// In en, this message translates to:
  /// **'Save Data'**
  String get saveData;

  /// Button text to update an existing entry
  ///
  /// In en, this message translates to:
  /// **'Update Data'**
  String get updateData;

  /// Text field hint for the item name
  ///
  /// In en, this message translates to:
  /// **'Item Name'**
  String get itemName;

  /// Text field hint for the item quantity
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get quantity;

  /// Text field hint for the unit price
  ///
  /// In en, this message translates to:
  /// **'Unit Price (Rp)'**
  String get unitPrice;

  /// Label above the main balance input field
  ///
  /// In en, this message translates to:
  /// **'Main Balance This Month'**
  String get mainBalanceLabel;

  /// Text field hint for the total balance
  ///
  /// In en, this message translates to:
  /// **'Total Balance (Rp)'**
  String get totalBalanceInput;

  /// Card header label for daily limit
  ///
  /// In en, this message translates to:
  /// **'DAILY LIMIT'**
  String get dailyLimit;

  /// Toggle button text for bi-weekly budgeting
  ///
  /// In en, this message translates to:
  /// **'14 Days'**
  String get fourteenDays;

  /// Toggle button text for full month budgeting
  ///
  /// In en, this message translates to:
  /// **'Full Month'**
  String get fullMonth;

  /// Footer context text for bi-weekly budget
  ///
  /// In en, this message translates to:
  /// **'Safe budget for today based on the cycle'**
  String get safeBudgetBiWeekly;

  /// Footer context text for monthly budget
  ///
  /// In en, this message translates to:
  /// **'Safe budget for today based on full month'**
  String get safeBudgetMonthly;

  /// Header label inside the main balance circle
  ///
  /// In en, this message translates to:
  /// **'TOTAL BALANCE'**
  String get totalBalance;

  /// Affordance text guiding the user to show their balance
  ///
  /// In en, this message translates to:
  /// **'Tap to reveal'**
  String get tapToReveal;

  /// Affordance text guiding the user to hide their balance
  ///
  /// In en, this message translates to:
  /// **'Tap to hide'**
  String get tapToHide;

  /// Toggle label to group analytics by item
  ///
  /// In en, this message translates to:
  /// **'By Item'**
  String get analyticsByItem;

  /// Toggle label to group analytics by category
  ///
  /// In en, this message translates to:
  /// **'By Category'**
  String get analyticsByCategory;

  /// Header label inside the analytics donut chart
  ///
  /// In en, this message translates to:
  /// **'TOTAL SPENT'**
  String get analyticsTotalSpent;

  /// Badge label when there are no expenses
  ///
  /// In en, this message translates to:
  /// **'No activity'**
  String get analyticsNoActivity;

  /// Badge label when there is 1 expense group
  ///
  /// In en, this message translates to:
  /// **'1 source'**
  String get analyticsSingleSource;

  /// Badge label showing total number of expense groups
  ///
  /// In en, this message translates to:
  /// **'{count} sources'**
  String analyticsMultipleSources(String count);

  /// Header label for the spending pace card
  ///
  /// In en, this message translates to:
  /// **'SPENDING PACE'**
  String get analyticsSpendingPace;

  /// Header label showing pace for a selected date or period
  ///
  /// In en, this message translates to:
  /// **'PACE • {date}'**
  String analyticsPacePrefix(String date);

  /// Comparison badge against previous period
  ///
  /// In en, this message translates to:
  /// **'{delta}% vs prev'**
  String analyticsVsPrev(String delta);

  /// Badge label for full month mode in analytics
  ///
  /// In en, this message translates to:
  /// **'Full Month'**
  String get analyticsFullMonth;

  /// Badge label for 14-day bi-weekly mode in analytics
  ///
  /// In en, this message translates to:
  /// **'14 Days'**
  String get analyticsBiWeekly;

  /// Status line when spending is below the safe limit
  ///
  /// In en, this message translates to:
  /// **'{diff} under safe limit ({limit})'**
  String analyticsUnderSafeLimit(String diff, String limit);

  /// Status line when spending exceeds the safe limit
  ///
  /// In en, this message translates to:
  /// **'{diff} over safe limit ({limit})'**
  String analyticsOverSafeLimit(String diff, String limit);

  /// Fallback status line showing average daily spending
  ///
  /// In en, this message translates to:
  /// **'Avg {amount}/day across active period'**
  String analyticsAvgPerDay(String amount);

  /// Analytics filter pill for today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get analyticsFilterToday;

  /// Analytics filter pill for this month
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get analyticsFilterThisMonth;

  /// Analytics filter pill for six months
  ///
  /// In en, this message translates to:
  /// **'6 Months'**
  String get analyticsFilterSixMonths;

  /// Section title for item breakdown list
  ///
  /// In en, this message translates to:
  /// **'Top Items'**
  String get analyticsTopItems;

  /// Section title for category breakdown list
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get analyticsCategories;

  /// Empty state title in analytics breakdown
  ///
  /// In en, this message translates to:
  /// **'No transactions found.'**
  String get analyticsEmptyTitle;

  /// Empty state subtitle in analytics breakdown
  ///
  /// In en, this message translates to:
  /// **'Tap + below to add an expense or switch the time filter.'**
  String get analyticsEmptySubtitle;

  /// Default fallback title for unnamed expense
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get analyticsDefaultExpenseName;

  /// Category label for food and meals
  ///
  /// In en, this message translates to:
  /// **'Food & Meals'**
  String get analyticsCategoryFood;

  /// Category label for drinks and coffee
  ///
  /// In en, this message translates to:
  /// **'Drinks & Coffee'**
  String get analyticsCategoryDrinks;

  /// Category label for transportation
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get analyticsCategoryTransport;

  /// Category label for bills and utilities
  ///
  /// In en, this message translates to:
  /// **'Bills & Utilities'**
  String get analyticsCategoryBills;

  /// Category label for general expenses
  ///
  /// In en, this message translates to:
  /// **'General & Others'**
  String get analyticsCategoryOthers;

  /// Short bar label for today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get analyticsTodayShort;

  /// Short bar label for week number
  ///
  /// In en, this message translates to:
  /// **'W{number}'**
  String analyticsWeekShort(String number);

  /// Label showing percentage of spending limit used by an item or category
  ///
  /// In en, this message translates to:
  /// **'{percent}% of spending limit'**
  String analyticsPercentOfLimit(String percent);

  /// Label showing the active spending limit benchmark on the card
  ///
  /// In en, this message translates to:
  /// **'Limit {amount}'**
  String analyticsLimitBenchmark(String amount);

  /// Fallback label when spending limit is not set
  ///
  /// In en, this message translates to:
  /// **'{percent}% of total spent'**
  String analyticsPercentOfTotal(String percent);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
