import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:money_manager/theme/app_colors.dart';
import 'package:money_manager/screens/dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _shiftAnimation;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.primaryDark,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    FlutterNativeSplash.remove();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnimation = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.0, end: 1.05)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 60.0,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.05, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 40.0,
      ),
    ]).animate(_controller);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    // INTI SOLUSI: The Dynamic Anchor Shift
    // Dimulai dari +40px (ke bawah) untuk mengunci logo di pusat geometris layar,
    // lalu bergerak ke 0.0 untuk mengangkat keseluruhan komposisi ke pusat optikal yang seimbang.
    _shiftAnimation = Tween<double>(
      begin: 40.0, 
      end: 0.0,    
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _startSplashSequence();
  }

  Future<void> _startSplashSequence() async {
    _controller.forward();
    await Future<void>.delayed(const Duration(milliseconds: 2600));

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (BuildContext context, Animation<double> animation, _) {
          return FadeTransition(
            opacity: animation,
            child: const DashboardScreen(),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Center(
        // AnimatedBuilder mengendalikan translasi (pergeseran Y) pada keseluruhan grup
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            return Transform.translate(
              offset: Offset(0, _shiftAnimation.value),
              child: child,
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min, // Mengelompokkan elemen secara padat
            children: <Widget>[
              ScaleTransition(
                scale: _scaleAnimation,
                child: SizedBox(
                  width: 160,
                  height: 160,
                  child: CustomPaint(
                    painter: _BreakoutMChartLogoPainter(),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: <Widget>[
                    Text(
                      'MONEY MANAGER',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4.0,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Take control of your wealth',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                        color: AppColors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Identitas Visual: "The Breakout M-Chart"
class _BreakoutMChartLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final Offset center = Offset(s / 2, s / 2);
    final double coinRadius = s * 0.23; 
    final double strokeWidth = s * 0.045;

    final Paint coinPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.fill;
      
    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: center, radius: coinRadius)),
      Colors.black.withValues(alpha: 0.25),
      12.0,
      true,
    );
    canvas.drawCircle(center, coinRadius, coinPaint);

    final Paint mPathPaint = Paint()
      ..color = AppColors.primaryDark 
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path mPath = Path();
    mPath.moveTo(s * 0.36, s * 0.60);
    mPath.lineTo(s * 0.44, s * 0.44);
    mPath.lineTo(s * 0.52, s * 0.54);
    mPath.lineTo(s * 0.68, s * 0.32);
    
    canvas.drawPath(mPath, mPathPaint);

    final Paint arrowPaint = Paint()
      ..color = AppColors.accentGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path arrowPath = Path();
    arrowPath.moveTo(s * 0.57, s * 0.32);
    arrowPath.lineTo(s * 0.68, s * 0.32);
    arrowPath.lineTo(s * 0.68, s * 0.43);

    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}