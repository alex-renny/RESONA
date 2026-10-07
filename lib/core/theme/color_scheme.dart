import 'package:flutter/material.dart';

/// RESONA accent color presets, selectable in Settings → Appearance.
enum ResonaAccent { purple, blue, cyan, green, orange, red, pink }

extension ResonaAccentColor on ResonaAccent {
  Color get color {
    switch (this) {
      case ResonaAccent.purple:
        return const Color(0xFF8B5CF6);
      case ResonaAccent.blue:
        return const Color(0xFF3B82F6);
      case ResonaAccent.cyan:
        return const Color(0xFF06B6D4);
      case ResonaAccent.green:
        return const Color(0xFF10B981);
      case ResonaAccent.orange:
        return const Color(0xFFF59E0B);
      case ResonaAccent.red:
        return const Color(0xFFEF4444);
      case ResonaAccent.pink:
        return const Color(0xFFEC4899);
    }
  }

  String get label {
    switch (this) {
      case ResonaAccent.purple:
        return 'Purple';
      case ResonaAccent.blue:
        return 'Blue';
      case ResonaAccent.cyan:
        return 'Cyan';
      case ResonaAccent.green:
        return 'Green';
      case ResonaAccent.orange:
        return 'Orange';
      case ResonaAccent.red:
        return 'Red';
      case ResonaAccent.pink:
        return 'Pink';
    }
  }
}

/// Base neutral palettes. Panels are intentionally a step lighter/darker than
/// the background so the waveform + timeline stay the visual focus.
class ResonaPalette {
  final Color background;
  final Color surface;
  final Color panel;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color success;
  final Color warning;
  final Color danger;
  final Color waveformInactive;

  const ResonaPalette({
    required this.background,
    required this.surface,
    required this.panel,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.success,
    required this.warning,
    required this.danger,
    required this.waveformInactive,
  });

  static const dark = ResonaPalette(
    background: Color(0xFF121214),
    surface: Color(0xFF1A1A1D),
    panel: Color(0xFF232327),
    border: Color(0xFF2E2E33),
    textPrimary: Color(0xFFF2F2F3),
    textSecondary: Color(0xFFA0A0A8),
    textDisabled: Color(0xFF5C5C63),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    waveformInactive: Color(0xFF3A3A40),
  );

  static const light = ResonaPalette(
    background: Color(0xFFF7F7F8),
    surface: Color(0xFFFFFFFF),
    panel: Color(0xFFEFEFF1),
    border: Color(0xFFDEDEE2),
    textPrimary: Color(0xFF17171A),
    textSecondary: Color(0xFF5C5C66),
    textDisabled: Color(0xFFA3A3AB),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    danger: Color(0xFFDC2626),
    waveformInactive: Color(0xFFCBCBD1),
  );
}
