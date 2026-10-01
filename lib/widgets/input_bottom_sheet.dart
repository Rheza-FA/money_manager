import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../theme/app_colors.dart';
import '../providers/database_provider.dart';
import '../models/expense.dart';

class InputBottomSheet extends ConsumerStatefulWidget {
  final Expense? expenseToEdit; // Jika null = Buat Baru, Jika ada = Mode Edit
  
  const InputBottomSheet({super.key, this.expenseToEdit});

  @override
  ConsumerState<InputBottomSheet> createState() => _InputBottomSheetState();
}

class _InputBottomSheetState extends ConsumerState<InputBottomSheet> {
  late bool isExpenseTab;

  final _nameController = TextEditingController();
  final _qtyController = TextEditingController();
  final _priceController = TextEditingController();
  final _balanceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill form jika dalam Mode Edit
    isExpenseTab = true; // Default tab

    if (widget.expenseToEdit != null) {
      _nameController.text = widget.expenseToEdit!.name;
      _qtyController.text = widget.expenseToEdit!.quantity.toString();
      _priceController.text = widget.expenseToEdit!.price.toStringAsFixed(0);
    } else {
      _qtyController.text = "1";
    }

    // Ambil saldo saat ini untuk di-prefill di Tab Saldo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentBal = ref.read(currentMonthBalanceProvider).value?.balance;
      if (currentBal != null) {
        _balanceController.text = currentBal.toStringAsFixed(0);
      }
    });
  }

  void _toggleTab(bool toExpense) => setState(() => isExpenseTab = toExpense);

  void _submitData() async {
    final dbService = ref.read(databaseServiceProvider);
    
    if (isExpenseTab) {
      final name = _nameController.text.trim();
      final qty = int.tryParse(_qtyController.text) ?? 1;
      final price = double.tryParse(_priceController.text) ?? 0.0;
      
      if (name.isNotEmpty && price > 0) {
        // Logika Senior: Preservasi ID dan Tanggal jika Edit
        final expense = Expense()
          ..id = widget.expenseToEdit?.id ?? Isar.autoIncrement
          ..name = name
          ..quantity = qty
          ..price = price
          ..totalAmount = (qty * price)
          ..date = widget.expenseToEdit?.date ?? DateTime.now();

        await dbService.saveExpense(expense);
        if (mounted) Navigator.pop(context);
      }
    } else {
      final balance = double.tryParse(_balanceController.text) ?? 0.0;
      if (balance > 0) {
        final now = DateTime.now();
        final monthYear = "${now.month.toString().padLeft(2, '0')}-${now.year}";
        await dbService.setMonthlyBalance(monthYear, balance);
        if (mounted) Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final isEditMode = widget.expenseToEdit != null;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundTop,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding + 32),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48, height: 5,
                decoration: BoxDecoration(color: AppColors.greyText.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 24),
            
            // Sembunyikan toggle jika sedang dalam mode Edit Pengeluaran (Fokus)
            if (!isEditMode)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _toggleTab(true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isExpenseTab ? AppColors.primaryDark : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isExpenseTab ? AppColors.softShadow : null,
                          ),
                          alignment: Alignment.center,
                          child: Text("Pengeluaran", style: TextStyle(color: isExpenseTab ? AppColors.white : AppColors.greyText, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _toggleTab(false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !isExpenseTab ? AppColors.primaryDark : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: !isExpenseTab ? AppColors.softShadow : null,
                          ),
                          alignment: Alignment.center,
                          child: Text("Set Saldo", style: TextStyle(color: !isExpenseTab ? AppColors.white : AppColors.greyText, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
               const Center(child: Text("Edit Transaksi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primaryDark))),
            
            const SizedBox(height: 32),
            isExpenseTab ? _buildExpenseForm() : _buildBalanceForm(),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _submitData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: Text(isEditMode ? "Perbarui Data" : "Simpan Data", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(label: "Nama Item", controller: _nameController, icon: Icons.shopping_bag_outlined),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(flex: 1, child: _buildTextField(label: "Qty", controller: _qtyController, icon: Icons.numbers_rounded, isNumber: true)),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: _buildTextField(label: "Harga Satuan (Rp)", controller: _priceController, icon: Icons.attach_money_rounded, isNumber: true)),
          ],
        ),
      ],
    );
  }

  Widget _buildBalanceForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Saldo Utama Bulan Ini", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
        const SizedBox(height: 8),
        _buildTextField(label: "Total Saldo (Rp)", controller: _balanceController, icon: Icons.account_balance_wallet_outlined, isNumber: true),
      ],
    );
  }

  Widget _buildTextField({required String label, required TextEditingController controller, required IconData icon, bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.greyText, fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, color: AppColors.primaryLight, size: 20),
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppColors.accentGreen, width: 2)),
      ),
    );
  }
}