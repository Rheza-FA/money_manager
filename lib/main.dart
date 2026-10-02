import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart'; // IMPORT DITAMBAHKAN UNTUK TYPOGRAPHY GLOBAL
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
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
      theme: ThemeData(
        // ROOT CAUSE FIX: Menghapus hardcode fontFamily: 'Montserrat' untuk menghindari bloat/konflik.
        // Menginjeksi Plus Jakarta Sans secara presisi ke seluruh struktur TextTheme Material 3.
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          Theme.of(context).textTheme,
        ),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}