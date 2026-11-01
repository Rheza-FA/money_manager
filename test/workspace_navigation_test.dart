import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:money_manager/features/receipt_share/services/receipt_share_service.dart';
import 'package:money_manager/l10n/app_localizations.dart';
import 'package:money_manager/models/app_settings.dart';
import 'package:money_manager/models/expense.dart';
import 'package:money_manager/models/monthly_balance.dart';
import 'package:money_manager/providers/database_provider.dart';
import 'package:money_manager/screens/dashboard_screen.dart';
import 'package:money_manager/theme/app_colors.dart';
import 'package:money_manager/widgets/transaction_card.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late ProviderContainer container;
  int instanceSeq = 0;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('neymo_nav_test_');
    isar = await Isar.open(
      [ExpenseSchema, MonthlyBalanceSchema, AppSettingsSchema],
      directory: tempDir.path,
      name: 'neymo_nav_${++instanceSeq}',
    );
    container = ProviderContainer(
      overrides: [isarProvider.overrideWithValue(isar)],
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kReceiptShareChannel, null);
    container.dispose();
    if (isar.isOpen) {
      await isar.close(deleteFromDisk: true);
    }
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget buildTestApp() {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorKey: appNavigatorKey,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const <Locale>[Locale('en', '')],
        home: const DashboardScreen(),
      ),
    );
  }

  void configureMobileViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> pumpIsar(WidgetTester tester, {int rounds = 5}) async {
    for (int i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await tester.pump();
    }
  }

  testWidgets(
    'bottom navigation buttons smoothly animate forward and back, both immediately and after settling on Analytics, while preserving state',
    (WidgetTester tester) async {
      configureMobileViewport(tester);

      try {
        await tester.runAsync(() async {
          final DateTime now = DateTime.now();
          final String monthYear =
              '${now.month.toString().padLeft(2, '0')}-${now.year}';
          await container
              .read(databaseServiceProvider)
              .setMonthlyBalance(monthYear, 2000000);
          await container.read(databaseServiceProvider).saveExpense(
                Expense()
                  ..name = 'Matcha Latte'
                  ..quantity = 1
                  ..price = 35000
                  ..totalAmount = 35000
                  ..date = now,
              );
        });

        await tester.pumpWidget(buildTestApp());
        await pumpIsar(tester);
        await tester.pump(const Duration(milliseconds: 400));

        // Initially on Dashboard: Total Balance visible, Analytics offstage.
        expect(find.text('TOTAL BALANCE'), findsOneWidget);
        expect(find.text('By Item'), findsNothing);

        final Icon homeIconInitial =
            tester.widget<Icon>(find.byIcon(Icons.home_filled));
        final Icon analyticsIconInitial =
            tester.widget<Icon>(find.byIcon(Icons.pie_chart_rounded));
        expect(homeIconInitial.color, AppColors.white);
        expect(analyticsIconInitial.color, AppColors.greyText);

        // 1. Tap Analytics button -> mid-flight reversal test (immediate tap back).
        await tester.tap(find.byIcon(Icons.pie_chart_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));

        // Mid-flight: both icons smoothly interpolate between greyText and white.
        final Icon homeIconMid =
            tester.widget<Icon>(find.byIcon(Icons.home_filled));
        expect(homeIconMid.color, isNot(equals(AppColors.white)));
        expect(homeIconMid.color, isNot(equals(AppColors.greyText)));

        // Immediately tap Home mid-flight -> smoothly reverses back to Dashboard.
        await tester.tap(find.byIcon(Icons.home_filled));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('TOTAL BALANCE'), findsOneWidget);
        expect(find.text('By Item'), findsNothing);

        // 2. Tap Analytics button and let Analytics completely settle for several seconds.
        await tester.tap(find.byIcon(Icons.pie_chart_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(seconds: 3));

        expect(find.text('By Item'), findsOneWidget);
        expect(find.text('TOTAL BALANCE'), findsNothing);
        expect(
          tester.widget<Icon>(find.byIcon(Icons.pie_chart_rounded)).color,
          AppColors.white,
        );
        expect(
          tester.widget<Icon>(find.byIcon(Icons.home_filled)).color,
          AppColors.greyText,
        );

        // Switch Analytics mode to By Category to verify state preservation across tabs.
        await tester.tap(find.text('By Category'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Categories'), findsOneWidget);

        // Now tap Home button after settling -> smoothly transitions back to Dashboard.
        await tester.tap(find.byIcon(Icons.home_filled));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('TOTAL BALANCE'), findsOneWidget);
        expect(find.text('By Item'), findsNothing);
        expect(
          tester.widget<Icon>(find.byIcon(Icons.home_filled)).color,
          AppColors.white,
        );

        // Return to Analytics -> By Category selection is preserved intact.
        await tester.tap(find.byIcon(Icons.pie_chart_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Categories'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpIsar(tester, rounds: 3);
      }
    },
  );

  testWidgets(
    'horizontal swipe gestures transition cleanly in both directions and system back returns from Analytics to Dashboard',
    (WidgetTester tester) async {
      configureMobileViewport(tester);

      try {
        await tester.pumpWidget(buildTestApp());
        await pumpIsar(tester);
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('TOTAL BALANCE'), findsOneWidget);

        // Swipe right-to-left on Dashboard -> glides to Analytics.
        await tester.fling(
          find.byType(PageView),
          const Offset(-320, 0),
          1200,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('By Item'), findsOneWidget);
        expect(find.text('TOTAL BALANCE'), findsNothing);

        // Swipe left-to-right on Analytics -> glides back to Dashboard.
        await tester.fling(
          find.byType(PageView),
          const Offset(320, 0),
          1200,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('TOTAL BALANCE'), findsOneWidget);
        expect(find.text('By Item'), findsNothing);

        // Swipe to Analytics again, then trigger system back (maybePop) -> returns to Dashboard without popping root route.
        await tester.fling(
          find.byType(PageView),
          const Offset(-320, 0),
          1200,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('By Item'), findsOneWidget);

        final bool popped = await appNavigatorKey.currentState!.maybePop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(popped, isTrue);
        expect(find.text('TOTAL BALANCE'), findsOneWidget);
        expect(find.byType(DashboardScreen), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpIsar(tester, rounds: 3);
      }
    },
  );

  testWidgets(
    'swipe-to-delete on TransactionCard and + InputBottomSheet continue working without gesture conflict',
    (WidgetTester tester) async {
      configureMobileViewport(tester);

      try {
        await tester.runAsync(() async {
          await container.read(databaseServiceProvider).saveExpense(
                Expense()
                  ..name = 'Nasi Goreng'
                  ..quantity = 1
                  ..price = 25000
                  ..totalAmount = 25000
                  ..date = DateTime.now(),
              );
        });

        await tester.pumpWidget(buildTestApp());
        await pumpIsar(tester);
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(TransactionCard), findsOneWidget);
        expect(find.text('Nasi Goreng'), findsOneWidget);

        // Scroll list into clear view above the floating bottom bar, then swipe right-to-left to delete.
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -220));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await tester.drag(find.byType(TransactionCard), const Offset(-400, 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await pumpIsar(tester);

        expect(find.text('Nasi Goreng'), findsNothing);
        expect(find.text('TOTAL BALANCE'), findsOneWidget);

        // Tap '+' button on bottom navigation pill opens InputBottomSheet cleanly.
        await tester.tap(find.byIcon(Icons.add_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Save Data'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpIsar(tester, rounds: 3);
      }
    },
  );
}
