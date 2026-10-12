import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/spacing.dart';
import '../../../auto_merge/presentation/auto_merge_screen.dart';
import '../../application/editor_project_provider.dart';
import '../../domain/timeline_geometry.dart';
import '../clip_inspector.dart';
import '../export_dialog.dart';

const List<String> kSupportedAudioExtensions = [
  'mp3',
  'wav',
  'flac',
  'm4a',
  'aac',
  'ogg',
  'opus',
];

class EditorToolbar extends ConsumerWidget {
  const EditorToolbar({super.key});

  Duration? _parseSplitTime(String input) {
    final parts = input.trim().split(':');
    if (parts.length != 2 && parts.length != 3) return null;
    final format = parts.length == 2
        ? RegExp(r'^\d+:\d{1,2}(?:\.\d{1,3})?$')
        : RegExp(r'^\d+:\d{1,2}:\d{1,2}(?:\.\d{1,3})?$');
    if (!format.hasMatch(input.trim())) return null;
    final secondParts = parts.last.split('.');
    if (secondParts.length > 2 || secondParts.first.isEmpty) return null;
    final seconds = int.tryParse(secondParts.first);
    final milliseconds = secondParts.length == 2 && secondParts[1].isNotEmpty
        ? int.tryParse(secondParts[1].padRight(3, '0'))
        : secondParts.length == 1
            ? 0
            : null;
    if (seconds == null || milliseconds == null || seconds >= 60) return null;

    if (parts.length == 2) {
      final minutes = int.tryParse(parts[0]);
      if (minutes == null || minutes < 0) return null;
      return Duration(minutes: minutes, seconds: seconds, milliseconds: milliseconds);
    }
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    if (hours == null || minutes == null || hours < 0 || minutes < 0 || minutes >= 60) return null;
    return Duration(hours: hours, minutes: minutes, seconds: seconds, milliseconds: milliseconds);
  }

  String _formatSplitTime(Duration value) {
    final totalSeconds = value.inSeconds;
    final seconds = totalSeconds % 60;
    final millis = value.inMilliseconds % 1000;
    final minuteText = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    return '$minuteText:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(3, '0')}';
  }

  Future<void> _splitAtExactTime(
    BuildContext context,
    EditorState editor,
    EditorProjectNotifier notifier,
  ) async {
    final selectedTrackId = editor.selectedTrackId;
    final selectedClipId = editor.selectedClipId;
    if (selectedTrackId == null || selectedClipId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a clip first, then choose Split.')),
      );
      return;
    }
    final controller = TextEditingController(text: _formatSplitTime(editor.playhead));
    String? error;
    final selectedTime = await showDialog<Duration>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Split at an exact time'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter the position on the project timeline. Example: 01:23.500 is 1 minute, 23.5 seconds.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.datetime,
                decoration: InputDecoration(
                  labelText: 'Minutes : seconds . milliseconds',
                  hintText: '01:23.500',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                final value = _parseSplitTime(controller.text);
                if (value == null) {
                  setDialogState(() => error = 'Use MM:SS.mmm, for example 01:23.500.');
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              icon: const Icon(Icons.content_cut),
              label: const Text('Split audio'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (selectedTime == null || !context.mounted) return;
    final didSplit = notifier.splitAt(selectedTrackId, selectedClipId, selectedTime);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(didSplit
            ? 'Audio split at ${_formatSplitTime(selectedTime)}.'
            : 'That time is outside the selected clip or too close to an edge. Choose a time at least 0.1 seconds inside it.'),
      ),
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final targetTrackId = ref.read(editorProjectProvider)?.selectedTrackId;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: kSupportedAudioExtensions,
    );
    if (result == null) return;
    final paths = result.files.map((f) => f.path).whereType<String>().toList();
    if (paths.isNotEmpty) {
      await ref.read(editorProjectProvider.notifier).importFiles(
            paths,
            targetTrackId: targetTrackId,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${paths.length} audio ${paths.length == 1 ? 'clip' : 'clips'} to the timeline.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _renameProject(
      BuildContext context, WidgetRef ref, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename project'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      ref.read(editorProjectProvider.notifier).renameProject(result);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final editor = ref.watch(editorProjectProvider);
    final notifier = ref.read(editorProjectProvider.notifier);

    final compact = MediaQuery.sizeOf(context).width < 700;
    if (compact) {
      return _buildMobile(context, ref, theme, editor, notifier);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: ResonaSpacing.md, vertical: ResonaSpacing.sm),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.dividerColor))),
      child: Row(
        children: [
          if (editor != null)
            Flexible(
              child: GestureDetector(
                onTap: () => _renameProject(context, ref, editor.project.name),
                child: Padding(
                  padding: const EdgeInsets.only(right: ResonaSpacing.md),
                  child: Text(
                    editor.project.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.file_open_outlined),
            tooltip: editor?.selectedTrackId == null
                ? 'Import audio to Track 1'
                : 'Import audio to selected track',
            onPressed: () => _import(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: 'Add Track',
            onPressed: editor == null ? null : notifier.addTrack,
          ),
          const SizedBox(width: ResonaSpacing.sm),
          if (editor != null) ...[
            ToggleButtons(
              isSelected: [
                editor.tool == EditorTool.select,
                editor.tool == EditorTool.split
              ],
              onPressed: (i) => notifier
                  .setTool(i == 0 ? EditorTool.select : EditorTool.split),
              borderRadius: BorderRadius.circular(8),
              constraints: const BoxConstraints(minHeight: 32, minWidth: 36),
              children: const [
                Tooltip(
                  message: 'Select, move and trim clips',
                  child: Icon(Icons.near_me, size: 16),
                ),
                Tooltip(
                  message: 'Split: tap the audio where you want the cut',
                  child: Icon(Icons.content_cut, size: 16),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Undo last edit',
              onPressed: editor.canUndo ? notifier.undo : null,
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              tooltip: 'Redo edit',
              onPressed: editor.canRedo ? notifier.redo : null,
            ),
            if (editor.tool == EditorTool.split)
              TextButton.icon(
                onPressed: () => _splitAtExactTime(context, editor, notifier),
                icon: const Icon(Icons.schedule, size: 18),
                label: const Text('Split at time'),
              ),
            const SizedBox(width: ResonaSpacing.sm),
            if (editor.selectedClipId != null && editor.selectedTrackId != null)
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Edit selected clip',
                onPressed: () => showClipInspectorSheet(
                  context,
                  trackId: editor.selectedTrackId!,
                  clipId: editor.selectedClipId!,
                ),
              ),
            if (editor.selectedClipId != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete clip',
                onPressed: () {
                  final trackId = editor.selectedTrackId;
                  final clipId = editor.selectedClipId;
                  if (trackId != null && clipId != null) {
                    notifier.deleteClip(trackId, clipId);
                  }
                },
              ),
            const Spacer(),
            Icon(Icons.zoom_out,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            SizedBox(
              width: 140,
              child: Slider(
                value: editor.pixelsPerSecond,
                min: TimelineGeometry.zoomSteps.first,
                max: TimelineGeometry.zoomSteps.last,
                onChanged: notifier.setZoom,
              ),
            ),
            Icon(Icons.zoom_in,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: ResonaSpacing.md),
            TextButton.icon(
              onPressed: editor.isSaving
                  ? null
                  : () async {
                      try {
                        await notifier.save();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Project saved.')));
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text("RESONA couldn't save this project.")),
                          );
                        }
                      }
                    },
              icon: editor.isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 16),
              label: Text(editor.isDirty ? 'Save' : 'Saved'),
            ),
            FilledButton.icon(
              onPressed: () => ExportDialog.show(context, editor.project),
              icon: const Icon(Icons.file_download_outlined, size: 16),
              label: const Text('Export'),
            ),
          ] else
            const Spacer(),
        ],
      ),
    );
  }

  Widget _buildMobile(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    EditorState? editor,
    EditorProjectNotifier notifier,
  ) {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(ResonaSpacing.md, 4, ResonaSpacing.md, 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (editor != null)
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        _renameProject(context, ref, editor.project.name),
                    child: Text(
                      editor.project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                )
              else
                const Spacer(),
              FilledButton.icon(
                onPressed: () => _import(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: Text(editor?.selectedTrackId == null
                    ? 'Add Audio'
                    : 'Add to Track'),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AutoMergeScreen()),
                ),
                icon: const Icon(Icons.merge_type, size: 18),
                label: const Text('Auto Merge'),
              ),
            ],
          ),
          if (editor != null) ...[
            const SizedBox(height: 2),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Add track',
                  onPressed: notifier.addTrack,
                  icon: const Icon(Icons.playlist_add),
                ),
                ToggleButtons(
                  isSelected: [
                    editor.tool == EditorTool.select,
                    editor.tool == EditorTool.split,
                  ],
                  onPressed: (i) => notifier.setTool(
                    i == 0 ? EditorTool.select : EditorTool.split,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  constraints:
                      const BoxConstraints(minHeight: 32, minWidth: 36),
                  children: const [
                    Tooltip(
                      message: 'Select, move and trim clips',
                      child: Icon(Icons.near_me, size: 16),
                    ),
                    Tooltip(
                      message: 'Split: tap the audio where you want the cut',
                      child: Icon(Icons.content_cut, size: 16),
                    ),
                  ],
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Undo last edit',
                  onPressed: editor.canUndo ? notifier.undo : null,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Redo edit',
                  onPressed: editor.canRedo ? notifier.redo : null,
                  icon: const Icon(Icons.redo),
                ),
                if (editor.tool == EditorTool.split)
                  TextButton.icon(
                    onPressed: () => _splitAtExactTime(context, editor, notifier),
                    icon: const Icon(Icons.schedule, size: 18),
                    label: const Text('Split at time'),
                  ),
                if (editor.selectedClipId != null && editor.selectedTrackId != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Edit selected clip',
                    onPressed: () => showClipInspectorSheet(
                      context,
                      trackId: editor.selectedTrackId!,
                      clipId: editor.selectedClipId!,
                    ),
                    icon: const Icon(Icons.tune_rounded),
                  ),
                if (editor.selectedClipId != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Delete clip',
                    onPressed: () {
                      final trackId = editor.selectedTrackId;
                      final clipId = editor.selectedClipId;
                      if (trackId != null && clipId != null) {
                        notifier.deleteClip(trackId, clipId);
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                const Icon(Icons.zoom_out, size: 16),
                SizedBox(
                  width: 104,
                  child: Slider(
                    value: editor.pixelsPerSecond,
                    min: TimelineGeometry.zoomSteps.first,
                    max: TimelineGeometry.zoomSteps.last,
                    onChanged: notifier.setZoom,
                  ),
                ),
                const Icon(Icons.zoom_in, size: 16),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: editor.isDirty ? 'Save project' : 'Project saved',
                  onPressed: editor.isSaving
                      ? null
                      : () async {
                          try {
                            await notifier.save();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Project saved.')),
                              );
                            }
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      "RESONA couldn't save this project."),
                                ),
                              );
                            }
                          }
                        },
                  icon: editor.isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          editor.isDirty ? Icons.save_outlined : Icons.check),
                ),
                ],
              ),
            ),
            if (editor.project.tracks.any((t) => t.clips.isNotEmpty))
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, top: 2),
                  child: Text(
                    editor.tool == EditorTool.split
                        ? 'Choose Split and tap the cut point, or use Split at time (MM:SS.mmm). Leave 0.1 seconds on both sides. Drag the blue handle to move the playhead.'
                        : editor.selectedClipId == null
                            ? 'Tap a clip to select it. Drag to move; drag an edge to trim. Drag the blue handle to seek.'
                            : 'Clip selected • edit volume, fades, speed and more. Drag the blue handle or tap the ruler to seek.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () =>
                        ExportDialog.show(context, editor.project),
                    icon: const Icon(Icons.file_download_outlined, size: 16),
                    label: const Text('Export'),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}


