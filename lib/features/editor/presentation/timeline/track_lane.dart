import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/color_scheme.dart';
import '../../../../models/audio_project.dart';
import '../../application/editor_project_provider.dart';
import 'audio_clip_widget.dart';

/// The horizontal lane for one track's clips. Tapping empty space deselects
/// the current clip.
class TrackLane extends ConsumerWidget {
  final AudioTrack track;
  final double pixelsPerSecond;
  final double width;
  final double height;
  final String? selectedClipId;
  final ResonaPalette palette;

  const TrackLane({
    super.key,
    required this.track,
    required this.pixelsPerSecond,
    required this.width,
    required this.height,
    required this.selectedClipId,
    required this.palette,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(editorProjectProvider.notifier);
    return GestureDetector(
      onTap: () => notifier.selectClip(null, null),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: track.muted ? palette.background : palette.surface,
          border: Border(bottom: BorderSide(color: palette.border)),
        ),
        child: Stack(
          children: [
            for (final clip in track.clips)
              AudioClipWidget(
                track: track,
                clip: clip,
                pixelsPerSecond: pixelsPerSecond,
                selected: clip.id == selectedClipId,
                palette: palette,
              ),
          ],
        ),
      ),
    );
  }
}
