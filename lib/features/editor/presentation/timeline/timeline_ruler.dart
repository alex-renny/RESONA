import 'package:flutter/material.dart';
import '../../../../core/theme/color_scheme.dart';
import '../../../../core/utils/time_format.dart';
import '../../domain/timeline_geometry.dart';

/// The horizontal time ruler above the timeline. Tapping or dragging along
/// it moves the playhead (spec section 17: playhead).
class TimelineRuler extends StatelessWidget {
  final double width;
  final double height;
  final double pixelsPerSecond;
  final ValueChanged<Duration> onSeek;
  final ResonaPalette palette;

  const TimelineRuler({
    super.key,
    required this.width,
    required this.height,
    required this.pixelsPerSecond,
    required this.onSeek,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final geometry = TimelineGeometry(pixelsPerSecond);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => onSeek(geometry.pixelsToTime(d.localPosition.dx)),
      onHorizontalDragUpdate: (d) => onSeek(geometry.pixelsToTime(d.localPosition.dx)),
      child: CustomPaint(
        size: Size(width, height),
        painter: _RulerPainter(pixelsPerSecond: pixelsPerSecond, palette: palette),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  final double pixelsPerSecond;
  final ResonaPalette palette;

  _RulerPainter({required this.pixelsPerSecond, required this.palette});

  // "Nice" tick intervals in seconds. We pick the smallest one that still
  // keeps ticks at least ~60px apart, so labels never overlap at any zoom.
  static const List<double> _candidateIntervals = [
    0.1, 0.25, 0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300, 600,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()..color = palette.border;
    final textStyle = TextStyle(color: palette.textSecondary, fontSize: 10);

    var interval = _candidateIntervals.last;
    for (final c in _candidateIntervals) {
      if (c * pixelsPerSecond >= 60) {
        interval = c;
        break;
      }
    }

    final totalSeconds = size.width / pixelsPerSecond;
    for (var t = 0.0; t <= totalSeconds; t += interval) {
      final x = t * pixelsPerSecond;
      canvas.drawLine(Offset(x, size.height - 8), Offset(x, size.height), linePaint);

      final label = TimeFormat.format(Duration(milliseconds: (t * 1000).round()));
      final painter = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(x + 3, 2));
    }
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RulerPainter oldDelegate) =>
      oldDelegate.pixelsPerSecond != pixelsPerSecond || oldDelegate.palette != palette;
}
