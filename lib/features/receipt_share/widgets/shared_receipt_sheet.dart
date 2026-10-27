import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:isar_community/isar.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/expense.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/history_provider.dart';
import '../../../theme/app_colors.dart';
import '../models/shared_receipt.dart';
import '../services/receipt_share_service.dart';

class SharedReceiptSheet extends ConsumerStatefulWidget {
  const SharedReceiptSheet({super.key});

  @override
  ConsumerState<SharedReceiptSheet> createState() => _SharedReceiptSheetState();
}

class _SharedReceiptSheetState extends ConsumerState<SharedReceiptSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _priceController = TextEditingController();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _qtyFocus = FocusNode();
  final FocusNode _priceFocus = FocusNode();

  late final AnimationController _pulseController;
  late final NumberFormat _currencyFormatter;
  late final DateFormat _dateBadgeFormatter;

  int _appliedSessionId = -1;
  ReceiptShareStatus _appliedStatus = ReceiptShareStatus.idle;
  DateTime _selectedDate = DateTime.now();
  bool _isIncome = false;
  bool _showRawText = false;
  bool _isSaving = false;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    _dateBadgeFormatter = DateFormat('dd MMM, HH:mm');

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (ref.read(receiptShareProvider).status == ReceiptShareStatus.scanning) {
      _pulseController.repeat(reverse: true);
    }

    for (final FocusNode node in <FocusNode>[
      _nameFocus,
      _qtyFocus,
      _priceFocus,
    ]) {
      node.addListener(() {
        if (node.hasFocus) HapticFeedback.selectionClick();
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncFromState(ref.read(receiptShareProvider), isInitial: true);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _nameController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _nameFocus.dispose();
    _qtyFocus.dispose();
    _priceFocus.dispose();
    super.dispose();
  }

  void _syncFromState(ReceiptShareState shareState, {bool isInitial = false}) {
    if (shareState.status == ReceiptShareStatus.scanning) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
      if (shareState.sessionId != _appliedSessionId) {
        _appliedSessionId = shareState.sessionId;
        _appliedStatus = shareState.status;
        setState(() {
          _nameController.clear();
          _qtyController.text = '1';
          _priceController.clear();
          _selectedDate = DateTime.now();
          _isIncome = false;
          _showRawText = false;
        });
      } else {
        _appliedStatus = shareState.status;
      }
      return;
    }

    if (_pulseController.isAnimating) {
      _pulseController.stop();
    }

    final ParsedReceipt? parsed = shareState.parsed;
    if (parsed == null) return;

    final bool shouldApply = shareState.sessionId != _appliedSessionId ||
        shareState.status != _appliedStatus;
    if (!shouldApply) return;

    final bool transitionedFromScan =
        !isInitial && _appliedStatus == ReceiptShareStatus.scanning;

    _appliedSessionId = shareState.sessionId;
    _appliedStatus = shareState.status;

    setState(() {
      _nameController.text = parsed.itemName;
      _qtyController.text = parsed.quantity.toString();
      _priceController.text =
          parsed.amount != null && parsed.amount! > 0
              ? parsed.amount!.toStringAsFixed(0)
              : '';
      _selectedDate = parsed.date;
      _isIncome = parsed.isLikelyIncoming;
      _showRawText = false;
    });

    if (transitionedFromScan) {
      HapticFeedback.mediumImpact();
    }

    // Only auto-focus if a required field is missing; when complete, keep the
    // keyboard closed so the user can review and save in a single thumb tap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_nameController.text.trim().isEmpty) {
        _nameFocus.requestFocus();
      } else if (_priceController.text.trim().isEmpty) {
        _priceFocus.requestFocus();
      }
    });
  }

  void _stepQuantity(int delta) {
    final int current = int.tryParse(_qtyController.text.trim()) ?? 1;
    final int next = (current + delta).clamp(1, 999);
    if (next == current) return;
    HapticFeedback.selectionClick();
    setState(() {
      _qtyController.text = next.toString();
    });
  }

  double get _computedTotal {
    final int qty = int.tryParse(_qtyController.text.trim()) ?? 1;
    final String digits =
        _priceController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final double unitPrice = double.tryParse(digits) ?? 0.0;
    if (qty <= 0 || unitPrice <= 0) return 0.0;
    return qty * unitPrice;
  }

  Future<void> _pickDate() async {
    HapticFeedback.selectionClick();
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(now) ? now : _selectedDate,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryDark,
              onPrimary: AppColors.white,
              onSurface: AppColors.primaryDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
          _selectedDate.second,
        );
      });
    }
  }

  Future<void> _submit() async {
    if (_isSaving || _isSuccess) return;

    final String name = _nameController.text.trim();
    final int qty = int.tryParse(_qtyController.text.trim()) ?? 1;
    final String priceDigits =
        _priceController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final double price = double.tryParse(priceDigits) ?? 0.0;

    if (name.isEmpty || qty <= 0 || price <= 0) {
      HapticFeedback.vibrate();
      if (name.isEmpty) {
        _nameFocus.requestFocus();
      } else {
        _priceFocus.requestFocus();
      }
      return;
    }

    setState(() => _isSaving = true);

    final Expense expense = Expense()
      ..id = Isar.autoIncrement
      ..name = name
      ..quantity = qty
      ..price = price
      ..totalAmount = qty * price
      ..date = _selectedDate
      ..isIncome = _isIncome;

    await ref.read(databaseServiceProvider).saveExpense(expense);
    _ensureTransactionVisibleInActiveFilter(_selectedDate);

    if (!mounted) return;
    HapticFeedback.heavyImpact();
    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = false;
      _isSuccess = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _ensureTransactionVisibleInActiveFilter(DateTime txDate) {
    final TimeFilter currentFilter = ref.read(timeFilterProvider);
    final DateTime now = DateTime.now();
    final bool isToday = txDate.year == now.year &&
        txDate.month == now.month &&
        txDate.day == now.day;
    final bool isThisMonth =
        txDate.year == now.year && txDate.month == now.month;

    if (currentFilter == TimeFilter.daily && !isToday && isThisMonth) {
      ref.read(timeFilterProvider.notifier).setFilter(TimeFilter.monthly);
    } else if (currentFilter == TimeFilter.customDate) {
      final DateTime? custom = ref.read(customDateProvider);
      final bool matchesCustom = custom != null &&
          custom.year == txDate.year &&
          custom.month == txDate.month &&
          custom.day == txDate.day;
      if (!matchesCustom) {
        if (isThisMonth) {
          ref.read(timeFilterProvider.notifier).setFilter(TimeFilter.monthly);
        } else {
          ref.read(customDateProvider.notifier).setDate(txDate);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ReceiptShareState shareState = ref.watch(receiptShareProvider);

    ref.listen<ReceiptShareState>(
      receiptShareProvider,
      (_, ReceiptShareState next) {
        _syncFromState(next);
      },
    );

    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool isScanning = shareState.status == ReceiptShareStatus.scanning;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundTop,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(24, 14, 24, bottomInset + 24),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.greyText.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeIn,
                child: isScanning
                    ? _buildScanningView(l10n)
                    : _buildFormView(context, l10n, shareState),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanningView(AppLocalizations l10n) {
    return Padding(
      key: const ValueKey<String>('scanning'),
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedBuilder(
              animation: _pulseController,
              builder: (BuildContext context, Widget? child) {
                final double scale = 0.94 + (_pulseController.value * 0.10);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark,
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.accentGreen.withValues(
                            alpha: 0.25 + (_pulseController.value * 0.20),
                          ),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: child,
                  ),
                );
              },
              child: const Icon(
                Icons.document_scanner_rounded,
                color: AppColors.accentGreen,
                size: 30,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.sharedReceiptScanningTitle,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.sharedReceiptScanningSubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.greyText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormView(
    BuildContext context,
    AppLocalizations l10n,
    ReceiptShareState shareState,
  ) {
    final ParsedReceipt? parsed = shareState.parsed;
    final String sourceLabel = parsed?.sourceLabel ?? 'Receipt';
    final List<String> candidates = parsed?.nameCandidates ?? const <String>[];
    final List<String> rawLines = parsed?.rawPreviewLines ?? const <String>[];
    final bool detectedIncoming = parsed?.isLikelyIncoming ?? false;
    final bool isError = shareState.status == ReceiptShareStatus.error;
    final bool needsAttention =
        !isError && parsed != null && !parsed.isComplete;

    return Column(
      key: const ValueKey<String>('form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Header row: Title + Source pill
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.sharedReceiptTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.accentGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    sourceLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Date chip + Optional raw receipt preview toggle
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: AppColors.primaryLight,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _dateBadgeFormatter.format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (rawLines.isNotEmpty)
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _showRawText = !_showRawText);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _showRawText
                        ? AppColors.primaryLight.withValues(alpha: 0.10)
                        : AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.receipt_long_outlined,
                        size: 14,
                        color: AppColors.primaryLight,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.sharedReceiptViewRaw,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        _showRawText
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppColors.primaryLight,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),

        // Collapsible extracted receipt text drawer
        if (_showRawText && rawLines.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 132),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryDark.withValues(alpha: 0.08),
              ),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Text(
                rawLines.join('\n'),
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryLight,
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 14),

        // Transaction Direction Toggle (Expense vs Income)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_isIncome) {
                      HapticFeedback.selectionClick();
                      setState(() => _isIncome = false);
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color:
                          !_isIncome ? AppColors.primaryDark : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: !_isIncome ? AppColors.softShadow : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      l10n.transactionTypeExpense,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: !_isIncome ? AppColors.white : AppColors.greyText,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (!_isIncome) {
                      HapticFeedback.selectionClick();
                      setState(() => _isIncome = true);
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _isIncome
                          ? AppColors.incomeEmerald
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _isIncome ? AppColors.softShadow : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      l10n.transactionTypeIncome,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _isIncome ? AppColors.white : AppColors.greyText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Contextual banners (shown only when needed)
        if (detectedIncoming && _isIncome) ...<Widget>[
          const SizedBox(height: 12),
          _buildNoticeBanner(
            icon: Icons.south_west_rounded,
            text: l10n.sharedReceiptIncomingHint,
            background: AppColors.accentGreen.withValues(alpha: 0.20),
            foreground: AppColors.primaryDark,
          ),
        ] else if (isError) ...<Widget>[
          const SizedBox(height: 12),
          _buildNoticeBanner(
            icon: Icons.info_outline_rounded,
            text: l10n.sharedReceiptReadError,
            background: AppColors.white,
            foreground: AppColors.primaryLight,
          ),
        ] else if (needsAttention) ...<Widget>[
          const SizedBox(height: 12),
          _buildNoticeBanner(
            icon: Icons.edit_note_rounded,
            text: l10n.sharedReceiptVerifyHint,
            background: AppColors.accentGreen.withValues(alpha: 0.18),
            foreground: AppColors.primaryDark,
          ),
        ],

        const SizedBox(height: 18),

        // Item Name field
        _buildTextField(
          label: l10n.itemName,
          controller: _nameController,
          focusNode: _nameFocus,
          icon: _isIncome
              ? Icons.person_outline_rounded
              : Icons.shopping_bag_outlined,
          onChanged: (_) => setState(() {}),
        ),

        // One-tap candidate pills when multiple good names exist (e.g., Note vs Merchant)
        if (candidates.length > 1 ||
            (candidates.length == 1 &&
                _nameController.text.trim().isEmpty)) ...<Widget>[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: candidates.map((String candidate) {
                final bool selected = _nameController.text.trim().toLowerCase() ==
                    candidate.toLowerCase();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _nameController.text = candidate;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primaryDark
                            : AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        candidate,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppColors.white
                              : AppColors.primaryLight,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          ),
        ],

        const SizedBox(height: 14),

        // Quantity & Unit Price row
        Row(
          children: <Widget>[
            Expanded(
              flex: 5,
              child: _buildQuantityField(l10n),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 7,
              child: _buildTextField(
                label: l10n.unitPrice,
                controller: _priceController,
                focusNode: _priceFocus,
                icon: Icons.payments_outlined,
                isNumber: true,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Live computed Rupiah total bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.sharedReceiptTotalLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.greyText,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _isIncome
                        ? '+ ${_currencyFormatter.format(_computedTotal)}'
                        : _currencyFormatter.format(_computedTotal),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _isIncome
                          ? AppColors.incomeEmerald
                          : AppColors.primaryDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Primary Save CTA
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isSuccess
                  ? AppColors.accentGreen
                  : (_isIncome
                      ? AppColors.incomeEmerald
                      : AppColors.primaryDark),
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
              animationDuration: const Duration(milliseconds: 300),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.elasticOut,
              switchOutCurve: Curves.easeInBack,
              transitionBuilder: (Widget child, Animation<double> animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: _isSuccess
                  ? const Icon(
                      Icons.check_circle_rounded,
                      key: ValueKey<String>('success'),
                      size: 28,
                      color: AppColors.white,
                    )
                  : Text(
                      l10n.sharedReceiptSaveButton,
                      key: const ValueKey<String>('save_label'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoticeBanner({
    required IconData icon,
    required String text,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: foreground,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityField(AppLocalizations l10n) {
    final int currentQty = int.tryParse(_qtyController.text.trim()) ?? 1;
    final bool canDecrement = currentQty > 1;
    final bool canIncrement = currentQty < 999;

    return TextField(
      controller: _qtyController,
      focusNode: _qtyFocus,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      onChanged: (_) => setState(() {}),
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.primaryDark,
      ),
      decoration: InputDecoration(
        labelText: l10n.quantity,
        labelStyle: const TextStyle(
          color: AppColors.greyText,
          fontWeight: FontWeight.w500,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        prefixIconConstraints: const BoxConstraints.tightFor(
          width: 36,
          height: 48,
        ),
        suffixIconConstraints: const BoxConstraints.tightFor(
          width: 36,
          height: 48,
        ),
        prefixIcon: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canDecrement ? () => _stepQuantity(-1) : null,
          child: Icon(
            Icons.remove_rounded,
            size: 18,
            color: canDecrement
                ? AppColors.primaryLight
                : AppColors.greyText.withValues(alpha: 0.35),
          ),
        ),
        suffixIcon: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canIncrement ? () => _stepQuantity(1) : null,
          child: Icon(
            Icons.add_rounded,
            size: 18,
            color: canIncrement
                ? AppColors.primaryLight
                : AppColors.greyText.withValues(alpha: 0.35),
          ),
        ),
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(
            color: AppColors.accentGreen,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    bool isNumber = false,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber
          ? <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly]
          : null,
      onChanged: onChanged,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.primaryDark,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: AppColors.greyText,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: AppColors.primaryLight, size: 20),
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(
            color: AppColors.accentGreen,
            width: 2,
          ),
        ),
      ),
    );
  }
}
