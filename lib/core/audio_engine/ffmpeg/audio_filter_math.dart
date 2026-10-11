import 'dart:math';

import '../../../models/audio_project.dart';

/// Pure FFmpeg audio-filter builders. Kept free of I/O so they can be unit tested.
class AudioFilterMath {
  static List<String> atempoChain(double speed) {
    final filters = <String>[];
    var remaining = speed;
    if (remaining <= 0) return const ['anull'];

    if (remaining < 0.5) {
      while (remaining < 0.5) {
        filters.add('atempo=0.5');
        remaining /= 0.5;
      }
    } else if (remaining > 2.0) {
      while (remaining > 2.0) {
        filters.add('atempo=2.0');
        remaining /= 2.0;
      }
    }
    filters.add('atempo=${remaining.toStringAsFixed(6)}');
    return filters;
  }

  static List<String> pitchFilters(double semitones, {int sampleRate = 44100}) {
    if (semitones.abs() < 0.01) return const [];
    final factor = pow(2, semitones / 12.0).toDouble();
    final newRate = (sampleRate * factor).round();
    return [
      'asetrate=$newRate',
      'atempo=${(1 / factor).toStringAsFixed(6)}',
      'aresample=$sampleRate',
    ];
  }

  static String? panFilter(double pan) {
    if (pan.abs() < 0.01) return null;
    final left = (1.0 - pan).clamp(0.0, 1.0);
    final right = (1.0 + pan).clamp(0.0, 1.0);
    return 'pan=stereo|c0=${left.toStringAsFixed(4)}*c0|c1=${right.toStringAsFixed(4)}*c1';
  }

  static List<String> fadeFilters({
    required Duration fadeIn,
    required Duration fadeOut,
    required Duration clipDuration,
  }) {
    final filters = <String>[];
    if (fadeIn > Duration.zero) {
      filters.add('afade=t=in:st=0:d=${_sec(fadeIn)}');
    }
    if (fadeOut > Duration.zero && clipDuration > fadeOut) {
      final start = _sec(clipDuration - fadeOut);
      filters.add('afade=t=out:st=$start:d=${_sec(fadeOut)}');
    }
    return filters;
  }

  static List<String> effectFilters(List<Effect> effects) {
    final filters = <String>[];
    for (final effect in effects) {
      if (!effect.enabled) continue;
      final built = _effect(effect);
      if (built != null && built.isNotEmpty) filters.addAll(built);
    }
    return filters;
  }

  static List<String>? _effect(Effect effect) {
    final p = effect.parameters;
    switch (effect.type) {
      case 'eq':
        final bands = <String>[];
        final bass = p['bass'] ?? 0;
        final mid = p['mid'] ?? 0;
        final treble = p['treble'] ?? 0;
        if (bass != 0) {
          bands.add('equalizer=f=100:t=o:w=200:g=${bass.toStringAsFixed(1)}');
        }
        if (mid != 0) {
          bands.add('equalizer=f=1000:t=o:w=1000:g=${mid.toStringAsFixed(1)}');
        }
        if (treble != 0) {
          bands.add('equalizer=f=10000:t=o:w=5000:g=${treble.toStringAsFixed(1)}');
        }
        return bands;
      case 'bassBoost':
        final g = p['gain'] ?? 6;
        return ['bass=g=${g.toStringAsFixed(1)}:f=100:w=0.5'];
      case 'treble':
        final g = p['gain'] ?? 4;
        return ['treble=g=${g.toStringAsFixed(1)}'];
      case 'reverb':
        final decay = p['decay'] ?? 0.4;
        return ['aecho=0.8:0.88:60:${decay.toStringAsFixed(2)}'];
      case 'echo':
      case 'delay':
        final ms = p['delayMs'] ?? 180;
        final decay = p['decay'] ?? 0.4;
        return ['aecho=0.8:0.9:${ms.toStringAsFixed(0)}:${decay.toStringAsFixed(2)}'];
      case 'compressor':
        return [
          'acompressor=threshold=${(p['threshold'] ?? 0.125).toStringAsFixed(3)}'
              ':ratio=${(p['ratio'] ?? 4).toStringAsFixed(1)}'
              ':attack=${(p['attack'] ?? 20).toStringAsFixed(0)}'
              ':release=${(p['release'] ?? 250).toStringAsFixed(0)}',
        ];
      case 'limiter':
        return ['alimiter=limit=${(p['limit'] ?? 0.95).toStringAsFixed(2)}'];
      case 'distortion':
        return ['acrusher=bits=${(p['bits'] ?? 8).toStringAsFixed(0)}:mode=log'];
      case 'chorus':
        return ['chorus=0.5:0.9:50:0.4:0.25:2'];
      case 'flanger':
        return ['flanger'];
      case 'stereoWidth':
        return ['extrastereo=m=${(p['width'] ?? 1.5).toStringAsFixed(2)}'];
      case 'normalize':
        return ['loudnorm=I=-23:TP=-2:LRA=7'];
      case 'gain':
        return ['volume=${(p['gain'] ?? 1.0).toStringAsFixed(3)}'];
      default:
        return null;
    }
  }

  static String _sec(Duration d) => (d.inMilliseconds / 1000.0).toStringAsFixed(3);
}

class MixClipSpec {
  final String path;
  final Duration startTime;
  final Duration endTime;
  final Duration timelinePosition;
  final double volume;
  final double pan;
  final Duration fadeIn;
  final Duration fadeOut;
  final double speed;
  final double pitchSemitones;
  final List<Effect> effects;

  const MixClipSpec({
    required this.path,
    required this.startTime,
    required this.endTime,
    required this.timelinePosition,
    this.volume = 1.0,
    this.pan = 0.0,
    this.fadeIn = Duration.zero,
    this.fadeOut = Duration.zero,
    this.speed = 1.0,
    this.pitchSemitones = 0.0,
    this.effects = const [],
  });

  Duration get clipDuration => endTime - startTime;
}

/// Builds a single FFmpeg filter_complex graph that places every clip on the
/// timeline and mixes tracks together.
class TimelineMixBuilder {
  static List<MixClipSpec> clipsFromProject(AudioProject project) {
    final anySolo = project.tracks.any((t) => t.solo);
    final specs = <MixClipSpec>[];
    for (final track in project.tracks) {
      if (track.muted) continue;
      if (anySolo && !track.solo) continue;
      for (final clip in track.clips) {
        if (clip.muted) continue;
        if (clip.sourceDuration <= Duration.zero) continue;
        specs.add(MixClipSpec(
          path: clip.sourcePath,
          startTime: clip.startTime,
          endTime: clip.endTime,
          timelinePosition: clip.timelinePosition,
          volume: clip.volume * track.volume,
          pan: (clip.pan + track.pan).clamp(-1.0, 1.0),
          fadeIn: clip.fadeIn,
          fadeOut: clip.fadeOut,
          speed: clip.speed,
          pitchSemitones: clip.pitchSemitones,
          effects: clip.effects,
        ));
      }
    }
    return specs;
  }

  static ({List<String> inputArgs, String filterComplex, String mapLabel}) build(
    List<MixClipSpec> clips, {
    int sampleRate = 44100,
  }) {
    if (clips.isEmpty) {
      throw ArgumentError('No audible clips to mix.');
    }

    final inputArgs = <String>[];
    final filterParts = <String>[];

    for (var i = 0; i < clips.length; i++) {
      final clip = clips[i];
      inputArgs.addAll([
        '-ss', _ts(clip.startTime),
        '-t', _ts(clip.clipDuration),
        '-i', clip.path,
      ]);

      final chain = <String>[
        'aformat=sample_fmts=fltp:channel_layouts=stereo',
        'aresample=$sampleRate',
      ];
      if ((clip.speed - 1.0).abs() > 0.001) {
        chain.addAll(AudioFilterMath.atempoChain(clip.speed));
      }
      chain.addAll(AudioFilterMath.pitchFilters(clip.pitchSemitones, sampleRate: sampleRate));
      if ((clip.volume - 1.0).abs() > 0.001) {
        chain.add('volume=${clip.volume.toStringAsFixed(4)}');
      }
      final pan = AudioFilterMath.panFilter(clip.pan);
      if (pan != null) chain.add(pan);
      chain.addAll(AudioFilterMath.fadeFilters(
        fadeIn: clip.fadeIn,
        fadeOut: clip.fadeOut,
        clipDuration: clip.clipDuration,
      ));
      chain.addAll(AudioFilterMath.effectFilters(clip.effects));
      final delayMs = clip.timelinePosition.inMilliseconds;
      if (delayMs > 0) {
        chain.add('adelay=$delayMs|$delayMs');
      }
      filterParts.add('[$i:a]${chain.join(',')}[c$i]');
    }

    if (clips.length == 1) {
      filterParts.add('[c0]anull[mix]');
    } else {
      final inputs = List.generate(clips.length, (i) => '[c$i]').join();
      filterParts.add(
        '${inputs}amix=inputs=${clips.length}:duration=longest:dropout_transition=0:normalize=0[mix]',
      );
    }

    return (
      inputArgs: inputArgs,
      filterComplex: filterParts.join(';'),
      mapLabel: '[mix]',
    );
  }

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
}
