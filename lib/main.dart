import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

// [INJEKSI LOKALISASI: Wajib di root aplikasi]
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart'; // Menggunakan jalur file fisik

import 'models/expense.dart';
import 'models/monthly_balance.dart';
import 'providers/database_provider.dart';
import 'screens/dashboard_screen.dart';
import 'models/app_settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [ExpenseSchema, MonthlyBalanceSchema, AppSettingsSchema],
    directory: dir.path,
  );

  runApp(
    ProviderScope(
      overrides: [
        isarProvider.overrideWithValue(isar),
      ],
      child: const MoneyManagerApp(),
    ),
  );
}

class MoneyManagerApp extends StatelessWidget {
  const MoneyManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Money Manager',
      debugShowCheckedModeBanner: false,
      
      // --- PENDAFTARAN MESIN KAMUS (WAJIB AGAR CONTEXT TIDAK NULL) ---
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // Mengunci bahasa aplikasi secara absolut ke Inggris
      ],
      // ---------------------------------------------------------------

      theme: ThemeData(
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          Theme.of(context).textTheme,
        ),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}