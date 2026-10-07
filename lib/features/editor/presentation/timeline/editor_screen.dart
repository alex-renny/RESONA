import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/color_scheme.dart';
import '../../../../core/utils/scroll_sync.dart';
import '../../../../core/widgets/resona_empty_state.dart';
import '../../../settings/application/settings_provider.dart';
import '../../application/editor_project_provider.dart';
import '../../domain/timeline_geometry.dart';
import 'editor_toolbar.dart';
import 'timeline_ruler.dart';
import 'track_header.dart';
import 'track_lane.dart';
import 'transport_bar.dart';

/// The full timeline editor (spec sections 17–21): time ruler, playhead,
/// track headers, waveform-backed clips, zoom, snapping, drag-to-move,
/// edge-drag-to-trim and a split tool. Basic cut/copy/paste and undo/redo
/// land in the next phase on top of the mutation methods already exposed by
/// [EditorProjectNotifier].
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  static const double _headerWidth = 180;
  static const double _rulerHeight = 28;
  static const double _laneHeight = 76;

  final _rulerH = ScrollController();
  final _bodyH = ScrollController();
  final _headerV = ScrollController();
  final _bodyV = ScrollController();
  late final ScrollSync _hSync;
  late final ScrollSync _vSync;

  @override
  void initState() {
    super.initState();
    _hSync = ScrollSync(_rulerH, _bodyH);
    _vSync = ScrollSync(_headerV, _bodyV);
  }

  @override
  void dispose() {
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
    final palette = AppTheme.resolvePalette(settings.themeMode, MediaQuery.platformBrightnessOf(context));
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
                              left: playheadX - 1,
                              top: 0,
                              bottom: 0,
                              width: 2,
                              child: IgnorePointer(child: Container(color: accent)),
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
