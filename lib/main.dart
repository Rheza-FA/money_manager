import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'models/expense.dart';
import 'models/monthly_balance.dart';
import 'providers/database_provider.dart'; // Baris yang tertinggal tadi
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [ExpenseSchema, MonthlyBalanceSchema],
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
      debugShowCheckedModeBanner: false, // Matikan pita debug merah
      theme: ThemeData(
        fontFamily: 'Montserrat', // Sangat disarankan pakai font sans-serif modern
        useMaterial3: true,
      ),
      home: const DashboardScreen(), // Arahkan ke sini
    );
  }
}