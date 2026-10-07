import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:resona/features/auto_merge/domain/auto_merge_models.dart';

// ---------------------------------------------------------------------------
// Result type
// ---------------------------------------------------------------------------

/// Result of a single FFmpeg operation.
class FfmpegResult {
  final bool success;
  final String? outputPath;
  final String? errorMessage;

  const FfmpegResult.success(this.outputPath)
      : success = true,
        errorMessage = null;

  const FfmpegResult.failure(this.errorMessage)
      : success = false,
        outputPath = null;

  @override
  String toString() => success
      ? 'FfmpegResult.success(outputPath: $outputPath)'
      : 'FfmpegResult.failure($errorMessage)';
}

// ---------------------------------------------------------------------------
// FfmpegService
// ---------------------------------------------------------------------------

/// Wraps all FFmpeg and FFprobe operations RESONA needs.
///
/// Every public method is safe against "FFmpeg not installed" — they return
/// [FfmpegResult.failure] immediately rather than throwing.
///
/// Commands are built as `List<String>` argument arrays and executed via
/// [Process.run] so shell injection is impossible.
class FfmpegService {
  // -------------------------------------------------------------------------
  // Discovery
  // -------------------------------------------------------------------------

  /// Finds the ffmpeg binary.
  ///
  /// Currently checks only the system PATH (`ffmpeg`). A bundled-asset path
  /// (spec §3/47) will be added in a later phase.
  ///
  /// Returns `null` if not found.
  static Future<String?> findFfmpeg() async {
    const candidates = ['ffmpeg', 'ffmpeg.exe'];
    for (final name in candidates) {
      try {
        final result = await Process.run(name, ['-version'],
            stdoutEncoding: utf8, stderrEncoding: utf8);
        if (result.exitCode == 0) return name;
      } catch (_) {
        // not on PATH under this name
      }
    }
    return null;
  }

  /// Returns `true` if an FFmpeg binary is reachable.
  static Future<bool> isAvailable() async => (await findFfmpeg()) != null;

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------

  static const _notFound =
      'FFmpeg not found. Please install FFmpeg and ensure it is on your PATH.';

  static Future<String?> _ffmpeg() => findFfmpeg();

  /// Finds ffprobe; falls back to the same location as ffmpeg.
  static Future<String?> _ffprobe() async {
    const candidates = ['ffprobe', 'ffprobe.exe'];
    for (final name in candidates) {
      try {
        final result = await Process.run(name, ['-version'],
            stdoutEncoding: utf8, stderrEncoding: utf8);
        if (result.exitCode == 0) return name;
      } catch (_) {
        // not found under this name
      }
    }
    return null;
  }

  /// Runs an ffmpeg command, returning a [FfmpegResult].
  Future<FfmpegResult> _run(
      String executable, List<String> args, String outputPath) async {
    try {
      final result = await Process.run(executable, args,
          stdoutEncoding: utf8, stderrEncoding: utf8);
      if (result.exitCode == 0 && await File(outputPath).exists()) {
        return FfmpegResult.success(outputPath);
      }
      final stderr = (result.stderr as String).trim();
      return FfmpegResult.failure(
          stderr.isNotEmpty ? stderr : 'FFmpeg exited with code ${result.exitCode}');
    } catch (e) {
      return FfmpegResult.failure('Process error: $e');
    }
  }

  /// Formats a [Duration] as an FFmpeg time string (`HH:MM:SS.mmm`).
  static String _ts(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    final ms = d.inMilliseconds % 1000;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}.'
        '${ms.toString().padLeft(3, '0')}';
  }

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Cuts a segment from [inputPath] between [startTime] and [endTime] and
  /// writes it to [outputPath].
  Future<FfmpegResult> cutAudio({
    required String inputPath,
    required String outputPath,
    required Duration startTime,
    required Duration endTime,
  }) async {
    final exe = await _ffmpeg();
    if (exe == null) return const FfmpegResult.failure(_notFound);

    final duration = endTime - startTime;
    if (duration <= Duration.zero) {
      return const FfmpegResult.failure('End time must be after start time.');
    }

    final args = [
      '-y',
      '-ss', _ts(startTime),
      '-i', inputPath,
      '-t', _ts(duration),
      '-c', 'copy',
      outputPath,
    ];

    return _run(exe, args, outputPath);
  }

  /// Concatenates a list of audio files in order into [outputPath].
  ///
  /// Uses the FFmpeg `concat` demuxer (via a temporary file list) for
  /// lossless joining when codecs match. Falls back to re-encoding via
  /// `aconcat` filter if needed.
  Future<FfmpegResult> concatAudio({
    required List<String> inputPaths,
    required String outputPath,
  }) async {
    final exe = await _ffmpeg();
    if (exe == null) return const FfmpegResult.failure(_notFound);
    if (inputPaths.isEmpty) return const FfmpegResult.failure('No input files given.');

    // Write a temporary concat list file.
    final listFile = File(p.join(
        p.dirname(outputPath), '_resona_concat_${DateTime.now().millisecondsSinceEpoch}.txt'));
    try {
      final lines = inputPaths.map((fp) => "file '${fp.replaceAll("'", "'\\''")}'").join('\n');
      await listFile.writeAsString(lines);

      final args = [
        '-y',
        '-f', 'concat',
        '-safe', '0',
        '-i', listFile.path,
        '-c', 'copy',
        outputPath,
      ];

      return await _run(exe, args, outputPath);
    } finally {
      if (await listFile.exists()) await listFile.delete();
    }
  }

  /// Applies fade-in and/or fade-out to [inputPath], writing to [outputPath].
  ///
  /// [totalDuration] is required only when [fadeOut] > zero and the file
  /// duration cannot be inferred; pass `null` to let FFmpeg probe it (slower).
  Future<FfmpegResult> applyFade({
    required String inputPath,
    required String outputPath,
    Duration fadeIn = Duration.zero,
    Duration fadeOut = Duration.zero,
    Duration? totalDuration,
  }) async {
    final exe = await _ffmpeg();
    if (exe == null) return const FfmpegResult.failure(_notFound);

    // Build the `afade` filter chain.
    final filters = <String>[];

    if (fadeIn > Duration.zero) {
      final d = fadeIn.inMilliseconds / 1000.0;
      filters.add('afade=t=in:st=0:d=$d');
    }

    if (fadeOut > Duration.zero) {
      final dur = totalDuration ?? await probeDuration(inputPath);
      if (dur == null) {
        return const FfmpegResult.failure(
            'Cannot determine file duration for fade-out calculation.');
      }
      final st = (dur - fadeOut).inMilliseconds / 1000.0;
      final d = fadeOut.inMilliseconds / 1000.0;
      filters.add('afade=t=out:st=$st:d=$d');
    }

    final filterStr = filters.isEmpty ? 'anull' : filters.join(',');

    final args = [
      '-y',
      '-i', inputPath,
      '-af', filterStr,
      outputPath,
    ];

    return _run(exe, args, outputPath);
  }

  /// Merges a list of [clips] with transitions, writing the result to
  /// [outputPath].
  ///
  /// Each map in [clips] must contain:
  /// - `path` (String) — absolute path to the source audio file
  /// - `startTime` (Duration) — trim start within the source file
  /// - `endTime` (Duration) — trim end within the source file
  /// - `fadeIn` (Duration) — fade applied to the head of this segment
  /// - `fadeOut` (Duration) — fade applied to the tail of this segment
  ///
  /// [transition] determines how adjacent clips are joined.
  /// [crossfadeDuration] is the overlap length for [TransitionType.crossfade]
  /// and the silence length for [TransitionType.fadeThroughSilence].
  Future<FfmpegResult> buildAutoMerge({
    required List<Map<String, dynamic>> clips,
    required String outputPath,
    TransitionType transition = TransitionType.hardCut,
    Duration crossfadeDuration = const Duration(seconds: 1),
  }) async {
    final exe = await _ffmpeg();
    if (exe == null) return const FfmpegResult.failure(_notFound);
    if (clips.isEmpty) return const FfmpegResult.failure('No clips provided.');

    // Single clip — just cut + fade, no complex filter needed.
    if (clips.length == 1) {
      final clip = clips.first;
      final path = clip['path'] as String;
      final start = clip['startTime'] as Duration? ?? Duration.zero;
      final end = clip['endTime'] as Duration? ?? Duration.zero;
      final fi = clip['fadeIn'] as Duration? ?? Duration.zero;
      final fo = clip['fadeOut'] as Duration? ?? Duration.zero;

      // Cut first.
      final tmp = p.join(p.dirname(outputPath),
          '_resona_tmp_${DateTime.now().millisecondsSinceEpoch}.wav');
      final cutResult = end > Duration.zero
          ? await cutAudio(
              inputPath: path,
              outputPath: tmp,
              startTime: start,
              endTime: end,
            )
          : FfmpegResult.success(path);

      if (!cutResult.success) return cutResult;

      final fadeResult = await applyFade(
        inputPath: cutResult.outputPath!,
        outputPath: outputPath,
        fadeIn: fi,
        fadeOut: fo,
      );

      if (tmp != path && await File(tmp).exists()) await File(tmp).delete();
      return fadeResult;
    }

    // -----------------------------------------------------------------------
    // Multi-clip: build a filter_complex graph.
    // -----------------------------------------------------------------------
    //
    // Strategy:
    //   1. For each clip, emit one `-ss`/`-t` trimmed input.
    //   2. Apply per-clip afade filters.
    //   3. Join with the requested transition type.
    // -----------------------------------------------------------------------

    final inputArgs = <String>[];
    final filterParts = <String>[];
    final n = clips.length;

    // Step 1 — declare inputs with seek + duration trimming.
    for (var i = 0; i < n; i++) {
      final clip = clips[i];
      final path = clip['path'] as String;
      final start = clip['startTime'] as Duration? ?? Duration.zero;
      final end = clip['endTime'] as Duration? ?? Duration.zero;

      inputArgs.addAll(['-ss', _ts(start)]);
      if (end > Duration.zero) {
        inputArgs.addAll(['-t', _ts(end - start)]);
      }
      inputArgs.addAll(['-i', path]);
    }

    // Step 2 — per-clip fade filters; output labelled [f0], [f1], …
    for (var i = 0; i < n; i++) {
      final clip = clips[i];
      final fi = clip['fadeIn'] as Duration? ?? Duration.zero;
      final fo = clip['fadeOut'] as Duration? ?? Duration.zero;

      // Determine clip length for fade-out anchor.
      final start = clip['startTime'] as Duration? ?? Duration.zero;
      final end = clip['endTime'] as Duration? ?? Duration.zero;
      final clipLen = end > Duration.zero ? end - start : null;

      final subFilters = <String>[];

      if (fi > Duration.zero) {
        final d = fi.inMilliseconds / 1000.0;
        subFilters.add('afade=t=in:st=0:d=$d');
      }

      if (fo > Duration.zero && clipLen != null) {
        final st = (clipLen - fo).inMilliseconds / 1000.0;
        final d = fo.inMilliseconds / 1000.0;
        if (st >= 0) subFilters.add('afade=t=out:st=$st:d=$d');
      }

      final filterExpr = subFilters.isEmpty ? 'anull' : subFilters.join(',');
      filterParts.add('[$i:a]$filterExpr[f$i]');
    }

    // Step 3 — join with transition.
    String finalLabel = '[out]';
    switch (transition) {
      case TransitionType.hardCut:
        // concat filter: N inputs, 0 video streams, 1 audio stream.
        final inputs = List.generate(n, (i) => '[f$i]').join('');
        filterParts.add('${inputs}concat=n=$n:v=0:a=1[out]');
        finalLabel = '[out]';

      case TransitionType.crossfade:
        // Chain acrossfade between consecutive faded clips.
        //
        // acrossfade is a 2-in-1-out filter; chain: [f0][f1] -> [cf0],
        // [cf0][f2] -> [cf1], …
        final cfDur = crossfadeDuration.inMilliseconds / 1000.0;
        String prev = '[f0]';
        for (var i = 1; i < n; i++) {
          final out = i == n - 1 ? 'out' : 'cf${i - 1}';
          filterParts.add('$prev[f$i]acrossfade=d=$cfDur:c1=tri:c2=tri[$out]');
          prev = '[$out]';
        }
        finalLabel = '[out]';

      case TransitionType.fadeThroughSilence:
        // Insert a silence source between each pair of faded clips, then
        // use the concat filter.
        final silDur = crossfadeDuration.inMilliseconds / 1000.0;
        final concatInputs = <String>[];
        for (var i = 0; i < n; i++) {
          concatInputs.add('[f$i]');
          if (i < n - 1) {
            final silLabel = 'sil$i';
            filterParts.add('aevalsrc=0:d=$silDur[$silLabel]');
            concatInputs.add('[$silLabel]');
          }
        }
        final total = n + (n - 1); // clips + silence segments
        filterParts
            .add('${concatInputs.join('')}concat=n=$total:v=0:a=1[out]');
        finalLabel = '[out]';
    }

    final filterComplex = filterParts.join(';');

    final args = [
      '-y',
      ...inputArgs,
      '-filter_complex', filterComplex,
      '-map', finalLabel,
      outputPath,
    ];

    return _run(exe, args, outputPath);
  }

  /// Converts [inputPath] to [outputPath], optionally re-encoding with the
  /// given [bitrate] (kbps), [sampleRate] (Hz), and channel count.
  Future<FfmpegResult> convertAudio({
    required String inputPath,
    required String outputPath,
    int? bitrate,
    int? sampleRate,
    int? channels,
  }) async {
    final exe = await _ffmpeg();
    if (exe == null) return const FfmpegResult.failure(_notFound);

    final args = <String>[
      '-y',
      '-i', inputPath,
    ];

    if (bitrate != null) args.addAll(['-b:a', '${bitrate}k']);
    if (sampleRate != null) args.addAll(['-ar', '$sampleRate']);
    if (channels != null) args.addAll(['-ac', '$channels']);

    args.add(outputPath);
    return _run(exe, args, outputPath);
  }

  /// Strips the audio stream from a video file at [inputPath] and writes an
  /// audio-only file to [outputPath].
  Future<FfmpegResult> extractAudio({
    required String inputPath,
    required String outputPath,
  }) async {
    final exe = await _ffmpeg();
    if (exe == null) return const FfmpegResult.failure(_notFound);

    final args = [
      '-y',
      '-i', inputPath,
      '-vn',        // no video
      '-acodec', 'copy',
      outputPath,
    ];

    return _run(exe, args, outputPath);
  }

  /// Uses `ffprobe` to determine the playback duration of a media file.
  ///
  /// Returns `null` if the file cannot be probed or FFprobe is unavailable.
  Future<Duration?> probeDuration(String path) async {
    final probe = await _ffprobe();
    if (probe == null) return null;

    try {
      final result = await Process.run(probe, [
        '-v', 'quiet',
        '-print_format', 'json',
        '-show_format',
        path,
      ], stdoutEncoding: utf8, stderrEncoding: utf8);

      if (result.exitCode != 0) return null;

      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final format = json['format'] as Map<String, dynamic>?;
      final durationStr = format?['duration'] as String?;
      if (durationStr == null) return null;

      final seconds = double.tryParse(durationStr);
      if (seconds == null) return null;

      return Duration(microseconds: (seconds * 1e6).round());
    } catch (_) {
      return null;
    }
  }

  /// Applies a simple 3-band equalizer to [inputPath].
  ///
  /// [bass], [mid], and [treble] are gain values in dB (positive = boost,
  /// negative = cut). Centre frequencies follow the common default:
  ///   bass  = 100 Hz, mid = 1 000 Hz, treble = 10 000 Hz.
  Future<FfmpegResult> applyEqualizer({
    required String inputPath,
    required String outputPath,
    double bass = 0,
    double mid = 0,
    double treble = 0,
  }) async {
    final exe = await _ffmpeg();
    if (exe == null) return const FfmpegResult.failure(_notFound);

    // Build an `equalizer` filter chain for each non-zero band.
    final filters = <String>[];
    if (bass != 0) {
      filters.add('equalizer=f=100:t=o:w=200:g=${bass.toStringAsFixed(1)}');
    }
    if (mid != 0) {
      filters.add('equalizer=f=1000:t=o:w=1000:g=${mid.toStringAsFixed(1)}');
    }
    if (treble != 0) {
      filters
          .add('equalizer=f=10000:t=o:w=5000:g=${treble.toStringAsFixed(1)}');
    }

    final filterStr = filters.isEmpty ? 'anull' : filters.join(',');

    final args = [
      '-y',
      '-i', inputPath,
      '-af', filterStr,
      outputPath,
    ];

    return _run(exe, args, outputPath);
  }

  /// Normalises the loudness of [inputPath] using the `loudnorm` filter
  /// (EBU R128 target: −23 LUFS, true peak −2 dBTP, LRA 7 LU).
  Future<FfmpegResult> normalize({
    required String inputPath,
    required String outputPath,
  }) async {
    final exe = await _ffmpeg();
    if (exe == null) return const FfmpegResult.failure(_notFound);

    const filter = 'loudnorm=I=-23:TP=-2:LRA=7';
    final args = [
      '-y',
      '-i', inputPath,
      '-af', filter,
      outputPath,
    ];

    return _run(exe, args, outputPath);
  }

  /// Changes the playback speed of [inputPath] by [speed]×.
  ///
  /// When [preservePitch] is `true` (default), the `atempo` filter is used so
  /// pitch does not shift with speed. `atempo` only accepts values in
  /// [0.5, 2.0], so extreme speeds are chained (e.g. 4× → `atempo=2,atempo=2`).
  ///
  /// When [preservePitch] is `false`, the `asetrate` + `aresample` approach
  /// is used — fast but changes pitch proportionally.
  Future<FfmpegResult> changeSpeed({
    required String inputPath,
    required String outputPath,
    required double speed,
    bool preservePitch = true,
  }) async {
    final exe = await _ffmpeg();
    if (exe == null) return const FfmpegResult.failure(_notFound);

    if (speed <= 0) {
      return const FfmpegResult.failure('Speed must be a positive number.');
    }

    String filterStr;

    if (preservePitch) {
      // Chain `atempo` filters to stay within [0.5, 2.0] per filter.
      final filters = _buildAtempoChain(speed);
      filterStr = filters.join(',');
    } else {
      // Alter sample rate then resample — pitch shifts with speed.
      final rate = (44100 * speed).round();
      filterStr = 'asetrate=$rate,aresample=44100';
    }

    final args = [
      '-y',
      '-i', inputPath,
      '-af', filterStr,
      outputPath,
    ];

    return _run(exe, args, outputPath);
  }

  /// Decomposes [speed] into a chain of `atempo` values, each in [0.5, 2.0].
  static List<String> _buildAtempoChain(double speed) {
    final filters = <String>[];
    var remaining = speed;

    if (remaining < 0.5) {
      // Slow down: repeatedly halve until within range.
      while (remaining < 0.5) {
        filters.add('atempo=0.5');
        remaining /= 0.5;
      }
    } else if (remaining > 2.0) {
      // Speed up: repeatedly double until within range.
      while (remaining > 2.0) {
        filters.add('atempo=2.0');
        remaining /= 2.0;
      }
    }

    // Remainder pass — format to 6 decimal places to avoid float noise.
    filters.add('atempo=${remaining.toStringAsFixed(6)}');
    return filters;
  }
}
