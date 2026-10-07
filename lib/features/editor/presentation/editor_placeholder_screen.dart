import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/resona_empty_state.dart';
import '../../player/application/audio_player_service.dart';

/// Phase 1 stand-in for the full waveform/timeline editor (spec sections
/// 17–21). Provides real, working import + playback so the app is never a
/// static mock — the timeline, waveform and multi-track editing land in the
/// next phase.
class EditorPlaceholderScreen extends ConsumerStatefulWidget {
  const EditorPlaceholderScreen({super.key});

  @override
  ConsumerState<EditorPlaceholderScreen> createState() => _EditorPlaceholderScreenState();
}

class _EditorPlaceholderScreenState extends ConsumerState<EditorPlaceholderScreen> {
  String? _fileName;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _isPlaying = false;
  bool _loading = false;
  String? _error;

  Future<void> _importFile() async {
    setState(() => _error = null);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'flac', 'm4a', 'aac', 'ogg', 'opus'],
    );
    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    setState(() => _loading = true);
    try {
      final player = ref.read(audioPlayerServiceProvider);
      final duration = await player.loadFile(path);
      player.positionStream.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      player.playerStateStream.listen((s) {
        if (mounted) setState(() => _isPlaying = s.playing);
      });
      setState(() {
        _fileName = result.files.single.name;
        _duration = duration;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = "RESONA couldn't process this audio file.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = ref.read(audioPlayerServiceProvider);

    if (_fileName == null) {
      return Scaffold(
        body: ResonaEmptyState(
          icon: Icons.graphic_eq,
          title: 'No audio clips yet.',
          message: 'Import an audio file to start editing.',
          actionLabel: 'Import Audio',
          onAction: _importFile,
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ResonaSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Editor', style: theme.textTheme.headlineMedium),
              const SizedBox(height: ResonaSpacing.sm),
              Text(_fileName!, style: theme.textTheme.bodyMedium),
              if (_error != null) ...[
                const SizedBox(height: ResonaSpacing.sm),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: ResonaSpacing.xl),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else ...[
                Slider(
                  min: 0,
                  max: (_duration?.inMilliseconds ?? 1).toDouble().clamp(1, double.infinity),
                  value: _position.inMilliseconds
                      .toDouble()
                      .clamp(0, (_duration?.inMilliseconds ?? 1).toDouble()),
                  onChanged: (v) => player.seek(Duration(milliseconds: v.round())),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(TimeFormat.format(_position), style: theme.textTheme.bodySmall),
                    Text(TimeFormat.format(_duration ?? Duration.zero), style: theme.textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: ResonaSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(icon: const Icon(Icons.stop), onPressed: player.stop),
                    const SizedBox(width: ResonaSpacing.md),
                    IconButton.filled(
                      iconSize: 32,
                      icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: () => _isPlaying ? player.pause() : player.play(),
                    ),
                    const SizedBox(width: ResonaSpacing.md),
                    IconButton(icon: const Icon(Icons.file_open_outlined), onPressed: _importFile),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
