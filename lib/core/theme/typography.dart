import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'color_scheme.dart';

/// Centralized type scale. `scale` is driven by Settings → Appearance →
/// Font scale, so every screen reacts uniformly instead of hardcoding sizes.
class ResonaTypography {
  final ResonaPalette palette;
  final double scale;

  ResonaTypography(this.palette, {this.scale = 1.0});

  TextTheme get textTheme {
    final base = GoogleFonts.interTextTheme();
    return base.copyWith(
      displaySmall: _s(base.displaySmall, 32, FontWeight.w700),
      headlineLarge: _s(base.headlineLarge, 28, FontWeight.w700),
      headlineMedium: _s(base.headlineMedium, 22, FontWeight.w600),
      headlineSmall: _s(base.headlineSmall, 18, FontWeight.w600),
      titleLarge: _s(base.titleLarge, 16, FontWeight.w600),
      titleMedium: _s(base.titleMedium, 14, FontWeight.w600),
      bodyLarge: _s(base.bodyLarge, 15, FontWeight.w400),
      bodyMedium: _s(base.bodyMedium, 13, FontWeight.w400),
      bodySmall: _s(base.bodySmall, 12, FontWeight.w400, color: palette.textSecondary),
      labelLarge: _s(base.labelLarge, 13, FontWeight.w600),
      labelSmall: _s(base.labelSmall, 11, FontWeight.w500, color: palette.textSecondary),
    ).apply(bodyColor: palette.textPrimary, displayColor: palette.textPrimary);
  }

  TextStyle _s(TextStyle? style, double size, FontWeight weight, {Color? color}) {
    return (style ?? const TextStyle()).copyWith(
      fontSize: size * scale,
      fontWeight: weight,
      color: color,
      letterSpacing: -0.1,
      height: 1.3,
    );
  }
}
