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
  late final Animation<Offset> _slideAnimation;

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

    // Melepaskan Native Splash agar transisi animasi ini berjalan
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

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ScaleTransition(
              scale: _scaleAnimation,
              child: SizedBox(
                width: 120, // Diperbesar sedikit agar presisi visualnya mantap
                height: 120,
                child: CustomPaint(
                  painter: _AnalyticCoinLogoPainter(),
                ),
              ),
            ),
            const SizedBox(height: 36),
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
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
            ),
          ],
        ),
      ),
    );
  }
}

/// Identitas Visual: "The Analytic Coin"
class _AnalyticCoinLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width * 0.20;
    final double strokeWidth = size.width * 0.085;

    // 1. Busur Analitik (Mint)
    final Paint arcPaint = Paint()
      ..color = AppColors.accentGreen
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0.0,
      math.pi * 1.5,
      false,
      arcPaint,
    );

    // 2. Koin Kekayaan (White)
    final Offset coinCenter = Offset(
      center.dx + radius * math.cos(-math.pi / 4),
      center.dy + radius * math.sin(-math.pi / 4),
    );
    final double coinRadius = size.width * 0.07;

    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: coinCenter, radius: coinRadius)),
      Colors.black.withValues(alpha: 0.15),
      8.0,
      true,
    );

    final Paint coinPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(coinCenter, coinRadius, coinPaint);

    // 3. Percikan Pertumbuhan (Emerald)
    final Offset sparkCenter = Offset(
      center.dx + (radius * 1.35) * math.cos(-math.pi / 5.0),
      center.dy + (radius * 1.35) * math.sin(-math.pi / 5.0),
    );
    final double sparkRadius = size.width * 0.03;

    final Paint sparkPaint = Paint()
      ..color = const Color(0xFF40916C) // Emerald Leaf
      ..style = PaintingStyle.fill;
    canvas.drawCircle(sparkCenter, sparkRadius, sparkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}