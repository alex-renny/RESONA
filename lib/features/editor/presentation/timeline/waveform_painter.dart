import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Paints a min/max peak table as filled vertical bars. Deliberately simple
/// and cheap — the peak table is already resampled to roughly one bucket
/// per pixel before it reaches here.
class WaveformPainter extends CustomPainter {
  final Float32List peaksMin;
  final Float32List peaksMax;
  final Color color;

  WaveformPainter({required this.peaksMin, required this.peaksMax, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (peaksMin.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final midY = size.height / 2;
    final count = peaksMin.length;
    final barWidth = size.width / count;

    for (var i = 0; i < count; i++) {
      final x = i * barWidth;
      final top = midY - peaksMax[i] * midY;
      final bottom = midY - peaksMin[i] * midY;
      final h = (bottom - top).abs().clamp(1.0, size.height);
      canvas.drawRect(
        Rect.fromLTWH(x, top, barWidth.clamp(0.5, double.infinity), h),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) =>
      oldDelegate.peaksMin != peaksMin || oldDelegate.color != color;
}
