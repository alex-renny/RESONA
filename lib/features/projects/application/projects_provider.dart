import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/audio_project.dart';
import '../data/project_repository.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) => ProjectRepository());

/// Async list of saved projects, newest-modified first. Home + Projects
/// screens both watch this; call `ref.invalidate(recentProjectsProvider)`
/// after save/delete/rename to refresh.
final recentProjectsProvider = FutureProvider<List<AudioProject>>((ref) async {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.listAll();
});
