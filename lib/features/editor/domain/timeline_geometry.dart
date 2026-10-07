/// Pure timeline math — zoom (pixels-per-second) conversions and snapping.
/// Kept free of Flutter widgets so it's directly unit-testable.
class TimelineGeometry {
  final double pixelsPerSecond;

  const TimelineGeometry(this.pixelsPerSecond);

  double timeToPixels(Duration time) => time.inMicroseconds / 1e6 * pixelsPerSecond;

  Duration pixelsToTime(double pixels) =>
      Duration(microseconds: (pixels / pixelsPerSecond * 1e6).round());

  /// Converts a drag delta in pixels straight to a delta duration, without
  /// going through an absolute pixel position.
  Duration deltaPixelsToTime(double dxPixels) =>
      Duration(microseconds: (dxPixels / pixelsPerSecond * 1e6).round());

  static const List<double> zoomSteps = [5, 10, 20, 40, 80, 120, 200, 320];

  static double clampZoom(double value) => value.clamp(zoomSteps.first, zoomSteps.last);
}

/// Snaps a candidate time to the nearest of [snapPoints] if it's within
/// [threshold]; otherwise returns the candidate unchanged. Used so dragging
/// a clip locks neatly onto the timeline start, the playhead, or another
/// clip's edge (spec section 17: "Snap clips").
Duration snapDuration(Duration candidate, List<Duration> snapPoints, Duration threshold) {
  Duration? best;
  var bestDelta = threshold;
  for (final point in snapPoints) {
    final delta = (candidate - point).abs();
    if (delta <= bestDelta) {
      bestDelta = delta;
      best = point;
    }
  }
  return best ?? candidate;
}
