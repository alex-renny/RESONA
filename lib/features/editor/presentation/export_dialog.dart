import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/audio_engine/ffmpeg/ffmpeg_availability.dart';
import '../../../../models/audio_project.dart';

// ─── Export configuration types ──────────────────────────────────────────────

enum _ExportFormat { mp3, wav, flac, m4a, aac, ogg }

extension _ExportFormatExt on _ExportFormat {
  String get label => name.toUpperCase();
  String get extension => name;
  bool get supportsBitrate =>
      this == _ExportFormat.mp3 ||
      this == _ExportFormat.aac ||
      this == _ExportFormat.ogg;
}

enum _ExportBitrate { k128, k192, k256, k320 }

extension _ExportBitrateExt on _ExportBitrate {
  String get label {
    switch (this) {
      case _ExportBitrate.k128:
        return '128 kbps';
      case _ExportBitrate.k192:
        return '192 kbps';
      case _ExportBitrate.k256:
        return '256 kbps';
      case _ExportBitrate.k320:
        return '320 kbps';
    }
  }

  String get ffmpegValue {
    switch (this) {
      case _ExportBitrate.k128:
        return '128k';
      case _ExportBitrate.k192:
        return '192k';
      case _ExportBitrate.k256:
        return '256k';
      case _ExportBitrate.k320:
        return '320k';
    }
  }
}

enum _SampleRate { hz22050, hz44100, hz48000 }

extension _SampleRateExt on _SampleRate {
  String get label {
    switch (this) {
      case _SampleRate.hz22050:
        return '22 050 Hz';
      case _SampleRate.hz44100:
        return '44 100 Hz';
      case _SampleRate.hz48000:
        return '48 000 Hz';
    }
  }

  int get value {
    switch (this) {
      case _SampleRate.hz22050:
        return 22050;
      case _SampleRate.hz44100:
        return 44100;
      case _SampleRate.hz48000:
        return 48000;
    }
  }
}

enum _Channels { stereo, mono }

extension _ChannelsExt on _Channels {
  String get label => name[0].toUpperCase() + name.substring(1);
  int get value => this == _Channels.stereo ? 2 : 1;
}

// ─── Export progress state ────────────────────────────────────────────────────

enum _ExportPhase { idle, preparing, processing, encoding, finalizing, done, error }

extension _ExportPhaseExt on _ExportPhase {
  String get label {
    switch (this) {
      case _ExportPhase.preparing:
        return 'Preparing…';
      case _ExportPhase.processing:
        return 'Processing tracks…';
      case _ExportPhase.encoding:
        return 'Encoding…';
      case _ExportPhase.finalizing:
        return 'Finalizing…';
      case _ExportPhase.done:
        return 'Export completed!';
      case _ExportPhase.error:
        return 'Export failed';
      case _ExportPhase.idle:
        return '';
    }
  }

  double get progress {
    switch (this) {
      case _ExportPhase.preparing:
        return 0.1;
      case _ExportPhase.processing:
        return 0.35;
      case _ExportPhase.encoding:
        return 0.70;
      case _ExportPhase.finalizing:
        return 0.90;
      case _ExportPhase.done:
        return 1.0;
      default:
        return 0.0;
    }
  }
}

// ─── Dialog ───────────────────────────────────────────────────────────────────

/// Professional export dialog driven by FFmpegService.
///
/// Called from [EditorToolbar]'s Export button. For now it exports the first
/// clip of the first track; full multi-track mixing arrives with the render
/// engine.
class ExportDialog extends ConsumerStatefulWidget {
  final AudioProject project;

  const ExportDialog({super.key, required this.project});

  static Future<void> show(BuildContext context, AudioProject project) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ExportDialog(project: project),
    );
  }

  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ExportDialog> {
  // ── Config ──────────────────────────────────────────────────────────────────
  _ExportFormat _format = _ExportFormat.mp3;
  _ExportBitrate _bitrate = _ExportBitrate.k320;
  _SampleRate _sampleRate = _SampleRate.hz44100;
  _Channels _channels = _Channels.stereo;
  late final TextEditingController _filenameCtrl;
  String _outputFolder = '';

  // ── Export state ────────────────────────────────────────────────────────────
  _ExportPhase _phase = _ExportPhase.idle;
  String? _errorMessage;
  String? _outputPath;

  @override
  void initState() {
    super.initState();
    _filenameCtrl = TextEditingController(
      text: _sanitize(widget.project.name),
    );
    _outputFolder = _defaultFolder();
  }

  @override
  void dispose() {
    _filenameCtrl.dispose();
    super.dispose();
  }

  String _sanitize(String name) =>
      name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();

  String _defaultFolder() {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'] ?? '';
      return '$userProfile\\Music';
    }
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      return '$home/Music';
    }
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Music';
  }

  bool get _isExporting =>
      _phase != _ExportPhase.idle &&
      _phase != _ExportPhase.done &&
      _phase != _ExportPhase.error;

  // ── UI helpers ──────────────────────────────────────────────────────────────

  Future<void> _chooseFolder() async {
    // Use xdg-open equivalent or simple dialog. On Windows/macOS we run a
    // process to pick a folder; if it fails we let the user type the path.
    try {
      if (Platform.isWindows) {
        final result = await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          r'Add-Type -AssemblyName System.Windows.Forms; '
              r'$d = New-Object System.Windows.Forms.FolderBrowserDialog; '
              r'$d.Description = "Choose export folder"; '
              r'if ($d.ShowDialog() -eq "OK") { $d.SelectedPath }',
        ]);
        final path = (result.stdout as String).trim();
        if (path.isNotEmpty) setState(() => _outputFolder = path);
      } else {
        // macOS / Linux: fall back to letting the user type the path.
        _showFolderInput();
      }
    } catch (_) {
      _showFolderInput();
    }
  }

  void _showFolderInput() {
    final ctrl = TextEditingController(text: _outputFolder);
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export folder'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('OK')),
        ],
      ),
    ).then((v) {
      if (v != null && v.trim().isNotEmpty) {
        setState(() => _outputFolder = v.trim());
      }
    });
  }

  Future<void> _startExport() async {
    // ── FFmpeg check ──────────────────────────────────────────────────────────
    final ffmpegAvailable = await FfmpegAvailability.check();
    if (!ffmpegAvailable) {
      setState(() {
        _phase = _ExportPhase.error;
        _errorMessage =
            'FFmpeg is required for export. Please install FFmpeg and restart RESONA.';
      });
      return;
    }

    // ── Resolve source clip ───────────────────────────────────────────────────
    final firstClip = widget.project.tracks
        .expand((t) => t.clips)
        .cast<AudioClip?>()
        .firstWhere((_) => true, orElse: () => null);

    if (firstClip == null) {
      setState(() {
        _phase = _ExportPhase.error;
        _errorMessage = 'This project has no audio clips to export.';
      });
      return;
    }

    final sep = Platform.isWindows ? '\\' : '/';
    final filename =
        '${_sanitize(_filenameCtrl.text.trim()).isEmpty ? 'export' : _sanitize(_filenameCtrl.text.trim())}.${_format.extension}';
    final outputPath = '$_outputFolder$sep$filename';

    // ── Build FFmpeg args ─────────────────────────────────────────────────────
    //
    // We re-encode the source file of the first clip with the user's chosen
    // settings. Trimming (startTime / endTime) is honoured via -ss / -to.
    // Multi-track mixing arrives with the render engine — an honest note is
    // shown in the UI.
    final args = <String>[
      '-y', // overwrite
      '-ss', _durToSeconds(firstClip.startTime),
      '-to', _durToSeconds(firstClip.endTime),
      '-i', firstClip.sourcePath,
      '-ar', _sampleRate.value.toString(),
      '-ac', _channels.value.toString(),
    ];

    if (_format.supportsBitrate) {
      args.addAll(['-b:a', _bitrate.ffmpegValue]);
    }

    if (_format == _ExportFormat.mp3) {
      args.addAll(['-codec:a', 'libmp3lame']);
    } else if (_format == _ExportFormat.flac) {
      args.addAll(['-codec:a', 'flac']);
    } else if (_format == _ExportFormat.wav) {
      args.addAll(['-codec:a', 'pcm_s16le']);
    } else if (_format == _ExportFormat.m4a) {
      args.addAll(['-codec:a', 'aac', '-f', 'ipod']);
    } else if (_format == _ExportFormat.aac) {
      args.addAll(['-codec:a', 'aac']);
    } else if (_format == _ExportFormat.ogg) {
      args.addAll(['-codec:a', 'libvorbis']);
    }

    args.add(outputPath);

    // ── Run ───────────────────────────────────────────────────────────────────
    setState(() => _phase = _ExportPhase.preparing);
    await _delay(400);

    setState(() => _phase = _ExportPhase.processing);
    await _delay(300);

    setState(() => _phase = _ExportPhase.encoding);

    ProcessResult result;
    try {
      result = await Process.run('ffmpeg', args);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _ExportPhase.error;
        _errorMessage = 'Could not launch FFmpeg: $e';
      });
      return;
    }

    if (!mounted) return;

    setState(() => _phase = _ExportPhase.finalizing);
    await _delay(300);

    if (!mounted) return;

    if (result.exitCode != 0) {
      setState(() {
        _phase = _ExportPhase.error;
        _errorMessage =
            'FFmpeg exited with code ${result.exitCode}:\n${result.stderr}';
      });
    } else {
      setState(() {
        _phase = _ExportPhase.done;
        _outputPath = outputPath;
      });
    }
  }

  Future<void> _delay(int ms) =>
      Future.delayed(Duration(milliseconds: ms));

  String _durToSeconds(Duration d) =>
      (d.inMilliseconds / 1000.0).toStringAsFixed(3);

  Future<void> _openFile(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', ['/select,', path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else {
        await Process.run('xdg-open', [path]);
      }
    } catch (_) {}
  }

  Future<void> _openFolder(String path) async {
    final folder = File(path).parent.path;
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', [folder]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [folder]);
      } else {
        await Process.run('xdg-open', [folder]);
      }
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────────────
              Row(
                children: [
                  Icon(Icons.upload_file_outlined, color: cs.primary),
                  const SizedBox(width: 10),
                  Text('Export Audio',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isExporting
                        ? null
                        : () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const Divider(height: 24),

              if (_phase == _ExportPhase.idle ||
                  _phase == _ExportPhase.error) ...[
                _buildForm(theme, cs),
              ] else if (_phase == _ExportPhase.done) ...[
                _buildSuccess(theme, cs),
              ] else ...[
                _buildProgress(theme, cs),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Form ─────────────────────────────────────────────────────────────────────

  Widget _buildForm(ThemeData theme, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Honest scope note
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: cs.secondaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline,
                  size: 16, color: cs.onSecondaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Exports the first available clip. '
                  'Multi-track mixing arrives with the render engine.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Format
        _label('Format', theme),
        const SizedBox(height: 6),
        _dropdown<_ExportFormat>(
          value: _format,
          items: _ExportFormat.values,
          labelOf: (f) => f.label,
          onChanged: (f) => setState(() => _format = f),
        ),
        const SizedBox(height: 14),

        // Bitrate (only when relevant)
        if (_format.supportsBitrate) ...[
          _label('Bitrate', theme),
          const SizedBox(height: 6),
          _dropdown<_ExportBitrate>(
            value: _bitrate,
            items: _ExportBitrate.values,
            labelOf: (b) => b.label,
            onChanged: (b) => setState(() => _bitrate = b),
          ),
          const SizedBox(height: 14),
        ],

        // Sample rate
        _label('Sample Rate', theme),
        const SizedBox(height: 6),
        _dropdown<_SampleRate>(
          value: _sampleRate,
          items: _SampleRate.values,
          labelOf: (r) => r.label,
          onChanged: (r) => setState(() => _sampleRate = r),
        ),
        const SizedBox(height: 14),

        // Channels
        _label('Channels', theme),
        const SizedBox(height: 6),
        _dropdown<_Channels>(
          value: _channels,
          items: _Channels.values,
          labelOf: (c) => c.label,
          onChanged: (c) => setState(() => _channels = c),
        ),
        const SizedBox(height: 14),

        // Filename
        _label('Filename', theme),
        const SizedBox(height: 6),
        TextField(
          controller: _filenameCtrl,
          decoration: InputDecoration(
            suffixText: '.${_format.extension}',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 14),

        // Output folder
        _label('Location', theme),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                _outputFolder.isEmpty ? 'No folder selected' : _outputFolder,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _outputFolder.isEmpty
                      ? cs.error
                      : cs.onSurface.withValues(alpha: 0.8),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _chooseFolder,
              child: const Text('Choose…'),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Error banner
        if (_phase == _ExportPhase.error && _errorMessage != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _errorMessage!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onErrorContainer),
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed:
                  _outputFolder.isEmpty ? null : _startExport,
              icon: const Icon(Icons.upload_outlined, size: 18),
              label: Text(
                _phase == _ExportPhase.error ? 'Retry' : 'Export',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Progress ─────────────────────────────────────────────────────────────────

  Widget _buildProgress(ThemeData theme, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Text(
          _phase.label,
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _phase.progress,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Please wait while RESONA processes your audio…',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Success ───────────────────────────────────────────────────────────────────

  Widget _buildSuccess(ThemeData theme, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Icon(Icons.check_circle_outline, color: cs.primary, size: 48),
        const SizedBox(height: 12),
        Text(
          'Export completed!',
          style:
              theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        if (_outputPath != null) ...[
          const SizedBox(height: 6),
          Text(
            _outputPath!,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _outputPath != null
                    ? () => _openFolder(_outputPath!)
                    : null,
                icon: const Icon(Icons.folder_open_outlined, size: 18),
                label: const Text('Open Folder'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _outputPath != null
                    ? () => _openFile(_outputPath!)
                    : null,
                icon: const Icon(Icons.play_circle_outline, size: 18),
                label: const Text('Open File'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────────

  Widget _label(String text, ThemeData theme) => Text(
        text,
        style: theme.textTheme.labelMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      );

  Widget _dropdown<T>({
    required T value,
    required List<T> items,
    required String Function(T) labelOf,
    required ValueChanged<T> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isDense: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(labelOf(e))))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
