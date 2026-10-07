import 'dart:io';
import 'dart:typed_data';
import '../../errors/app_exception.dart';
import 'ffmpeg_availability.dart';

/// Decodes an audio file to raw mono 16-bit PCM via a system `ffmpeg`
/// process. This is intentionally narrow — just enough to feed the waveform
/// engine real sample data (spec section 18/48: waveform generation must be
/// "based on actual audio data", never a static placeholder). The full
/// cut/merge/fade FFmpegService (spec section 47) arrives in a later phase
/// and will reuse this same process-invocation approach.
class FfmpegPcmDecoder {
  /// Sample rate used purely for waveform decoding — deliberately low.
  /// Peaks don't need full fidelity, and a low rate keeps decoding fast even
  /// for long files.
  static const int waveformSampleRate = 8000;

  Future<Int16List> decodeMonoPcm(String sourcePath) async {
    final available = await FfmpegAvailability.check();
    if (!available) {
      throw const AppException(
        "RESONA couldn't generate a waveform for this file.",
        technicalDetails: 'ffmpeg not found on PATH for this platform',
      );
    }

    if (!await File(sourcePath).exists()) {
      throw const AppException(
        'Source audio not found.',
        technicalDetails: 'file missing at decode time',
      );
    }

    final args = <String>[
      '-y',
      '-v', 'error',
      '-i', sourcePath,
      '-ac', '1',
      '-ar', '$waveformSampleRate',
      '-f', 's16le',
      '-',
    ];

    ProcessResult result;
    try {
      result = await Process.run(
        'ffmpeg',
        args,
        stdoutEncoding: null,
        stderrEncoding: null,
      );
    } catch (e) {
      throw AppException(
        "RESONA couldn't process this audio file.",
        technicalDetails: 'ffmpeg process failed to start: $e',
      );
    }

    if (result.exitCode != 0) {
      throw AppException(
        "RESONA couldn't process this audio file.",
        technicalDetails: 'ffmpeg exited ${result.exitCode}',
      );
    }

    final bytes = result.stdout as Uint8List;
    if (bytes.isEmpty) {
      throw const AppException(
        "RESONA couldn't process this audio file.",
        technicalDetails: 'ffmpeg produced no audio data — possibly an unsupported format',
      );
    }

    // s16le, little-endian — wrap the raw bytes directly as Int16 samples.
    final usableBytes = bytes.length - (bytes.length % 2);
    return bytes.buffer.asInt16List(bytes.offsetInBytes, usableBytes ~/ 2);
  }
}
