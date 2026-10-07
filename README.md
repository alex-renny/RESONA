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
