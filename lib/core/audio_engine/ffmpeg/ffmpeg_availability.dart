import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';

/// Checks once per app run whether an audio processing engine is available.
/// Android uses the FFmpeg libraries bundled with the app; desktop platforms
/// use the system executable on PATH.
class FfmpegAvailability {
  static bool? _available;

  /// Exposed so Settings/tests can force a re-check after the user installs
  /// FFmpeg without restarting the app.
  static void reset() => _available = null;

  static Future<bool> check() async {
    if (_available != null) return _available!;
    if (Platform.isAndroid) {
      try {
        final session = await FFmpegKit.executeWithArguments(['-version']);
        _available = ReturnCode.isSuccess(await session.getReturnCode());
      } catch (_) {
        _available = false;
      }
      return _available!;
    }
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
