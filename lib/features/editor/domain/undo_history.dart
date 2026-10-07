/// Immutable undo/redo history for any state [T].
///
/// Push new states via [push], then walk back and forward with [undo]/[redo].
/// The redo stack is cleared on every [push], mirroring conventional editor
/// behaviour (spec section 20: Undo/Redo). History depth is capped at
/// [maxLength] to bound memory usage.
class UndoHistory<T> {
  final List<T> _past; // states before current (index 0 = oldest)
  final T current;
  final List<T> _future; // states that can be re-done (index 0 = next)
  final int maxLength;

  const UndoHistory({
    required this.current,
    List<T> past = const [],
    List<T> future = const [],
    this.maxLength = 100,
  })  : _past = past,
        _future = future;

  bool get canUndo => _past.isNotEmpty;
  bool get canRedo => _future.isNotEmpty;

  List<T> get past => List.unmodifiable(_past);
  List<T> get future => List.unmodifiable(_future);

  /// Push [newState] as the new current, clearing the redo stack and trimming
  /// past history if it exceeds [maxLength].
  UndoHistory<T> push(T newState) {
    final past = [..._past, current];
    final trimmed =
        past.length > maxLength ? past.sublist(past.length - maxLength) : past;
    return UndoHistory(
      current: newState,
      past: trimmed,
      future: const [],
      maxLength: maxLength,
    );
  }

  /// Step back one state. Returns [this] when already at the beginning.
  UndoHistory<T> undo() {
    if (!canUndo) return this;
    return UndoHistory(
      current: _past.last,
      past: _past.sublist(0, _past.length - 1),
      future: [current, ..._future],
      maxLength: maxLength,
    );
  }

  /// Step forward one state. Returns [this] when already at the end.
  UndoHistory<T> redo() {
    if (!canRedo) return this;
    return UndoHistory(
      current: _future.first,
      past: [..._past, current],
      future: _future.sublist(1),
      maxLength: maxLength,
    );
  }
}
