import 'package:flutter_test/flutter_test.dart';
import 'package:resona/features/editor/domain/undo_history.dart';

void main() {
  group('UndoHistory', () {
    test('initial state has no undo or redo', () {
      const history = UndoHistory<int>(current: 1);
      expect(history.current, equals(1));
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isFalse);
    });

    test('push adds to past and clears redo', () {
      final h1 = const UndoHistory<int>(current: 1).push(2);
      expect(h1.current, equals(2));
      expect(h1.canUndo, isTrue);
      expect(h1.canRedo, isFalse);

      final h2 = h1.undo();
      expect(h2.current, equals(1));
      expect(h2.canUndo, isFalse);
      expect(h2.canRedo, isTrue);

      final h3 = h2.push(3);
      expect(h3.current, equals(3));
      expect(h3.canUndo, isTrue);
      expect(h3.canRedo, isFalse); // redo stack cleared
    });

    test('undo and redo cycle correctly', () {
      var h = const UndoHistory<int>(current: 1).push(2).push(3);
      expect(h.current, equals(3));

      h = h.undo();
      expect(h.current, equals(2));

      h = h.undo();
      expect(h.current, equals(1));

      h = h.redo();
      expect(h.current, equals(2));

      h = h.redo();
      expect(h.current, equals(3));
    });

    test('respects maxLength limit', () {
      var h = const UndoHistory<int>(current: 0, maxLength: 2);
      for (var i = 1; i <= 5; i++) {
        h = h.push(i);
      }

      expect(h.current, equals(5));
      h = h.undo(); // -> 4
      expect(h.current, equals(4));
      h = h.undo(); // -> 3
      expect(h.current, equals(3));
      expect(h.canUndo, isFalse); // Max past length was 2 (states 3 and 4)
    });
  });
}
