import 'dart:typed_data';

/// Pure peak-computation helpers — kept free of Flutter/plugin dependencies
/// so they're easy to unit test in isolation.
class WaveformMath {
  /// Splits [samples] into [bucketCount] buckets and returns the min and max
  /// value in each bucket, normalized to -1.0..1.0. Used to turn raw PCM
  /// into a fixed-resolution peak table cheap enough to paint at any zoom
  /// level. Runs inside a background isolate via `compute()` (spec section
  /// 39/48) since this is the expensive part for long files.
  static (Float32List min, Float32List max) computePeaks(
    Int16List samples,
    int bucketCount,
  ) {
    if (samples.isEmpty || bucketCount <= 0) {
      return (Float32List(0), Float32List(0));
    }
    final mins = Float32List(bucketCount);
    final maxs = Float32List(bucketCount);
    final samplesPerBucket = samples.length / bucketCount;

    for (var b = 0; b < bucketCount; b++) {
      final start = (b * samplesPerBucket).floor();
      var end = ((b + 1) * samplesPerBucket).floor();
      if (end <= start) end = start + 1;
      if (end > samples.length) end = samples.length;

      var minV = 32767;
      var maxV = -32768;
      for (var i = start; i < end; i++) {
        final s = samples[i];
        if (s < minV) minV = s;
        if (s > maxV) maxV = s;
      }
      if (start >= samples.length) {
        minV = 0;
        maxV = 0;
      }
      mins[b] = minV / 32768.0;
      maxs[b] = maxV / 32768.0;
    }
    return (mins, maxs);
  }

  /// Resamples an already-computed peak table down to [targetCount] buckets
  /// — e.g. shrinking the cached 4000-point table to however many pixels a
  /// clip currently occupies on screen at the current zoom level. Returns
  /// the source unchanged (not copied) when it's already small enough.
  static (Float32List min, Float32List max) resamplePeaks(
    Float32List sourceMin,
    Float32List sourceMax,
    int targetCount,
  ) {
    if (sourceMin.isEmpty || targetCount <= 0) {
      return (Float32List(0), Float32List(0));
    }
    if (targetCount >= sourceMin.length) {
      return (sourceMin, sourceMax);
    }
    final mins = Float32List(targetCount);
    final maxs = Float32List(targetCount);
    final ratio = sourceMin.length / targetCount;

    for (var b = 0; b < targetCount; b++) {
      final start = (b * ratio).floor();
      var end = ((b + 1) * ratio).floor();
      if (end <= start) end = start + 1;
      if (end > sourceMin.length) end = sourceMin.length;

      var minV = 1.0;
      var maxV = -1.0;
      for (var i = start; i < end; i++) {
        if (sourceMin[i] < minV) minV = sourceMin[i];
        if (sourceMax[i] > maxV) maxV = sourceMax[i];
      }
      mins[b] = minV;
      maxs[b] = maxV;
    }
    return (mins, maxs);
  }
}
