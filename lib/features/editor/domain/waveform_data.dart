import 'dart:typed_data';

/// Downsampled min/max peak pairs for fast waveform rendering at any zoom
/// level, generated from real decoded audio (spec section 18) and cached to
/// disk (spec section 48) so re-opening a project doesn't re-decode.
class WaveformData {
  /// Fixed peak resolution the data is stored/cached at. The painter
  /// resamples this down further to match whatever pixel width a clip
  /// currently occupies on screen.
  static const int resolution = 4000;

  final Float32List peaksMin;
  final Float32List peaksMax;
  final Duration duration;

  const WaveformData({
    required this.peaksMin,
    required this.peaksMax,
    required this.duration,
  });

  bool get isEmpty => peaksMin.isEmpty;

  static final empty = WaveformData(
    peaksMin: Float32List(0),
    peaksMax: Float32List(0),
    duration: Duration.zero,
  );
}
