import 'package:just_audio/just_audio.dart';

import 'ffmpeg/ffmpeg_service.dart';

/// Reads duration from FFmpeg first, then just_audio. Android file pickers
/// often hand over formats just_audio cannot open.
class DurationProbe {
  static Future<Duration?> probe(String path) async {
    final fromFfmpeg = await FfmpegService().probeDuration(path);
    if (fromFfmpeg != null && fromFfmpeg > Duration.zero) return fromFfmpeg;

    final player = AudioPlayer();
    try {
      final duration = await player.setFilePath(path);
      if (duration != null && duration > Duration.zero) return duration;
    } catch (_) {
      return null;
    } finally {
      await player.dispose();
    }
    return null;
  }
}
