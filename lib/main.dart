import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'features/navigation/presentation/app_shell.dart';
import 'features/settings/application/settings_provider.dart';
import 'features/settings/domain/app_settings.dart';
import 'core/theme/dimensions.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  runApp(const ProviderScope(child: ResonaApp()));
}

class ResonaApp extends ConsumerWidget {
  const ResonaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final platformBrightness = MediaQuery.platformBrightnessOf(context);

    final resolvedBrightness = AppTheme.resolveBrightness(settings.themeMode, platformBrightness);
    final palette = AppTheme.resolvePalette(settings.themeMode, platformBrightness,
        highContrast: settings.highContrast);

    return MaterialApp(
      title: 'RESONA',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const ResonaScrollBehavior(),
      theme: AppTheme.build(
        palette: palette,
        accent: settings.accent,
        dimensions: settings.dimensions,
        fontScale: settings.fontScale,
        brightness: resolvedBrightness,
        largeTouchTargets: settings.largeTouchTargets,
      ),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            disableAnimations: settings.animationLevel != AnimationLevel.full,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AppShell(),
    );
  }
}
