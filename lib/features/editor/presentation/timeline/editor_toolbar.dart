import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/spacing.dart';
import '../../application/editor_project_provider.dart';
import '../../domain/timeline_geometry.dart';

const List<String> kSupportedAudioExtensions = [
  'mp3', 'wav', 'flac', 'm4a', 'aac', 'ogg', 'opus',
];

class EditorToolbar extends ConsumerWidget {
  const EditorToolbar({super.key});

  Future<void> _import(WidgetRef ref) async {
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

  Future<void> _renameProject(BuildContext context, WidgetRef ref, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename project'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Save')),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ResonaSpacing.md, vertical: ResonaSpacing.sm),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.dividerColor))),
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
            tooltip: 'Import Audio',
            onPressed: () => _import(ref),
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: 'Add Track',
            onPressed: editor == null ? null : notifier.addTrack,
          ),
          const SizedBox(width: ResonaSpacing.sm),
          if (editor != null) ...[
            ToggleButtons(
              isSelected: [editor.tool == EditorTool.select, editor.tool == EditorTool.split],
              onPressed: (i) => notifier.setTool(i == 0 ? EditorTool.select : EditorTool.split),
              borderRadius: BorderRadius.circular(8),
              constraints: const BoxConstraints(minHeight: 32, minWidth: 36),
              children: const [
                Icon(Icons.near_me, size: 16),
                Icon(Icons.content_cut, size: 16),
              ],
            ),
            const SizedBox(width: ResonaSpacing.sm),
            if (editor.selectedClipId != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete clip',
                onPressed: () {
                  final trackId = editor.selectedTrackId;
                  final clipId = editor.selectedClipId;
                  if (trackId != null && clipId != null) notifier.deleteClip(trackId, clipId);
                },
              ),
            const Spacer(),
            Icon(Icons.zoom_out, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            SizedBox(
              width: 140,
              child: Slider(
                value: editor.pixelsPerSecond,
                min: TimelineGeometry.zoomSteps.first,
                max: TimelineGeometry.zoomSteps.last,
                onChanged: notifier.setZoom,
              ),
            ),
            Icon(Icons.zoom_in, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: ResonaSpacing.md),
            TextButton.icon(
              onPressed: editor.isSaving
                  ? null
                  : () async {
                      try {
                        await notifier.save();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('Project saved.')));
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("RESONA couldn't save this project.")),
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
          ] else
            const Spacer(),
        ],
      ),
    );
  }
}
