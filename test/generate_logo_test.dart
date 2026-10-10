import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Generate Enterprise Native Splash Logo PNG', () async {
    const double size = 512.0;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    // KOREKSI GEOMETRIS: Mengunci radius maksimum di dalam Safe-Zone Android 12
    final Offset center = const Offset(size / 2, size / 2);
    const double radius = size * 0.20; // 20% dari kanvas, sangat aman dari pemotongan
    const double strokeWidth = size * 0.085;

    // 1. THE MANAGEMENT ARC (Mint Accent)
    final Paint arcPaint = Paint()
      ..color = const Color(0xFF84D696)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    // Busur 270 derajat dari arah jam 3 memutar ke jam 12. Meninggalkan kuadran Kanan Atas kosong.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0.0,
      math.pi * 1.5,
      false,
      arcPaint,
    );

    // 2. THE WEALTH COIN (White)
    // Diposisikan presisi menggunakan koordinat kutub (Polar Coordinates) di sudut -45 derajat
    final Offset coinCenter = Offset(
      center.dx + radius * math.cos(-math.pi / 4),
      center.dy + radius * math.sin(-math.pi / 4),
    );
    const double coinRadius = size * 0.07;

    // Bayangan Koin (Elevasi 3D)
    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: coinCenter, radius: coinRadius)),
      const Color(0xFF000000).withValues(alpha: 0.15),
      8.0,
      true,
    );

    final Paint coinPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(coinCenter, coinRadius, coinPaint);

    // 3. THE GROWTH SPARK (Emerald Leaf)
    // Titik aksen di luar koin, mengarah ke kanan atas (uptrend)
    final Offset sparkCenter = Offset(
      center.dx + (radius * 1.35) * math.cos(-math.pi / 5.0),
      center.dy + (radius * 1.35) * math.sin(-math.pi / 5.0),
    );
    const double sparkRadius = size * 0.03;

    final Paint sparkPaint = Paint()
      ..color = const Color(0xFF40916C)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(sparkCenter, sparkRadius, sparkPaint);

    // Rendering ke PNG Byte Data
    final ui.Picture picture = recorder.endRecording();
    final ui.Image img = await picture.toImage(size.toInt(), size.toInt());
    
    final ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Gagal mengonversi gambar ke byte.');
    }
    
    final Uint8List buffer = byteData.buffer.asUint8List();

    final Directory dir = Directory('web/icons');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final File file = File('web/icons/native_splash_logo.png');
    await file.writeAsBytes(buffer);
    
    debugPrint('Enterprise Logo sukses di-generate di: ${file.path}');
  });
}