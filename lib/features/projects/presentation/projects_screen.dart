import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/resona_card.dart';
import '../../../core/widgets/resona_empty_state.dart';
import '../../../models/audio_project.dart';
import '../../editor/application/editor_project_provider.dart';
import '../../navigation/application/shell_tab_provider.dart';
import '../application/projects_provider.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  void _openInEditor(WidgetRef ref, AudioProject project) {
    ref.read(editorProjectProvider.notifier).openProject(project);
    ref.read(appShellTabIndexProvider.notifier).state = kEditorTabIndex;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final projectsAsync = ref.watch(recentProjectsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(ResonaSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Projects', style: theme.textTheme.headlineMedium),
            const SizedBox(height: ResonaSpacing.lg),
            Expanded(
              child: projectsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Couldn\'t load projects.', style: theme.textTheme.bodyMedium)),
                data: (projects) {
                  if (projects.isEmpty) {
                    return const ResonaEmptyState(
                      icon: Icons.folder_open_outlined,
                      title: 'No Projects',
                      message: 'Your audio projects will appear here.',
                      actionLabel: 'Create Project',
                    );
                  }
                  return ListView.separated(
                    itemCount: projects.length,
                    separatorBuilder: (_, __) => const SizedBox(height: ResonaSpacing.sm),
                    itemBuilder: (context, i) {
                      final p = projects[i];
                      return ResonaCard(
                        onTap: () => _openInEditor(ref, p),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name, style: theme.textTheme.titleMedium),
                                  Text(
                                    '${TimeFormat.format(p.duration)} · ${p.trackCount} tracks · modified '
                                    '${p.modifiedAt.toLocal().toString().split('.').first}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (action) async {
                                final repo = ref.read(projectRepositoryProvider);
                                if (action == 'open') {
                                  _openInEditor(ref, p);
                                } else if (action == 'rename') {
                                  final controller = TextEditingController(text: p.name);
                                  final newName = await showDialog<String>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Rename project'),
                                      content: TextField(controller: controller, autofocus: true),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, controller.text),
                                          child: const Text('Save'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (newName != null && newName.trim().isNotEmpty) {
                                    await repo.rename(p.id, newName.trim());
                                    ref.invalidate(recentProjectsProvider);
                                  }
                                } else if (action == 'delete') {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete project?'),
                                      content: Text('"${p.name}" will be permanently deleted.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    await repo.delete(p.id);
                                    ref.invalidate(recentProjectsProvider);
                                  }
                                } else if (action == 'duplicate') {
                                  final copy = p.copyWith(name: '${p.name} copy');
                                  await repo.save(copy);
                                  ref.invalidate(recentProjectsProvider);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(value: 'open', child: Text('Open')),
                                PopupMenuItem(value: 'rename', child: Text('Rename')),
                                PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                                PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
