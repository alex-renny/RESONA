import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/resona_card.dart';
import '../../../core/widgets/resona_empty_state.dart';
import '../../auto_merge/presentation/auto_merge_screen.dart';
import '../../editor/application/editor_project_provider.dart';
import '../../navigation/application/shell_tab_provider.dart';
import '../../projects/application/projects_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final projectsAsync = ref.watch(recentProjectsProvider);
    final wide = MediaQuery.of(context).size.width >= 700;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ResonaSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RESONA', style: theme.textTheme.displaySmall),
            Text('Shape Your Sound.',
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: ResonaSpacing.xxl),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: wide ? 4 : 2,
              mainAxisSpacing: ResonaSpacing.md,
              crossAxisSpacing: ResonaSpacing.md,
              childAspectRatio: 1.6,
              children: [
                _ActionTile(
                  icon: Icons.merge_type,
                  label: 'Auto Merge',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AutoMergeScreen()),
                    );
                  },
                ),
                _ActionTile(
                  icon: Icons.add_box_outlined,
                  label: 'New Project',
                  onTap: () {
                    ref.read(editorProjectProvider.notifier).newProject();
                    ref.read(appShellTabIndexProvider.notifier).state = kEditorTabIndex;
                  },
                ),
                _ActionTile(
                  icon: Icons.call_merge,
                  label: 'Combine Audio',
                  onTap: () => _comingSoon(context, 'Combine Audio'),
                ),
                _ActionTile(
                  icon: Icons.graphic_eq,
                  label: 'Edit Audio',
                  onTap: () => ref.read(appShellTabIndexProvider.notifier).state = kEditorTabIndex,
                ),
                _ActionTile(
                  icon: Icons.mic_none,
                  label: 'Record Audio',
                  onTap: () => _comingSoon(context, 'Record Audio'),
                ),
                _ActionTile(
                  icon: Icons.audiotrack,
                  label: 'Extract Audio',
                  onTap: () => _comingSoon(context, 'Extract Audio'),
                ),
                _ActionTile(
                  icon: Icons.transform,
                  label: 'Convert Audio',
                  onTap: () => _comingSoon(context, 'Convert Audio'),
                ),
              ],
            ),
            const SizedBox(height: ResonaSpacing.xxl),
            Text('Recent Projects', style: theme.textTheme.titleLarge),
            const SizedBox(height: ResonaSpacing.md),
            projectsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: ResonaSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Couldn\'t load recent projects.', style: theme.textTheme.bodyMedium),
              data: (projects) {
                if (projects.isEmpty) {
                  return const ResonaEmptyState(
                    icon: Icons.folder_open_outlined,
                    title: 'No Projects',
                    message: 'Your audio projects will appear here.',
                    actionLabel: 'Create Project',
                  );
                }
                return Column(
                  children: [
                    for (final p in projects.take(6))
                      Padding(
                        padding: const EdgeInsets.only(bottom: ResonaSpacing.sm),
                        child: ResonaCard(
                          onTap: () {
                            ref.read(editorProjectProvider.notifier).openProject(p);
                            ref.read(appShellTabIndexProvider.notifier).state = kEditorTabIndex;
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.graphic_eq, color: theme.colorScheme.primary, size: 20),
                              ),
                              const SizedBox(width: ResonaSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.name, style: theme.textTheme.titleMedium),
                                    Text(
                                      '${TimeFormat.format(p.duration)} · ${p.trackCount} track${p.trackCount == 1 ? '' : 's'}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
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
    );
  }
}

/// A brief, honest acknowledgement for actions that aren't built yet, rather
/// than a button that silently does nothing (spec section 4: every visible
/// major feature should either work or clearly indicate it's under
/// development).
void _comingSoon(BuildContext context, String feature) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$feature is coming in a later phase.')),
  );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ResonaCard(
      onTap: onTap,
      padding: const EdgeInsets.all(ResonaSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          Text(label, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}
