import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart'; // INJEKSI FONT
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

    // Mencabut layar native secara mulus saat UI Flutter siap
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
                width: 110,
                height: 110,
                child: CustomPaint(
                  painter: _BrandLogoPainter(),
                ),
              ),
            ),
            const SizedBox(height: 32),
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

class _BrandLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // KOREKSI SIMETRIS ABSOLUT (Diubah dari 0.40/0.60 menjadi 0.36/0.64 yang seimbang)
    final double radius = size.width * 0.32;
    final Offset centerLeft = Offset(size.width * 0.36, size.height / 2);
    final Offset centerRight = Offset(size.width * 0.64, size.height / 2);

    final Paint leftPaint = Paint()
      ..color = AppColors.accentGreen
      ..style = PaintingStyle.fill;

    // Menggunakan alpha blending murni tanpa kliping agar bentuk tetap simetris
    final Paint rightPaint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    canvas.drawShadow(
      Path()
        ..addOval(Rect.fromCircle(center: centerLeft, radius: radius))
        ..addOval(Rect.fromCircle(center: centerRight, radius: radius)),
      Colors.black.withValues(alpha: 0.25),
      12.0,
      true,
    );

    // Menggambar lingkaran kiri dan kanan secara utuh
    canvas.drawCircle(centerLeft, radius, leftPaint);
    canvas.drawCircle(centerRight, radius, rightPaint);

    final Paint dotPaint = Paint()
      ..color = AppColors.primaryDark
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      radius * 0.28,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}