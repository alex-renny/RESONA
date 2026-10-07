import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/color_scheme.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../models/audio_project.dart';
import '../../application/editor_project_provider.dart';

/// Per-track controls (spec section 19: Mute, Solo, Volume, Pan, Lock,
/// Hide/show, Delete). Mute/solo/volume update the project model now;
/// audibly reflecting them during playback arrives with the multi-track
/// mixing/render engine in a later phase.
class TrackHeader extends ConsumerWidget {
  final AudioTrack track;
  final double height;
  final ResonaPalette palette;

  const TrackHeader({super.key, required this.track, required this.height, required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(editorProjectProvider.notifier);
    final theme = Theme.of(context);

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: ResonaSpacing.sm, vertical: ResonaSpacing.xs),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: palette.border),
          right: BorderSide(color: palette.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _rename(context, ref),
                  child: Text(
                    track.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(track.locked ? Icons.lock : Icons.lock_open, size: 16),
                onPressed: () => notifier.toggleLock(track.id),
                tooltip: track.locked ? 'Unlock track' : 'Lock track',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: ResonaSpacing.xs),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16),
                onPressed: () => notifier.deleteTrack(track.id),
                tooltip: 'Delete track',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          Row(
            children: [
              _MiniToggle(
                label: 'M',
                active: track.muted,
                activeColor: palette.danger,
                onTap: () => notifier.toggleMute(track.id),
              ),
              const SizedBox(width: ResonaSpacing.xs),
              _MiniToggle(
                label: 'S',
                active: track.solo,
                activeColor: theme.colorScheme.primary,
                onTap: () => notifier.toggleSolo(track.id),
              ),
              const SizedBox(width: ResonaSpacing.sm),
              Expanded(
                child: Slider(
                  value: track.volume.clamp(0.0, 2.0),
                  min: 0,
                  max: 2,
                  onChanged: track.locked ? null : (v) => notifier.setTrackVolume(track.id, v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: track.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename track'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      ref.read(editorProjectProvider.notifier).renameTrack(track.id, result);
    }
  }
}

class _MiniToggle extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _MiniToggle({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.2) : Colors.transparent,
          border: Border.all(color: active ? activeColor : Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: active ? activeColor : null,
          ),
        ),
      ),
    );
  }
}
