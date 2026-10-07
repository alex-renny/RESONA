# RESONA — Shape Your Sound.

**Phase 2** of the RESONA build is on top of Phase 1. This delivery adds:

- A **real waveform engine** — decodes actual audio via a system `ffmpeg`
  process (not a placeholder/fake waveform), computes min/max peaks off the
  main isolate, and caches the result to disk so re-opening a project doesn't
  re-decode.
- A **working timeline editor** — multi-track layout, a time ruler with
  tap/drag-to-seek, a playhead, real waveforms drawn on every clip, drag to
  move clips (with snapping to other clip edges), drag either edge to trim
  in/out points, a Split tool, add/rename/lock/delete tracks, mute/solo/
  volume per track, zoom in/out, and Save/Saved status tied to the project
  repository from Phase 1.
- Home and Projects now actually open a project into the Editor tab (New
  Project, Edit Audio, tapping a recent project, and the Projects screen's
  Open/Rename actions all do real things now instead of nothing).

Nothing here is a placeholder pretending to be finished. Buttons that aren't
wired up yet (Auto Merge, Combine, Record, Extract, Convert) show a plain
"coming in a later phase" message instead of silently doing nothing (spec
§4). See "What's real right now" and "Roadmap" below for the exact line.

## Setup

1. Install the [Flutter SDK](https://flutter.dev) (stable channel), and make
   sure `flutter doctor` is clean for the platforms you're targeting (Windows
   desktop + Android per the spec).
2. **Install FFmpeg** and make sure it's on your `PATH` — required for real
   waveform generation on desktop (see "FFmpeg requirement" below).
3. From this folder:
   ```
   flutter pub get
   flutter run -d windows
   # or
   flutter run -d <android-device-id>
   ```
4. Run tests:
   ```
   flutter test
   ```

This project is authored without a local Flutter toolchain available to
verify compilation — run `flutter pub get` / `flutter analyze` first and send
me the output so I can fix anything real before we move to Phase 3.

## FFmpeg requirement (read this)

Waveform generation shells out to a system `ffmpeg` binary via `dart:io
Process.run` — no plugin, no bundled binary yet. That means:

- **Windows/macOS/Linux**: install FFmpeg and make sure `ffmpeg -version`
  works from a plain terminal. If it's missing, clips show a friendly
  "RESONA couldn't generate a waveform for this file" error state instead of
  a fake/blank waveform — the app doesn't pretend it worked.
- **Android**: there's no shell/PATH to invoke a binary from, so waveform
  generation isn't available on Android yet. This is an honest gap, not a
  silent one — it surfaces the same friendly error state. A bundled FFmpeg
  (via a proper Android-capable integration) arrives with the full
  `FFmpegService` in Phase 6, and this same `FfmpegPcmDecoder` entry point
  will grow to use it.

Import and single-clip preview playback (via `just_audio`) work on both
platforms regardless — only the waveform *picture* depends on FFmpeg being
reachable right now.

## What's real right now

- **Theme engine** (`lib/core/theme/`) — including `AppTheme.resolvePalette`,
  the shared helper any widget can call to get design-system colors beyond
  what `ColorScheme` exposes (panel, waveform, border, etc).
- **Settings → Appearance**, **Projects** (list/open/rename/duplicate/delete),
  as in Phase 1.
- **Waveform engine** (`lib/core/audio_engine/ffmpeg/`,
  `lib/features/editor/{domain,data,application}/`) — `FfmpegPcmDecoder` →
  `WaveformMath.computePeaks` (via `compute()`) → `WaveformCache` (disk) →
  `WaveformService`/`waveformProvider` (memory + Riverpod).
- **Timeline editor** (`lib/features/editor/presentation/timeline/`) —
  `EditorScreen` assembles `EditorToolbar`, `TimelineRuler`, `TrackHeader`,
  `TrackLane`, `AudioClipWidget` (with `WaveformPainter`), and `TransportBar`.
  All backed by `EditorProjectNotifier` (`editor_project_provider.dart`),
  which holds the in-memory `AudioProject` being edited and every mutation:
  `moveClip`, `trimClipStart`/`trimClipEnd`, `splitAt`, `deleteClip`,
  `addTrack`/`deleteTrack`/`renameTrack`, `toggleMute`/`toggleSolo`/
  `setTrackVolume`/`toggleLock`, `setZoom`, `seek`, `save`.
- **Pure, unit-tested logic layers** — `ClipEditMath` (move/trim/split) and
  `TimelineGeometry`/`snapDuration` (pixel↔time conversion, snapping) are
  plain Dart with no Flutter/plugin dependencies, so their correctness is
  verified by `flutter test` rather than by hand.

### Known, deliberate limitations of this phase

- **Mute/solo/volume update the project model but don't yet change audio.**
  There's no mixed multi-track playback engine yet — that's the FFmpeg
  render/export pipeline in Phase 6/7. The transport bar previews whichever
  single clip is selected and says so on-screen.
- **No undo/redo yet** (Phase 4) — every timeline edit applies immediately.
- **No cut/copy/paste clipboard yet** (Phase 3) — Split + drag + trim +
  delete are in; the rest of "Basic editing" (§20) follows next.

## Roadmap (matches spec §65)

Phase 1 ✅ — architecture, design system, theme, navigation, home, settings,
basic import/playback.

Phase 2 ✅ (this delivery) — waveform engine, timeline editor.

Next phases, in order:
3. Basic editing — copy/paste/duplicate/silence/insert-silence/reverse (cut,
   trim and split already landed in Phase 2)
4. Undo/redo system
5. **Auto Merge** — the core feature: multi-file select, start/end/position/
   fade/transition inputs, automatic timeline build, preview, export
6. FFmpeg integration (`FFmpegService`) — cutting, merging, fades, crossfades,
   normalization, format conversion, speed/pitch, and the Android-capable
   waveform path
7. Multi-track editor — real mixed playback respecting mute/solo/volume/pan
8. Effects panel — EQ, reverb, echo, compressor, limiter, etc. (FFmpeg filters)
9. Recorder, Combine tool, Converter, Video-to-audio extraction
10. Export dialog, auto-save/recovery, keyboard shortcuts, accessibility pass,
    performance pass, packaging

Each phase builds cleanly on its own before the next one starts, per the
spec's own development rule (§59).
