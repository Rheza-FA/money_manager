import 'package:isar/isar.dart';

part 'monthly_balance.g.dart';

@collection
class MonthlyBalance {
  Id id = Isar.autoIncrement;

  // Format "MM-YYYY" (Contoh: "10-2026"). 
  // String tunggal lebih efisien untuk pencarian Isar dibanding dua kolom integer terpisah.
  @Index(unique: true, replace: true)
  late String monthYear;

  late double balance;
}