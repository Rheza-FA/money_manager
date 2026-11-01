import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:money_manager/features/receipt_share/services/receipt_share_service.dart';
import 'package:money_manager/l10n/app_localizations.dart';
import 'package:money_manager/models/app_settings.dart';
import 'package:money_manager/models/expense.dart';
import 'package:money_manager/models/monthly_balance.dart';
import 'package:money_manager/providers/calculator_provider.dart';
import 'package:money_manager/providers/database_provider.dart';
import 'package:money_manager/screens/dashboard_screen.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late ProviderContainer container;
  int instanceSeq = 0;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('neymo_share_flow_');
    isar = await Isar.open(
      [ExpenseSchema, MonthlyBalanceSchema, AppSettingsSchema],
      directory: tempDir.path,
      name: 'neymo_share_${++instanceSeq}',
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

  /// Bridges multi-step native Isar C FFI `ReceivePort` callbacks (beginTxn ->
  /// put -> commit -> watchLazy -> query) across `FakeAsync` microtask flushes.
  Future<void> pumpNativeIsarRoundTrips(
    WidgetTester tester, {
    int rounds = 8,
  }) async {
    for (int i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await tester.pump();
    }
  }

  testWidgets(
    'cold-start shared QRIS receipt opens sheet, pre-fills fields, and saves to Isar',
    (WidgetTester tester) async {
      configureMobileViewport(tester);

      final DateTime now = DateTime.now();
      final String todayFormatted =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} 14:25:00';

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kReceiptShareChannel,
              (MethodCall call) async {
        if (call.method == 'consumeInitialShare') {
          return <String, Object?>{
            'status': 'ready',
            'payload': <String, Object?>{
              'lines': <String>[
                'gopay',
                'Pembayaran berhasil',
                'Rp32.000',
                'Kopi Kenangan Sudirman',
                todayFormatted,
                'Total pembayaran   Rp32.000',
                'NMID   ID102003004005',
              ],
              'extraText': null,
              'extraSubject': null,
              'mimeType': 'image/png',
              'referrer': 'com.gojek.app',
            },
          };
        }
        return null;
      });

      try {
        await tester.pumpWidget(buildTestApp());
        await pumpNativeIsarRoundTrips(tester, rounds: 5);
        await tester.pump(const Duration(milliseconds: 450));

        // Verify sheet opened with source badge and pre-filled values.
        expect(find.text('Import Receipt'), findsOneWidget);
        expect(find.text('GoPay • QRIS'), findsOneWidget);
        expect(
          find.widgetWithText(TextField, 'Kopi Kenangan Sudirman'),
          findsOneWidget,
        );
        expect(find.widgetWithText(TextField, '32000'), findsOneWidget);

        // One-tap Save Transaction.
        final Finder saveButton = find.text('Save Transaction');
        await tester.ensureVisible(saveButton);
        await tester.pump();
        await tester.tap(saveButton);
        await tester.pump();

        // Flush all native Isar writeTxn + watchLazy FFI round-trips.
        await pumpNativeIsarRoundTrips(tester, rounds: 10);

        // Advance past the 550ms success confirmation delay & bottom-sheet close animation.
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 400));
        await pumpNativeIsarRoundTrips(tester, rounds: 4);

        late List<Expense> saved;
        await tester.runAsync(() async {
          saved = await isar.expenses.where().findAll();
        });

        expect(saved, hasLength(1));
        expect(saved.first.name, 'Kopi Kenangan Sudirman');
        expect(saved.first.quantity, 1);
        expect(saved.first.price, 32000);
        expect(saved.first.totalAmount, 32000);

        // Verify sheet dismissed and newly imported transaction renders on Dashboard.
        expect(find.text('Import Receipt'), findsNothing);
        expect(find.text('Kopi Kenangan Sudirman'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpNativeIsarRoundTrips(tester, rounds: 3);
      }
    },
  );

  testWidgets(
    'warm-start share transitions smoothly from scanning state to populated form',
    (WidgetTester tester) async {
      configureMobileViewport(tester);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kReceiptShareChannel,
              (MethodCall call) async {
        if (call.method == 'consumeInitialShare') return null;
        return null;
      });

      try {
        await tester.pumpWidget(buildTestApp());
        await pumpNativeIsarRoundTrips(tester, rounds: 5);
        await tester.pump(const Duration(milliseconds: 300));

        // Simulate warm-start native callback: OCR started.
        final ByteData startMsg = const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onShareStarted'),
        );
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage('neymo/receipt_share', startMsg, (_) {});
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('Reading receipt...'), findsOneWidget);

        // Simulate warm-start native callback: OCR resolved (BCA receipt).
        final ByteData resolvedMsg =
            const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onShareResolved', <String, Object?>{
            'lines': <String>[
              'myBCA',
              'Transaksi Berhasil',
              'Nama Merchant',
              'INDOMARET POINT',
              'Total Nominal',
              'IDR 54.500,00',
            ],
            'mimeType': 'image/jpeg',
          }),
        );
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage('neymo/receipt_share', resolvedMsg, (_) {});
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('Reading receipt...'), findsNothing);
        expect(find.text('BCA'), findsOneWidget);
        expect(
          find.widgetWithText(TextField, 'Indomaret Point'),
          findsOneWidget,
        );
        expect(find.widgetWithText(TextField, '54500'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpNativeIsarRoundTrips(tester, rounds: 3);
      }
    },
  );

  testWidgets(
    'isolates consecutive GoPay -> BRImo shares, strips GoPay promo link, extracts Qty, and steps Qty cleanly',
    (WidgetTester tester) async {
      configureMobileViewport(tester);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kReceiptShareChannel,
              (MethodCall call) async {
        if (call.method == 'consumeInitialShare') return null;
        return null;
      });

      try {
        await tester.pumpWidget(buildTestApp());
        await pumpNativeIsarRoundTrips(tester, rounds: 5);
        await tester.pump(const Duration(milliseconds: 300));

        // 1. First share: GoPay image receipt carrying Indonesian promo caption & URL.
        final ByteData gopayResolved =
            const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onShareResolved', <String, Object?>{
            'lines': <String>[
              'Pembayaran berhasil',
              'Rp25.000',
              'TOKO KOPI TUKU',
            ],
            'extraText':
                'Hai, ini bukti transaksinya ya. Buat rincian lebih lanjut, bisa cek di app GoPay https://app.gopay.co.id/NF8p/x3fpwee1',
            'mimeType': 'image/png',
            'referrer': 'com.gojek.gopay',
            'hasAttachment': true,
          }),
        );
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'neymo/receipt_share',
          gopayResolved,
          (_) {},
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('GoPay'), findsOneWidget);
        expect(find.widgetWithText(TextField, 'Toko Kopi Tuku'), findsOneWidget);
        expect(find.widgetWithText(TextField, '25000'), findsOneWidget);

        // Expand raw receipt text and confirm GoPay's Indonesian promo caption/URL was stripped.
        await tester.tap(find.text('Receipt text'));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.textContaining('gopay.co.id'), findsNothing);
        expect(find.textContaining('bukti transaksinya ya'), findsNothing);

        // 2. While the GoPay sheet is STILL open, user shares a BRImo receipt with Qty = 2.
        final ByteData brimoStart =
            const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onShareStarted'),
        );
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage('neymo/receipt_share', brimoStart, (_) {});
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Reading receipt...'), findsOneWidget);

        final ByteData brimoResolved =
            const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onShareResolved', <String, Object?>{
            'lines': <String>[
              'Transaksi Berhasil',
              'Sumber Dana',
              'RHEZA FIRMANSYAH',
              '0123 **** **** 567',
              '2x Es Kopi Susu Aren',
              'Total Transaksi',
              'Rp 36.000',
            ],
            'mimeType': 'image/png',
            'referrer': 'id.co.bri.brimo',
            'hasAttachment': true,
          }),
        );
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'neymo/receipt_share',
          brimoResolved,
          (_) {},
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Sheet cleanly isolated to BRImo: Qty = 2, Unit Price = 18000, Total = Rp 36.000.
        expect(find.text('BRImo'), findsOneWidget);
        expect(find.text('GoPay'), findsNothing);
        expect(
          find.widgetWithText(TextField, 'Es Kopi Susu Aren'),
          findsOneWidget,
        );
        expect(find.widgetWithText(TextField, '2'), findsOneWidget);
        expect(find.widgetWithText(TextField, '18000'), findsOneWidget);
        expect(find.text('Rp 36.000'), findsOneWidget);

        // Tap '+' stepper on Qty -> Qty becomes 3, Total updates live to Rp 54.000.
        await tester.tap(
          find.descendant(
            of: find.byType(TextField),
            matching: find.byIcon(Icons.add_rounded),
          ),
        );
        await tester.pump();
        expect(find.widgetWithText(TextField, '3'), findsOneWidget);
        expect(find.text('Rp 54.000'), findsOneWidget);

        // Save Transaction and verify Isar persisted Qty = 3, Price = 18000, Total = 54000.
        final Finder saveButton = find.text('Save Transaction');
        await tester.ensureVisible(saveButton);
        await tester.pump();
        await tester.tap(saveButton);
        await tester.pump();

        await pumpNativeIsarRoundTrips(tester, rounds: 10);
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 400));
        await pumpNativeIsarRoundTrips(tester, rounds: 4);

        late List<Expense> saved;
        await tester.runAsync(() async {
          saved = await isar.expenses.where().findAll();
        });

        expect(saved, hasLength(1));
        expect(saved.first.name, 'Es Kopi Susu Aren');
        expect(saved.first.quantity, 3);
        expect(saved.first.price, 18000);
        expect(saved.first.totalAmount, 54000);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpNativeIsarRoundTrips(tester, rounds: 3);
      }
    },
  );

  testWidgets(
    'shared expense decreases Total Balance while keeping Daily Limit locked, and shared +Rp income increases Total Balance',
    (WidgetTester tester) async {
      configureMobileViewport(tester);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kReceiptShareChannel,
              (MethodCall call) async {
        if (call.method == 'consumeInitialShare') return null;
        return null;
      });

      final DateTime now = DateTime.now();
      final String monthYear =
          '${now.month.toString().padLeft(2, '0')}-${now.year}';
      // Use a backdated day earlier in the same month when possible (or today on the 1st)
      final DateTime receiptDay =
          now.day > 1 ? DateTime(now.year, now.month, 1, 13, 0) : now;
      final String receiptDateStr =
          '${receiptDay.day.toString().padLeft(2, '0')}/${receiptDay.month.toString().padLeft(2, '0')}/${receiptDay.year} 13:00:00';

      try {
        await tester.runAsync(() async {
          await container
              .read(databaseServiceProvider)
              .setMonthlyBalance(monthYear, 1000000);
        });

        await tester.pumpWidget(buildTestApp());
        await pumpNativeIsarRoundTrips(tester, rounds: 8);
        await tester.pump(const Duration(milliseconds: 450));

        expect(container.read(liveBalanceProvider), 1000000);
        expect(find.text('1.000.000'), findsOneWidget);
        final double initialDailyLimit =
            container.read(maxDailySpendingProvider);
        expect(initialDailyLimit, greaterThan(0));

        // 1. Share a noisy backdated BRImo expense receipt (Rp 50.000).
        final ByteData brimoExpenseMsg =
            const StandardMethodCodec().encodeMethodCall(
          MethodCall('onShareResolved', <String, Object?>{
            'lines': <String>[
              'bn br a bb',
              'Transaksi Berhasil',
              receiptDateStr,
              'Sumber Dana   RHEZA FIRMANSYAH',
              '0123 **** 567',
              'Tujuan',
              'bn bri a bb',
              'WARUNG PADANG SEDERHANA',
              'Total Transaksi   Rp 50.000',
            ],
            'mimeType': 'image/png',
            'referrer': 'id.co.bri.brimo',
            'hasAttachment': true,
          }),
        );
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'neymo/receipt_share',
          brimoExpenseMsg,
          (_) {},
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('BRImo'), findsOneWidget);
        expect(
          find.widgetWithText(TextField, 'Warung Padang Sederhana'),
          findsOneWidget,
        );
        expect(find.widgetWithText(TextField, '50000'), findsOneWidget);

        final Finder saveExpenseBtn = find.text('Save Transaction');
        await tester.ensureVisible(saveExpenseBtn);
        await tester.pump();
        await tester.tap(saveExpenseBtn);
        await tester.pump();

        await pumpNativeIsarRoundTrips(tester, rounds: 10);
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 400));
        await pumpNativeIsarRoundTrips(tester, rounds: 6);

        // Total Balance decreased immediately to 950.000, while today's Daily Limit stayed 100% locked!
        expect(container.read(liveBalanceProvider), 950000);
        expect(find.text('950.000'), findsOneWidget);
        expect(container.read(maxDailySpendingProvider), initialDailyLimit);

        // 2. Share an incoming SeaBank transfer receipt (+Rp 200.000).
        final ByteData incomingMsg =
            const StandardMethodCodec().encodeMethodCall(
          MethodCall('onShareResolved', <String, Object?>{
            'lines': <String>[
              'SeaBank',
              'Transfer Masuk Berhasil',
              '+Rp 200.000',
              receiptDateStr,
              'Dari: Andi Wijaya',
            ],
            'mimeType': 'image/png',
            'referrer': 'id.co.seabank.app',
            'hasAttachment': true,
          }),
        );
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'neymo/receipt_share',
          incomingMsg,
          (_) {},
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('SeaBank'), findsOneWidget);
        expect(find.widgetWithText(TextField, 'Andi Wijaya'), findsOneWidget);
        expect(find.widgetWithText(TextField, '200000'), findsOneWidget);
        expect(
          find.text(
            'Detected as incoming money — it will be added to your balance.',
          ),
          findsOneWidget,
        );
        expect(find.text('+ Rp 200.000'), findsOneWidget);

        final Finder saveIncomeBtn = find.text('Save Transaction');
        await tester.ensureVisible(saveIncomeBtn);
        await tester.pump();
        await tester.tap(saveIncomeBtn);
        await tester.pump();

        await pumpNativeIsarRoundTrips(tester, rounds: 10);
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 400));
        await pumpNativeIsarRoundTrips(tester, rounds: 6);

        // Total Balance increased to 1.150.000, Daily Limit remained locked today, and Income card is shown!
        expect(container.read(liveBalanceProvider), 1150000);
        expect(find.text('1.150.000'), findsOneWidget);
        expect(container.read(maxDailySpendingProvider), initialDailyLimit);
        expect(find.text('Andi Wijaya'), findsOneWidget);
        expect(find.text('Money in'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpNativeIsarRoundTrips(tester, rounds: 3);
      }
    },
  );
}
