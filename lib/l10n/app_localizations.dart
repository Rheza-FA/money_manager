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
  /// **'Safe budget for today based on current cycle'**
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
