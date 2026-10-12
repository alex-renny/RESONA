import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/audio_engine/ffmpeg/encode_options.dart';
import '../../../../core/audio_engine/ffmpeg/ffmpeg_service.dart';
import '../../../../models/audio_project.dart';
import '../../../player/application/audio_player_service.dart';
import '../../application/editor_project_provider.dart';

/// Plays the source directly so clip controls can update without re-rendering it.
/// Panning uses a short FFmpeg preview because just_audio has no live pan control.
class TransportBar extends ConsumerStatefulWidget {
  final EditorState editor;
  const TransportBar({super.key, required this.editor});

  @override
  ConsumerState<TransportBar> createState() => _TransportBarState();
}

class _TransportBarState extends ConsumerState<TransportBar> {
  bool _isPlaying = false;
  bool _isPreparingPreview = false;
  bool _isPreparingProjectPreview = false;
  bool _isProjectPlayback = false;
  bool _timelineMixStale = false;
  bool _isRefreshingPreview = false;
  bool _usingPanRender = false;
  String? _previewPath;
  String? _projectPreviewPath;
  Timer? _panRefreshTimer;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;
  bool _reachedClipEnd = false;
  int _panRevision = 0;
  Duration _lastPreviewSourcePosition = Duration.zero;

  AudioClip? get _selectedClip => _findSelectedClip(widget.editor);

  AudioClip? _findSelectedClip(EditorState editor) {
    if (editor.selectedTrackId == null || editor.selectedClipId == null) return null;
    for (final track in editor.project.tracks) {
      if (track.id != editor.selectedTrackId) continue;
      for (final clip in track.clips) {
        if (clip.id == editor.selectedClipId) return clip;
      }
    }
    return null;
  }

  AudioTrack? _findTrack(EditorState editor, String? id) {
    if (id == null) return null;
    for (final track in editor.project.tracks) {
      if (track.id == id) return track;
    }
    return null;
  }

  bool _clipAudioSettingsChanged(AudioClip a, AudioClip b) =>
      a.id != b.id || a.sourcePath != b.sourcePath || a.startTime != b.startTime ||
      a.endTime != b.endTime || a.timelinePosition != b.timelinePosition ||
      a.volume != b.volume || a.pan != b.pan || a.fadeIn != b.fadeIn ||
      a.fadeOut != b.fadeOut || a.speed != b.speed ||
      a.pitchSemitones != b.pitchSemitones || a.muted != b.muted ||
      a.effects.toString() != b.effects.toString();

  bool _trackAudioSettingsChanged(AudioTrack? a, AudioTrack? b) =>
      a?.id != b?.id || a?.volume != b?.volume || a?.pan != b?.pan ||
      a?.muted != b?.muted || a?.solo != b?.solo;

  bool _needsProcessedPreview(AudioClip clip, AudioTrack? track) =>
      clip.pan.abs() > 0.001 || (track?.pan ?? 0).abs() > 0.001 ||
      clip.effects.any((effect) => effect.enabled);

  @override
  void didUpdateWidget(covariant TransportBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editor.selectedClipId != widget.editor.selectedClipId &&
        _isPlaying && !_isProjectPlayback) {
      unawaited(ref.read(audioPlayerServiceProvider).pause());
      if (mounted) setState(() => _isPlaying = false);
    }
    if (oldWidget.editor.seekRequestVersion != widget.editor.seekRequestVersion) {
      unawaited(_seekActivePreview(widget.editor.playhead));
      return;
    }
    final previous = _findSelectedClip(oldWidget.editor);
    final current = _selectedClip;
    if (previous == null || current == null) {
      if (previous != null && current == null) unawaited(_stopPreview());
      return;
    }
    final oldTrack = _findTrack(oldWidget.editor, oldWidget.editor.selectedTrackId);
    final track = _findTrack(widget.editor, widget.editor.selectedTrackId);
    if (!_clipAudioSettingsChanged(previous, current) &&
        !_trackAudioSettingsChanged(oldTrack, track)) return;
    if (_isProjectPlayback) {
      _timelineMixStale = true;
      if (mounted) setState(() {});
      return;
    }
    if (_previewPath == null && !_isPlaying) return;

    final panChanged = previous.pan != current.pan || oldTrack?.pan != track?.pan;
    final sourceChanged = previous.sourcePath != current.sourcePath;
    final effectsChanged = previous.effects.toString() != current.effects.toString();
    if (panChanged || effectsChanged || sourceChanged || (_usingPanRender &&
        (previous.startTime != current.startTime || previous.endTime != current.endTime))) {
      _panRevision++;
      _panRefreshTimer?.cancel();
      _panRefreshTimer = Timer(const Duration(milliseconds: 180), () {
        unawaited(_refreshPanPreview());
      });
      return;
    }
    unawaited(_applyLiveSettings(current, track));
  }

  Future<String> _renderPanPreview(AudioProject project, AudioTrack track, AudioClip clip) async {
    final neutralClip = clip.copyWith(
      muted: false, locked: false, timelinePosition: Duration.zero,
      volume: 1, speed: 1, pitchSemitones: 0,
      fadeIn: Duration.zero, fadeOut: Duration.zero,
    );
    final neutralTrack = track.copyWith(
      clips: [neutralClip], muted: false, solo: false, volume: 1,
    );
    final previewProject = project.copyWith(tracks: [neutralTrack]);
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}${Platform.pathSeparator}resona_pan_${clip.id}_${DateTime.now().microsecondsSinceEpoch}.wav';
    final result = await FfmpegService().mixProject(
      project: previewProject,
      outputPath: path,
      encode: AudioEncodeOptions(format: 'wav', sampleRate: project.sampleRate),
    );
    if (!result.success) throw StateError(result.errorMessage ?? 'Could not prepare pan preview.');
    return path;
  }

  Future<String> _renderProjectPreview(AudioProject project) async {
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}${Platform.pathSeparator}'
        'resona_timeline_${project.id}_${DateTime.now().microsecondsSinceEpoch}.wav';
    final result = await FfmpegService().mixProject(
      project: project,
      outputPath: path,
      encode: AudioEncodeOptions(format: 'wav', sampleRate: project.sampleRate),
    );
    if (!result.success) {
      throw StateError(result.errorMessage ?? 'Could not prepare the timeline mix.');
    }
    return path;
  }

  Future<void> _toggleProjectPlayback() async {
    final player = ref.read(audioPlayerServiceProvider);
    if (_isProjectPlayback) {
      if (_isPlaying) {
        await player.pause();
      } else {
        await player.play();
      }
      return;
    }

    setState(() => _isPreparingProjectPreview = true);
    try {
      await player.stop();
      _positionSub?.cancel();
      _stateSub?.cancel();
      final oldClipPreview = _previewPath;
      final oldProjectPreview = _projectPreviewPath;
      _previewPath = null;
      _usingPanRender = false;
      _projectPreviewPath = null;
      if (oldClipPreview != null) await _deletePreview(oldClipPreview);
      if (oldProjectPreview != null) await _deletePreview(oldProjectPreview);

      final projectSnapshot = widget.editor.project;
      final path = await _renderProjectPreview(projectSnapshot);
      if (!mounted) {
        await _deletePreview(path);
        return;
      }
      await player.loadFile(path);
      _projectPreviewPath = path;
      _isProjectPlayback = true;
      _timelineMixStale =
          ref.read(editorProjectProvider)?.project != projectSnapshot;
      await player.setSpeed(1);
      await player.setPitch(1);
      await player.setVolume(1);
      var startAt = widget.editor.playhead;
      if (startAt.isNegative || startAt >= widget.editor.project.duration) {
        startAt = Duration.zero;
      }
      await player.seek(startAt);
      _listenToProjectPlayer(player);
      await player.play();
    } catch (error) {
      _isProjectPlayback = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not play the complete timeline: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPreparingProjectPreview = false);
    }
  }

  void _listenToProjectPlayer(AudioPlayerService player) {
    final notifier = ref.read(editorProjectProvider.notifier);
    _positionSub?.cancel();
    _positionSub = player.positionStream.listen(
      (position) => notifier.seek(position, fromPlayback: true),
    );
    _stateSub?.cancel();
    _stateSub = player.playerStateStream.listen((state) {
      if (mounted) setState(() => _isPlaying = state.playing);
      if (state.processingState == ProcessingState.completed) {
        _isProjectPlayback = false;
        unawaited(player.pause());
      }
    });
  }

  Future<void> _seekActivePreview(Duration timelinePosition) async {
    final player = ref.read(audioPlayerServiceProvider);
    if (_isProjectPlayback) {
      await player.seek(timelinePosition);
      return;
    }
    if (!_isPlaying) return;
    final clip = _selectedClip;
    if (clip == null) return;
    final clipOffset = timelinePosition - clip.timelinePosition;
    if (clipOffset.isNegative || clipOffset >= clip.sourceDuration) {
      await player.pause();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }
    final sourcePosition = clip.startTime + clipOffset;
    _lastPreviewSourcePosition = sourcePosition;
    await player.seek(_usingPanRender ? clipOffset : sourcePosition);
  }

  Future<void> _refreshPanPreview() async {
    if (!_isPlaying && _previewPath == null) return;
    final wasPlaying = _isPlaying;
    final revision = _panRevision;
    final player = ref.read(audioPlayerServiceProvider);
    final latest = ref.read(editorProjectProvider);
    if (latest == null) return;
    final clip = _findSelectedClip(latest);
    final track = _findTrack(latest, latest.selectedTrackId);
    if (clip == null || track == null) return;
    setState(() => _isRefreshingPreview = true);
    try {
      final oldPath = _previewPath;
      final keepPanRender = _needsProcessedPreview(clip, track);
      String? newPath;
      if (keepPanRender) newPath = await _renderPanPreview(latest.project, track, clip);
      if (!mounted || revision != _panRevision) {
        if (newPath != null) await _deletePreview(newPath);
        return;
      }
      await player.pause();
      if (keepPanRender) {
        await player.loadFile(newPath!);
        _previewPath = newPath;
      } else {
        await player.loadFile(clip.sourcePath);
        _previewPath = null;
      }
      _usingPanRender = keepPanRender;
      final sourcePosition = _lastPreviewSourcePosition < clip.startTime
          ? clip.startTime
          : (_lastPreviewSourcePosition > clip.endTime ? clip.endTime : _lastPreviewSourcePosition);
      await player.seek(_usingPanRender ? sourcePosition - clip.startTime : sourcePosition);
      await _applyLiveSettings(clip, track);
      _listenToPlayer(player);
      if (oldPath != null && oldPath != _previewPath) await _deletePreview(oldPath);
      if (wasPlaying) await player.play();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update pan preview: $error')),
      );
    } finally {
      if (mounted) setState(() => _isRefreshingPreview = false);
    }
  }

  Future<void> _applyLiveSettings(AudioClip clip, AudioTrack? track) async {
    final player = ref.read(audioPlayerServiceProvider);
    try {
      await player.setSpeed(clip.speed.clamp(0.25, 4.0).toDouble());
      await player.setPitch(math.pow(2, clip.pitchSemitones / 12).toDouble());
      final position = _sourcePosition(player.position, clip);
      await player.setVolume(_gainAt(position, clip, track));
      if (position < clip.startTime || position >= clip.endTime) {
        final safe = position < clip.startTime
            ? clip.startTime
            : clip.endTime - const Duration(milliseconds: 1);
        await player.seek(_usingPanRender ? safe - clip.startTime : safe);
      }
      _listenToPlayer(player);
    } catch (_) {
      // The selected clip may change while the platform player is updating.
    }
  }

  Duration _sourcePosition(Duration playerPosition, AudioClip clip) =>
      _usingPanRender ? clip.startTime + playerPosition : playerPosition;

  double _gainAt(Duration sourcePosition, AudioClip clip, AudioTrack? track) {
    if (clip.muted || track == null || track.muted) return 0;
    final speed = clip.speed.clamp(0.25, 4.0).toDouble();
    var gain = clip.volume * track.volume;
    if (clip.fadeIn > Duration.zero) {
      final elapsedOutput = (sourcePosition - clip.startTime).inMicroseconds / speed;
      gain *= (elapsedOutput / clip.fadeIn.inMicroseconds).clamp(0.0, 1.0);
    }
    if (clip.fadeOut > Duration.zero) {
      final remainingOutput = (clip.endTime - sourcePosition).inMicroseconds / speed;
      gain *= (remainingOutput / clip.fadeOut.inMicroseconds).clamp(0.0, 1.0);
    }
    return gain.clamp(0.0, 1.0).toDouble();
  }

  void _listenToPlayer(AudioPlayerService player) {
    final notifier = ref.read(editorProjectProvider.notifier);
    _positionSub?.cancel();
    _positionSub = player.positionStream.listen((pos) {
      final clip = _selectedClip;
      if (clip == null) return;
      final track = _findTrack(widget.editor, widget.editor.selectedTrackId);
      final sourcePos = _sourcePosition(pos, clip);
      _lastPreviewSourcePosition = sourcePos;
      unawaited(player.setVolume(_gainAt(sourcePos, clip, track)).catchError((_) {}));
      final offset = sourcePos - clip.startTime;
      notifier.seek(clip.timelinePosition + offset, fromPlayback: true);
      if (!_reachedClipEnd && sourcePos >= clip.endTime) {
        _reachedClipEnd = true;
        unawaited(player.pause());
        if (mounted) setState(() => _isPlaying = false);
      } else if (sourcePos < clip.endTime) {
        _reachedClipEnd = false;
      }
    });
    _stateSub?.cancel();
    _stateSub = player.playerStateStream.listen((state) {
      if (mounted) setState(() => _isPlaying = state.playing);
      if (state.processingState == ProcessingState.completed) unawaited(player.pause());
    });
  }

  Future<void> _togglePlay() async {
    final clip = _selectedClip;
    final track = _findTrack(widget.editor, widget.editor.selectedTrackId);
    if (clip == null || track == null) return;
    final player = ref.read(audioPlayerServiceProvider);
    if (_isPlaying) {
      await player.pause();
      return;
    }
    if (_isProjectPlayback) {
      await player.stop();
      _isProjectPlayback = false;
      final projectPath = _projectPreviewPath;
      _projectPreviewPath = null;
      if (projectPath != null) await _deletePreview(projectPath);
    }
    setState(() => _isPreparingPreview = true);
    try {
      await player.stop();
      final oldPath = _previewPath;
      _usingPanRender = _needsProcessedPreview(clip, track);
      if (_usingPanRender) {
        final path = await _renderPanPreview(widget.editor.project, track, clip);
        await player.loadFile(path);
        _previewPath = path;
      } else {
        await player.loadFile(clip.sourcePath);
        _previewPath = null;
      }
      if (oldPath != null && oldPath != _previewPath) await _deletePreview(oldPath);
      var sourcePosition = widget.editor.playhead;
      if (sourcePosition < clip.timelinePosition || sourcePosition >= clip.timelinePosition + clip.sourceDuration) {
        sourcePosition = clip.timelinePosition;
      }
      _lastPreviewSourcePosition = clip.startTime + sourcePosition - clip.timelinePosition;
      await player.seek(_usingPanRender ? sourcePosition - clip.timelinePosition : _lastPreviewSourcePosition);
      _reachedClipEnd = false;
      await _applyLiveSettings(clip, track);
      _listenToPlayer(player);
      await player.play();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audio preview failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _isPreparingPreview = false);
    }
  }

  Future<void> _stopPreview() async {
    _panRefreshTimer?.cancel();
    _positionSub?.cancel();
    _stateSub?.cancel();
    final old = _previewPath;
    final oldProject = _projectPreviewPath;
    _previewPath = null;
    _projectPreviewPath = null;
    _usingPanRender = false;
    _isProjectPlayback = false;
    await ref.read(audioPlayerServiceProvider).stop();
    if (old != null) await _deletePreview(old);
    if (oldProject != null) await _deletePreview(oldProject);
    if (mounted) setState(() => _isPlaying = false);
  }

  @override
  void dispose() {
    _panRefreshTimer?.cancel();
    _positionSub?.cancel();
    _stateSub?.cancel();
    final path = _previewPath;
    if (path != null) unawaited(_deletePreview(path));
    final projectPath = _projectPreviewPath;
    if (projectPath != null) unawaited(_deletePreview(projectPath));
    super.dispose();
  }

  Future<void> _deletePreview(String path) async {
    try { await File(path).delete(); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final clip = _selectedClip;
    final theme = Theme.of(context);
    final position = widget.editor.playhead;
    final positionMilliseconds = position.inMilliseconds.remainder(1000);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ResonaSpacing.lg, vertical: ResonaSpacing.sm),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.dividerColor))),
      child: Row(children: [
        IconButton(icon: const Icon(Icons.stop), onPressed: _stopPreview),
        IconButton.filled(
          icon: _isPreparingPreview || _isRefreshingPreview
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: clip == null || _isPreparingPreview || _isRefreshingPreview ? null : _togglePlay,
        ),
        IconButton.filledTonal(
          tooltip: 'Play the complete timeline, including all split pieces in order',
          onPressed: _isPreparingProjectPreview || _isPreparingPreview || _isRefreshingPreview
              ? null
              : _toggleProjectPlayback,
          icon: _isPreparingProjectPreview
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.queue_music),
        ),
        const SizedBox(width: ResonaSpacing.md),
        Text(
          '${TimeFormat.format(position)}.${positionMilliseconds.toString().padLeft(3, '0')}',
          style: theme.textTheme.bodySmall,
        ),
        const Spacer(),
        Flexible(child: Text(
          _isProjectPlayback
              ? _timelineMixStale
                  ? 'Timeline changed • stop and replay to hear updates'
                  : 'Playing complete timeline mix'
              : _isRefreshingPreview
                  ? 'Updating audio effect…'
                  : clip == null
                      ? 'Select a clip to preview it.'
                      : 'Live preview: ${clip.name}',
          maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall,
        )),
      ]),
    );
  }
}


