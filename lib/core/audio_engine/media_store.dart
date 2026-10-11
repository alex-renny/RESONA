import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Keeps imported and rendered audio inside the app documents folder so
/// Android cache/picker paths do not vanish after a reboot.
class MediaStore {
  static Future<Directory> _dir(String name) async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, name));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory> importsDir() => _dir('resona_media');
  static Future<Directory> exportsDir() => _dir('resona_exports');
  static Future<Directory> recordingsDir() => _dir('resona_recordings');

  static String sanitizeFileName(String name) {
    final trimmed = name.trim().isEmpty ? 'audio' : name.trim();
    return trimmed.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }

  static Future<String> persistCopy(String sourcePath, {String? preferredName}) async {
    final source = File(sourcePath);
    if (!await source.exists()) return sourcePath;

    final dir = await importsDir();
    if (p.isWithin(dir.path, sourcePath) || p.equals(dir.path, p.dirname(sourcePath))) {
      return sourcePath;
    }

    final base = sanitizeFileName(preferredName ?? p.basename(sourcePath));
    final destPath = p.join(
      dir.path,
      '${DateTime.now().millisecondsSinceEpoch}_$base',
    );
    await source.copy(destPath);
    return destPath;
  }

  static Future<String> exportPath(String fileName) async {
    final dir = await exportsDir();
    return p.join(dir.path, sanitizeFileName(fileName));
  }
}
