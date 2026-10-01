import 'package:isar/isar.dart';

part 'expense.g.dart';

@collection
class Expense {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late DateTime date;

  late String name;
  
  late int quantity;
  
  late double price;
  
  // Total harga (quantity * price). Disimpan statis agar Isar bisa membaca tanpa komputasi ulang.
  late double totalAmount; 
}