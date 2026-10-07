import 'package:flutter/widgets.dart';

/// Keeps two [ScrollController]s in lockstep — used to sync the timeline
/// ruler with its track lanes, and the track-header column with the lanes'
/// vertical scroll — without pulling in an extra dependency for it.
class ScrollSync {
  final ScrollController a;
  final ScrollController b;
  bool _syncing = false;

  ScrollSync(this.a, this.b) {
    a.addListener(_onAChanged);
    b.addListener(_onBChanged);
  }

  void _onAChanged() {
    if (_syncing || !a.hasClients || !b.hasClients) return;
    _syncing = true;
    b.jumpTo(a.offset.clamp(0, b.position.maxScrollExtent));
    _syncing = false;
  }

  void _onBChanged() {
    if (_syncing || !a.hasClients || !b.hasClients) return;
    _syncing = true;
    a.jumpTo(b.offset.clamp(0, a.position.maxScrollExtent));
    _syncing = false;
  }

  void dispose() {
    a.removeListener(_onAChanged);
    b.removeListener(_onBChanged);
  }
}
