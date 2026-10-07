import 'dart:io';

/// Checks once per app run whether a system `ffmpeg` binary is reachable on
/// PATH. Desktop platforms (Windows/macOS/Linux) can invoke it directly as a
/// process; this is what powers real waveform decoding today. RESONA's own
/// bundled FFmpeg (spec section 3/47) — including an Android-capable path —
/// lands with the full FFmpegService in a later phase.
class FfmpegAvailability {
  static bool? _available;

  /// Exposed so Settings/tests can force a re-check after the user installs
  /// FFmpeg without restarting the app.
  static void reset() => _available = null;

  static Future<bool> check() async {
    if (_available != null) return _available!;
    if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      _available = false;
      return false;
    }
    try {
      final result = await Process.run('ffmpeg', ['-version']);
      _available = result.exitCode == 0;
    } catch (_) {
      _available = false;
    }
    return _available!;
  }
}
