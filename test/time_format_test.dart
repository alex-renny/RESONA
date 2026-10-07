import 'package:flutter_test/flutter_test.dart';
import 'package:resona/core/utils/time_format.dart';

void main() {
  group('TimeFormat.parse', () {
    test('parses MM:SS', () {
      expect(TimeFormat.parse('03:45'), const Duration(minutes: 3, seconds: 45));
    });

    test('parses HH:MM:SS', () {
      expect(TimeFormat.parse('01:02:03'), const Duration(hours: 1, minutes: 2, seconds: 3));
    });

    test('rejects invalid seconds', () {
      expect(TimeFormat.parse('00:75'), isNull);
    });

    test('rejects malformed input', () {
      expect(TimeFormat.parse('not-a-time'), isNull);
      expect(TimeFormat.parse(''), isNull);
    });
  });

  group('TimeFormat.format', () {
    test('formats under an hour as MM:SS', () {
      expect(TimeFormat.format(const Duration(minutes: 3, seconds: 45)), '03:45');
    });

    test('formats an hour+ as HH:MM:SS', () {
      expect(TimeFormat.format(const Duration(hours: 1, minutes: 2, seconds: 3)), '01:02:03');
    });
  });
}
