import 'package:flutter_test/flutter_test.dart';
import 'package:resona/features/auto_merge/domain/auto_merge_models.dart';
import 'package:resona/features/auto_merge/domain/auto_merge_validator.dart';

void main() {
  group('AutoMergeValidator', () {
    test('validates correct item', () {
      final item = AutoMergeItem(
        id: '1',
        sourcePath: '/path/audio.mp3',
        name: 'audio.mp3',
        sourceDuration: const Duration(minutes: 5),
        startTime: const Duration(seconds: 30),
        endTime: const Duration(minutes: 3),
        position: 1,
        fadeIn: const Duration(seconds: 2),
        fadeOut: const Duration(seconds: 2),
        transition: TransitionType.crossfade,
        crossfadeDuration: const Duration(seconds: 1),
      );

      final result = AutoMergeValidator.validateItem(item);
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('detects start time after end time', () {
      final item = AutoMergeItem(
        id: '1',
        sourcePath: '/path/audio.mp3',
        name: 'audio.mp3',
        sourceDuration: const Duration(minutes: 5),
        startTime: const Duration(minutes: 4),
        endTime: const Duration(minutes: 2),
        position: 1,
      );

      final result = AutoMergeValidator.validateItem(item);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('must be before end time')), isTrue);
    });

    test('detects end time exceeding source duration', () {
      final item = AutoMergeItem(
        id: '1',
        sourcePath: '/path/audio.mp3',
        name: 'audio.mp3',
        sourceDuration: const Duration(minutes: 2),
        startTime: Duration.zero,
        endTime: const Duration(minutes: 5),
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
