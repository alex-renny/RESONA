import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which sidebar/bottom-nav tab is active. Other screens (Projects → Open,
/// Home → Edit Audio / New Project / a recent project) write to this so
/// they can jump straight into the Editor tab after opening a project,
/// without needing to import the [AppShell] widget itself.
final appShellTabIndexProvider = StateProvider<int>((ref) => 0);

const int kHomeTabIndex = 0;
const int kProjectsTabIndex = 1;
const int kEditorTabIndex = 2;
const int kToolsTabIndex = 3;
const int kSettingsTabIndex = 4;
