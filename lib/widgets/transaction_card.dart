import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../theme/app_colors.dart';
import '../providers/database_provider.dart';
import 'input_bottom_sheet.dart';

class TransactionCard extends ConsumerStatefulWidget {
  final Expense expense;

  const TransactionCard({super.key, required this.expense});

  @override
  ConsumerState<TransactionCard> createState() => _TransactionCardState();
}

class _TransactionCardState extends ConsumerState<TransactionCard> with SingleTickerProviderStateMixin {
  late final AnimationController _liftController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _shadowBlurAnim;
  late final Animation<double> _shadowOffsetAnim;

  // Optimasi 1: ValueNotifier untuk memisahkan re-render background swipe dari main UI
  final ValueNotifier<bool> _isPopNotifier = ValueNotifier<bool>(false);

  // Optimasi 2: Cache Formatter untuk mencegah memory bloat saat list di-scroll
  late final NumberFormat _formatCurrency;
  late final NumberFormat _formatPrice;
  late final DateFormat _formatTime;

  @override
  void initState() {
    super.initState();

    _formatCurrency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    _formatPrice = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    _formatTime = DateFormat('dd MMM, HH:mm');

    _liftController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100), // Sangat cepat saat ditekan
      reverseDuration: const Duration(milliseconds: 400), // Lembut saat dilepas (memantul)
    );

    _scaleAnim = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(
        parent: _liftController,
        curve: Curves.easeOutQuad,
        reverseCurve: Curves.elasticOut, 
      ),
    );

    _shadowBlurAnim = Tween<double>(begin: 10.0, end: 22.0).animate(
      CurvedAnimation(parent: _liftController, curve: Curves.easeOutQuad),
    );

    _shadowOffsetAnim = Tween<double>(begin: 4.0, end: 12.0).animate(
      CurvedAnimation(parent: _liftController, curve: Curves.easeOutQuad),
    );
  }

  @override
  void dispose() {
    _liftController.dispose();
    _isPopNotifier.dispose();
    super.dispose();
  }

  // Pointer events untuk menjamin respons Haptic & Visual 0 milidetik 
  // (Membypass delay scroll dari GestureDetector)
  void _onPointerDown(PointerDownEvent event) {
    HapticFeedback.selectionClick();
    _liftController.forward();
  }

  void _onPointerUpOrCancel(PointerEvent event) {
    _liftController.reverse();
  }

  void _onTap() {
    // Action logical tetap menggunakan GestureDetector agar tidak tumpang tindih dengan Scroll
    HapticFeedback.lightImpact(); 
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InputBottomSheet(expenseToEdit: widget.expense),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(widget.expense.id.toString()),
      direction: DismissDirection.endToStart,
      
      onUpdate: (details) {
        // Logika Threshold 40% (0.4) untuk Bubble Wrap Effect
        if (details.progress >= 0.4 && !_isPopNotifier.value) {
          _isPopNotifier.value = true;
          HapticFeedback.mediumImpact(); // Mekanikal snap
        } else if (details.progress < 0.4 && _isPopNotifier.value) {
          _isPopNotifier.value = false;
        }
      },
      
      onDismissed: (direction) {
        HapticFeedback.heavyImpact(); // Finalisasi aksi destruktif
        ref.read(databaseServiceProvider).deleteExpense(widget.expense.id);
      },
      
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(24),
        ),
        // Hanya me-render ulang ikon saat threshold tercapai, bukan seluruh kartu
        child: ValueListenableBuilder<bool>(
          valueListenable: _isPopNotifier,
          builder: (context, isPop, child) {
            return AnimatedScale(
              scale: isPop ? 1.35 : 1.0, // Skala yang cukup besar agar pop terlihat jelas
              duration: const Duration(milliseconds: 250),
              curve: Curves.elasticOut,
              child: AnimatedOpacity(
                opacity: isPop ? 1.0 : 0.6,
                duration: const Duration(milliseconds: 150),
                child: const Icon(Icons.delete_sweep_rounded, color: AppColors.white, size: 28),
              ),
            );
          },
        ),
      ),
      
      // Listener mendeteksi sentuhan mentah dari hardware, bypass delay arena gesture
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerUp: _onPointerUpOrCancel,
        onPointerCancel: _onPointerUpOrCancel,
        child: GestureDetector(
          onTap: _onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: _liftController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnim.value,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryDark.withValues(alpha: 0.05),
                        blurRadius: _shadowBlurAnim.value,
                        spreadRadius: 0,
                        offset: Offset(0, _shadowOffsetAnim.value), // Ilusi elevasi
                      ),
                    ],
                  ),
                  child: child,
                ),
              );
            },
            // Konten statis dimasukkan sebagai 'child' agar tidak ikut dirender ulang tiap frame animasi
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
                      Text(
                        widget.expense.name, 
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primaryDark), 
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${widget.expense.quantity}x Rp ${_formatPrice.format(widget.expense.price)}", 
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.greyText)
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency.format(widget.expense.totalAmount), 
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primaryDark)
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime.format(widget.expense.date), 
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.greyText)
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}