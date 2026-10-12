import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/resona_card.dart';
import '../../auto_merge/presentation/auto_merge_screen.dart';
import '../../editor/application/editor_project_provider.dart';
import '../../navigation/application/shell_tab_provider.dart';
import '../../projects/application/projects_provider.dart';
import '../../settings/application/settings_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final projectsAsync = ref.watch(recentProjectsProvider);
    final recentCount = ref.watch(settingsProvider).recentProjectsCount;
    final wide = MediaQuery.sizeOf(context).width >= 700;

    void openEditor({bool createProject = false}) {
      if (createProject) ref.read(editorProjectProvider.notifier).newProject();
      ref.read(appShellTabIndexProvider.notifier).state = kEditorTabIndex;
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ResonaSpacing.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RESONA', style: theme.textTheme.displaySmall),
                Text(
                  'Shape Your Sound.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: ResonaSpacing.xl),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: wide ? 3 : 1,
                  mainAxisSpacing: ResonaSpacing.md,
                  crossAxisSpacing: ResonaSpacing.md,
                  childAspectRatio: wide ? 2.1 : 3.2,
                  children: [
                    _HomeAction(
                      icon: Icons.merge_type,
                      title: 'Auto Merge',
                      subtitle: 'Arrange clips and build one audio file',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AutoMergeScreen(),
                        ),
                      ),
                    ),
                    _HomeAction(
                      icon: Icons.add_box_outlined,
                      title: 'New Project',
                      subtitle: 'Start editing audio on a timeline',
                      onTap: () => openEditor(createProject: true),
                    ),
                    _HomeAction(
                      icon: Icons.graphic_eq,
                      title: 'Edit Audio',
                      subtitle: 'Open the audio editor',
                      onTap: () => openEditor(),
                    ),
                  ],
                ),
                const SizedBox(height: ResonaSpacing.xl),
                Text('Recent Projects', style: theme.textTheme.titleLarge),
                const SizedBox(height: ResonaSpacing.md),
                projectsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: ResonaSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text(
                    'Couldn’t load recent projects.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  data: (projects) {
                    if (projects.isEmpty) {
                      return ResonaCard(
                        child: Row(
                          children: [
                            Icon(Icons.folder_open_outlined,
                                color: theme.colorScheme.primary),
                            const SizedBox(width: ResonaSpacing.md),
                            const Expanded(child: Text('Your projects will appear here.')),
                            TextButton(
                              onPressed: () => openEditor(createProject: true),
                              child: const Text('Create Project'),
                            ),
                          ],
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final project in projects.take(recentCount))
                          Padding(
                            padding: const EdgeInsets.only(
                                bottom: ResonaSpacing.sm),
                            child: ResonaCard(
                              onTap: () {
                                ref
                                    .read(editorProjectProvider.notifier)
                                    .openProject(project);
                                ref
                                    .read(appShellTabIndexProvider.notifier)
                                    .state = kEditorTabIndex;
                              },
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.graphic_eq,
                                        color: theme.colorScheme.primary,
                                        size: 20),
                                  ),
                                  const SizedBox(width: ResonaSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(project.name,
                                            style: theme.textTheme.titleMedium),
                                        Text(
                                          '${TimeFormat.format(project.duration)} · ${project.trackCount} track${project.trackCount == 1 ? '' : 's'}',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ResonaCard(
      onTap: onTap,
      padding: const EdgeInsets.all(ResonaSpacing.lg),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 30),
          const SizedBox(width: ResonaSpacing.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: ResonaSpacing.xs),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    )),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
