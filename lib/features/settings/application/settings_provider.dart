import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/app_settings.dart';

const _prefsKey = 'resona_app_settings';

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  final Future<SharedPreferences> _preferences =
      SharedPreferences.getInstance();
  Timer? _persistTimer;
  bool _changedBeforeLoad = false;

  Future<void> _load() async {
    final prefs = await _preferences;
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        final loaded = AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        if (_changedBeforeLoad) {
          _schedulePersist();
        } else {
          state = loaded;
        }
      } catch (_) {
        // Corrupted preferences fall back to defaults rather than crashing.
      }
    }
  }

  Future<void> _persist() async {
    final snapshot = state;
    try {
      final prefs = await _preferences;
      await prefs.setString(_prefsKey, jsonEncode(snapshot.toJson()));
    } catch (_) {
      // Keep the current in-memory setting even if device storage is busy.
    }
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 350), _persist);
  }

  void update(AppSettings Function(AppSettings current) transform) {
    _changedBeforeLoad = true;
    state = transform(state);
    _schedulePersist();
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    if (_changedBeforeLoad) unawaited(_persist());
    super.dispose();
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(),
);
