import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Generate Enterprise "Breakout M-Chart" Master Icon (1024px)', () async {
    // RESOLUSI MASTER: Ditingkatkan dari 512 ke 1024 piksel untuk ketajaman absolut
    const double size = 1024.0;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    // 1. BACKGROUND (Deep Forest)
    // Dirender solid agar iOS tidak menolak (iOS melarang adanya alpha channel/transparansi)
    final Paint bgPaint = Paint()..color = const Color(0xFF0A332B);
    canvas.drawRect(const Rect.fromLTWH(0, 0, size, size), bgPaint);

    final Offset center = const Offset(size / 2, size / 2);
    const double coinRadius = size * 0.23; 
    const double strokeWidth = size * 0.045;

    // 2. THE SOLID COIN (White Foundation)
    final Paint coinPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, coinRadius, coinPaint);

    // 3. THE NEGATIVE-SPACE 'M' CHART
    final Paint mPathPaint = Paint()
      ..color = const Color(0xFF0A332B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path mPath = Path();
    mPath.moveTo(size * 0.36, size * 0.60);
    mPath.lineTo(size * 0.44, size * 0.44);
    mPath.lineTo(size * 0.52, size * 0.54);
    mPath.lineTo(size * 0.68, size * 0.32);
    
    canvas.drawPath(mPath, mPathPaint);

    // 4. THE BREAKOUT ARROW (Mint Accent)
    final Paint arrowPaint = Paint()
      ..color = const Color(0xFF84D696)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path arrowPath = Path();
    arrowPath.moveTo(size * 0.57, size * 0.32);
    arrowPath.lineTo(size * 0.68, size * 0.32);
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

    // Output disalurkan ke file master khusus icon
    final File file = File('web/icons/app_icon_master.png');
    await file.writeAsBytes(buffer);
    
    debugPrint('Master Icon 1024x1024 berhasil dicetak di: ${file.path}');
  });
}