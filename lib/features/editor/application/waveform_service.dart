import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/audio_engine/ffmpeg/ffmpeg_pcm_decoder.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/waveform_math.dart';
import '../data/waveform_cache.dart';
import '../domain/waveform_data.dart';

/// Runs off the main isolate via `compute()` — this is the part that would
/// otherwise freeze the UI for long files (spec section 39).
(Float32List, Float32List) _computePeaksIsolate(Int16List samples) {
  return WaveformMath.computePeaks(samples, WaveformData.resolution);
}

/// Orchestrates waveform generation: memory cache → disk cache → real decode
/// via FFmpeg, with peak computation offloaded to a background isolate so
/// long files never freeze the UI (spec section 39/48).
class WaveformService {
  final FfmpegPcmDecoder _decoder = FfmpegPcmDecoder();
  final WaveformCache _cache = WaveformCache();
  final Map<String, WaveformData> _memory = {};

  Future<WaveformData> getWaveform(String sourcePath) async {
    final cached = _memory[sourcePath];
    if (cached != null) return cached;

    final onDisk = await _cache.read(sourcePath);
    if (onDisk != null) {
      _memory[sourcePath] = onDisk;
      return onDisk;
    }

    final samples = await _decoder.decodeMonoPcm(sourcePath);
    final (min, max) = await compute(_computePeaksIsolate, samples);
    final durationMs = ((samples.length / FfmpegPcmDecoder.waveformSampleRate) * 1000).round();
    final data = WaveformData(
      peaksMin: min,
      peaksMax: max,
      duration: Duration(milliseconds: durationMs),
    );

    _memory[sourcePath] = data;
    unawaited(_cache.write(sourcePath, data));
    return data;
  }

  void evict(String sourcePath) => _memory.remove(sourcePath);
}

final waveformServiceProvider = Provider<WaveformService>((ref) => WaveformService());

/// Per-source-file waveform, watched by clip widgets. Wrapping it as an
/// AsyncValue gives the timeline a real "Generating waveform..." loading
/// state (spec section 53) instead of a blank or fake waveform while
/// decoding, and a real error state when FFmpeg isn't available or the file
/// can't be decoded (spec section 38).
final waveformProvider = FutureProvider.family<WaveformData, String>((ref, sourcePath) async {
  final service = ref.watch(waveformServiceProvider);
  try {
    return await service.getWaveform(sourcePath);
  } on AppException {
    rethrow;
  } catch (e) {
    throw AppException("RESONA couldn't generate a waveform for this file.", technicalDetails: '$e');
  }
});
