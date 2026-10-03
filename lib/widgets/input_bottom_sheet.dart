import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
// [INJEKSI LOKALISASI]
import '../l10n/app_localizations.dart';

import '../theme/app_colors.dart';
import '../providers/database_provider.dart';
import '../models/expense.dart';

class InputBottomSheet extends ConsumerStatefulWidget {
  final Expense? expenseToEdit; 
  
  const InputBottomSheet({super.key, this.expenseToEdit});

  @override
  ConsumerState<InputBottomSheet> createState() => _InputBottomSheetState();
}

class _InputBottomSheetState extends ConsumerState<InputBottomSheet> {
  late bool isExpenseTab;
  bool _isSuccess = false;

  final _nameController = TextEditingController();
  final _qtyController = TextEditingController();
  final _priceController = TextEditingController();
  final _balanceController = TextEditingController();

  final _nameFocus = FocusNode();
  final _qtyFocus = FocusNode();
  final _priceFocus = FocusNode();
  final _balanceFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    isExpenseTab = true; 

    if (widget.expenseToEdit != null) {
      _nameController.text = widget.expenseToEdit!.name;
      _qtyController.text = widget.expenseToEdit!.quantity.toString();
      _priceController.text = widget.expenseToEdit!.price.toStringAsFixed(0);
    } else {
      _qtyController.text = "1";
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentBal = ref.read(currentMonthBalanceProvider).value?.balance;
      if (currentBal != null) {
        _balanceController.text = currentBal.toStringAsFixed(0);
      }
    });

    _setupFocusHaptics([_nameFocus, _qtyFocus, _priceFocus, _balanceFocus]);
  }

  void _setupFocusHaptics(List<FocusNode> nodes) {
    for (var node in nodes) {
      node.addListener(() {
        if (node.hasFocus) HapticFeedback.selectionClick();
      });
    }
  }

  void _toggleTab(bool toExpense) {
    if (isExpenseTab == toExpense) return;
    HapticFeedback.lightImpact();
    setState(() => isExpenseTab = toExpense);
  }

  Future<void> _submitData() async {
    if (_isSuccess) return;

    final dbService = ref.read(databaseServiceProvider);
    bool isValid = false;
    
    if (isExpenseTab) {
      final name = _nameController.text.trim();
      final qty = int.tryParse(_qtyController.text) ?? 1;
      final price = double.tryParse(_priceController.text) ?? 0.0;
      
      if (name.isNotEmpty && price > 0) {
        final expense = Expense()
          ..id = widget.expenseToEdit?.id ?? Isar.autoIncrement
          ..name = name
          ..quantity = qty
          ..price = price
          ..totalAmount = (qty * price)
          ..date = widget.expenseToEdit?.date ?? DateTime.now();

        await dbService.saveExpense(expense);
        isValid = true;
      }
    } else {
      final balance = double.tryParse(_balanceController.text) ?? 0.0;
      if (balance > 0) {
        final now = DateTime.now();
        final monthYear = "${now.month.toString().padLeft(2, '0')}-${now.year}";
        await dbService.setMonthlyBalance(monthYear, balance);
        isValid = true;
      }
    }

    if (isValid && mounted) {
      HapticFeedback.heavyImpact(); 
      FocusScope.of(context).unfocus(); 

      setState(() {
        _isSuccess = true;
      });
      
      await Future.delayed(const Duration(milliseconds: 600));
      
      if (mounted) Navigator.pop(context);
    } else {
      HapticFeedback.vibrate(); 
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _balanceController.dispose();
    
    _nameFocus.dispose();
    _qtyFocus.dispose();
    _priceFocus.dispose();
    _balanceFocus.dispose();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // [BEST PRACTICE: Cache kamus]
    final l10n = AppLocalizations.of(context)!;

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
                decoration: BoxDecoration(color: AppColors.greyText.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 24),
            
            if (!isEditMode)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _toggleTab(true),
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isExpenseTab ? AppColors.primaryDark : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isExpenseTab ? AppColors.softShadow : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            l10n.expenseTab, // [INJEKSI LOKALISASI]
                            style: TextStyle(color: isExpenseTab ? AppColors.white : AppColors.greyText, fontWeight: FontWeight.w600)
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _toggleTab(false),
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !isExpenseTab ? AppColors.primaryDark : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: !isExpenseTab ? AppColors.softShadow : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            l10n.setBalanceTab, // [INJEKSI LOKALISASI]
                            style: TextStyle(color: !isExpenseTab ? AppColors.white : AppColors.greyText, fontWeight: FontWeight.w600)
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
               Center(
                 child: Text(
                   l10n.editTransaction, // [INJEKSI LOKALISASI]
                   style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primaryDark)
                 )
               ),
            
            const SizedBox(height: 32),
            
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0.02, 0.0), end: Offset.zero).animate(animation),
                    child: child,
                  ),
                );
              },
              // Pass context agar l10n bisa digunakan di sub-widget
              child: isExpenseTab 
                  ? _buildExpenseForm(context: context, l10n: l10n, key: const ValueKey("expense")) 
                  : _buildBalanceForm(context: context, l10n: l10n, key: const ValueKey("balance")),
            ),
            
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _submitData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSuccess ? AppColors.accentGreen : AppColors.primaryDark,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                  animationDuration: const Duration(milliseconds: 300),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  switchInCurve: Curves.elasticOut,
                  switchOutCurve: Curves.easeInBack, 
                  transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                  child: _isSuccess
                      ? const Icon(
                          Icons.check_circle_rounded, 
                          key: ValueKey("success"), 
                          size: 28, 
                          color: AppColors.white
                        )
                      : Text(
                          key: const ValueKey("text"),
                          isEditMode ? l10n.updateData : l10n.saveData, // [INJEKSI LOKALISASI]
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Parameter ditambah l10n untuk injeksi teks
  Widget _buildExpenseForm({required BuildContext context, required AppLocalizations l10n, Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(label: l10n.itemName, controller: _nameController, focusNode: _nameFocus, icon: Icons.shopping_bag_outlined),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(flex: 1, child: _buildTextField(label: l10n.quantity, controller: _qtyController, focusNode: _qtyFocus, icon: Icons.numbers_rounded, isNumber: true)),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: _buildTextField(label: l10n.unitPrice, controller: _priceController, focusNode: _priceFocus, icon: Icons.attach_money_rounded, isNumber: true)),
          ],
        ),
      ],
    );
  }

  Widget _buildBalanceForm({required BuildContext context, required AppLocalizations l10n, Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.mainBalanceLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
        const SizedBox(height: 8),
        _buildTextField(label: l10n.totalBalanceInput, controller: _balanceController, focusNode: _balanceFocus, icon: Icons.account_balance_wallet_outlined, isNumber: true),
      ],
    );
  }

  Widget _buildTextField({
    required String label, 
    required TextEditingController controller, 
    required FocusNode focusNode,
    required IconData icon, 
    bool isNumber = false
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
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