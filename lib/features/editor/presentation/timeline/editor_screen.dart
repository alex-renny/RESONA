import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/color_scheme.dart';
import '../../../../core/utils/scroll_sync.dart';
import '../../../../core/widgets/resona_empty_state.dart';
import '../../../settings/application/settings_provider.dart';
import '../../../../models/audio_project.dart';
import '../../application/editor_project_provider.dart';
import '../../domain/timeline_geometry.dart';
import 'editor_toolbar.dart';
import 'timeline_ruler.dart';
import 'track_header.dart';
import 'track_lane.dart';
import 'transport_bar.dart';

/// The full timeline editor: ruler, playhead, waveform clips, zoom, snapping,
/// drag-to-move, edge trimming, tap-to-split, duplicate, and undo/redo.
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  static const double _headerWidth = 180;
  static const double _rulerHeight = 28;
  // Leaves room for Material's 48 px slider touch target plus the track title.
  static const double _laneHeight = 88;

  final _rulerH = ScrollController();
  final _bodyH = ScrollController();
  final _headerV = ScrollController();
  final _bodyV = ScrollController();
  late final ScrollSync _hSync;
  late final ScrollSync _vSync;
  String? _lastScrolledSelection;
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    _hSync = ScrollSync(_rulerH, _bodyH);
    _vSync = ScrollSync(_headerV, _bodyV);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleAutoSave(ref.read(settingsProvider).autoSaveMinutes);
    });
  }

  void _scheduleAutoSave(int minutes) {
    _autoSaveTimer?.cancel();
    if (minutes <= 0) return;
    _autoSaveTimer = Timer.periodic(Duration(minutes: minutes), (_) async {
      final current = ref.read(editorProjectProvider);
      if (current == null || !current.isDirty || current.isSaving) return;
      try { await ref.read(editorProjectProvider.notifier).save(); } catch (_) {}
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _hSync.dispose();
    _vSync.dispose();
    _rulerH.dispose();
    _bodyH.dispose();
    _headerV.dispose();
    _bodyV.dispose();
    super.dispose();
  }

  Future<void> _importForEmptyState() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: kSupportedAudioExtensions,
    );
    if (result == null) return;
    final paths = result.files.map((f) => f.path).whereType<String>().toList();
    if (paths.isNotEmpty) {
      await ref.read(editorProjectProvider.notifier).importFiles(paths);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(editorProjectProvider);
    final settings = ref.watch(settingsProvider);
    ref.listen(settingsProvider.select((s) => s.autoSaveMinutes), (_, next) => _scheduleAutoSave(next));
    final palette = AppTheme.resolvePalette(settings.themeMode, MediaQuery.platformBrightnessOf(context), highContrast: settings.highContrast);
    final isEmpty = editor == null || editor.project.tracks.every((t) => t.clips.isEmpty);

    return Scaffold(
      body: Column(
        children: [
          const EditorToolbar(),
          Expanded(
            child: isEmpty
                ? ResonaEmptyState(
                    icon: Icons.graphic_eq,
                    title: 'No audio clips yet.',
                    message: 'Import audio to start building your timeline.',
                    actionLabel: 'Import Audio',
                    onAction: _importForEmptyState,
                  )
                : _buildTimeline(context, editor, palette),
          ),
          if (editor != null) TransportBar(editor: editor),
        ],
      ),
    );
  }

  Widget _buildTimeline(BuildContext context, EditorState editor, ResonaPalette palette) {
    final geometry = TimelineGeometry(editor.pixelsPerSecond);
    final selectedId = editor.selectedClipId;
    if (selectedId != null) {
      AudioClip? selectedClip;
      String? selectedTrackId;
      for (final track in editor.project.tracks) {
        for (final clip in track.clips) {
          if (clip.id == selectedId) {
            selectedClip = clip;
            selectedTrackId = track.id;
          }
        }
      }
      final targetClip = selectedClip;
      final scrollKey = targetClip == null
          ? null
          : '$selectedTrackId:$selectedId:${targetClip.timelinePosition.inMicroseconds}';
      if (targetClip != null && scrollKey != _lastScrolledSelection) {
        _lastScrolledSelection = scrollKey;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_bodyH.hasClients) return;
          final target = geometry.timeToPixels(targetClip.timelinePosition)
              .clamp(0.0, _bodyH.position.maxScrollExtent)
              .toDouble();
          _bodyH.animateTo(
            target,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
          );
        });
      }
    }
    // A little trailing runway past the last clip so there's always room to
    // drop new clips or drag existing ones further right.
    final contentDuration = editor.project.duration + const Duration(seconds: 20);
    final contentWidth = geometry.timeToPixels(contentDuration).clamp(400.0, double.infinity);
    final playheadX = geometry.timeToPixels(editor.playhead);
    final tracks = editor.project.tracks;
    final bodyHeight = tracks.length * _laneHeight;
    final accent = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: _headerWidth),
            Expanded(
              child: SingleChildScrollView(
                controller: _rulerH,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: TimelineRuler(
                  width: contentWidth,
                  height: _rulerHeight,
                  pixelsPerSecond: editor.pixelsPerSecond,
                  palette: palette,
                  onSeek: (t) => ref.read(editorProjectProvider.notifier).seek(t),
                ),
              ),
            ),
          ],
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _headerWidth,
                child: SingleChildScrollView(
                  controller: _headerV,
                  child: Column(
                    children: [
                      for (final t in tracks)
                        TrackHeader(track: t, height: _laneHeight, palette: palette),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _bodyH,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(
                    width: contentWidth,
                    child: SingleChildScrollView(
                      controller: _bodyV,
                      child: SizedBox(
                        height: bodyHeight,
                        child: Stack(
                          children: [
                            Column(
                              children: [
                                for (final t in tracks)
                                  TrackLane(
                                    track: t,
                                    pixelsPerSecond: editor.pixelsPerSecond,
                                    width: contentWidth,
                                    height: _laneHeight,
                                    selectedClipId: editor.selectedClipId,
                                    palette: palette,
                                  ),
                              ],
                            ),
                            Positioned(
                              left: playheadX - 24,
                              top: 0,
                              bottom: 0,
                              width: 48,
                              child: Tooltip(
                                message: 'Drag to choose where playback starts',
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTapDown: (details) {
                                    final offset = details.localPosition.dx - 24;
                                    ref.read(editorProjectProvider.notifier).seek(
                                          editor.playhead + geometry.deltaPixelsToTime(offset),
                                        );
                                  },
                                  onHorizontalDragUpdate: (details) {
                                    ref.read(editorProjectProvider.notifier).seek(
                                          editor.playhead + geometry.deltaPixelsToTime(details.delta.dx),
                                        );
                                  },
                                  child: Stack(
                                    alignment: Alignment.topCenter,
                                    children: [
                                      Align(
                                        alignment: Alignment.topCenter,
                                        child: Container(
                                          width: 40,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: accent,
                                            borderRadius: BorderRadius.circular(18),
                                          ),
                                          child: const Icon(
                                            Icons.drag_indicator,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 32,
                                        bottom: 0,
                                        child: Container(width: 2, color: accent),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

