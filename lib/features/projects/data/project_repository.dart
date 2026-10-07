import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../models/audio_project.dart';

/// Persists AudioProjects as JSON strings inside a Hive box. Projects are
/// saved separately from exported audio (spec section 32) — this box only
/// ever holds project *metadata + structure*, never raw audio bytes.
class ProjectRepository {
  static const _boxName = 'resona_projects';

  Future<Box<String>> _box() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return Hive.openBox<String>(_boxName);
    }
    return Hive.box<String>(_boxName);
  }

  Future<void> save(AudioProject project) async {
    final box = await _box();
    await box.put(project.id, jsonEncode(project.toJson()));
  }

  Future<List<AudioProject>> listAll() async {
    final box = await _box();
    final projects = box.values
        .map((raw) {
          try {
            return AudioProject.fromJson(jsonDecode(raw) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<AudioProject>()
        .toList();
    projects.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return projects;
  }

  Future<AudioProject?> load(String id) async {
    final box = await _box();
    final raw = box.get(id);
    if (raw == null) return null;
    return AudioProject.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    final box = await _box();
    await box.delete(id);
  }

  Future<void> rename(String id, String newName) async {
    final project = await load(id);
    if (project == null) return;
    await save(project.copyWith(name: newName, modifiedAt: DateTime.now()));
  }
}
