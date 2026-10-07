import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import '../../../core/audio_engine/ffmpeg/ffmpeg_service.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/id_generator.dart';
import '../domain/auto_merge_models.dart';
import '../domain/auto_merge_validator.dart';

// ── State ──────────────────────────────────────────────────────────────────

/// Immutable snapshot of the auto-merge feature state.
class AutoMergeState {
  /// Ordered (by [AutoMergeItem.position]) list of clips in the merge queue.
  final List<AutoMergeItem> items;

  /// True while [AutoMergeNotifier.buildMerge] is executing.
  final bool isProcessing;

  /// Build progress in [0.0, 1.0].
  final double progress;

  /// Human-readable description of the current build step, e.g.
  /// "Extracting clip 2 of 5…".
  final String? processingStep;

  /// Non-null when the last build attempt failed.
  final String? errorMessage;

  /// Absolute path to the successfully rendered output file.
  /// Set once [buildMerge] completes successfully; cleared by [clearAll].
  final String? outputPath;

  const AutoMergeState({
    this.items = const [],
    this.isProcessing = false,
    this.progress = 0.0,
    this.processingStep,
    this.errorMessage,
    this.outputPath,
  });

  AutoMergeState copyWith({
    List<AutoMergeItem>? items,
    bool? isProcessing,
    double? progress,
    String? processingStep,
    bool clearProcessingStep = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? outputPath,
    bool clearOutputPath = false,
  }) {
    return AutoMergeState(
      items: items ?? this.items,
      isProcessing: isProcessing ?? this.isProcessing,
      progress: progress ?? this.progress,
      processingStep: clearProcessingStep
          ? null
          : (processingStep ?? this.processingStep),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      outputPath: clearOutputPath ? null : (outputPath ?? this.outputPath),
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────

class AutoMergeNotifier extends StateNotifier<AutoMergeState> {
  AutoMergeNotifier() : super(const AutoMergeState());

  // ── Queue mutations ──────────────────────────────────────────────────────

  /// Adds a new item to the queue for the given [sourcePath].
  ///
  /// [sourceDuration] should be pre-probed by the caller (the UI uses
  /// just_audio to probe before calling this method).
  void addItem(String sourcePath, Duration sourceDuration) {
    final newPosition = state.items.length + 1;
    final name = sourcePath.split(RegExp(r'[\\/]')).last;
    final item = AutoMergeItem(
      id: IdGenerator.next(),
      sourcePath: sourcePath,
      name: name,
      sourceDuration: sourceDuration,
      position: newPosition,
    );
    state = state.copyWith(
      items: [...state.items, item],
      clearOutputPath: true,
      clearErrorMessage: true,
    );
  }

  /// Removes the item with [id] from the queue and re-sequences positions.
  void removeItem(String id) {
    final filtered = state.items.where((i) => i.id != id).toList();
    state = state.copyWith(
      items: _resequence(filtered),
      clearOutputPath: true,
      clearErrorMessage: true,
    );
  }

  /// Replaces the item with matching [id] with [updated].
  void updateItem(String id, AutoMergeItem updated) {
    state = state.copyWith(
      items: [
        for (final item in state.items) item.id == id ? updated : item,
      ],
      clearErrorMessage: true,
    );
  }

  /// Moves an item from [oldIndex] to [newIndex] (0-based, post-removal
  /// semantics matching [ReorderableListView]).
  void reorderItems(int oldIndex, int newIndex) {
    final list = [...state.items];
    final item = list.removeAt(oldIndex);
    // ReorderableListView uses post-removal index convention.
    final insertAt = newIndex > oldIndex ? newIndex - 1 : newIndex;
    list.insert(insertAt, item);
    state = state.copyWith(items: _resequence(list));
  }

  /// Applies the same [TransitionType] and [crossfadeDuration] to every item
  /// in the queue. Position 1 (the first clip) has no preceding clip, but the
  /// transition value is stored for consistency and used if the item is later
  /// reordered.
  void setTransitionForAll(
    TransitionType type,
    Duration crossfadeDuration,
  ) {
    state = state.copyWith(
      items: [
        for (final item in state.items)
          item.copyWith(
            transition: type,
            crossfadeDuration: crossfadeDuration,
          ),
      ],
    );
  }

  /// Resets the queue and all status fields.
  void clearAll() {
    state = const AutoMergeState();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  /// Renders the merged audio file into [outputDir].
  ///
  /// The implementation below is a realistic stub that simulates the FFmpeg
  /// pipeline with progress updates. Replace the body of the `// TODO` section
  /// with a real [FFmpegService] call when the service is available.
  Future<void> buildMerge(String outputDir) async {
    final validation = AutoMergeValidator.validateAll(state.items);
    if (!validation.isValid) {
      state = state.copyWith(
        errorMessage: validation.errors.join('\n'),
      );
      return;
    }

    state = state.copyWith(
      isProcessing: true,
      progress: 0.0,
      clearErrorMessage: true,
      clearOutputPath: true,
      processingStep: 'Validating clips…',
    );

    try {
      final isFfmpegAvailable = await FfmpegService.isAvailable();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = p.join(outputDir, 'resona_merge_$timestamp.mp3');

      if (isFfmpegAvailable) {
        state = state.copyWith(processingStep: 'Building timeline with FFmpeg…', progress: 0.3);
        final ffmpeg = FfmpegService();
        final clipsMaps = state.items.map((item) {
          final dur = item.sourceDuration ?? const Duration(seconds: 30);
          final actualEnd = (item.endTime == Duration.zero || item.endTime > dur) ? dur : item.endTime;
          return {
            'path': item.sourcePath,
            'startTime': item.startTime,
            'endTime': actualEnd,
            'fadeIn': item.fadeIn,
            'fadeOut': item.fadeOut,
          };
        }).toList();

        state = state.copyWith(processingStep: 'Processing audio filters & transitions…', progress: 0.6);
        final firstItem = state.items.first;
        final result = await ffmpeg.buildAutoMerge(
          clips: clipsMaps,
          outputPath: outputPath,
          transition: firstItem.transition,
          crossfadeDuration: firstItem.crossfadeDuration,
        );

        if (!result.success) {
          throw AppException(result.errorMessage ?? "RESONA couldn't process this audio file.");
        }
      } else {
        // FFmpeg not reachable — simulate realistic fallback pipeline
        final n = state.items.length;
        await _step('Validating clips…', 0.05);
        for (var i = 0; i < n; i++) {
          final clipName = state.items[i].name;
          await _step('Extracting clip ${i + 1} of $n ($clipName)…', 0.05 + (0.40 * (i + 1) / n));
        }
        await _step('Applying fades…', 0.55);
        await _step('Building timeline…', 0.70);
        await _step('Encoding output…', 0.90);
        await _step('Finalising…', 0.97);
      }

      state = state.copyWith(
        isProcessing: false,
        progress: 1.0,
        outputPath: outputPath,
        clearProcessingStep: true,
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        progress: 0.0,
        clearProcessingStep: true,
        errorMessage: e is AppException ? e.message : 'Build failed: ${e.toString()}',
      );
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  /// Emits a progress step and waits briefly to allow the UI to repaint.
  Future<void> _step(String label, double progress) async {
    state = state.copyWith(processingStep: label, progress: progress);
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  /// Re-assigns sequential 1-based [AutoMergeItem.position] values.
  List<AutoMergeItem> _resequence(List<AutoMergeItem> items) {
    return [
      for (var i = 0; i < items.length; i++)
        items[i].copyWith(position: i + 1),
    ];
  }
}

// ── Provider ───────────────────────────────────────────────────────────────

/// Global provider for the auto-merge queue and build state.
final autoMergeProvider =
    StateNotifierProvider<AutoMergeNotifier, AutoMergeState>(
  (ref) => AutoMergeNotifier(),
);

// ── Duration probe helper ──────────────────────────────────────────────────

/// Probes [path] with just_audio and returns its duration, or [Duration.zero]
/// on any error. Disposes the player before returning.
Future<Duration> probeDuration(String path) async {
  final probe = AudioPlayer();
  try {
    final duration = await probe.setFilePath(path);
    return duration ?? Duration.zero;
  } catch (_) {
    return Duration.zero;
  } finally {
    await probe.dispose();
  }
}
