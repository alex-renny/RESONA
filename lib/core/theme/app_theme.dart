import 'package:flutter/material.dart';
import 'color_scheme.dart';
import 'dimensions.dart';
import 'typography.dart';

enum ResonaThemeMode { dark, light, system }

class AppTheme {
  /// Resolves the effective [Brightness] for a theme mode — Dark/Light are
  /// fixed, System follows the OS.
  static Brightness resolveBrightness(ResonaThemeMode mode, Brightness platformBrightness) {
    return switch (mode) {
      ResonaThemeMode.dark => Brightness.dark,
      ResonaThemeMode.light => Brightness.light,
      ResonaThemeMode.system => platformBrightness,
    };
  }

  /// Resolves the [ResonaPalette] for a theme mode. Widgets that need
  /// design-system colors beyond what [ColorScheme] exposes (panel,
  /// waveform, etc.) call this instead of duplicating the dark/light choice.
  static ResonaPalette resolvePalette(ResonaThemeMode mode, Brightness platformBrightness) {
    final brightness = resolveBrightness(mode, platformBrightness);
    return brightness == Brightness.dark ? ResonaPalette.dark : ResonaPalette.light;
  }

  /// Builds a full [ThemeData] from the design-system tokens. Called from
  /// MaterialApp with the palette resolved for either brightness so the whole
  /// app reacts immediately to Settings → Appearance changes.
  static ThemeData build({
    required ResonaPalette palette,
    required ResonaAccent accent,
    required ResonaDimensions dimensions,
    required double fontScale,
    required Brightness brightness,
  }) {
    final typography = ResonaTypography(palette, scale: fontScale);
    final accentColor = accent.color;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accentColor,
      onPrimary: Colors.white,
      secondary: accentColor,
      onSecondary: Colors.white,
      error: palette.danger,
      onError: Colors.white,
      surface: palette.surface,
      onSurface: palette.textPrimary,
    );

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: palette.background,
      colorScheme: colorScheme,
      textTheme: typography.textTheme,
      dividerColor: palette.border,
      splashFactory: InkRipple.splashFactory,
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: dimensions.radiusMd,
          side: BorderSide(color: palette.border),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: typography.textTheme.headlineSmall,
      ),
      iconTheme: IconThemeData(color: palette.textPrimary, size: dimensions.iconSize),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          minimumSize: Size(0, dimensions.controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: dimensions.radiusMd),
          elevation: 0,
          textStyle: typography.textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.border),
          minimumSize: Size(0, dimensions.controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: dimensions.radiusMd),
          textStyle: typography.textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentColor,
          minimumSize: Size(0, dimensions.controlHeight),
          shape: RoundedRectangleBorder(borderRadius: dimensions.radiusMd),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.panel,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: dimensions.radiusMd,
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: dimensions.radiusMd,
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: dimensions.radiusMd,
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
        hintStyle: typography.textTheme.bodyMedium?.copyWith(color: palette.textSecondary),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accentColor,
        inactiveTrackColor: palette.panel,
        thumbColor: accentColor,
        overlayColor: accentColor.withValues(alpha: 0.15),
        trackHeight: 3,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: palette.surface,
        selectedIconTheme: IconThemeData(color: accentColor),
        selectedLabelTextStyle: typography.textTheme.labelSmall?.copyWith(color: accentColor),
        unselectedIconTheme: IconThemeData(color: palette.textSecondary),
        unselectedLabelTextStyle: typography.textTheme.labelSmall,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: accentColor.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(typography.textTheme.labelSmall),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: dimensions.radiusLg),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(dimensions.cornerRadius * 1.3)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.panel,
        contentTextStyle: typography.textTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: dimensions.radiusMd),
      ),
    );
  }
}

/// Custom scroll behavior that replaces Android's aggressive stretch overscroll
/// with a subtle glowing edge indicator and clean clamping physics so the UI
/// does not over-stretch when reaching the scroll boundaries.
class ResonaScrollBehavior extends MaterialScrollBehavior {
  const ResonaScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return GlowingOverscrollIndicator(
      axisDirection: details.direction,
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
      child: child,
    );
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}

