import 'package:isar/isar.dart';

part 'expense.g.dart';

@collection
class Expense {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late DateTime date;

  late double amount;
  
  late String description;
  
  // Opsional untuk filter masa depan (makanan, transportasi, dll)
  String? category; 
}