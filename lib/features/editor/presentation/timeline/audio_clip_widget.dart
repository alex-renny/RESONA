import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/color_scheme.dart';
import '../../../../core/utils/waveform_math.dart';
import '../../../../models/audio_project.dart';
import '../../application/editor_project_provider.dart';
import '../../application/waveform_service.dart';
import '../../domain/timeline_geometry.dart';
import '../clip_inspector.dart';
import 'waveform_painter.dart';

/// A single clip on the timeline. Shows its real, decoded waveform (never a
/// placeholder — spec section 18), and supports:
///  - tap to select (or split, when the Split tool is active)
///  - double-tap to open the Clip Inspector
///  - drag to move along the track, with snapping to other clip edges
///  - dragging either edge to trim in/out points
class AudioClipWidget extends ConsumerWidget {
  final AudioTrack track;
  final AudioClip clip;
  final double pixelsPerSecond;
  final bool selected;
  final ResonaPalette palette;

  const AudioClipWidget({
    super.key,
    required this.track,
    required this.clip,
    required this.pixelsPerSecond,
    required this.selected,
    required this.palette,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final geometry = TimelineGeometry(pixelsPerSecond);
    final left = geometry.timeToPixels(clip.timelinePosition);
    final width = geometry.timeToPixels(clip.sourceDuration).clamp(8.0, double.infinity);

    final waveformAsync = ref.watch(waveformProvider(clip.sourcePath));
    final notifier = ref.read(editorProjectProvider.notifier);
    final editor = ref.watch(editorProjectProvider);
    final locked = track.locked || clip.locked;
    final accent = Theme.of(context).colorScheme.primary;

    return Positioned(
      left: left,
      top: 4,
      bottom: 4,
      width: width,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (editor?.tool == EditorTool.split) {
            notifier.splitAt(track.id, clip.id, editor!.playhead);
          } else {
            notifier.selectClip(track.id, clip.id);
          }
        },
        onDoubleTap: () {
          notifier.selectClip(track.id, clip.id);
          showClipInspectorSheet(context, trackId: track.id, clipId: clip.id);
        },
        onPanUpdate: locked
            ? null
            : (d) => notifier.moveClip(
                  track.id,
                  clip.id,
                  clip.timelinePosition + geometry.deltaPixelsToTime(d.delta.dx),
                ),
        child: Container(
          decoration: BoxDecoration(
            color: palette.panel,
            border: Border.all(color: selected ? accent : palette.border, width: selected ? 2 : 1),
            borderRadius: BorderRadius.circular(6),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: waveformAsync.when(
                  data: (wf) {
                    if (wf.isEmpty) return const SizedBox.shrink();
                    final targetBuckets = width.round().clamp(1, 2000);
                    final (rMin, rMax) =
                        WaveformMath.resamplePeaks(wf.peaksMin, wf.peaksMax, targetBuckets);
                    return CustomPaint(
                      painter: WaveformPainter(
                        peaksMin: rMin,
                        peaksMax: rMax,
                        color: palette.waveformInactive,
                      ),
                    );
                  },
                  loading: () => const Center(
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Icon(Icons.error_outline, size: 14, color: palette.danger),
                  ),
                ),
              ),
              Positioned(
                left: 4,
                top: 2,
                right: 4,
                child: Text(
                  clip.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: palette.textPrimary),
                ),
              ),
              if (!locked) ...[
                _EdgeHandle(
                  alignment: Alignment.centerLeft,
                  onDrag: (dx) => notifier.trimClipStart(
                    track.id,
                    clip.id,
                    geometry.deltaPixelsToTime(dx),
                  ),
                ),
                _EdgeHandle(
                  alignment: Alignment.centerRight,
                  onDrag: (dx) => notifier.trimClipEnd(
                    track.id,
                    clip.id,
                    geometry.deltaPixelsToTime(dx),
                    maxSourceDuration: waveformAsync.valueOrNull?.duration,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EdgeHandle extends StatelessWidget {
  final Alignment alignment;
  final ValueChanged<double> onDrag;

  const _EdgeHandle({required this.alignment, required this.onDrag});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => onDrag(d.delta.dx),
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: Container(width: 8, color: Colors.transparent),
        ),
      ),
    );
  }
}
