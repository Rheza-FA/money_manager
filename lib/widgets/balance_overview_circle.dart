import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
// [INJEKSI LOKALISASI]
import '../l10n/app_localizations.dart';

import '../theme/app_colors.dart';

class BalanceOverviewCircle extends StatefulWidget {
  final double balance;

  const BalanceOverviewCircle({super.key, required this.balance});

  @override
  State<BalanceOverviewCircle> createState() => _BalanceOverviewCircleState();
}

class _BalanceOverviewCircleState extends State<BalanceOverviewCircle> with TickerProviderStateMixin {
  late final AnimationController _spinController;
  late final AnimationController _entranceController;
  late final AnimationController _scaleController;

  late final NumberFormat _formatNumber;

  bool _isObscured = false; 

  @override
  void initState() {
    super.initState();

    _formatNumber = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400), 
    );

    _scaleController = AnimationController(
      vsync: this,
      lowerBound: 0.85,
      upperBound: 1.0,
      value: 1.0, 
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _entranceController.animateTo(1.0, curve: Curves.easeOutCubic);
      }
    });
  }

  @override
  void dispose() {
    _spinController.dispose();
    _entranceController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    HapticFeedback.lightImpact(); 
    _scaleController.animateTo(0.96, duration: const Duration(milliseconds: 100), curve: Curves.easeOutQuad);
  }

  void _onTapUp(TapUpDetails details) {
    HapticFeedback.mediumImpact(); 
    _scaleController.animateTo(1.0, duration: const Duration(milliseconds: 600), curve: Curves.elasticOut);

    setState(() {
      _isObscured = !_isObscured;
    });
  }

  void _onTapCancel() {
    _scaleController.animateTo(1.0, duration: const Duration(milliseconds: 600), curve: Curves.elasticOut);
  }

  @override
  Widget build(BuildContext context) {
    // [BEST PRACTICE: Cache kamus]
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: AspectRatio(
        aspectRatio: 1,
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          behavior: HitTestBehavior.opaque,
          child: ScaleTransition(
            scale: _scaleController, 
            child: Stack(
              children: [
                // 1. Lapangan Belakang
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.white,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryDark.withValues(alpha: 0.04),
                        blurRadius: 30,
                        spreadRadius: 0,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                ),

                // 2. Lapisan Tengah (Aura)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_spinController, _entranceController]),
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _AuraRingPainter(
                          rotation: _spinController.value * 2 * math.pi,
                          entranceProgress: _entranceController.value,
                        ),
                      );
                    },
                  ),
                ),

                // 3. Lapisan Depan (Teks)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.totalBalance, // [INJEKSI LOKALISASI]
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.greyText.withValues(alpha: 0.8),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              "Rp",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _isObscured 
                                    ? AppColors.greyText.withValues(alpha: 0.5) 
                                    : AppColors.primaryDark.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),

                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            switchInCurve: Curves.easeOutQuart,
                            switchOutCurve: Curves.easeInQuad,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: Tween<double>(begin: 0.96, end: 1.0).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: Text(
                              _isObscured ? "• • • • • • •" : _formatNumber.format(widget.balance),
                              key: ValueKey<bool>(_isObscured),
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                color: _isObscured ? AppColors.greyText : AppColors.primaryDark,
                                height: 1.1,
                                letterSpacing: _isObscured ? 1.0 : -1.0, 
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                        child: Row(
                          key: ValueKey<bool>(_isObscured),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              size: 14,
                              color: AppColors.accentGreen,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isObscured ? l10n.tapToReveal : l10n.tapToHide, // [INJEKSI LOKALISASI]
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.greyText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuraRingPainter extends CustomPainter {
  final double rotation;
  final double entranceProgress;

  _AuraRingPainter({required this.rotation, required this.entranceProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius - 16);

    final trackPaint = Paint()
      ..color = AppColors.greyText.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius - 16, trackPaint);

    if (entranceProgress <= 0.0) return;

    final sweepAngle = entranceProgress * 2 * math.pi;
    final startAngle = rotation - (math.pi / 2);
    final gradientRotation = startAngle + sweepAngle - math.pi;

    final auraPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0 
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          AppColors.accentGreen.withValues(alpha: 0.1),
          AppColors.accentGreen.withValues(alpha: 0.40), 
          AppColors.accentGreen.withValues(alpha: 0.1),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0], 
        transform: GradientRotation(gradientRotation),
      ).createShader(rect);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16.0 
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16.0) 
      ..shader = auraPaint.shader;

    canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);
    canvas.drawArc(rect, startAngle, sweepAngle, false, auraPaint);
  }

  @override
  bool shouldRepaint(covariant _AuraRingPainter oldDelegate) {
    return oldDelegate.rotation != rotation || 
           oldDelegate.entranceProgress != entranceProgress;
  }
}