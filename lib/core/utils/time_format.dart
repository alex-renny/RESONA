class TimeFormat {
  /// Formats a duration as MM:SS, or HH:MM:SS once it reaches an hour.
  static String format(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Parses "MM:SS" or "HH:MM:SS" into a Duration. Returns null on invalid
  /// input rather than silently coercing it (spec section 12: never
  /// silently modify the user's requested value).
  static Duration? parse(String input) {
    final parts = input.trim().split(':');
    if (parts.length < 2 || parts.length > 3) return null;
    final nums = <int>[];
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n < 0) return null;
      nums.add(n);
    }
    if (parts.length == 2) {
      final [m, s] = nums;
      if (s >= 60) return null;
      return Duration(minutes: m, seconds: s);
    } else {
      final [h, m, s] = nums;
      if (m >= 60 || s >= 60) return null;
      return Duration(hours: h, minutes: m, seconds: s);
    }
  }
}
