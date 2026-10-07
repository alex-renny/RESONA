import 'package:flutter_test/flutter_test.dart';
import 'package:resona/features/editor/domain/clip_edit_math.dart';
import 'package:resona/models/audio_project.dart';

AudioClip _clip({
  Duration start = Duration.zero,
  Duration end = const Duration(seconds: 10),
  Duration position = Duration.zero,
}) {
  return AudioClip(
    id: 'c1',
    sourcePath: '/tmp/a.mp3',
    name: 'a.mp3',
    startTime: start,
    endTime: end,
    timelinePosition: position,
  );
}

void main() {
  group('ClipEditMath.move', () {
    test('moves to the requested position', () {
      final moved = ClipEditMath.move(_clip(), const Duration(seconds: 5));
      expect(moved.timelinePosition, const Duration(seconds: 5));
    });

    test('clamps negative positions to zero', () {
      final moved = ClipEditMath.move(_clip(), const Duration(seconds: -3));
      expect(moved.timelinePosition, Duration.zero);
    });
  });

  group('ClipEditMath.trimStart', () {
    test('trims the in-point and shifts timeline position to keep the end fixed', () {
      final clip = _clip(
        start: const Duration(seconds: 2),
        end: const Duration(seconds: 10),
        position: const Duration(seconds: 20),
      );
      // absolute end = 20 + (10-2) = 28
      final trimmed = ClipEditMath.trimStart(clip, const Duration(seconds: 3));
      expect(trimmed.startTime, const Duration(seconds: 5));
      expect(trimmed.timelinePosition, const Duration(seconds: 23)); // 28 - (10-5)
    });

    test('never trims past minClipLength before the out-point', () {
      final clip = _clip(start: Duration.zero, end: const Duration(milliseconds: 500));
      final trimmed = ClipEditMath.trimStart(clip, const Duration(seconds: 1));
      expect(trimmed.sourceDuration, greaterThanOrEqualTo(ClipEditMath.minClipLength));
    });

    test('never trims the start below zero', () {
      final clip = _clip();
      final trimmed = ClipEditMath.trimStart(clip, const Duration(seconds: -5));
      expect(trimmed.startTime, Duration.zero);
    });
  });

  group('ClipEditMath.trimEnd', () {
    test('extends the out-point', () {
      final trimmed = ClipEditMath.trimEnd(_clip(), const Duration(seconds: 5));
      expect(trimmed.endTime, const Duration(seconds: 15));
    });

    test('is bounded by the known source file duration', () {
      final trimmed = ClipEditMath.trimEnd(
        _clip(),
        const Duration(seconds: 100),
        maxSourceDuration: const Duration(seconds: 12),
      );
      expect(trimmed.endTime, const Duration(seconds: 12));
    });

    test('never shrinks below minClipLength past the in-point', () {
      final clip = _clip(start: Duration.zero, end: const Duration(seconds: 10));
      final trimmed = ClipEditMath.trimEnd(clip, const Duration(seconds: -20));
      expect(trimmed.sourceDuration, greaterThanOrEqualTo(ClipEditMath.minClipLength));
    });
  });

  group('ClipEditMath.split', () {
    test('splits a clip into two at the requested absolute time', () {
      final clip = _clip(start: Duration.zero, end: const Duration(seconds: 10));
      var nextId = 0;
      final result = ClipEditMath.split(clip, const Duration(seconds: 4), () => 'new-${nextId++}');
      expect(result, isNotNull);
      final (left, right) = result!;
      expect(left.endTime, const Duration(seconds: 4));
      expect(right.startTime, const Duration(seconds: 4));
      expect(right.timelinePosition, const Duration(seconds: 4));
      expect(left.timelinePosition, clip.timelinePosition);
      expect(right.id, isNot(left.id));
      expect(right.sourcePath, clip.sourcePath);
    });

    test('refuses to split too close to either edge', () {
      final clip = _clip(start: Duration.zero, end: const Duration(seconds: 10));
      final result = ClipEditMath.split(clip, const Duration(milliseconds: 10), () => 'x');
      expect(result, isNull);
    });

    test('refuses to split outside the clip entirely', () {
      final clip = _clip(start: Duration.zero, end: const Duration(seconds: 10), position: const Duration(seconds: 5));
      final result = ClipEditMath.split(clip, const Duration(seconds: 100), () => 'x');
      expect(result, isNull);
    });
  });
}
