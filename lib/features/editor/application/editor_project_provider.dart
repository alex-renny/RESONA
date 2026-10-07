import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/id_generator.dart';
import '../../../models/audio_project.dart';
import '../../projects/application/projects_provider.dart';
import '../domain/clip_edit_math.dart';
import '../domain/timeline_geometry.dart';
import '../domain/undo_history.dart';

/// Active timeline tool. Select is the default interaction (tap to select,
/// drag to move, edge-drag to trim); Split cuts the tapped clip at the
/// current playhead (spec section 20: Split).
enum EditorTool { select, split }

/// Everything the timeline UI needs: the project being edited, current
/// selection, zoom, playhead, save status, and undo/redo availability.
class EditorState {
  final AudioProject project;
  final String? selectedTrackId;
  final String? selectedClipId;
  final double pixelsPerSecond;
  final Duration playhead;
  final bool isDirty;
  final bool isSaving;
  final EditorTool tool;
  final String? importError;

  /// Whether there is a previous state to restore (Ctrl+Z).
  final bool canUndo;

  /// Whether there is a future state to replay (Ctrl+Shift+Z).
  final bool canRedo;

  const EditorState({
    required this.project,
    this.selectedTrackId,
    this.selectedClipId,
    this.pixelsPerSecond = 60,
    this.playhead = Duration.zero,
    this.isDirty = false,
    this.isSaving = false,
    this.tool = EditorTool.select,
    this.importError,
    this.canUndo = false,
    this.canRedo = false,
  });

  EditorState copyWith({
    AudioProject? project,
    String? selectedTrackId,
    bool clearSelectedTrack = false,
    String? selectedClipId,
    bool clearSelectedClip = false,
    double? pixelsPerSecond,
    Duration? playhead,
    bool? isDirty,
    bool? isSaving,
    EditorTool? tool,
    String? importError,
    bool clearImportError = false,
    bool? canUndo,
    bool? canRedo,
  }) {
    return EditorState(
      project: project ?? this.project,
      selectedTrackId:
          clearSelectedTrack ? null : (selectedTrackId ?? this.selectedTrackId),
      selectedClipId:
          clearSelectedClip ? null : (selectedClipId ?? this.selectedClipId),
      pixelsPerSecond: pixelsPerSecond ?? this.pixelsPerSecond,
      playhead: playhead ?? this.playhead,
      isDirty: isDirty ?? this.isDirty,
      isSaving: isSaving ?? this.isSaving,
      tool: tool ?? this.tool,
      importError:
          clearImportError ? null : (importError ?? this.importError),
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
    );
  }
}

class EditorProjectNotifier extends StateNotifier<EditorState?> {
  final Ref _ref;

  /// Tracks undo/redo history for [AudioProject] mutations. Initialised when
  /// a project is opened or created; null when the editor is closed.
  UndoHistory<AudioProject>? _history;

  EditorProjectNotifier(this._ref) : super(null);

  // ─── Project lifecycle ──────────────────────────────────────────────────────

  void openProject(AudioProject project) {
    _history = UndoHistory(current: project);
    state = EditorState(project: project, canUndo: false, canRedo: false);
  }

  void newProject({String name = 'Untitled Project'}) {
    final now = DateTime.now();
    final project = AudioProject(
      id: IdGenerator.next(),
      name: name,
      createdAt: now,
      modifiedAt: now,
      tracks: [AudioTrack(id: IdGenerator.next(), name: 'Track 1')],
    );
    _history = UndoHistory(current: project);
    state = EditorState(project: project, isDirty: true, canUndo: false, canRedo: false);
  }

  /// Opens a newly merged audio file in the timeline editor for further editing.
  /// Automatically creates an [AudioProject] containing the merged audio clip,
  /// loads it into the timeline, and flags the project for editing.
  Future<void> openMergedFile(String filePath, {String projectName = 'Auto Merge Project'}) async {
    Duration? duration;
    final probe = AudioPlayer();
    try {
      duration = await probe.setFilePath(filePath);
    } catch (_) {
      duration = null;
    } finally {
      await probe.dispose();
    }

    final now = DateTime.now();
    final clipDuration = duration ?? const Duration(seconds: 30);
    final clipName = filePath.split(RegExp(r'[\\/]')).last;

    final clip = AudioClip(
      id: IdGenerator.next(),
      sourcePath: filePath,
      name: clipName,
      startTime: Duration.zero,
      endTime: clipDuration,
      timelinePosition: Duration.zero,
    );

    final track = AudioTrack(
      id: IdGenerator.next(),
      name: 'Merged Audio Track',
      clips: [clip],
    );

    final project = AudioProject(
      id: IdGenerator.next(),
      name: projectName,
      createdAt: now,
      modifiedAt: now,
      tracks: [track],
    );

    _history = UndoHistory(current: project);
    state = EditorState(
      project: project,
      selectedTrackId: track.id,
      selectedClipId: clip.id,
      isDirty: true,
      canUndo: false,
      canRedo: false,
    );
  }

  void close() {
    _history = null;
    state = null;
  }

  // ─── Undo / Redo ────────────────────────────────────────────────────────────

  bool get canUndo => _history?.canUndo ?? false;
  bool get canRedo => _history?.canRedo ?? false;

  void undo() {
    final s = state;
    final h = _history;
    if (s == null || h == null || !h.canUndo) return;
    _history = h.undo();
    state = s.copyWith(
      project: _history!.current,
      isDirty: true,
      canUndo: _history!.canUndo,
      canRedo: _history!.canRedo,
    );
  }

  void redo() {
    final s = state;
    final h = _history;
    if (s == null || h == null || !h.canRedo) return;
    _history = h.redo();
    state = s.copyWith(
      project: _history!.current,
      isDirty: true,
      canUndo: _history!.canUndo,
      canRedo: _history!.canRedo,
    );
  }

  // ─── Import ─────────────────────────────────────────────────────────────────

  /// Imports one or more files onto the first track, positioned back to
  /// back after whatever's already there (spec section 11: the user
  /// shouldn't have to manually arrange a straightforward import). Creates a
  /// project automatically if none is open yet.
  Future<void> importFiles(List<String> paths) async {
    if (state == null) newProject();
    var current = state!;

    for (final path in paths) {
      Duration? duration;
      final probe = AudioPlayer();
      try {
        duration = await probe.setFilePath(path);
      } catch (_) {
        duration = null;
      } finally {
        await probe.dispose();
      }

      if (duration == null || duration == Duration.zero) {
        current = current.copyWith(
            importError: "RESONA couldn't process this audio file.");
        continue;
      }

      var tracks = current.project.tracks;
      if (tracks.isEmpty) {
        tracks = [AudioTrack(id: IdGenerator.next(), name: 'Track 1')];
      }
      final targetTrack = tracks.first;
      final lastEnd = targetTrack.clips.isEmpty
          ? Duration.zero
          : targetTrack.clips
              .map((c) => c.timelinePosition + c.sourceDuration)
              .reduce((a, b) => a > b ? a : b);

      final clip = AudioClip(
        id: IdGenerator.next(),
        sourcePath: path,
        name: path.split(RegExp(r'[\\/]')).last,
        startTime: Duration.zero,
        endTime: duration,
        timelinePosition: lastEnd,
      );

      final updatedTrack =
          targetTrack.copyWith(clips: [...targetTrack.clips, clip]);
      tracks = [updatedTrack, ...tracks.skip(1)];

      final newProject =
          current.project.copyWith(tracks: tracks, modifiedAt: DateTime.now());
      // Push imported state into history so it can be undone.
      _history = (_history ?? UndoHistory(current: current.project))
          .push(newProject);

      current = current.copyWith(
        project: newProject,
        isDirty: true,
        selectedTrackId: updatedTrack.id,
        selectedClipId: clip.id,
        canUndo: _history!.canUndo,
        canRedo: _history!.canRedo,
      );
    }

    state = current;
  }

  // ─── Core mutation helper ───────────────────────────────────────────────────

  /// Applies [transform] to the current track list, pushes the resulting
  /// project into the undo history, then emits the new [EditorState].
  void _mutateTracks(
      List<AudioTrack> Function(List<AudioTrack> tracks) transform) {
    final s = state;
    if (s == null) return;

    final tracks = transform(s.project.tracks);
    final newProject =
        s.project.copyWith(tracks: tracks, modifiedAt: DateTime.now());

    // Push to history before applying so undo can revert this change.
    _history = (_history ?? UndoHistory(current: s.project)).push(newProject);

    state = s.copyWith(
      project: newProject,
      isDirty: true,
      canUndo: _history!.canUndo,
      canRedo: _history!.canRedo,
    );
  }

  // ─── Editing operations (all covered by undo/redo via _mutateTracks) ───────

  void moveClip(String trackId, String clipId, Duration newPosition,
      {bool snap = true}) {
    _mutateTracks((tracks) {
      var position = newPosition;
      if (snap) {
        final snapPoints = <Duration>[Duration.zero];
        for (final t in tracks) {
          for (final c in t.clips) {
            if (c.id == clipId) continue;
            snapPoints.add(c.timelinePosition);
            snapPoints.add(c.timelinePosition + c.sourceDuration);
          }
        }
        position =
            snapDuration(position, snapPoints, const Duration(milliseconds: 150));
      }
      return [
        for (final t in tracks)
          t.id == trackId
              ? t.copyWith(clips: [
                  for (final c in t.clips)
                    c.id == clipId ? ClipEditMath.move(c, position) : c,
                ])
              : t,
      ];
    });
  }

  void trimClipStart(String trackId, String clipId, Duration delta) {
    _mutateTracks((tracks) => [
          for (final t in tracks)
            t.id == trackId
                ? t.copyWith(clips: [
                    for (final c in t.clips)
                      c.id == clipId ? ClipEditMath.trimStart(c, delta) : c,
                  ])
                : t,
        ]);
  }

  void trimClipEnd(String trackId, String clipId, Duration delta,
      {Duration? maxSourceDuration}) {
    _mutateTracks((tracks) => [
          for (final t in tracks)
            t.id == trackId
                ? t.copyWith(clips: [
                    for (final c in t.clips)
                      c.id == clipId
                          ? ClipEditMath.trimEnd(c, delta,
                              maxSourceDuration: maxSourceDuration)
                          : c,
                  ])
                : t,
        ]);
  }

  List<AudioClip> _splitClipInList(
      List<AudioClip> clips, String clipId, Duration absoluteTime) {
    final result = <AudioClip>[];
    for (final c in clips) {
      if (c.id != clipId) {
        result.add(c);
        continue;
      }
      final splitResult = ClipEditMath.split(c, absoluteTime, IdGenerator.next);
      if (splitResult == null) {
        result.add(c);
      } else {
        result.add(splitResult.$1);
        result.add(splitResult.$2);
      }
    }
    return result;
  }

  void splitAt(String trackId, String clipId, Duration absoluteTime) {
    _mutateTracks((tracks) => [
          for (final t in tracks)
            t.id == trackId
                ? t.copyWith(
                    clips: _splitClipInList(t.clips, clipId, absoluteTime))
                : t,
        ]);
  }

  void deleteClip(String trackId, String clipId) {
    _mutateTracks((tracks) => [
          for (final t in tracks)
            t.id == trackId
                ? t.copyWith(
                    clips: t.clips.where((c) => c.id != clipId).toList())
                : t,
        ]);
    // Clear selection without pushing into history — selection is not undoable.
    final s = state;
    if (s != null && s.selectedClipId == clipId) {
      state = s.copyWith(clearSelectedClip: true);
    }
  }

  void updateClipProperties(String trackId, String clipId, AudioClip updatedClip) {
    _mutateTracks((tracks) => [
          for (final t in tracks)
            t.id == trackId
                ? t.copyWith(
                    clips: [
                      for (final c in t.clips)
                        c.id == clipId ? updatedClip : c
                    ],
                  )
                : t,
        ]);
  }

  void duplicateClip(String trackId, String clipId) {
    _mutateTracks((tracks) {
      return [
        for (final t in tracks)
          if (t.id == trackId)
            () {
              final clip = t.clips.firstWhere((c) => c.id == clipId);
              final copy = clip.copyWith();
              final duplicated = AudioClip(
                id: IdGenerator.next(),
                sourcePath: copy.sourcePath,
                name: '${copy.name} copy',
                startTime: copy.startTime,
                endTime: copy.endTime,
                timelinePosition: copy.timelinePosition + copy.sourceDuration + const Duration(milliseconds: 500),
                volume: copy.volume,
                pan: copy.pan,
                fadeIn: copy.fadeIn,
                fadeOut: copy.fadeOut,
                effects: copy.effects,
                speed: copy.speed,
                pitchSemitones: copy.pitchSemitones,
                muted: copy.muted,
                locked: copy.locked,
              );
              return t.copyWith(clips: [...t.clips, duplicated]);
            }()
          else
            t,
      ];
    });
  }

  void selectClip(String? trackId, String? clipId) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(
      selectedTrackId: trackId,
      clearSelectedTrack: trackId == null,
      selectedClipId: clipId,
      clearSelectedClip: clipId == null,
    );
  }

  void addTrack() {
    _mutateTracks((tracks) => [
          ...tracks,
          AudioTrack(
              id: IdGenerator.next(), name: 'Track ${tracks.length + 1}'),
        ]);
  }

  void deleteTrack(String trackId) {
    _mutateTracks(
        (tracks) => tracks.where((t) => t.id != trackId).toList());
  }

  void renameTrack(String trackId, String name) {
    if (name.trim().isEmpty) return;
    _mutateTracks((tracks) => [
          for (final t in tracks)
            t.id == trackId ? t.copyWith(name: name.trim()) : t,
        ]);
  }

  void toggleMute(String trackId) {
    _mutateTracks((tracks) => [
          for (final t in tracks)
            t.id == trackId ? t.copyWith(muted: !t.muted) : t,
        ]);
  }

  void toggleSolo(String trackId) {
    _mutateTracks((tracks) => [
          for (final t in tracks)
            t.id == trackId ? t.copyWith(solo: !t.solo) : t,
        ]);
  }

  void toggleLock(String trackId) {
    _mutateTracks((tracks) => [
          for (final t in tracks)
            t.id == trackId ? t.copyWith(locked: !t.locked) : t,
        ]);
  }

  void setTrackVolume(String trackId, double volume) {
    _mutateTracks((tracks) => [
          for (final t in tracks)
            t.id == trackId ? t.copyWith(volume: volume) : t,
        ]);
  }

  // ─── Non-undoable UI state ──────────────────────────────────────────────────

  void setZoom(double pixelsPerSecond) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(
        pixelsPerSecond: TimelineGeometry.clampZoom(pixelsPerSecond));
  }

  void setTool(EditorTool tool) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(tool: tool);
  }

  void seek(Duration position) {
    final s = state;
    if (s == null) return;
    state =
        s.copyWith(playhead: position.isNegative ? Duration.zero : position);
  }

  void renameProject(String name) {
    final s = state;
    if (s == null || name.trim().isEmpty) return;
    state = s.copyWith(
      project: s.project.copyWith(name: name.trim(), modifiedAt: DateTime.now()),
      isDirty: true,
    );
  }

  // ─── Save ───────────────────────────────────────────────────────────────────

  Future<void> save() async {
    final s = state;
    if (s == null) return;
    state = s.copyWith(isSaving: true);
    try {
      final repo = _ref.read(projectRepositoryProvider);
      final saved = s.project.copyWith(modifiedAt: DateTime.now());
      await repo.save(saved);
      _ref.invalidate(recentProjectsProvider);
      state = s.copyWith(project: saved, isDirty: false, isSaving: false);
    } catch (e) {
      state = s.copyWith(isSaving: false);
      throw const AppException("RESONA couldn't save this project.");
    }
  }
}

final editorProjectProvider =
    StateNotifierProvider<EditorProjectNotifier, EditorState?>(
  (ref) => EditorProjectNotifier(ref),
);
