import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/dimensions.dart';
import '../../../core/theme/spacing.dart';
import '../application/settings_provider.dart';
import '../domain/app_settings.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers / shared constants
// ─────────────────────────────────────────────────────────────────────────────

const _kVersion = '0.2.0';
const _kBuild = '2';

/// Converts a [Duration] to a human-readable label used in fade dropdowns.
String _durationLabel(Duration d) {
  if (d == Duration.zero) return 'Off';
  final ms = d.inMilliseconds;
  if (ms % 1000 == 0) return '${ms ~/ 1000}s';
  return '${ms / 1000}s';
}

const _fadeDurations = [
  Duration.zero,
  Duration(milliseconds: 500),
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 3),
];

// ─────────────────────────────────────────────────────────────────────────────
// Root widget
// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(ResonaSpacing.xl),
        children: [
          Text('Settings', style: theme.textTheme.headlineMedium),
          const SizedBox(height: ResonaSpacing.xl),

          // ── Appearance ───────────────────────────────────────────────────
          _SectionHeader('Appearance', icon: Icons.palette_outlined),
          _AppearanceThemeCard(settings: settings, notifier: notifier),
          const SizedBox(height: ResonaSpacing.md),
          _AppearanceInterfaceCard(settings: settings, notifier: notifier),
          const SizedBox(height: ResonaSpacing.xl),

          // ── Editor ───────────────────────────────────────────────────────
          _SectionHeader('Editor', icon: Icons.tune_outlined),
          _EditorCard(settings: settings, notifier: notifier),
          const SizedBox(height: ResonaSpacing.xl),

          // ── Audio ────────────────────────────────────────────────────────
          _SectionHeader('Audio', icon: Icons.graphic_eq_outlined),
          _AudioCard(settings: settings, notifier: notifier),
          const SizedBox(height: ResonaSpacing.xl),

          // ── Projects ─────────────────────────────────────────────────────
          _SectionHeader('Projects', icon: Icons.folder_outlined),
          _ProjectsCard(settings: settings, notifier: notifier),
          const SizedBox(height: ResonaSpacing.xl),

          // ── Keyboard Shortcuts ───────────────────────────────────────────
          _SectionHeader('Keyboard Shortcuts', icon: Icons.keyboard_outlined),
          const _KeyboardShortcutsCard(),
          const SizedBox(height: ResonaSpacing.xl),

          // ── Accessibility ────────────────────────────────────────────────
          _SectionHeader('Accessibility', icon: Icons.accessibility_new_outlined),
          _AccessibilityCard(settings: settings, notifier: notifier),
          const SizedBox(height: ResonaSpacing.xl),

          // ── About ────────────────────────────────────────────────────────
          _SectionHeader('About', icon: Icons.info_outline),
          const _AboutCard(),
          const SizedBox(height: ResonaSpacing.xl),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Appearance – theme & accent
// ─────────────────────────────────────────────────────────────────────────────

class _AppearanceThemeCard extends StatelessWidget {
  final AppSettings settings;
  final SettingsNotifier notifier;
  const _AppearanceThemeCard({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(children: [
      _RowLabel('Theme'),
      SegmentedButton<ResonaThemeMode>(
        segments: const [
          ButtonSegment(
            value: ResonaThemeMode.dark,
            label: Text('Dark'),
            icon: Icon(Icons.dark_mode_outlined),
          ),
          ButtonSegment(
            value: ResonaThemeMode.light,
            label: Text('Light'),
            icon: Icon(Icons.light_mode_outlined),
          ),
          ButtonSegment(
            value: ResonaThemeMode.system,
            label: Text('System'),
            icon: Icon(Icons.settings_suggest_outlined),
          ),
        ],
        selected: {settings.themeMode},
        onSelectionChanged: (s) =>
            notifier.update((c) => c.copyWith(themeMode: s.first)),
      ),
      const SizedBox(height: ResonaSpacing.lg),
      _RowLabel('Accent color'),
      Wrap(
        spacing: ResonaSpacing.sm,
        children: [
          for (final accent in ResonaAccent.values)
            _AccentSwatch(
              accent: accent,
              selected: settings.accent == accent,
              onTap: () => notifier.update((c) => c.copyWith(accent: accent)),
            ),
        ],
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Appearance – interface sliders & animation
// ─────────────────────────────────────────────────────────────────────────────

class _AppearanceInterfaceCard extends StatelessWidget {
  final AppSettings settings;
  final SettingsNotifier notifier;
  const _AppearanceInterfaceCard({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(children: [
      _RowLabel('Interface'),
      _LabeledSlider(
        label: 'UI density',
        value: UiDensity.values.indexOf(settings.density).toDouble(),
        min: 0,
        max: (UiDensity.values.length - 1).toDouble(),
        divisions: UiDensity.values.length - 1,
        valueLabel: settings.density.label,
        onChanged: (v) => notifier.update(
            (c) => c.copyWith(density: UiDensity.values[v.round()])),
      ),
      _LabeledSlider(
        label: 'Corner radius',
        value: settings.cornerRadius,
        min: 0,
        max: 24,
        divisions: 12,
        valueLabel: settings.cornerRadius.round().toString(),
        onChanged: (v) => notifier.update((c) => c.copyWith(cornerRadius: v)),
      ),
      _LabeledSlider(
        label: 'Icon size',
        value: settings.iconSize,
        min: 16,
        max: 28,
        divisions: 12,
        valueLabel: settings.iconSize.round().toString(),
        onChanged: (v) => notifier.update((c) => c.copyWith(iconSize: v)),
      ),
      _LabeledSlider(
        label: 'Font scale',
        value: settings.fontScale,
        min: 0.85,
        max: 1.3,
        divisions: 9,
        valueLabel: '${(settings.fontScale * 100).round()}%',
        onChanged: (v) => notifier.update((c) => c.copyWith(fontScale: v)),
      ),
      const SizedBox(height: ResonaSpacing.sm),
      _RowLabel('Animation'),
      SegmentedButton<AnimationLevel>(
        segments: const [
          ButtonSegment(value: AnimationLevel.full, label: Text('Full')),
          ButtonSegment(
              value: AnimationLevel.reduced, label: Text('Reduced')),
          ButtonSegment(value: AnimationLevel.disabled, label: Text('Off')),
        ],
        selected: {settings.animationLevel},
        onSelectionChanged: (s) =>
            notifier.update((c) => c.copyWith(animationLevel: s.first)),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Editor card
// ─────────────────────────────────────────────────────────────────────────────

class _EditorCard extends StatelessWidget {
  final AppSettings settings;
  final SettingsNotifier notifier;
  const _EditorCard({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const transitions = [
      ('hardCut', 'Hard Cut'),
      ('crossfade', 'Crossfade'),
      ('fadeThroughSilence', 'Fade Through Silence'),
    ];

    return _SettingsCard(children: [
      // Fade In dropdown
      _DropdownRow<Duration>(
        label: 'Default fade in',
        value: settings.defaultFadeIn,
        items: _fadeDurations
            .map((d) => DropdownMenuItem(value: d, child: Text(_durationLabel(d))))
            .toList(),
        onChanged: (d) =>
            notifier.update((c) => c.copyWith(defaultFadeIn: d!)),
      ),
      const _RowDivider(),

      // Fade Out dropdown
      _DropdownRow<Duration>(
        label: 'Default fade out',
        value: settings.defaultFadeOut,
        items: _fadeDurations
            .map((d) => DropdownMenuItem(value: d, child: Text(_durationLabel(d))))
            .toList(),
        onChanged: (d) =>
            notifier.update((c) => c.copyWith(defaultFadeOut: d!)),
      ),
      const _RowDivider(),

      // Transition dropdown
      _DropdownRow<String>(
        label: 'Default transition',
        value: settings.defaultTransition,
        items: transitions
            .map((t) =>
                DropdownMenuItem(value: t.$1, child: Text(t.$2)))
            .toList(),
        onChanged: (v) =>
            notifier.update((c) => c.copyWith(defaultTransition: v!)),
      ),
      const _RowDivider(),

      // Snap to grid toggle
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Snap to grid', style: theme.textTheme.bodyMedium),
        subtitle: Text(
          'Clip edges snap to timeline grid lines',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        value: settings.snapToGrid,
        onChanged: (v) =>
            notifier.update((c) => c.copyWith(snapToGrid: v)),
      ),
      const _RowDivider(),

      // Crossfade duration slider
      const SizedBox(height: ResonaSpacing.sm),
      _LabeledSlider(
        label: 'Default crossfade',
        value: settings.crossfadeDuration.inMilliseconds / 1000,
        min: 0.5,
        max: 5.0,
        divisions: 9,
        valueLabel:
            '${(settings.crossfadeDuration.inMilliseconds / 1000).toStringAsFixed(1)}s',
        onChanged: (v) => notifier.update((c) => c.copyWith(
            crossfadeDuration:
                Duration(milliseconds: (v * 1000).round()))),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Audio card
// ─────────────────────────────────────────────────────────────────────────────

class _AudioCard extends StatelessWidget {
  final AppSettings settings;
  final SettingsNotifier notifier;
  const _AudioCard({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const formats = [
      ('mp3', 'MP3'),
      ('wav', 'WAV'),
      ('flac', 'FLAC'),
      ('m4a', 'M4A'),
    ];
    const bitrates = [128, 192, 256, 320];
    const sampleRates = [22050, 44100, 48000];

    return _SettingsCard(children: [
      // Format
      _DropdownRow<String>(
        label: 'Export format',
        value: settings.exportFormat,
        items: formats
            .map((f) => DropdownMenuItem(value: f.$1, child: Text(f.$2)))
            .toList(),
        onChanged: (v) =>
            notifier.update((c) => c.copyWith(exportFormat: v!)),
      ),
      const _RowDivider(),

      // Bitrate
      _DropdownRow<int>(
        label: 'Bitrate',
        value: settings.exportBitrate,
        items: bitrates
            .map((b) =>
                DropdownMenuItem(value: b, child: Text('$b kbps')))
            .toList(),
        onChanged: (v) =>
            notifier.update((c) => c.copyWith(exportBitrate: v!)),
      ),
      const _RowDivider(),

      // Sample rate
      _DropdownRow<int>(
        label: 'Sample rate',
        value: settings.exportSampleRate,
        items: sampleRates
            .map((s) =>
                DropdownMenuItem(value: s, child: Text('${s ~/ 1000} kHz')))
            .toList(),
        onChanged: (v) =>
            notifier.update((c) => c.copyWith(exportSampleRate: v!)),
      ),
      const _RowDivider(),

      // Channels
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Stereo output', style: theme.textTheme.bodyMedium),
        subtitle: Text(
          settings.exportStereo ? 'Stereo (2 channels)' : 'Mono (1 channel)',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        value: settings.exportStereo,
        onChanged: (v) =>
            notifier.update((c) => c.copyWith(exportStereo: v)),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Projects card
// ─────────────────────────────────────────────────────────────────────────────

class _ProjectsCard extends StatelessWidget {
  final AppSettings settings;
  final SettingsNotifier notifier;
  const _ProjectsCard({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context) {
    const autoSaveOptions = [
      (0, 'Off'),
      (1, '1 min'),
      (5, '5 min'),
      (10, '10 min'),
    ];

    return _SettingsCard(children: [
      // Auto-save
      _DropdownRow<int>(
        label: 'Auto-save interval',
        value: settings.autoSaveMinutes,
        items: autoSaveOptions
            .map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2)))
            .toList(),
        onChanged: (v) =>
            notifier.update((c) => c.copyWith(autoSaveMinutes: v!)),
      ),
      const _RowDivider(),

      // Recent projects slider
      const SizedBox(height: ResonaSpacing.sm),
      _LabeledSlider(
        label: 'Recent projects count',
        value: settings.recentProjectsCount.toDouble(),
        min: 3,
        max: 20,
        divisions: 17,
        valueLabel: settings.recentProjectsCount.toString(),
        onChanged: (v) => notifier.update(
            (c) => c.copyWith(recentProjectsCount: v.round())),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Keyboard shortcuts card
// ─────────────────────────────────────────────────────────────────────────────

class _KeyboardShortcutsCard extends StatelessWidget {
  const _KeyboardShortcutsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const shortcuts = [
      ('Space', 'Play / Pause'),
      ('Ctrl + Z', 'Undo'),
      ('Ctrl + Shift + Z', 'Redo'),
      ('Ctrl + S', 'Save'),
      ('Ctrl + O', 'Open project'),
      ('Ctrl + E', 'Export'),
      ('S', 'Split clip at playhead'),
      ('Delete', 'Delete selection'),
    ];

    return _SettingsCard(children: [
      Table(
        columnWidths: const {
          0: IntrinsicColumnWidth(),
          1: FlexColumnWidth(),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          // Header row
          TableRow(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(
                    right: ResonaSpacing.xl, bottom: ResonaSpacing.sm),
                child: Text(
                  'Shortcut',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: ResonaSpacing.sm),
                child: Text(
                  'Action',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          // Data rows
          for (final (shortcut, action) in shortcuts)
            TableRow(children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: ResonaSpacing.sm,
                    horizontal: 0),
                child: Container(
                  margin: const EdgeInsets.only(
                      right: ResonaSpacing.xl, top: ResonaSpacing.xs),
                  padding: const EdgeInsets.symmetric(
                      horizontal: ResonaSpacing.sm,
                      vertical: ResonaSpacing.xs),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: theme.colorScheme.outlineVariant),
                  ),
                  child: Text(
                    shortcut,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: ResonaSpacing.sm),
                child: Text(action, style: theme.textTheme.bodyMedium),
              ),
            ]),
        ],
      ),
      const SizedBox(height: ResonaSpacing.md),
      Container(
        padding: const EdgeInsets.all(ResonaSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer
              .withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: ResonaSpacing.sm),
            Expanded(
              child: Text(
                'Customization coming in a later phase.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Accessibility card
// ─────────────────────────────────────────────────────────────────────────────

class _AccessibilityCard extends StatelessWidget {
  final AppSettings settings;
  final SettingsNotifier notifier;
  const _AccessibilityCard({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _SettingsCard(children: [
      // High contrast – not yet implemented, grayed out
      Opacity(
        opacity: 0.5,
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Row(
            children: [
              Text('High contrast mode', style: theme.textTheme.bodyMedium),
              const SizedBox(width: ResonaSpacing.sm),
              _ComingSoonBadge(),
            ],
          ),
          subtitle: Text(
            'Increase contrast for better readability',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          value: false,
          onChanged: null, // disabled
        ),
      ),
      const _RowDivider(),

      // Reduced motion – maps to animationLevel = disabled
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title:
            Text('Reduce motion', style: theme.textTheme.bodyMedium),
        subtitle: Text(
          'Minimises animations throughout the app',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        value: settings.animationLevel == AnimationLevel.disabled,
        onChanged: (v) => notifier.update((c) => c.copyWith(
            animationLevel:
                v ? AnimationLevel.disabled : AnimationLevel.full)),
      ),
      const _RowDivider(),

      // Large touch targets – not yet implemented
      Opacity(
        opacity: 0.5,
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Row(
            children: [
              Text('Large touch targets',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(width: ResonaSpacing.sm),
              _ComingSoonBadge(),
            ],
          ),
          subtitle: Text(
            'Increases tap areas across all controls',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          value: false,
          onChanged: null, // disabled
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// About card
// ─────────────────────────────────────────────────────────────────────────────

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Hero banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                vertical: ResonaSpacing.xl * 1.5,
                horizontal: ResonaSpacing.xl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.primary.withValues(alpha: 0.85),
                  cs.tertiary.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                // App icon placeholder
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: cs.onPrimary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: cs.onPrimary.withValues(alpha: 0.3),
                        width: 2),
                  ),
                  child: Icon(Icons.graphic_eq,
                      size: 36, color: cs.onPrimary),
                ),
                const SizedBox(height: ResonaSpacing.md),
                Text(
                  'RESONA',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: ResonaSpacing.xs),
                Text(
                  'Shape Your Sound.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: cs.onPrimary.withValues(alpha: 0.85),
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: ResonaSpacing.sm),
                Text(
                  'Version $_kVersion  ·  Build $_kBuild',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onPrimary.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          // Info rows
          Padding(
            padding: const EdgeInsets.all(ResonaSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Professional audio editing for everyone.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: ResonaSpacing.lg),
                _AboutInfoRow(
                  icon: Icons.lock_outline,
                  text:
                      'RESONA processes all audio locally. No files are uploaded to any server.',
                ),
                const SizedBox(height: ResonaSpacing.md),
                _AboutInfoRow(
                  icon: Icons.code_outlined,
                  text:
                      'Built with Flutter, powered by FFmpeg.',
                ),
                const Divider(height: ResonaSpacing.xl),
                Text(
                  '© 2024 RESONA',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _AboutInfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: ResonaSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared primitive widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  final IconData icon;
  const _SectionHeader(this.text, {required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: ResonaSpacing.sm),
      child: Row(
        children: [
          Icon(icon,
              size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: ResonaSpacing.sm),
          Text(
            text,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(ResonaSpacing.lg),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children),
        ),
      );
}

class _RowLabel extends StatelessWidget {
  final String text;
  const _RowLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: ResonaSpacing.sm),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      );
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: ResonaSpacing.xl);
}

class _ComingSoonBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: ResonaSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Coming soon',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onTertiaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  final ResonaAccent accent;
  final bool selected;
  final VoidCallback onTap;
  const _AccentSwatch(
      {required this.accent, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: accent.color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 2)
              : null,
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 16)
            : null,
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            Text(valueLabel, style: theme.textTheme.bodySmall),
          ],
        ),
        Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged),
      ],
    );
  }
}

/// A labeled row that wraps a [DropdownButton], expanding to fill width.
class _DropdownRow<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DropdownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          underline: const SizedBox.shrink(),
          style: theme.textTheme.bodyMedium,
          dropdownColor: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
          isDense: true,
        ),
      ],
    );
  }
}
