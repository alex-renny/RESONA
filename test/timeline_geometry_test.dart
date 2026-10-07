import 'package:flutter_test/flutter_test.dart';
import 'package:resona/features/editor/domain/timeline_geometry.dart';

void main() {
  group('TimelineGeometry', () {
    test('converts time to pixels and back', () {
      const geometry = TimelineGeometry(60); // 60 px/sec
      final pixels = geometry.timeToPixels(const Duration(seconds: 5));
      expect(pixels, 300);
      final time = geometry.pixelsToTime(300);
      expect(time, const Duration(seconds: 5));
    });

    test('deltaPixelsToTime converts a drag delta directly', () {
      const geometry = TimelineGeometry(60);
      expect(geometry.deltaPixelsToTime(60), const Duration(seconds: 1));
      expect(geometry.deltaPixelsToTime(-30), const Duration(milliseconds: -500));
    });

    test('clampZoom keeps values within the defined steps', () {
      expect(TimelineGeometry.clampZoom(1), TimelineGeometry.zoomSteps.first);
      expect(TimelineGeometry.clampZoom(10000), TimelineGeometry.zoomSteps.last);
      expect(TimelineGeometry.clampZoom(50), 50);
    });
  });

  group('snapDuration', () {
    test('snaps to the nearest point within the threshold', () {
      final result = snapDuration(
        const Duration(milliseconds: 4950),
        [const Duration(seconds: 5)],
        const Duration(milliseconds: 150),
      );
      expect(result, const Duration(seconds: 5));
    });

    test('leaves the value alone when nothing is close enough', () {
      final result = snapDuration(
        const Duration(seconds: 2),
        [const Duration(seconds: 5)],
        const Duration(milliseconds: 150),
      );
      expect(result, const Duration(seconds: 2));
    });

    test('picks the nearest of several snap points', () {
      final result = snapDuration(
        const Duration(seconds: 9, milliseconds: 900),
        [const Duration(seconds: 5), const Duration(seconds: 10)],
        const Duration(milliseconds: 200),
      );
      expect(result, const Duration(seconds: 10));
    });
  });
}
