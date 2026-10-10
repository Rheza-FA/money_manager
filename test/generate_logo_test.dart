import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Generate Enterprise "Breakout M-Chart" Logo PNG', () async {
    const double size = 512.0;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    // 1. BACKGROUND (Deep Forest)
    // Dirender agar transisi dengan Native Splash OS menjadi 100% seamless
    final Paint bgPaint = Paint()..color = const Color(0xFF0A332B);
    canvas.drawRect(const Rect.fromLTWH(0, 0, size, size), bgPaint);

    // Variabel Geometris (Golden Ratio approach)
    final Offset center = const Offset(size / 2, size / 2);
    const double coinRadius = size * 0.23; 
    const double strokeWidth = size * 0.045;

    // 2. THE SOLID COIN (White Foundation)
    final Paint coinPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, coinRadius, coinPaint);

    // 3. THE NEGATIVE-SPACE 'M' CHART
    // Kita melukis dengan warna background (#0A332B) di atas koin putih 
    // untuk menciptakan efek ilusi ruang negatif (cutout).
    final Paint mPathPaint = Paint()
      ..color = const Color(0xFF0A332B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path mPath = Path();
    // P1: Start bottom-left
    mPath.moveTo(size * 0.36, size * 0.60);
    // P2: First Peak
    mPath.lineTo(size * 0.44, size * 0.44);
    // P3: The Dip (Center)
    mPath.lineTo(size * 0.52, size * 0.54);
    // P4: Second Peak (Breaking out of the coin radius)
    mPath.lineTo(size * 0.68, size * 0.32);
    
    canvas.drawPath(mPath, mPathPaint);

    // 4. THE BREAKOUT ARROW (Mint Accent)
    // Mata panah tajam yang diletakkan persis di P4
    final Paint arrowPaint = Paint()
      ..color = const Color(0xFF84D696)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path arrowPath = Path();
    // Sayap kiri panah
    arrowPath.moveTo(size * 0.57, size * 0.32);
    // Ujung puncak panah (P4)
    arrowPath.lineTo(size * 0.68, size * 0.32);
    // Sayap bawah panah
    arrowPath.lineTo(size * 0.68, size * 0.43);

    canvas.drawPath(arrowPath, arrowPaint);

    // Eksekusi Kompilasi Gambar
    final ui.Picture picture = recorder.endRecording();
    final ui.Image img = await picture.toImage(size.toInt(), size.toInt());
    
    final ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Gagal mengonversi gambar ke byte.');
    
    final Uint8List buffer = byteData.buffer.asUint8List();
    final Directory dir = Directory('web/icons');
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final File file = File('web/icons/native_splash_logo.png');
    await file.writeAsBytes(buffer);
    
    debugPrint('Enterprise "Breakout M-Chart" Logo berhasil dicetak di: ${file.path}');
  });
}