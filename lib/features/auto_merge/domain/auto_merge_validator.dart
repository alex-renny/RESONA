import 'auto_merge_models.dart';

/// Pure domain utility — no state, no side effects.
///
/// All methods are static so they can be called from UI validation callbacks
/// without needing a provider reference.
class AutoMergeValidator {
  AutoMergeValidator._();

  // ── Single-item validation ──────────────────────────────────────────────

  /// Validates a single [AutoMergeItem] for logical consistency.
  ///
  /// Checks performed:
  /// - `startTime` must be < `endTime` when `endTime` is not the sentinel
  ///   [Duration.zero] (meaning "play to source end").
  /// - Both `startTime` and `endTime` must be within [sourceDuration] when
  ///   the source duration is known.
  /// - `crossfadeDuration` must be shorter than the clip's usable duration
  ///   when the transition type is [TransitionType.crossfade].
  /// - Fade-in and fade-out durations must not exceed half the clip's usable
  ///   duration (to prevent overlapping fades).
  static ValidationResult validateItem(AutoMergeItem item) {
    final errors = <String>[];

    final source = item.sourceDuration;
    final effectiveEnd = _effectiveEnd(item);

    // start < end
    if (effectiveEnd != null && item.startTime >= effectiveEnd) {
      errors.add(
        '"${item.name}": Start time (${formatTime(item.startTime)}) must be '
        'before end time (${formatTime(effectiveEnd)}).',
      );
    }

    // bounds against source duration
    if (source != null) {
      if (item.startTime > source) {
        errors.add(
          '"${item.name}": Start time (${formatTime(item.startTime)}) exceeds '
          'source duration (${formatTime(source)}).',
        );
      }
      if (item.endTime != Duration.zero && item.endTime > source) {
        errors.add(
          '"${item.name}": End time (${formatTime(item.endTime)}) exceeds '
          'source duration (${formatTime(source)}).',
        );
      }
    }

    // crossfade duration vs clip duration
    if (item.transition == TransitionType.crossfade && effectiveEnd != null) {
      final clipDuration = effectiveEnd - item.startTime;
      if (item.crossfadeDuration >= clipDuration) {
        errors.add(
          '"${item.name}": Crossfade duration (${formatTime(item.crossfadeDuration)}) '
          'must be shorter than the clip duration (${formatTime(clipDuration)}).',
        );
      }
    }

    // fade-in + fade-out must not exceed clip duration
    if (effectiveEnd != null) {
      final clipDuration = effectiveEnd - item.startTime;
      final maxFade = clipDuration ~/ 2;
      if (item.fadeIn > maxFade) {
        errors.add(
          '"${item.name}": Fade-in (${formatTime(item.fadeIn)}) exceeds '
          'half the clip duration.',
        );
      }
      if (item.fadeOut > maxFade) {
        errors.add(
          '"${item.name}": Fade-out (${formatTime(item.fadeOut)}) exceeds '
          'half the clip duration.',
        );
      }
    }

    return errors.isEmpty
        ? const ValidationResult.ok()
        : ValidationResult.errors(errors);
  }

  // ── Full-queue validation ───────────────────────────────────────────────

  /// Validates the entire merge queue.
  ///
  /// Additional checks beyond per-item validation:
  /// - At least one item must be present.
  /// - Position values must be unique and sequential (1-based).
  static ValidationResult validateAll(List<AutoMergeItem> items) {
    final errors = <String>[];

    if (items.isEmpty) {
      errors.add('Add at least one audio file before building.');
      return ValidationResult.errors(errors);
    }

    // Per-item checks
    for (final item in items) {
      final result = validateItem(item);
      if (!result.isValid) errors.addAll(result.errors);
    }

    // Position uniqueness
    final positions = items.map((i) => i.position).toList()..sort();
    final expected = List.generate(items.length, (i) => i + 1);
    if (positions.join() != expected.join()) {
      errors.add(
        'Clip positions are not sequential. Re-order the queue and try again.',
      );
    }

    return errors.isEmpty
        ? const ValidationResult.ok()
        : ValidationResult.errors(errors);
  }

  // ── Time formatting ─────────────────────────────────────────────────────

  /// Formats a [Duration] as `MM:SS` or `HH:MM:SS` depending on length.
  ///
  /// Examples:
  /// - `Duration(seconds: 75)` → `"01:15"`
  /// - `Duration(hours: 1, minutes: 2, seconds: 3)` → `"01:02:03"`
  static String formatTime(Duration d) {
    final total = d.inSeconds.abs();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) {
      final hh = h.toString().padLeft(2, '0');
      return '$hh:$mm:$ss';
    }
    return '$mm:$ss';
  }

  /// Parses a time string in `MM:SS` or `HH:MM:SS` format.
  ///
  /// Returns `null` if the string does not match either format or contains
  /// out-of-range values (minutes/seconds >= 60).
  static Duration? parseTime(String s) {
    s = s.trim();
    // HH:MM:SS
    final hhmmss = RegExp(r'^(\d{1,2}):(\d{2}):(\d{2})$');
    final m3 = hhmmss.firstMatch(s);
    if (m3 != null) {
      final h = int.parse(m3.group(1)!);
      final m = int.parse(m3.group(2)!);
      final sec = int.parse(m3.group(3)!);
      if (m >= 60 || sec >= 60) return null;
      return Duration(hours: h, minutes: m, seconds: sec);
    }

    // MM:SS
    final mmss = RegExp(r'^(\d{1,2}):(\d{2})$');
    final m2 = mmss.firstMatch(s);
    if (m2 != null) {
      final m = int.parse(m2.group(1)!);
      final sec = int.parse(m2.group(2)!);
      if (sec >= 60) return null;
      return Duration(minutes: m, seconds: sec);
    }

    return null;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Returns the effective out-point for [item].
  ///
  /// - If [item.endTime] is the sentinel [Duration.zero], returns
  ///   [item.sourceDuration] (which may itself be null if not yet probed).
  /// - Otherwise returns [item.endTime] directly.
  static Duration? _effectiveEnd(AutoMergeItem item) {
    if (item.endTime == Duration.zero) return item.sourceDuration;
    return item.endTime;
  }

  /// Convenience wrapper that returns the effective end-point for a known item,
  /// exposed for use in UI widgets.
  static Duration? effectiveEnd(AutoMergeItem item) => _effectiveEnd(item);

  /// Returns the usable clip duration, or null if not fully determinable.
  static Duration? clipDuration(AutoMergeItem item) {
    final end = _effectiveEnd(item);
    if (end == null) return null;
    if (end <= item.startTime) return Duration.zero;
    return end - item.startTime;
  }
}
