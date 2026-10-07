/// Clip Inspector panel – shows and edits the selected clip's properties.
///
/// Layout is adaptive:
///   • Narrow screen (< 600 px wide) → modal bottom-sheet (DraggableScrollableSheet)
///   • Wide screen (≥ 600 px)         → fixed side-panel embedded in the editor layout
///
/// All mutations are dispatched immediately to [EditorProjectNotifier].
library;

import 'dart:math' show log, ln10;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/spacing.dart';
import '../../../models/audio_project.dart';
import '../application/editor_project_provider.dart';

// ---------------------------------------------------------------------------
// Public entry point helpers
// ---------------------------------------------------------------------------

/// Opens the inspector as a [DraggableScrollableSheet] inside a modal bottom
/// sheet. Call this on double-tap from [TrackLane] / [AudioClipWidget].
Future<void> showClipInspectorSheet(
  BuildContext context, {
  required String trackId,
  required String clipId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.30,
      maxChildSize: 0.92,
      expand: false,
      builder: (sheetCtx, scrollController) => ClipInspector(
        trackId: trackId,
        clipId: clipId,
        scrollController: scrollController,
        onClose: () => Navigator.of(sheetCtx).pop(),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// dB utility
// ---------------------------------------------------------------------------

/// Converts a linear gain value (0.0–2.0) to dB.
/// Returns [double.negativeInfinity] when [linear] == 0.
double linearToDb(double linear) =>
    linear == 0 ? double.negativeInfinity : 20 * log(linear) / ln10;

String _formatDb(double linear) {
  final db = linearToDb(linear);
  if (db == double.negativeInfinity) return '−∞ dB';
  final sign = db >= 0 ? '+' : '';
  return '$sign${db.toStringAsFixed(1)} dB';
}

// ---------------------------------------------------------------------------
// Duration formatting helpers
// ---------------------------------------------------------------------------

String _formatMmSs(Duration d) {
  final totalSeconds = d.inSeconds;
  final mm = totalSeconds ~/ 60;
  final ss = totalSeconds % 60;
  final ms = (d.inMilliseconds % 1000) ~/ 10; // centiseconds
  return '${mm.toString().padLeft(2, '0')}:'
      '${ss.toString().padLeft(2, '0')}.'
      '${ms.toString().padLeft(2, '0')}';
}

String _formatSeconds(Duration d) {
  final s = d.inMilliseconds / 1000.0;
  return '${s.toStringAsFixed(2)} s';
}

// ---------------------------------------------------------------------------
// ClipInspector widget
// ---------------------------------------------------------------------------

/// The inspector panel itself. Can be used either inline (side panel) or
/// inside a [DraggableScrollableSheet] (bottom sheet on narrow screens).
class ClipInspector extends ConsumerStatefulWidget {
  /// Track that owns the clip.
  final String trackId;

  /// Clip being inspected.
  final String clipId;

  /// Optional scroll controller injected by DraggableScrollableSheet.
  final ScrollController? scrollController;

  /// Called when the user dismisses the inspector (e.g. close button).
  final VoidCallback? onClose;

  const ClipInspector({
    super.key,
    required this.trackId,
    required this.clipId,
    this.scrollController,
    this.onClose,
  });

  @override
  ConsumerState<ClipInspector> createState() => _ClipInspectorState();
}

class _ClipInspectorState extends ConsumerState<ClipInspector> {
  late TextEditingController _nameController;
  bool _nameEditing = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  AudioClip? _findClip(EditorState? state) {
    if (state == null) return null;
    for (final t in state.project.tracks) {
      if (t.id == widget.trackId) {
        for (final c in t.clips) {
          if (c.id == widget.clipId) return c;
        }
      }
    }
    return null;
  }

  EditorProjectNotifier get _notifier =>
      ref.read(editorProjectProvider.notifier);

  void _updateClip(AudioClip Function(AudioClip) updater) {
    final state = ref.read(editorProjectProvider);
    final clip = _findClip(state);
    if (clip == null) return;
    final updated = updater(clip);
    // Use the notifier's internal mutation mechanism via a dedicated clip-edit
    // method. Since there isn't a generic "replace clip" yet, we route through
    // the existing primitives where possible and a direct state mutation for
    // fields that don't have a dedicated method yet.
    _notifier.updateClipProperties(widget.trackId, widget.clipId, updated);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editorProjectProvider);
    final clip = _findClip(state);

    if (clip == null) {
      return _buildShell(
        context,
        child: const Center(child: Text('Clip not found')),
      );
    }

    // Keep name controller in sync when clip name changes externally.
    if (!_nameEditing && _nameController.text != clip.name) {
      _nameController.text = clip.name;
    }

    return _buildShell(
      context,
      child: _buildBody(context, clip),
    );
  }

  Widget _buildShell(BuildContext context, {required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: ResonaSpacing.sm),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ResonaSpacing.lg,
              vertical: ResonaSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, size: 18, color: cs.primary),
                const SizedBox(width: ResonaSpacing.sm),
                Text(
                  'Clip Inspector',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    iconSize: 20,
                    onPressed: widget.onClose,
                    tooltip: 'Close',
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Scrollable body
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, AudioClip clip) {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(ResonaSpacing.lg),
      children: [
        _NameField(
          controller: _nameController,
          onEditingStarted: () => setState(() => _nameEditing = true),
          onSubmitted: (value) {
            setState(() => _nameEditing = false);
            if (value.trim().isNotEmpty) {
              _updateClip((c) => c.copyWith(name: value.trim()));
            }
          },
        ),
        const SizedBox(height: ResonaSpacing.lg),
        _TimingSection(
          clip: clip,
          onStartNudge: (delta) => _updateClip(
            (c) => c.copyWith(
              startTime: _clampDuration(c.startTime + delta, Duration.zero, c.endTime - const Duration(milliseconds: 50)),
            ),
          ),
          onEndNudge: (delta) => _updateClip(
            (c) => c.copyWith(
              endTime: _clampDuration(c.endTime + delta, c.startTime + const Duration(milliseconds: 50), null),
            ),
          ),
        ),
        const SizedBox(height: ResonaSpacing.lg),
        _VolumePanSection(
          clip: clip,
          onVolumeChanged: (v) => _updateClip((c) => c.copyWith(volume: v)),
          onPanChanged: (p) => _updateClip((c) => c.copyWith(pan: p)),
        ),
        const SizedBox(height: ResonaSpacing.lg),
        _FadeSection(
          clip: clip,
          onFadeInChanged: (d) => _updateClip((c) => c.copyWith(fadeIn: d)),
          onFadeOutChanged: (d) => _updateClip((c) => c.copyWith(fadeOut: d)),
        ),
        const SizedBox(height: ResonaSpacing.lg),
        _SpeedSection(
          clip: clip,
          onSpeedChanged: (s) => _updateClip((c) => c.copyWith(speed: s)),
        ),
        const SizedBox(height: ResonaSpacing.lg),
        _PitchSection(
          clip: clip,
          onPitchChanged: (p) => _updateClip((c) => c.copyWith(pitchSemitones: p)),
        ),
        const SizedBox(height: ResonaSpacing.xl),
        _ActionsSection(
          clip: clip,
          trackId: widget.trackId,
          onClose: widget.onClose,
          onResetAll: () => _updateClip(
            (_) => AudioClip(
              id: clip.id,
              sourcePath: clip.sourcePath,
              name: clip.name,
              startTime: clip.startTime,
              endTime: clip.endTime,
              timelinePosition: clip.timelinePosition,
              // all other fields revert to their const defaults
            ),
          ),
        ),
        const SizedBox(height: ResonaSpacing.xxxl),
      ],
    );
  }

  Duration _clampDuration(Duration value, Duration min, Duration? max) {
    if (value < min) return min;
    if (max != null && value > max) return max;
    return value;
  }
}

// ---------------------------------------------------------------------------
// Section: Clip Name
// ---------------------------------------------------------------------------

class _NameField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onEditingStarted;
  final ValueChanged<String> onSubmitted;

  const _NameField({
    required this.controller,
    required this.onEditingStarted,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: const InputDecoration(
        labelText: 'Clip Name',
        prefixIcon: Icon(Icons.label_outline_rounded),
        border: OutlineInputBorder(),
      ),
      onTap: onEditingStarted,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.done,
    );
  }
}

// ---------------------------------------------------------------------------
// Section: Timing
// ---------------------------------------------------------------------------

class _TimingSection extends StatelessWidget {
  final AudioClip clip;
  final ValueChanged<Duration> onStartNudge;
  final ValueChanged<Duration> onEndNudge;

  const _TimingSection({
    required this.clip,
    required this.onStartNudge,
    required this.onEndNudge,
  });

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Timing',
      icon: Icons.schedule_rounded,
      children: [
        _NudgeRow(
          label: 'Start (in-point)',
          value: _formatMmSs(clip.startTime),
          onMinus: () => onStartNudge(const Duration(milliseconds: -100)),
          onPlus: () => onStartNudge(const Duration(milliseconds: 100)),
        ),
        const SizedBox(height: ResonaSpacing.sm),
        _NudgeRow(
          label: 'End (out-point)',
          value: _formatMmSs(clip.endTime),
          onMinus: () => onEndNudge(const Duration(milliseconds: -100)),
          onPlus: () => onEndNudge(const Duration(milliseconds: 100)),
        ),
        const SizedBox(height: ResonaSpacing.sm),
        _ReadOnlyRow(
          label: 'Source duration',
          value: _formatSeconds(clip.sourceDuration),
        ),
        const SizedBox(height: ResonaSpacing.xs),
        _ReadOnlyRow(
          label: 'Timeline position',
          value: _formatMmSs(clip.timelinePosition),
        ),
      ],
    );
  }
}

class _NudgeRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _NudgeRow({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.6),
                      )),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontFeatures: [const TextScaler.linear(1.0).scale as dynamic].isEmpty
                          ? null
                          : null,
                        fontFamily: 'monospace',
                      )),
            ],
          ),
        ),
        _SmallIconButton(icon: Icons.remove, onPressed: onMinus, tooltip: '−100 ms'),
        const SizedBox(width: ResonaSpacing.xs),
        _SmallIconButton(icon: Icons.add, onPressed: onPlus, tooltip: '+100 ms'),
      ],
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
        Text(value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6),
                )),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section: Volume & Pan
// ---------------------------------------------------------------------------

class _VolumePanSection extends StatelessWidget {
  final AudioClip clip;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onPanChanged;

  const _VolumePanSection({
    required this.clip,
    required this.onVolumeChanged,
    required this.onPanChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final volumePct = (clip.volume * 100).roundToDouble();
    return _Section(
      title: 'Volume & Pan',
      icon: Icons.volume_up_rounded,
      children: [
        // Volume
        Row(
          children: [
            const Icon(Icons.volume_down_rounded, size: 16),
            Expanded(
              child: Slider(
                value: clip.volume.clamp(0.0, 2.0),
                min: 0.0,
                max: 2.0,
                divisions: 200,
                onChanged: onVolumeChanged,
              ),
            ),
            const Icon(Icons.volume_up_rounded, size: 16),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${volumePct.toInt()}%',
                style: Theme.of(context).textTheme.bodySmall),
            Text(
              _formatDb(clip.volume),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: ResonaSpacing.md),
        // Pan
        Row(
          children: [
            Text('L',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
            Expanded(
              child: Slider(
                value: clip.pan.clamp(-1.0, 1.0),
                min: -1.0,
                max: 1.0,
                divisions: 200,
                onChanged: onPanChanged,
              ),
            ),
            Text('R',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
          ],
        ),
        Center(
          child: Text(
            clip.pan == 0
                ? 'Center'
                : clip.pan < 0
                    ? 'L ${(-clip.pan * 100).toStringAsFixed(0)}%'
                    : 'R ${(clip.pan * 100).toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section: Fade
// ---------------------------------------------------------------------------

const _kFadePresets = <double>[0.0, 0.5, 1.0, 2.0, 3.0];

class _FadeSection extends StatelessWidget {
  final AudioClip clip;
  final ValueChanged<Duration> onFadeInChanged;
  final ValueChanged<Duration> onFadeOutChanged;

  const _FadeSection({
    required this.clip,
    required this.onFadeInChanged,
    required this.onFadeOutChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Fade',
      icon: Icons.gradient_rounded,
      children: [
        _FadeRow(
          label: 'Fade In',
          value: clip.fadeIn,
          onChanged: onFadeInChanged,
        ),
        const SizedBox(height: ResonaSpacing.md),
        _FadeRow(
          label: 'Fade Out',
          value: clip.fadeOut,
          onChanged: onFadeOutChanged,
        ),
      ],
    );
  }
}

class _FadeRow extends StatelessWidget {
  final String label;
  final Duration value;
  final ValueChanged<Duration> onChanged;

  const _FadeRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final seconds = value.inMilliseconds / 1000.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            Text('${seconds.toStringAsFixed(2)} s',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        Slider(
          value: seconds.clamp(0.0, 10.0),
          min: 0.0,
          max: 10.0,
          divisions: 100,
          onChanged: (v) => onChanged(
            Duration(milliseconds: (v * 1000).round()),
          ),
        ),
        Wrap(
          spacing: ResonaSpacing.xs,
          children: _kFadePresets.map((preset) {
            final selected = (seconds - preset).abs() < 0.01;
            return ChoiceChip(
              label: Text(preset == 0 ? 'Off' : '${preset}s'),
              selected: selected,
              onSelected: (_) => onChanged(
                Duration(milliseconds: (preset * 1000).round()),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section: Speed
// ---------------------------------------------------------------------------

const _kSpeedPresets = <double>[0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

class _SpeedSection extends StatelessWidget {
  final AudioClip clip;
  final ValueChanged<double> onSpeedChanged;

  const _SpeedSection({required this.clip, required this.onSpeedChanged});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Speed',
      icon: Icons.speed_rounded,
      children: [
        Wrap(
          spacing: ResonaSpacing.xs,
          runSpacing: ResonaSpacing.xs,
          children: _kSpeedPresets.map((preset) {
            final selected = (clip.speed - preset).abs() < 0.001;
            return ChoiceChip(
              label: Text('${preset}x'),
              selected: selected,
              onSelected: (_) => onSpeedChanged(preset),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
        const SizedBox(height: ResonaSpacing.xs),
        Center(
          child: Text(
            'Current: ${clip.speed}x',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section: Pitch
// ---------------------------------------------------------------------------

class _PitchSection extends StatelessWidget {
  final AudioClip clip;
  final ValueChanged<double> onPitchChanged;

  const _PitchSection({required this.clip, required this.onPitchChanged});

  @override
  Widget build(BuildContext context) {
    final semitones = clip.pitchSemitones;
    final label = semitones == 0
        ? '0 (original)'
        : '${semitones > 0 ? '+' : ''}${semitones.toStringAsFixed(1)} st';

    return _Section(
      title: 'Pitch',
      icon: Icons.piano_rounded,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('−12 st', style: Theme.of(context).textTheme.labelSmall),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            Text('+12 st', style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        Slider(
          value: semitones.clamp(-12.0, 12.0),
          min: -12.0,
          max: 12.0,
          divisions: 48,
          onChanged: onPitchChanged,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section: Actions
// ---------------------------------------------------------------------------

class _ActionsSection extends ConsumerWidget {
  final AudioClip clip;
  final String trackId;
  final VoidCallback? onClose;
  final VoidCallback onResetAll;

  const _ActionsSection({
    required this.clip,
    required this.trackId,
    required this.onClose,
    required this.onResetAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final notifier = ref.read(editorProjectProvider.notifier);

    return _Section(
      title: 'Actions',
      icon: Icons.build_circle_outlined,
      children: [
        // Duplicate
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Duplicate Clip'),
            onPressed: () {
              notifier.duplicateClip(trackId, clip.id);
              onClose?.call();
            },
          ),
        ),
        const SizedBox(height: ResonaSpacing.sm),
        // Reset all
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reset All'),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Reset Clip?'),
                  content: const Text(
                    'All edits (volume, pan, fades, speed, pitch) will be reset to defaults.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) onResetAll();
            },
          ),
        ),
        const SizedBox(height: ResonaSpacing.sm),
        // Delete
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete Clip'),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Delete Clip?'),
                  content: Text(
                    'This will permanently remove "${clip.name}" from the track.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                notifier.deleteClip(trackId, clip.id);
                onClose?.call();
              }
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable sub-widgets
// ---------------------------------------------------------------------------

/// Generic titled section with an icon header.
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: cs.primary),
            const SizedBox(width: ResonaSpacing.xs),
            Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.primary,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        const SizedBox(height: ResonaSpacing.sm),
        Container(
          padding: const EdgeInsets.all(ResonaSpacing.md),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const _SmallIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(ResonaSpacing.xs),
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }
}
