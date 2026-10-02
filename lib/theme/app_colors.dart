import 'package:flutter/material.dart';

class AppColors {
  static const Color backgroundTop = Color(0xFFF0F7F4);
  static const Color backgroundBottom = Color(0xFFDCECE4);
  static const Color primaryDark = Color(0xFF06302B);
  static const Color primaryLight = Color(0xFF0A4740);
  static const Color accentGreen = Color(0xFF8DC985);
  static const Color white = Color(0xFFFFFFFF);
  static const Color greyText = Color(0xFF7A908C);
  
  static const List<Color> bgGradient = [backgroundTop, backgroundBottom];

  // Efek shadow premium berstandar iOS/Modern UI
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: primaryDark.withValues(alpha: 0.04),
      blurRadius: 40,
      spreadRadius: 0,
      offset: const Offset(0, 16),
    ),
  ];
}