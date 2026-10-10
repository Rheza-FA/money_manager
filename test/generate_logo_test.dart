import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Generate Native Splash Logo PNG', () async {
    const double size = 512.0; 
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    final double radius = size * 0.32;
    final Offset centerLeft = Offset(size * 0.36, size / 2);
    final Offset centerRight = Offset(size * 0.64, size / 2);

    final Paint leftPaint = Paint()
      ..color = const Color(0xFF84D696)
      ..style = PaintingStyle.fill;

    final Paint rightPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(centerLeft, radius, leftPaint);
    canvas.drawCircle(centerRight, radius, rightPaint);

    final Paint dotPaint = Paint()
      ..color = const Color(0xFF0A332B)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size / 2, size / 2), radius * 0.28, dotPaint);

    final ui.Picture picture = recorder.endRecording();
    final ui.Image img = await picture.toImage(size.toInt(), size.toInt());
    
    final ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Gagal mengonversi gambar ke dalam bentuk byte.');
    }
    
    final Uint8List buffer = byteData.buffer.asUint8List();

    final Directory dir = Directory('web/icons');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final File file = File('web/icons/native_splash_logo.png');
    await file.writeAsBytes(buffer);
    
    debugPrint('Logo berhasil di-generate di: ${file.path}');
  });
}