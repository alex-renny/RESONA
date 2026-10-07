import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../models/audio_project.dart';
import '../../../player/application/audio_player_service.dart';
import '../../application/editor_project_provider.dart';

/// Plays back whichever clip is currently selected, syncing the timeline
/// playhead to real playback position as it goes. This is an honest single-
/// clip preview, not a mixed multi-track render — that arrives once the
/// FFmpeg-backed render/export engine exists (spec section 49).
class TransportBar extends ConsumerStatefulWidget {
  final EditorState editor;
  const TransportBar({super.key, required this.editor});

  @override
  ConsumerState<TransportBar> createState() => _TransportBarState();
}

class _TransportBarState extends ConsumerState<TransportBar> {
  bool _isPlaying = false;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;

  AudioClip? get _selectedClip {
    final editor = widget.editor;
    if (editor.selectedTrackId == null || editor.selectedClipId == null) return null;
    for (final t in editor.project.tracks) {
      if (t.id != editor.selectedTrackId) continue;
      for (final c in t.clips) {
        if (c.id == editor.selectedClipId) return c;
      }
    }
    return null;
  }

  Future<void> _togglePlay() async {
    final clip = _selectedClip;
    if (clip == null) return;
    final player = ref.read(audioPlayerServiceProvider);
    final notifier = ref.read(editorProjectProvider.notifier);

    if (_isPlaying) {
      await player.pause();
      return;
    }

    await player.loadFile(clip.sourcePath);

    var offsetIntoClip = widget.editor.playhead - clip.timelinePosition;
    if (offsetIntoClip.isNegative) offsetIntoClip = Duration.zero;
    var seekTarget = clip.startTime + offsetIntoClip;
    if (seekTarget > clip.endTime) seekTarget = clip.startTime;
    await player.seek(seekTarget);

    _positionSub?.cancel();
    _positionSub = player.positionStream.listen((pos) {
      final absolute = clip.timelinePosition + (pos - clip.startTime);
      notifier.seek(absolute);
    });
    _stateSub?.cancel();
    _stateSub = player.playerStateStream.listen((s) {
      if (mounted) setState(() => _isPlaying = s.playing);
      if (s.processingState == ProcessingState.completed) {
        player.stop();
      }
    });

    await player.play();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clip = _selectedClip;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ResonaSpacing.lg, vertical: ResonaSpacing.sm),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.dividerColor))),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.stop),
            onPressed: () {
              ref.read(audioPlayerServiceProvider).stop();
              if (mounted) setState(() => _isPlaying = false);
            },
          ),
          IconButton.filled(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: clip == null ? null : _togglePlay,
          ),
          const SizedBox(width: ResonaSpacing.md),
          Text(TimeFormat.format(widget.editor.playhead), style: theme.textTheme.bodySmall),
          const Spacer(),
          Flexible(
            child: Text(
              clip == null
                  ? 'Select a clip to preview it.'
                  : 'Previewing "${clip.name}" — mixed playback arrives with the render engine.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
