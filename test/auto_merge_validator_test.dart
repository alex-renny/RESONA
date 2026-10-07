import 'package:flutter_test/flutter_test.dart';
import 'package:resona/features/auto_merge/domain/auto_merge_models.dart';
import 'package:resona/features/auto_merge/domain/auto_merge_validator.dart';

void main() {
  group('AutoMergeValidator', () {
    test('validates correct item', () {
      const item = AutoMergeItem(
        id: '1',
        sourcePath: '/path/audio.mp3',
        name: 'audio.mp3',
        sourceDuration: Duration(minutes: 5),
        startTime: Duration(seconds: 30),
        endTime: Duration(minutes: 3),
        position: 1,
        fadeIn: Duration(seconds: 2),
        fadeOut: Duration(seconds: 2),
        transition: TransitionType.crossfade,
        crossfadeDuration: Duration(seconds: 1),
      );

      final result = AutoMergeValidator.validateItem(item);
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('detects start time after end time', () {
      const item = AutoMergeItem(
        id: '1',
        sourcePath: '/path/audio.mp3',
        name: 'audio.mp3',
        sourceDuration: Duration(minutes: 5),
        startTime: Duration(minutes: 4),
        endTime: Duration(minutes: 2),
        position: 1,
      );

      final result = AutoMergeValidator.validateItem(item);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('must be before end time')), isTrue);
    });

    test('detects end time exceeding source duration', () {
      const item = AutoMergeItem(
        id: '1',
        sourcePath: '/path/audio.mp3',
        name: 'audio.mp3',
        sourceDuration: Duration(minutes: 2),
        startTime: Duration.zero,
        endTime: Duration(minutes: 5),
        position: 1,
      );

      final result = AutoMergeValidator.validateItem(item);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('exceeds source duration')), isTrue);
    });

    test('validateAll returns error if queue is empty', () {
      final result = AutoMergeValidator.validateAll([]);
      expect(result.isValid, isFalse);
      expect(result.errors.first, equals('Add at least one audio file before building.'));
    });
  });
}
