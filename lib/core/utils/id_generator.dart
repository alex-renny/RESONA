import 'dart:math';

/// Generates short, unique-enough IDs for projects/tracks/clips without
/// pulling in a uuid dependency. Not cryptographically random — fine for
/// local-only identifiers that never leave the device.
class IdGenerator {
  static final Random _random = Random();

  static String next() {
    final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final rand = _random.nextInt(1 << 32).toRadixString(36);
    return '$time$rand';
  }
}
