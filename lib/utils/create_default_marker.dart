import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';

Future<Uint8List> createDefaultMarker(MaterialColor paintColor) async {
    const int size = 60;
    const double strokeWidth = 10.0;

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);

    final paintOutside = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size / 2, paintOutside);

    final paintInside = Paint()
      ..color = paintColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, (size / 2) - strokeWidth, paintInside);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }