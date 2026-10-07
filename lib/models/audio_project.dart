/// Core project data models. These describe the *project representation* —
/// edits (cut/trim/move/fade/effects) are applied here, never directly to
/// source files (spec section 20).
library;

class Effect {
  final String id;
  final String type; // e.g. 'eq', 'reverb', 'echo', 'compressor'
  final bool enabled;
  final Map<String, double> parameters;

  const Effect({
    required this.id,
    required this.type,
    this.enabled = true,
    this.parameters = const {},
  });

  Effect copyWith({bool? enabled, Map<String, double>? parameters}) => Effect(
        id: id,
        type: type,
        enabled: enabled ?? this.enabled,
        parameters: parameters ?? this.parameters,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'enabled': enabled,
        'parameters': parameters,
      };

  factory Effect.fromJson(Map<String, dynamic> json) => Effect(
        id: json['id'],
        type: json['type'],
        enabled: json['enabled'] ?? true,
        parameters: Map<String, double>.from(json['parameters'] ?? {}),
      );
}

class AudioClip {
  final String id;
  final String sourcePath;
  final String name;
  final Duration startTime; // in-point within the source file
  final Duration endTime; // out-point within the source file
  final Duration timelinePosition; // where it sits on the track
  final double volume; // linear 0.0–2.0 (0 dB = 1.0)
  final double pan; // -1.0 (L) .. 1.0 (R)
  final Duration fadeIn;
  final Duration fadeOut;
  final List<Effect> effects;
  final double speed; // 1.0 = normal
  final double pitchSemitones; // 0 = unchanged
  final bool muted;
  final bool locked;

  const AudioClip({
    required this.id,
    required this.sourcePath,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.timelinePosition,
    this.volume = 1.0,
    this.pan = 0.0,
    this.fadeIn = Duration.zero,
    this.fadeOut = Duration.zero,
    this.effects = const [],
    this.speed = 1.0,
    this.pitchSemitones = 0.0,
    this.muted = false,
    this.locked = false,
  });

  Duration get sourceDuration => endTime - startTime;

  AudioClip copyWith({
    String? name,
    Duration? startTime,
    Duration? endTime,
    Duration? timelinePosition,
    double? volume,
    double? pan,
    Duration? fadeIn,
    Duration? fadeOut,
    List<Effect>? effects,
    double? speed,
    double? pitchSemitones,
    bool? muted,
    bool? locked,
  }) {
    return AudioClip(
      id: id,
      sourcePath: sourcePath,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      timelinePosition: timelinePosition ?? this.timelinePosition,
      volume: volume ?? this.volume,
      pan: pan ?? this.pan,
      fadeIn: fadeIn ?? this.fadeIn,
      fadeOut: fadeOut ?? this.fadeOut,
      effects: effects ?? this.effects,
      speed: speed ?? this.speed,
      pitchSemitones: pitchSemitones ?? this.pitchSemitones,
      muted: muted ?? this.muted,
      locked: locked ?? this.locked,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourcePath': sourcePath,
        'name': name,
        'startTimeMs': startTime.inMilliseconds,
        'endTimeMs': endTime.inMilliseconds,
        'timelinePositionMs': timelinePosition.inMilliseconds,
        'volume': volume,
        'pan': pan,
        'fadeInMs': fadeIn.inMilliseconds,
        'fadeOutMs': fadeOut.inMilliseconds,
        'effects': effects.map((e) => e.toJson()).toList(),
        'speed': speed,
        'pitchSemitones': pitchSemitones,
        'muted': muted,
        'locked': locked,
      };

  factory AudioClip.fromJson(Map<String, dynamic> json) => AudioClip(
        id: json['id'],
        sourcePath: json['sourcePath'],
        name: json['name'],
        startTime: Duration(milliseconds: json['startTimeMs'] ?? 0),
        endTime: Duration(milliseconds: json['endTimeMs'] ?? 0),
        timelinePosition: Duration(milliseconds: json['timelinePositionMs'] ?? 0),
        volume: (json['volume'] ?? 1.0).toDouble(),
        pan: (json['pan'] ?? 0.0).toDouble(),
        fadeIn: Duration(milliseconds: json['fadeInMs'] ?? 0),
        fadeOut: Duration(milliseconds: json['fadeOutMs'] ?? 0),
        effects: (json['effects'] as List? ?? []).map((e) => Effect.fromJson(e)).toList(),
        speed: (json['speed'] ?? 1.0).toDouble(),
        pitchSemitones: (json['pitchSemitones'] ?? 0.0).toDouble(),
        muted: json['muted'] ?? false,
        locked: json['locked'] ?? false,
      );
}

class AudioTrack {
  final String id;
  final String name;
  final List<AudioClip> clips;
  final double volume;
  final double pan;
  final bool muted;
  final bool solo;
  final bool locked;

  const AudioTrack({
    required this.id,
    required this.name,
    this.clips = const [],
    this.volume = 1.0,
    this.pan = 0.0,
    this.muted = false,
    this.solo = false,
    this.locked = false,
  });

  AudioTrack copyWith({
    String? name,
    List<AudioClip>? clips,
    double? volume,
    double? pan,
    bool? muted,
    bool? solo,
    bool? locked,
  }) {
    return AudioTrack(
      id: id,
      name: name ?? this.name,
      clips: clips ?? this.clips,
      volume: volume ?? this.volume,
      pan: pan ?? this.pan,
      muted: muted ?? this.muted,
      solo: solo ?? this.solo,
      locked: locked ?? this.locked,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'clips': clips.map((c) => c.toJson()).toList(),
        'volume': volume,
        'pan': pan,
        'muted': muted,
        'solo': solo,
        'locked': locked,
      };

  factory AudioTrack.fromJson(Map<String, dynamic> json) => AudioTrack(
        id: json['id'],
        name: json['name'],
        clips: (json['clips'] as List? ?? []).map((c) => AudioClip.fromJson(c)).toList(),
        volume: (json['volume'] ?? 1.0).toDouble(),
        pan: (json['pan'] ?? 0.0).toDouble(),
        muted: json['muted'] ?? false,
        solo: json['solo'] ?? false,
        locked: json['locked'] ?? false,
      );
}

class AudioProject {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final List<AudioTrack> tracks;
  final int sampleRate;
  final Map<String, dynamic> projectSettings;

  const AudioProject({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.modifiedAt,
    this.tracks = const [],
    this.sampleRate = 44100,
    this.projectSettings = const {},
  });

  /// Total duration = furthest clip end across all tracks.
  Duration get duration {
    Duration max = Duration.zero;
    for (final track in tracks) {
      for (final clip in track.clips) {
        final end = clip.timelinePosition + clip.sourceDuration;
        if (end > max) max = end;
      }
    }
    return max;
  }

  int get trackCount => tracks.length;

  AudioProject copyWith({
    String? name,
    DateTime? modifiedAt,
    List<AudioTrack>? tracks,
    int? sampleRate,
    Map<String, dynamic>? projectSettings,
  }) {
    return AudioProject(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? DateTime.now(),
      tracks: tracks ?? this.tracks,
      sampleRate: sampleRate ?? this.sampleRate,
      projectSettings: projectSettings ?? this.projectSettings,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        'tracks': tracks.map((t) => t.toJson()).toList(),
        'sampleRate': sampleRate,
        'projectSettings': projectSettings,
      };

  factory AudioProject.fromJson(Map<String, dynamic> json) => AudioProject(
        id: json['id'],
        name: json['name'],
        createdAt: DateTime.parse(json['createdAt']),
        modifiedAt: DateTime.parse(json['modifiedAt']),
        tracks: (json['tracks'] as List? ?? []).map((t) => AudioTrack.fromJson(t)).toList(),
        sampleRate: json['sampleRate'] ?? 44100,
        projectSettings: Map<String, dynamic>.from(json['projectSettings'] ?? {}),
      );
}
