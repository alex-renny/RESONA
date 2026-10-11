import 'dart:io';
import 'dart:typed_data';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import '../../errors/app_exception.dart';
import 'ffmpeg_availability.dart';

/// Decodes an audio file to raw mono 16-bit PCM via FFmpeg. Android uses the
/// bundled FFmpegKit library; desktop uses the system executable. This is
/// intentionally narrow — just enough to feed the waveform engine real
/// sample data (spec section 18/48: waveform generation must be based on actual
/// audio data, never a static placeholder).
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

    final tempPath = Platform.isAndroid
        ? '${Directory.systemTemp.path}${Platform.pathSeparator}resona_${DateTime.now().microsecondsSinceEpoch}.pcm'
        : null;
    final args = <String>[
      '-y',
      '-v', 'error',
      '-i', sourcePath,
      '-ac', '1',
      '-ar', '$waveformSampleRate',
      '-f', 's16le',
      tempPath ?? '-',
    ];

    Uint8List bytes;
    try {
      if (Platform.isAndroid) {
        try {
          final session = await FFmpegKit.executeWithArguments(args);
          if (!ReturnCode.isSuccess(await session.getReturnCode())) {
            throw const AppException(
              "RESONA couldn't process this audio file.",
              technicalDetails: 'bundled FFmpeg could not decode the source',
            );
          }
          bytes = await File(tempPath!).readAsBytes();
        } finally {
          final temp = File(tempPath!);
          if (await temp.exists()) await temp.delete();
        }
      } else {
        final result = await Process.run(
          'ffmpeg',
          args,
          stdoutEncoding: null,
          stderrEncoding: null,
        );
        if (result.exitCode != 0) {
          throw AppException(
            "RESONA couldn't process this audio file.",
            technicalDetails: 'ffmpeg exited ${result.exitCode}',
          );
        }
        bytes = result.stdout as Uint8List;
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(
        "RESONA couldn't process this audio file.",
        technicalDetails: 'ffmpeg decoding failed: $e',
      );
    }

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
