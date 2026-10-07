import 'dart:convert';

/// Transition type applied between two consecutive clips.
enum TransitionType {
  /// Direct cut with no overlap or silence.
  hardCut,

  /// Outgoing clip fades out while incoming clip fades in simultaneously.
  crossfade,

  /// Outgoing clip fades to silence, then incoming clip fades in from silence.
  fadeThroughSilence,
}

/// A single item in the auto-merge queue representing one audio source with
/// all user-configurable parameters (in/out points, fades, transition).
class AutoMergeItem {
  final String id;
  final String sourcePath;
  final String name;

  /// Actual duration of the source file; null until probed via just_audio.
  final Duration? sourceDuration;

  /// In-point: where playback of this source begins. Defaults to Duration.zero.
  final Duration startTime;

  /// Out-point: where playback of this source ends.
  /// [Duration.zero] is a sentinel meaning "play until source end".
  final Duration endTime;

  /// 1-based position in the merge queue.
  final int position;

  /// Fade-in applied to the beginning of this clip's segment.
  final Duration fadeIn;

  /// Fade-out applied to the end of this clip's segment.
  final Duration fadeOut;

  /// Transition type used between the previous clip and this clip.
  final TransitionType transition;

  /// Duration of the crossfade overlap. Only meaningful when
  /// [transition] == [TransitionType.crossfade].
  final Duration crossfadeDuration;

  const AutoMergeItem({
    required this.id,
    required this.sourcePath,
    required this.name,
    this.sourceDuration,
    this.startTime = Duration.zero,
    this.endTime = Duration.zero,
    this.position = 1,
    this.fadeIn = Duration.zero,
    this.fadeOut = Duration.zero,
    this.transition = TransitionType.hardCut,
    this.crossfadeDuration = const Duration(milliseconds: 1000),
  });

  AutoMergeItem copyWith({
    String? id,
    String? sourcePath,
    String? name,
    Duration? sourceDuration,
    bool clearSourceDuration = false,
    Duration? startTime,
    Duration? endTime,
    int? position,
    Duration? fadeIn,
    Duration? fadeOut,
    TransitionType? transition,
    Duration? crossfadeDuration,
  }) {
    return AutoMergeItem(
      id: id ?? this.id,
      sourcePath: sourcePath ?? this.sourcePath,
      name: name ?? this.name,
      sourceDuration: clearSourceDuration ? null : (sourceDuration ?? this.sourceDuration),
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      position: position ?? this.position,
      fadeIn: fadeIn ?? this.fadeIn,
      fadeOut: fadeOut ?? this.fadeOut,
      transition: transition ?? this.transition,
      crossfadeDuration: crossfadeDuration ?? this.crossfadeDuration,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourcePath': sourcePath,
        'name': name,
        'sourceDurationMs': sourceDuration?.inMilliseconds,
        'startTimeMs': startTime.inMilliseconds,
        'endTimeMs': endTime.inMilliseconds,
        'position': position,
        'fadeInMs': fadeIn.inMilliseconds,
        'fadeOutMs': fadeOut.inMilliseconds,
        'transition': transition.name,
        'crossfadeDurationMs': crossfadeDuration.inMilliseconds,
      };

  factory AutoMergeItem.fromJson(Map<String, dynamic> json) {
    final sourceDurationMs = json['sourceDurationMs'] as int?;
    return AutoMergeItem(
      id: json['id'] as String,
      sourcePath: json['sourcePath'] as String,
      name: json['name'] as String,
      sourceDuration: sourceDurationMs != null
          ? Duration(milliseconds: sourceDurationMs)
          : null,
      startTime: Duration(milliseconds: (json['startTimeMs'] as int? ?? 0)),
      endTime: Duration(milliseconds: (json['endTimeMs'] as int? ?? 0)),
      position: (json['position'] as int? ?? 1),
      fadeIn: Duration(milliseconds: (json['fadeInMs'] as int? ?? 0)),
      fadeOut: Duration(milliseconds: (json['fadeOutMs'] as int? ?? 0)),
      transition: TransitionType.values.firstWhere(
        (t) => t.name == (json['transition'] as String? ?? 'hardCut'),
        orElse: () => TransitionType.hardCut,
      ),
      crossfadeDuration: Duration(
          milliseconds: (json['crossfadeDurationMs'] as int? ?? 1000)),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory AutoMergeItem.fromJsonString(String source) =>
      AutoMergeItem.fromJson(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AutoMergeItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Outcome of a validation check — either success or a list of human-readable
/// error messages.
class ValidationResult {
  final bool isValid;
  final List<String> errors;

  /// Constructs a passing result.
  const ValidationResult.ok()
      : isValid = true,
        errors = const [];

  /// Constructs a failing result from a non-empty list of [errors].
  const ValidationResult.errors(this.errors) : isValid = false;
}

/// The final output produced by a successful build operation.
class AutoMergeResult {
  /// Absolute path to the rendered output file.
  final String outputPath;

  /// Total playback duration of the merged output.
  final Duration totalDuration;

  const AutoMergeResult({
    required this.outputPath,
    required this.totalDuration,
  });
}
