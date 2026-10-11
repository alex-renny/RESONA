/// Shared encode flags for export, convert, extract, and auto-merge.
class AudioEncodeOptions {
  final String format;
  final int bitrateKbps;
  final int sampleRate;
  final int channels;

  const AudioEncodeOptions({
    required this.format,
    this.bitrateKbps = 320,
    this.sampleRate = 44100,
    this.channels = 2,
  });

  String get extension => format.toLowerCase();

  bool get supportsBitrate =>
      extension == 'mp3' || extension == 'aac' || extension == 'ogg' || extension == 'm4a';

  String get mimeType => switch (extension) {
        'mp3' => 'audio/mpeg',
        'wav' => 'audio/wav',
        'flac' => 'audio/flac',
        'm4a' => 'audio/mp4',
        'aac' => 'audio/aac',
        'ogg' => 'audio/ogg',
        _ => 'application/octet-stream',
      };

  /// Codec/container arguments inserted before the output path.
  List<String> toArguments() {
    final args = <String>[
      '-ar', '$sampleRate',
      '-ac', '$channels',
    ];
    switch (extension) {
      case 'mp3':
        args.addAll(['-codec:a', 'libmp3lame', '-b:a', '${bitrateKbps}k']);
      case 'wav':
        args.addAll(['-codec:a', 'pcm_s16le']);
      case 'flac':
        args.addAll(['-codec:a', 'flac']);
      case 'm4a':
        args.addAll(['-codec:a', 'aac', '-b:a', '${bitrateKbps}k', '-f', 'ipod']);
      case 'aac':
        args.addAll(['-codec:a', 'aac', '-b:a', '${bitrateKbps}k']);
      case 'ogg':
        args.addAll(['-codec:a', 'libvorbis', '-b:a', '${bitrateKbps}k']);
      default:
        args.addAll(['-codec:a', 'libmp3lame', '-b:a', '${bitrateKbps}k']);
    }
    return args;
  }
}
