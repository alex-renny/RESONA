import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'features/navigation/presentation/app_shell.dart';
import 'features/settings/application/settings_provider.dart';

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
    final palette = AppTheme.resolvePalette(settings.themeMode, platformBrightness);

    return MaterialApp(
      title: 'RESONA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(
        palette: palette,
        accent: settings.accent,
        dimensions: settings.dimensions,
        fontScale: settings.fontScale,
        brightness: resolvedBrightness,
      ),
      home: const AppShell(),
    );
  }
}
