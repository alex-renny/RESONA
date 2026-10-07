import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../domain/waveform_data.dart';

/// Disk cache for computed waveform peak tables, keyed by source file path +
/// size + modified time so a changed file on disk invalidates automatically
/// (spec section 18: "Cache waveform information where appropriate for
/// performance"). Stored as a compact custom binary format rather than JSON
/// to keep re-opening a project with many clips fast.
class WaveformCache {
  static const _magic = 0x52534E57; // 'RSNW'

  Future<Directory> _cacheDir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/waveform_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> _keyFor(String sourcePath) async {
    final file = File(sourcePath);
    var size = 0;
    var modifiedMs = 0;
    if (await file.exists()) {
      final stat = await file.stat();
      size = stat.size;
      modifiedMs = stat.modified.millisecondsSinceEpoch;
    }
    return _fnv1a('$sourcePath|$size|$modifiedMs');
  }

  static String _fnv1a(String input) {
    var hash = 0x811c9dc5;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  Future<WaveformData?> read(String sourcePath) async {
    try {
      final dir = await _cacheDir();
      final key = await _keyFor(sourcePath);
      final file = File('${dir.path}/$key.rwc');
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      if (bytes.length < 12) return null;
      final data = ByteData.sublistView(bytes);
      if (data.getUint32(0, Endian.little) != _magic) return null;

      final durationMs = data.getUint32(4, Endian.little);
      final count = data.getUint32(8, Endian.little);
      final expectedLength = 12 + count * 4 * 2;
      if (bytes.length < expectedLength) return null;

      final mins = Float32List(count);
      final maxs = Float32List(count);
      var offset = 12;
      for (var i = 0; i < count; i++) {
        mins[i] = data.getFloat32(offset, Endian.little);
        offset += 4;
      }
      for (var i = 0; i < count; i++) {
        maxs[i] = data.getFloat32(offset, Endian.little);
        offset += 4;
      }
      return WaveformData(peaksMin: mins, peaksMax: maxs, duration: Duration(milliseconds: durationMs));
    } catch (_) {
      return null; // A corrupt/partial cache entry just triggers regeneration.
    }
  }

  Future<void> write(String sourcePath, WaveformData waveform) async {
    try {
      final dir = await _cacheDir();
      final key = await _keyFor(sourcePath);
      final file = File('${dir.path}/$key.rwc');

      final count = waveform.peaksMin.length;
      final bytes = ByteData(12 + count * 4 * 2);
      bytes.setUint32(0, _magic, Endian.little);
      bytes.setUint32(4, waveform.duration.inMilliseconds, Endian.little);
      bytes.setUint32(8, count, Endian.little);
      var offset = 12;
      for (var i = 0; i < count; i++) {
        bytes.setFloat32(offset, waveform.peaksMin[i], Endian.little);
        offset += 4;
      }
      for (var i = 0; i < count; i++) {
        bytes.setFloat32(offset, waveform.peaksMax[i], Endian.little);
        offset += 4;
      }
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    } catch (_) {
      // Best-effort cache — a failed write just means the next open regenerates.
    }
  }

  /// Wired up to Settings → Storage → Clear cache once that screen lands.
  Future<void> clear() async {
    try {
      final dir = await _cacheDir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Ignore — worst case, stale cache entries just linger on disk.
    }
  }
}
