import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../theme/app_colors.dart';
import '../providers/database_provider.dart';
import 'input_bottom_sheet.dart';

class TransactionCard extends ConsumerWidget {
  final Expense expense;

  const TransactionCard({super.key, required this.expense});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatCurrency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final formatTime = DateFormat('dd MMM, HH:mm').format(expense.date);
    final formatPrice = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);

    return Dismissible(
      key: Key(expense.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.delete_sweep_rounded, color: AppColors.white, size: 28),
      ),
      onDismissed: (direction) {
        ref.read(databaseServiceProvider).deleteExpense(expense.id);
      },
      child: GestureDetector(
        onTap: () {
          // Buka Bottom Sheet dengan membawa data untuk di-edit
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => InputBottomSheet(expenseToEdit: expense),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppColors.softShadow,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundTop,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: AppColors.primaryDark, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(expense.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primaryDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text("${expense.quantity}x Rp ${formatPrice.format(expense.price)}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.greyText)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatCurrency.format(expense.totalAmount), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                  const SizedBox(height: 4),
                  Text(formatTime, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.greyText)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}