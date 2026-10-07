import 'package:flutter/material.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/resona_card.dart';
import '../../auto_merge/presentation/auto_merge_screen.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  void _comingSoon(BuildContext context, String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$featureName is coming in a later update.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = MediaQuery.of(context).size.width >= 700;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ResonaSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tools', style: theme.textTheme.headlineMedium),
              const SizedBox(height: ResonaSpacing.xs),
              Text(
                'Automated processing, audio conversion, recording, and extraction.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: ResonaSpacing.xxl),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: wide ? 2 : 1,
                mainAxisSpacing: ResonaSpacing.md,
                crossAxisSpacing: ResonaSpacing.md,
                childAspectRatio: wide ? 2.8 : 2.5,
                children: [
                  _ToolCard(
                    icon: Icons.merge_type,
                    title: 'Auto Merge',
                    subtitle: 'Combine clips automatically with fades, transitions, and timestamp extraction.',
                    isAvailable: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AutoMergeScreen()),
                      );
                    },
                  ),
                  _ToolCard(
                    icon: Icons.call_merge,
                    title: 'Combine Audio',
                    subtitle: 'Quickly join multiple audio files end-to-end with custom gaps.',
                    isAvailable: false,
                    onTap: () => _comingSoon(context, 'Combine Audio'),
                  ),
                  _ToolCard(
                    icon: Icons.transform,
                    title: 'Convert Audio',
                    subtitle: 'Convert between MP3, WAV, FLAC, AAC, M4A, OGG, and OPUS formats.',
                    isAvailable: false,
                    onTap: () => _comingSoon(context, 'Convert Audio'),
                  ),
                  _ToolCard(
                    icon: Icons.audiotrack,
                    title: 'Extract Audio',
                    subtitle: 'Extract audio tracks from video files into high-quality audio formats.',
                    isAvailable: false,
                    onTap: () => _comingSoon(context, 'Extract Audio'),
                  ),
                  _ToolCard(
                    icon: Icons.mic_none,
                    title: 'Record Audio',
                    subtitle: 'High-quality microphone recording with live waveform display.',
                    isAvailable: false,
                    onTap: () => _comingSoon(context, 'Record Audio'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isAvailable;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isAvailable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return ResonaCard(
      onTap: onTap,
      padding: const EdgeInsets.all(ResonaSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isAvailable ? 0.12 : 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isAvailable ? accent : theme.colorScheme.onSurface.withValues(alpha: 0.4),
              size: 24,
            ),
          ),
          const SizedBox(width: ResonaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    if (!isAvailable) ...[
                      const SizedBox(width: ResonaSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Soon',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: theme.colorScheme.onSurface.withValues(alpha: isAvailable ? 0.6 : 0.2),
          ),
        ],
      ),
    );
  }
}
