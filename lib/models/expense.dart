import 'package:isar_community/isar.dart';

part 'expense.g.dart';

/// A single money movement recorded by the user.
///
/// The collection keeps its historical name (`Expense`) so the on-disk schema
/// stays compatible; [isIncome] distinguishes incoming money from spending.
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

  /// `true` for money received (e.g. an incoming transfer shared from a
  /// banking app). Records created before this field existed read as `false`.
  bool isIncome = false;

  /// Wall-clock moment the record was first saved. May differ from [date]
  /// when a past receipt is imported later. `null` for legacy records, which
  /// were always saved at their own [date].
  DateTime? recordedAt;
}
