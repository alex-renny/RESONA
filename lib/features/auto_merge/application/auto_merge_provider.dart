import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../core/audio_engine/duration_probe.dart';
import '../../../core/audio_engine/ffmpeg/ffmpeg_service.dart';
import '../../../core/audio_engine/media_store.dart';
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
      processingStep:
          clearProcessingStep ? null : (processingStep ?? this.processingStep),
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
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
    final defaultFade = Duration(
      milliseconds: (sourceDuration.inMilliseconds ~/ 4).clamp(0, 500),
    );
    final item = AutoMergeItem(
      id: IdGenerator.next(),
      sourcePath: sourcePath,
      name: name,
      sourceDuration: sourceDuration,
      position: newPosition,
      fadeIn: defaultFade,
      fadeOut: defaultFade,
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
    list.insert(newIndex, item);
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

  /// Renders the ordered clips into [outputDir] using the local FFmpeg engine.
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
      final ffmpeg = FfmpegService();
      if (!await FfmpegService.isAvailable()) {
        throw const AppException(
          'Audio processing is unavailable. On Android, RESONA includes a '
          'bundled engine. On desktop, install FFmpeg and add it to PATH.',
        );
      }

      if (state.items.any((item) =>
          item.sourceDuration == null ||
          item.sourceDuration! <= Duration.zero)) {
        throw const AppException(
          'RESONA could not read the duration of one or more audio files. '
          'Remove those files and import them again.',
        );
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final destDir =
          outputDir.isEmpty ? (await MediaStore.exportsDir()).path : outputDir;
      final outputPath = p.join(destDir, 'resona_merge_$timestamp.mp3');

      state = state.copyWith(
        processingStep: 'Building timeline with FFmpeg…',
      );
      final clipsMaps = state.items
          .map((item) => {
                'path': item.sourcePath,
                'startTime': item.startTime,
                'endTime': item.endTime == Duration.zero
                    ? item.sourceDuration!
                    : item.endTime,
                'fadeIn': item.fadeIn,
                'fadeOut': item.fadeOut,
              })
          .toList();

      state = state.copyWith(
        processingStep: 'Applying fades and transitions…',
      );
      final firstItem = state.items.first;
      final result = await ffmpeg.buildAutoMerge(
        clips: clipsMaps,
        outputPath: outputPath,
        transition: firstItem.transition,
        crossfadeDuration: firstItem.crossfadeDuration,
      );

      if (!result.success || result.outputPath == null) {
        throw AppException(result.errorMessage ??
            "RESONA couldn't process this audio. Check that the source files are available and use a supported format.");
      }

      final renderedDuration = await ffmpeg.probeDuration(outputPath);
      if (renderedDuration == null || renderedDuration <= Duration.zero) {
        throw const AppException(
          'FFmpeg finished, but RESONA could not reopen the merged audio. '
          'The result was not marked complete.',
        );
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
        errorMessage: e is AppException
            ? e.message
            : "RESONA couldn't build the merge: $e",
      );
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  /// Re-assigns sequential 1-based [AutoMergeItem.position] values.
  List<AutoMergeItem> _resequence(List<AutoMergeItem> items) {
    return [
      for (var i = 0; i < items.length; i++) items[i].copyWith(position: i + 1),
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

/// Probes [path] with FFmpeg, then just_audio, and returns null when unavailable.
Future<Duration?> probeDuration(String path) => DurationProbe.probe(path);
