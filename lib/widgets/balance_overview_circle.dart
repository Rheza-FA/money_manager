import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';

class BalanceOverviewCircle extends StatefulWidget {
  final double balance;

  const BalanceOverviewCircle({super.key, required this.balance});

  @override
  State<BalanceOverviewCircle> createState() => _BalanceOverviewCircleState();
}

class _BalanceOverviewCircleState extends State<BalanceOverviewCircle> with TickerProviderStateMixin {
  late final AnimationController _spinController;
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;
  bool _isObscured = false; 

  @override
  void initState() {
    super.initState();
    
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeOutCirc,
        reverseCurve: Curves.easeIn,
      ),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    HapticFeedback.selectionClick();
    _scaleController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    HapticFeedback.lightImpact();
    _scaleController.reverse();
    setState(() {
      _isObscured = !_isObscured;
    });
  }

  void _onTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final formatNumber = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );

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
            scale: _scaleAnimation,
            child: Stack(
              children: [
                // 1. Lapangan Belakang: Container Putih Solid & Bayangan
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.white,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryDark.withOpacity(0.04),
                        blurRadius: 30,
                        spreadRadius: 0,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                ),

                // 2. Lapisan Tengah: CustomPaint untuk Cincin Aura (Sekarang di atas container putih)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _spinController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _AuraRingPainter(
                          rotation: _spinController.value * 2 * math.pi,
                        ),
                      );
                    },
                  ),
                ),

                // 3. Lapisan Depan: Konten Teks & Informasi Balance
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "TOTAL BALANCE",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.greyText.withOpacity(0.8),
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
                                    ? AppColors.greyText.withOpacity(0.5) 
                                    : AppColors.primaryDark.withOpacity(0.7),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            switchInCurve: Curves.easeOutBack,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.0, 0.2),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: Text(
                              _isObscured ? "•••••••" : formatNumber.format(widget.balance),
                              key: ValueKey<bool>(_isObscured),
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                color: _isObscured ? AppColors.greyText : AppColors.primaryDark,
                                height: 1.1,
                                letterSpacing: -1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: _isObscured ? 1.0 : 0.0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility_off_rounded,
                              size: 14,
                              color: AppColors.accentGreen,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Tap to reveal",
                              style: TextStyle(
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
  _AuraRingPainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final trackPaint = Paint()
      ..color = AppColors.greyText.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius - 16, trackPaint);

    final auraPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          AppColors.accentGreen.withOpacity(0.5),
          AppColors.accentGreen,
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 0.5, 0.9],
        transform: GradientRotation(rotation),
      ).createShader(Rect.fromCircle(center: center, radius: radius - 16));

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0)
      ..shader = auraPaint.shader;

    canvas.drawCircle(center, radius - 16, glowPaint);
    canvas.drawCircle(center, radius - 16, auraPaint);
  }

  @override
  bool shouldRepaint(covariant _AuraRingPainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}
