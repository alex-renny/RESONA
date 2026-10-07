import '../../../models/audio_project.dart';

/// Pure editing math for clips — trimming, splitting and moving all funnel
/// through here so the same rules are enforced everywhere and are directly
/// unit-testable without spinning up any widgets. Every operation returns a
/// new [AudioClip] (or pair of them); none of this ever touches the source
/// file on disk (spec section 20: edits operate on the project
/// representation, never the original audio).
class ClipEditMath {
  static const Duration minClipLength = Duration(milliseconds: 100);

  /// Moves a clip to [newTimelinePosition], clamped to zero.
  static AudioClip move(AudioClip clip, Duration newTimelinePosition) {
    final clamped = newTimelinePosition.isNegative ? Duration.zero : newTimelinePosition;
    return clip.copyWith(timelinePosition: clamped);
  }

  /// Drags the clip's left edge by [delta] (positive = trim more off the
  /// start). The clip's absolute end on the timeline stays fixed, so the
  /// clip appears to "grow" from the right as you trim its start.
  static AudioClip trimStart(AudioClip clip, Duration delta) {
    final absoluteEnd = clip.timelinePosition + clip.sourceDuration;

    var newStart = clip.startTime + delta;
    if (newStart.isNegative) newStart = Duration.zero;
    final maxStart = clip.endTime - minClipLength;
    if (newStart > maxStart) newStart = maxStart.isNegative ? Duration.zero : maxStart;

    final newSourceDuration = clip.endTime - newStart;
    var newTimelinePosition = absoluteEnd - newSourceDuration;
    if (newTimelinePosition.isNegative) newTimelinePosition = Duration.zero;

    return clip.copyWith(startTime: newStart, timelinePosition: newTimelinePosition);
  }

  /// Drags the clip's right edge by [delta]. The clip's timeline start stays
  /// fixed. [maxSourceDuration], when known (from the decoded waveform),
  /// bounds the out-point to the real file length so the user can never drag
  /// past audio that doesn't exist.
  static AudioClip trimEnd(AudioClip clip, Duration delta, {Duration? maxSourceDuration}) {
    var newEnd = clip.endTime + delta;
    final minEnd = clip.startTime + minClipLength;
    if (newEnd < minEnd) newEnd = minEnd;
    if (maxSourceDuration != null && newEnd > maxSourceDuration) newEnd = maxSourceDuration;
    return clip.copyWith(endTime: newEnd);
  }

  /// Splits [clip] at [absoluteTime] (a position on the timeline, not
  /// within the source file) into two clips. Returns null if the split
  /// point doesn't fall strictly inside the clip by at least
  /// [minClipLength] on either side. [newId] generates the new right-hand
  /// clip's id.
  static (AudioClip left, AudioClip right)? split(
    AudioClip clip,
    Duration absoluteTime,
    String Function() newId,
  ) {
    final clipStart = clip.timelinePosition;
    final clipEnd = clip.timelinePosition + clip.sourceDuration;
    if (absoluteTime <= clipStart + minClipLength || absoluteTime >= clipEnd - minClipLength) {
      return null;
    }

    final offsetIntoClip = absoluteTime - clipStart;
    final splitSourceTime = clip.startTime + offsetIntoClip;

    final left = clip.copyWith(endTime: splitSourceTime, fadeOut: Duration.zero);
    final right = AudioClip(
      id: newId(),
      sourcePath: clip.sourcePath,
      name: clip.name,
      startTime: splitSourceTime,
      endTime: clip.endTime,
      timelinePosition: absoluteTime,
      volume: clip.volume,
      pan: clip.pan,
      fadeIn: Duration.zero,
      fadeOut: clip.fadeOut,
      effects: clip.effects,
      speed: clip.speed,
      pitchSemitones: clip.pitchSemitones,
      muted: clip.muted,
      locked: clip.locked,
    );
    return (left, right);
  }
}
