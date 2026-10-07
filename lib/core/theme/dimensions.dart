import 'package:flutter/material.dart';

enum UiDensity { compact, comfortable, spacious }

extension UiDensityValue on UiDensity {
  /// Multiplier applied to vertical padding across list tiles, cards, toolbars.
  double get factor {
    switch (this) {
      case UiDensity.compact:
        return 0.8;
      case UiDensity.comfortable:
        return 1.0;
      case UiDensity.spacious:
        return 1.25;
    }
  }

  String get label {
    switch (this) {
      case UiDensity.compact:
        return 'Compact';
      case UiDensity.comfortable:
        return 'Comfortable';
      case UiDensity.spacious:
        return 'Spacious';
    }
  }
}

enum AnimationLevel { full, reduced, disabled }

/// Corner radius / icon size / shadow tokens. `cornerRadius` and `iconSize`
/// are user-adjustable in Settings → Appearance → Interface.
class ResonaDimensions {
  final double cornerRadius;
  final double iconSize;
  final UiDensity density;

  const ResonaDimensions({
    this.cornerRadius = 12,
    this.iconSize = 20,
    this.density = UiDensity.comfortable,
  });

  BorderRadius get radiusSm => BorderRadius.circular(cornerRadius * 0.5);
  BorderRadius get radiusMd => BorderRadius.circular(cornerRadius);
  BorderRadius get radiusLg => BorderRadius.circular(cornerRadius * 1.5);

  double get controlHeight => 40 * density.factor;
  double get listTileVerticalPadding => 10 * density.factor;

  List<BoxShadow> shadow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.24),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
}
