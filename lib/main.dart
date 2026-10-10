import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

// [INJEKSI LOKALISASI]
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

// [INJEKSI NATIVE SPLASH SCREEN]
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'models/expense.dart';
import 'models/monthly_balance.dart';
import 'providers/database_provider.dart';
import 'models/app_settings.dart';
import 'screens/splash_screen.dart';

void main() async {
  // 1. Ambil instance WidgetsBinding
  final WidgetsBinding widgetsBinding =
      WidgetsFlutterBinding.ensureInitialized();

  // 2. PERINTAHKAN OS UNTUK MENAHAN NATIVE SPLASH (WARNA HIJAU GELAP)
  // Mencegah black screen selama proses await di bawah ini berjalan.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // 3. Proses asinkron (Inisialisasi Database Isar)
  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [ExpenseSchema, MonthlyBalanceSchema, AppSettingsSchema],
    directory: dir.path,
  );

  // 4. Jalankan Aplikasi
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
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
      ],
      theme: ThemeData(
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          Theme.of(context).textTheme,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}