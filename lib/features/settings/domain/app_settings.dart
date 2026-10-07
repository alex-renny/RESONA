import '../../../core/theme/app_theme.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/dimensions.dart';

/// Immutable settings snapshot covering Appearance, Editor, Audio, and Projects.
class AppSettings {
  // ── Appearance ────────────────────────────────────────────────────────────
  final ResonaThemeMode themeMode;
  final ResonaAccent accent;
  final UiDensity density;
  final double cornerRadius;
  final double iconSize;
  final double fontScale;
  final AnimationLevel animationLevel;

  // ── Editor ────────────────────────────────────────────────────────────────
  /// Duration of the default fade-in applied to new clips.
  final Duration defaultFadeIn;

  /// Duration of the default fade-out applied to new clips.
  final Duration defaultFadeOut;

  /// Transition type between clips: 'hardCut' | 'crossfade' | 'fadeThroughSilence'.
  final String defaultTransition;

  /// Whether the timeline snaps clip edges to the grid.
  final bool snapToGrid;

  /// Duration used for auto-crossfade between adjacent clips.
  final Duration crossfadeDuration;

  // ── Audio export ──────────────────────────────────────────────────────────
  /// Container/codec for the default export: 'mp3' | 'wav' | 'flac' | 'm4a'.
  final String exportFormat;

  /// Export bit-rate in kbps (128, 192, 256, 320).
  final int exportBitrate;

  /// Export sample-rate in Hz (22050, 44100, 48000).
  final int exportSampleRate;

  /// true = stereo, false = mono.
  final bool exportStereo;

  // ── Projects ──────────────────────────────────────────────────────────────
  /// Auto-save interval in minutes. 0 = off.
  final int autoSaveMinutes;

  /// Maximum number of recent projects shown in the home screen.
  final int recentProjectsCount;

  const AppSettings({
    // Appearance
    this.themeMode = ResonaThemeMode.dark,
    this.accent = ResonaAccent.purple,
    this.density = UiDensity.comfortable,
    this.cornerRadius = 12,
    this.iconSize = 20,
    this.fontScale = 1.0,
    this.animationLevel = AnimationLevel.full,
    // Editor
    this.defaultFadeIn = Duration.zero,
    this.defaultFadeOut = Duration.zero,
    this.defaultTransition = 'hardCut',
    this.snapToGrid = true,
    this.crossfadeDuration = const Duration(seconds: 1),
    // Audio
    this.exportFormat = 'mp3',
    this.exportBitrate = 320,
    this.exportSampleRate = 44100,
    this.exportStereo = true,
    // Projects
    this.autoSaveMinutes = 5,
    this.recentProjectsCount = 10,
  });

  ResonaDimensions get dimensions => ResonaDimensions(
        cornerRadius: cornerRadius,
        iconSize: iconSize,
        density: density,
      );

  AppSettings copyWith({
    // Appearance
    ResonaThemeMode? themeMode,
    ResonaAccent? accent,
    UiDensity? density,
    double? cornerRadius,
    double? iconSize,
    double? fontScale,
    AnimationLevel? animationLevel,
    // Editor
    Duration? defaultFadeIn,
    Duration? defaultFadeOut,
    String? defaultTransition,
    bool? snapToGrid,
    Duration? crossfadeDuration,
    // Audio
    String? exportFormat,
    int? exportBitrate,
    int? exportSampleRate,
    bool? exportStereo,
    // Projects
    int? autoSaveMinutes,
    int? recentProjectsCount,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      accent: accent ?? this.accent,
      density: density ?? this.density,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      iconSize: iconSize ?? this.iconSize,
      fontScale: fontScale ?? this.fontScale,
      animationLevel: animationLevel ?? this.animationLevel,
      defaultFadeIn: defaultFadeIn ?? this.defaultFadeIn,
      defaultFadeOut: defaultFadeOut ?? this.defaultFadeOut,
      defaultTransition: defaultTransition ?? this.defaultTransition,
      snapToGrid: snapToGrid ?? this.snapToGrid,
      crossfadeDuration: crossfadeDuration ?? this.crossfadeDuration,
      exportFormat: exportFormat ?? this.exportFormat,
      exportBitrate: exportBitrate ?? this.exportBitrate,
      exportSampleRate: exportSampleRate ?? this.exportSampleRate,
      exportStereo: exportStereo ?? this.exportStereo,
      autoSaveMinutes: autoSaveMinutes ?? this.autoSaveMinutes,
      recentProjectsCount: recentProjectsCount ?? this.recentProjectsCount,
    );
  }

  Map<String, dynamic> toJson() => {
        // Appearance
        'themeMode': themeMode.index,
        'accent': accent.index,
        'density': density.index,
        'cornerRadius': cornerRadius,
        'iconSize': iconSize,
        'fontScale': fontScale,
        'animationLevel': animationLevel.index,
        // Editor – store durations as milliseconds for easy JSON round-trip
        'defaultFadeInMs': defaultFadeIn.inMilliseconds,
        'defaultFadeOutMs': defaultFadeOut.inMilliseconds,
        'defaultTransition': defaultTransition,
        'snapToGrid': snapToGrid,
        'crossfadeDurationMs': crossfadeDuration.inMilliseconds,
        // Audio
        'exportFormat': exportFormat,
        'exportBitrate': exportBitrate,
        'exportSampleRate': exportSampleRate,
        'exportStereo': exportStereo,
        // Projects
        'autoSaveMinutes': autoSaveMinutes,
        'recentProjectsCount': recentProjectsCount,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        // Appearance
        themeMode: ResonaThemeMode.values[json['themeMode'] ?? 0],
        accent: ResonaAccent.values[json['accent'] ?? 0],
        density: UiDensity.values[json['density'] ?? 1],
        cornerRadius: (json['cornerRadius'] ?? 12).toDouble(),
        iconSize: (json['iconSize'] ?? 20).toDouble(),
        fontScale: (json['fontScale'] ?? 1.0).toDouble(),
        animationLevel: AnimationLevel.values[json['animationLevel'] ?? 0],
        // Editor
        defaultFadeIn: Duration(milliseconds: json['defaultFadeInMs'] ?? 0),
        defaultFadeOut: Duration(milliseconds: json['defaultFadeOutMs'] ?? 0),
        defaultTransition: json['defaultTransition'] ?? 'hardCut',
        snapToGrid: json['snapToGrid'] ?? true,
        crossfadeDuration: Duration(milliseconds: json['crossfadeDurationMs'] ?? 1000),
        // Audio
        exportFormat: json['exportFormat'] ?? 'mp3',
        exportBitrate: json['exportBitrate'] ?? 320,
        exportSampleRate: json['exportSampleRate'] ?? 44100,
        exportStereo: json['exportStereo'] ?? true,
        // Projects
        autoSaveMinutes: json['autoSaveMinutes'] ?? 5,
        recentProjectsCount: json['recentProjectsCount'] ?? 10,
      );
}
