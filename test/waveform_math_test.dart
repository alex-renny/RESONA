import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:resona/core/utils/waveform_math.dart';

void main() {
  group('WaveformMath.computePeaks', () {
    test('splits samples into the requested number of buckets', () {
      final samples = Int16List.fromList([0, 100, -100, 200, -200, 300]);
      final (min, max) = WaveformMath.computePeaks(samples, 3);
      expect(min.length, 3);
      expect(max.length, 3);
      expect(max[0], closeTo(100 / 32768, 0.0001));
      expect(min[1], closeTo(-100 / 32768, 0.0001));
      expect(max[2], closeTo(300 / 32768, 0.0001));
    });

    test('returns empty arrays for empty input', () {
      final (min, max) = WaveformMath.computePeaks(Int16List(0), 10);
      expect(min, isEmpty);
      expect(max, isEmpty);
    });

    test('returns empty arrays for a non-positive bucket count', () {
      final (min, max) = WaveformMath.computePeaks(Int16List.fromList([1, 2, 3]), 0);
      expect(min, isEmpty);
      expect(max, isEmpty);
    });

    test('values stay within -1.0..1.0 for full-scale input', () {
      final samples = Int16List.fromList(List.generate(1000, (i) => i.isEven ? 32767 : -32768));
      final (min, max) = WaveformMath.computePeaks(samples, 50);
      for (final v in min) {
        expect(v, greaterThanOrEqualTo(-1.0));
      }
      for (final v in max) {
        expect(v, lessThanOrEqualTo(1.0));
      }
    });
  });

  group('WaveformMath.resamplePeaks', () {
    test('shrinks a peak table to the target bucket count', () {
      final source = Float32List.fromList(List.generate(100, (i) => i / 100));
      final (min, max) = WaveformMath.resamplePeaks(source, source, 10);
      expect(min.length, 10);
      expect(max.length, 10);
    });

    test('returns the source unchanged when the target is not smaller', () {
      final source = Float32List.fromList([0.1, 0.2, 0.3]);
      final (min, max) = WaveformMath.resamplePeaks(source, source, 10);
      expect(min.length, 3);
      expect(identical(max, source), isTrue);
    });

    test('returns empty arrays for empty input', () {
      final (min, max) = WaveformMath.resamplePeaks(Float32List(0), Float32List(0), 10);
      expect(min, isEmpty);
      expect(max, isEmpty);
    });
  });
}
