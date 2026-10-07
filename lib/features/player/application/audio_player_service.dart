import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// Thin wrapper around just_audio for Phase 1 single-file preview playback.
/// The full timeline-synced multi-track player (spec section 49) arrives
/// once the timeline/mixing engine exists — this gives Home/Editor a working
/// "import and preview a file" loop today.
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Duration? get duration => _player.duration;

  Future<Duration?> loadFile(String path) async {
    return _player.setFilePath(path);
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();
  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> setVolume(double volume) => _player.setVolume(volume.clamp(0.0, 1.0));
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  void dispose() => _player.dispose();
}

final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final service = AudioPlayerService();
  ref.onDispose(service.dispose);
  return service;
});
