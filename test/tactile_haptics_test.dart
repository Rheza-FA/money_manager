import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:money_manager/features/analytics/widgets/cashflow_comparison_chart.dart';
import 'package:money_manager/features/analytics/widgets/interactive_donut_chart.dart';
import 'package:money_manager/features/receipt_share/services/receipt_share_service.dart';
import 'package:money_manager/l10n/app_localizations.dart';
import 'package:money_manager/models/app_settings.dart';
import 'package:money_manager/models/expense.dart';
import 'package:money_manager/models/monthly_balance.dart';
import 'package:money_manager/providers/database_provider.dart';
import 'package:money_manager/screens/dashboard_screen.dart';
import 'package:money_manager/services/app_haptics.dart';
import 'package:money_manager/widgets/balance_overview_circle.dart';
import 'package:money_manager/widgets/tactile_press.dart';
import 'package:money_manager/widgets/transaction_card.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late ProviderContainer container;
  late List<String> hapticCalls;
  int instanceSeq = 0;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    hapticCalls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      kTactileHapticChannel,
      (MethodCall call) async {
        hapticCalls.add(call.method);
        return null;
      },
    );

    tempDir = await Directory.systemTemp.createTemp('neymo_haptics_test_');
    isar = await Isar.open(
      [
        ExpenseSchema,
        MonthlyBalanceSchema,
        AppSettingsSchema,
      ],
      directory: tempDir.path,
      name: 'neymo_haptics_${++instanceSeq}',
    );
    container = ProviderContainer(
      overrides: [isarProvider.overrideWithValue(isar)],
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kTactileHapticChannel, null);
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

  double readScaleOf(WidgetTester tester, Finder wrapperFinder) {
    final Transform transformWidget = tester.widget<Transform>(
      find.descendant(of: wrapperFinder, matching: find.byType(Transform)).first,
    );
    return transformWidget.transform.storage[0];
  }

  testWidgets(
    'dedicated buttons compress and emit synchronized pressDown + releaseUp on BOTH quick clicks and holds, while Save preempts releaseUp on error/success',
    (WidgetTester tester) async {
      configureMobileViewport(tester);

      try {
        await tester.pumpWidget(buildTestApp());
        await pumpIsar(tester);
        await tester.pump(const Duration(milliseconds: 300));
        hapticCalls.clear();

        final Finder addTactileFinder = find.ancestor(
          of: find.byIcon(Icons.add_rounded),
          matching: find.byType(TactilePress),
        );
        expect(readScaleOf(tester, addTactileFinder), closeTo(1.0, 0.0001));

        // 1. Deliberate hold (>= 160ms) on '+' button: compresses & holds at physical stop,
        // firing ONLY pressDown until finger lifts!
        final Offset addCenter = tester.getCenter(find.byIcon(Icons.add_rounded));
        final TestGesture holdGesture = await tester.startGesture(addCenter);
        await tester.pump();
        expect(hapticCalls, <String>['pressDown']);

        await tester.pump(const Duration(milliseconds: 160));
        expect(hapticCalls, <String>['pressDown']);
        expect(readScaleOf(tester, addTactileFinder), closeTo(0.916, 0.01));

        // Lift finger -> immediate releaseUp + spring return to 1.0!
        await holdGesture.up();
        await tester.pump();
        expect(hapticCalls, <String>['pressDown', 'releaseUp']);

        await tester.pump(const Duration(milliseconds: 350));
        expect(readScaleOf(tester, addTactileFinder), closeTo(1.0, 0.0001));
        expect(find.text('Save Data'), findsOneWidget);

        // 2. Normal quick click (0ms tap) on 'Set Balance' tab -> MUST fire BOTH pressDown AND releaseUp
        // synchronized with full inward compression (72ms) and spring rebound!
        hapticCalls.clear();
        final Finder setBalancePressFinder = find.ancestor(
          of: find.text('Set Balance'),
          matching: find.byType(TactilePress),
        );

        await tester.tap(find.text('Set Balance'));
        await tester.pump();
        expect(hapticCalls, <String>['pressDown']);

        // Mid-compression (40ms): visibly shrinking inward, releaseUp has NOT fired yet!
        await tester.pump(const Duration(milliseconds: 40));
        expect(readScaleOf(tester, setBalancePressFinder), lessThan(0.97));
        expect(hapticCalls, <String>['pressDown']);

        // Bottom of compression stroke reached (40 + 35 = 75ms >= 72ms): releaseUp fires in lockstep!
        await tester.pump(const Duration(milliseconds: 35));
        expect(hapticCalls, <String>['pressDown', 'releaseUp']);

        // Rebound completes cleanly back to 1.0.
        await tester.pump(const Duration(milliseconds: 200));
        expect(readScaleOf(tester, setBalancePressFinder), closeTo(1.0, 0.0001));

        // Quick click back to 'Expense' tab -> also fires ['pressDown', 'releaseUp'].
        hapticCalls.clear();
        await tester.tap(find.text('Expense'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(hapticCalls, <String>['pressDown', 'releaseUp']);

        // 3. Submit empty Expense form -> emits 'pressDown' + 'error' WITHOUT trailing releaseUp clobbering it!
        hapticCalls.clear();
        await tester.tap(find.text('Save Data'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(hapticCalls, <String>['pressDown', 'error']);

        // 4. Fill valid data and submit -> emits 'pressDown' + 'success' WITHOUT trailing releaseUp!
        await tester.enterText(find.byType(TextField).at(0), 'Espresso');
        await tester.enterText(find.byType(TextField).at(2), '28000');
        await tester.pump();

        hapticCalls.clear();
        await tester.tap(find.text('Save Data'));
        await pumpIsar(tester);
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pump(const Duration(milliseconds: 300));
        expect(hapticCalls, <String>['pressDown', 'success']);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpIsar(tester, rounds: 3);
      }
    },
  );

  testWidgets(
    'scrollable components compress and emit two-stage pressDown + releaseUp on quick clicks and holds, but ZERO haptics or scale change when scrolling',
    (WidgetTester tester) async {
      configureMobileViewport(tester);

      try {
        await tester.runAsync(() async {
          final DateTime now = DateTime.now();
          final String monthYear =
              '${now.month.toString().padLeft(2, '0')}-${now.year}';
          await container
              .read(databaseServiceProvider)
              .setMonthlyBalance(monthYear, 3000000);
          await container.read(databaseServiceProvider).saveExpense(
                Expense()
                  ..name = 'Artisan Bread'
                  ..quantity = 1
                  ..price = 45000
                  ..totalAmount = 45000
                  ..date = now,
              );
        });

        await tester.pumpWidget(buildTestApp());
        await pumpIsar(tester);
        await tester.pump(const Duration(milliseconds: 400));
        hapticCalls.clear();

        final Finder circleTapFinder = find.descendant(
          of: find.byType(BalanceOverviewCircle),
          matching: find.byType(TactileTap),
        );
        final Finder cardTapFinder = find.descendant(
          of: find.byType(TransactionCard),
          matching: find.byType(TactileTap),
        );

        // 1. Vertical scroll starting right on BalanceOverviewCircle -> ZERO haptics & scale stays 1.0!
        await tester.drag(
          find.byType(BalanceOverviewCircle),
          const Offset(0, -180),
        );
        await tester.pump();
        expect(readScaleOf(tester, circleTapFinder), closeTo(1.0, 0.0001));
        await tester.pump(const Duration(milliseconds: 250));
        expect(hapticCalls, isEmpty);

        // 2. Vertical scroll starting right on TransactionCard -> ZERO haptics & scale stays 1.0!
        await tester.drag(
          find.byType(TransactionCard),
          const Offset(0, 180),
        );
        await tester.pump();
        expect(readScaleOf(tester, cardTapFinder), closeTo(1.0, 0.0001));
        await tester.pump(const Duration(milliseconds: 250));
        expect(hapticCalls, isEmpty);

        // 3. Normal quick click on BalanceOverviewCircle -> visibly shrinks to 0.965,
        // emits pressDown then releaseUp at 72ms, and springs back to 1.0!
        await tester.tap(find.byType(BalanceOverviewCircle));
        await tester.pump();
        expect(hapticCalls, <String>['pressDown']);
        expect(find.text('• • • • • • •'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 50));
        expect(readScaleOf(tester, circleTapFinder), lessThan(0.98));
        expect(hapticCalls, <String>['pressDown']);

        await tester.pump(const Duration(milliseconds: 30));
        expect(hapticCalls, <String>['pressDown', 'releaseUp']);

        await tester.pump(const Duration(milliseconds: 220));
        expect(readScaleOf(tester, circleTapFinder), closeTo(1.0, 0.0001));

        // 4. Held press (>= 200ms) on BalanceOverviewCircle -> stays compressed at 0.965
        // with ONLY 'pressDown' while held, then 'releaseUp' + spring return on lift!
        hapticCalls.clear();
        final Offset circleCenter =
            tester.getCenter(find.byType(BalanceOverviewCircle));
        final TestGesture holdCircle = await tester.startGesture(circleCenter);
        await tester.pump(const Duration(milliseconds: 110));
        await tester.pump(const Duration(milliseconds: 80));
        expect(hapticCalls, <String>['pressDown']);
        expect(readScaleOf(tester, circleTapFinder), closeTo(0.965, 0.005));

        await holdCircle.up();
        await tester.pump();
        expect(hapticCalls, <String>['pressDown', 'releaseUp']);

        await tester.pump(const Duration(milliseconds: 220));
        expect(readScaleOf(tester, circleTapFinder), closeTo(1.0, 0.0001));

        // 5. Quick click on DailyLimitCard spending mode pill ('Full Month') -> ['pressDown', 'releaseUp'].
        hapticCalls.clear();
        await tester.tap(find.text('Full Month'));
        await pumpIsar(tester);
        await tester.pump(const Duration(milliseconds: 250));
        expect(hapticCalls, <String>['pressDown', 'releaseUp']);

        // 6. Quick click on filter chip ('Today') -> shrinks and emits ['pressDown', 'releaseUp'].
        hapticCalls.clear();
        final Finder todayTapFinder = find.ancestor(
          of: find.text('Today'),
          matching: find.byType(TactileTap),
        );
        await tester.tap(find.text('Today'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        expect(readScaleOf(tester, todayTapFinder), lessThan(0.96));
        expect(hapticCalls, <String>['pressDown']);
        await tester.pump(const Duration(milliseconds: 40));
        expect(hapticCalls, <String>['pressDown', 'releaseUp']);
        await tester.pump(const Duration(milliseconds: 200));
        expect(readScaleOf(tester, todayTapFinder), closeTo(1.0, 0.0001));

        // 7. Quick click on TransactionCard -> shrinks inward (< 1.0, never enlarges!) & emits ['pressDown', 'releaseUp'].
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -220));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        hapticCalls.clear();

        await tester.tap(find.text('Artisan Bread'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 45));
        expect(readScaleOf(tester, cardTapFinder), lessThan(0.985));
        expect(hapticCalls, <String>['pressDown']);
        await tester.pump(const Duration(milliseconds: 35));
        expect(hapticCalls, <String>['pressDown', 'releaseUp']);
        await tester.pump(const Duration(milliseconds: 220));
        expect(readScaleOf(tester, cardTapFinder), closeTo(1.0, 0.0001));
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpIsar(tester, rounds: 3);
      }
    },
  );

  testWidgets(
    'analytics controls shrink and emit pressDown + releaseUp on quick clicks while Donut and Bar charts NEVER vibrate',
    (WidgetTester tester) async {
      configureMobileViewport(tester);

      try {
        await tester.runAsync(() async {
          final DateTime now = DateTime.now();
          final String monthYear =
              '${now.month.toString().padLeft(2, '0')}-${now.year}';
          await container
              .read(databaseServiceProvider)
              .setMonthlyBalance(monthYear, 5000000);
          await container.read(databaseServiceProvider).saveExpense(
                Expense()
                  ..name = 'Cold Brew'
                  ..quantity = 2
                  ..price = 30000
                  ..totalAmount = 60000
                  ..date = now,
              );
          await container.read(databaseServiceProvider).saveExpense(
                Expense()
                  ..name = 'MRT Ticket'
                  ..quantity = 1
                  ..price = 40000
                  ..totalAmount = 40000
                  ..date = now,
              );
        });

        await tester.pumpWidget(buildTestApp());
        await pumpIsar(tester);
        await tester.pump(const Duration(milliseconds: 400));

        // Navigate to Analytics screen via quick click on bottom navigation button -> ['pressDown', 'releaseUp']!
        hapticCalls.clear();
        await tester.tap(find.byIcon(Icons.pie_chart_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(hapticCalls, <String>['pressDown', 'releaseUp']);
        expect(find.byType(InteractiveDonutChart), findsOneWidget);

        // 1. Quick click mode pill ('By Category' then 'By Item') -> ['pressDown', 'releaseUp']!
        hapticCalls.clear();
        await tester.tap(find.text('By Category'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(hapticCalls, <String>['pressDown', 'releaseUp']);

        hapticCalls.clear();
        await tester.tap(find.text('By Item'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(hapticCalls, <String>['pressDown', 'releaseUp']);

        // 2. Tap InteractiveDonutChart ring slice (top-right arc) -> selects slice with ZERO haptics!
        hapticCalls.clear();
        final Offset donutCenter =
            tester.getCenter(find.byType(InteractiveDonutChart));
        await tester.tapAt(donutCenter + const Offset(75, -75));
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text('COLD BREW'), findsOneWidget);
        expect(
          hapticCalls,
          isEmpty,
          reason: 'InteractiveDonutChart must NOT vibrate when clicked',
        );

        // Tap center of Donut to deselect -> still ZERO haptics!
        await tester.tapAt(donutCenter);
        await tester.pump(const Duration(milliseconds: 250));
        expect(hapticCalls, isEmpty);

        // 3. Tap ForestPaceHeroCard interactive bar chart column -> changes selected bar with ZERO haptics!
        final Rect heroRect =
            tester.getRect(find.byType(ForestPaceHeroCard));
        final Offset firstBarPoint = Offset(
          heroRect.left + 64,
          heroRect.bottom - 56,
        );
        await tester.tapAt(firstBarPoint);
        await tester.pump(const Duration(milliseconds: 250));
        expect(
          hapticCalls,
          isEmpty,
          reason: 'ForestPaceHeroCard bar chart must NOT vibrate when clicked',
        );

        // 4. Quick click ForestPaceHeroCard header mode toggle pill ('Full Month') -> ['pressDown', 'releaseUp']!
        await tester.tap(find.text('Full Month'));
        await pumpIsar(tester);
        await tester.pump(const Duration(milliseconds: 250));
        expect(hapticCalls, <String>['pressDown', 'releaseUp']);

        // 5. Scroll down and quick click a _NativeBreakdownCard ('Cold Brew') -> shrinks & emits ['pressDown', 'releaseUp']!
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -320),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        hapticCalls.clear();

        await tester.tap(find.text('Cold Brew'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(hapticCalls, <String>['pressDown', 'releaseUp']);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpIsar(tester, rounds: 3);
      }
    },
  );

  testWidgets(
    'TransactionCard swipe-to-delete reveals floating rounded capsule with 12px breathing gap and clean armed/disarmed choreography',
    (WidgetTester tester) async {
      configureMobileViewport(tester);

      try {
        await tester.runAsync(() async {
          await container.read(databaseServiceProvider).saveExpense(
                Expense()
                  ..name = 'Matcha Croissant'
                  ..quantity = 1
                  ..price = 42000
                  ..totalAmount = 42000
                  ..date = DateTime.now(),
              );
        });

        await tester.pumpWidget(buildTestApp());
        await pumpIsar(tester);
        await tester.pump(const Duration(milliseconds: 400));

        // Scroll card clear of bottom navigation pill.
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -220));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        hapticCalls.clear();

        final Finder cardSurfaceFinder = find
            .descendant(
              of: find.byType(TransactionCard),
              matching: find.byType(TactileTap),
            )
            .first;

        final Offset startCenter = tester.getCenter(cardSurfaceFinder);
        final TestGesture swipe = await tester.startGesture(startCenter);
        await tester.pump();

        // Cross horizontal touch slop (18px) to engage Dismissible's drag recognizer,
        // then drag -95px (below 40% threshold on 382px card): unarmed soft capsule with 12px gap.
        await swipe.moveBy(const Offset(-20, 0));
        await tester.pump();
        await swipe.moveBy(const Offset(-95, 0));
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
        expect(find.byIcon(Icons.delete_rounded), findsNothing);
        expect(hapticCalls, isEmpty);

        final Finder capsuleFinder = find
            .ancestor(
              of: find.byIcon(Icons.delete_outline_rounded),
              matching: find.byType(AnimatedContainer),
            )
            .first;

        final Rect slidingCardRect = tester.getRect(cardSurfaceFinder);
        final Rect capsuleRect = tester.getRect(capsuleFinder);

        // Verify the capsule is separated from the card's right edge by the 12px breathing gap!
        expect(
          capsuleRect.left - slidingCardRect.right,
          closeTo(12.0, 1.0),
        );

        // 2. Drag further by -95px (total -190px > 40% threshold): arms capsule & fires destructive haptic!
        await swipe.moveBy(const Offset(-95, 0));
        await tester.pump(const Duration(milliseconds: 250));

        expect(hapticCalls, <String>['destructive']);
        expect(find.byIcon(Icons.delete_rounded), findsOneWidget);

        // 3. Pull back +120px (below threshold): disarms cleanly with softDetent & keeps item on release!
        await swipe.moveBy(const Offset(120, 0));
        await tester.pump(const Duration(milliseconds: 250));

        expect(hapticCalls, <String>['destructive', 'softDetent']);
        expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

        await swipe.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('Matcha Croissant'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpIsar(tester, rounds: 3);
      }
    },
  );
}
