import 'package:isar/isar.dart';

part 'app_settings.g.dart';

@collection
class AppSettings {
  // Id statis '0' menjadikannya Singleton (hanya ada 1 baris pengaturan di database)
  Id id = 0; 
  
  // false = Bulanan, true = Bi-Weekly (Siklus 14 hari)
  bool isBiWeeklyMode = false; 
}