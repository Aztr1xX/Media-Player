# Take

A modern media player for reviewing clips and audio before you edit them.
Plays almost anything (libmpv + FFmpeg), with frame-accurate tools for creators.

Status: **Phase 0 / early Phase 1**. Windows first; also builds on Linux.

## What works now

- Plays video, audio and URLs (URLs need `yt-dlp` on PATH); hardware decoding where safe
- Drag and drop a file or folder; the folder becomes the queue, in natural order
- Frame step back and forward, exact seeks, SMPTE timecode and frame number
- J / K / L shuttle, speed 0.25× to 4× with pitch kept
- In / Out points, loop between them
- Markers with notes and three kinds (note, good take, mistake), saved automatically per file
- Exports: lossless clip (instant), frame-exact clip (re-encode), markers as EDL for DaVinci Resolve,
  CSV, YouTube chapters (checked against YouTube's rules), frame grab to PNG
- Resume where you left off; recent files
- Media inspector (codec, resolution, frame rate, colour, HDR, decoder)
- Command palette (Ctrl+K) and a shortcut sheet (?)

## Keyboard

| Key | Action |
| --- | --- |
| Space | Play / pause |
| , and . | Previous / next frame |
| ← → | Back / forward 5 s (Shift: 1 s) |
| J K L | Rewind / stop / play (press L again for faster) |
| I, O, X | Set In, set Out, clear both |
| M | Add marker; Ctrl+← / Ctrl+→ jump between markers |
| [ ] = | Slower / faster / normal speed |
| Ctrl+E | Export In→Out losslessly (Ctrl+Shift+E: frame-exact) |
| Ctrl+Shift+S | Save current frame as PNG |
| PgUp / PgDn | Previous / next file in the folder |
| H | Hide side panels; F or double-click: full screen |
| Ctrl+K | Search all actions |

## Build on Windows (all free)

The easy way: push to GitHub and download the `Take-windows-x64` artifact from the
**Windows build** action (see `.github/workflows/windows.yml`).

By hand:

1. Install Qt 6.8 LTS with the Qt Online Installer (open-source), selecting **MinGW 13.1 64-bit**
   and the matching **MinGW** tool.
2. Download `mpv-dev-lgpl-x86_64-*.7z` from <https://github.com/zhongfly/mpv-winbuild/releases>
   and unpack it to `deps\mpv`.
3. Download an FFmpeg build (e.g. `ffmpeg-master-latest-win64-gpl.zip` from
   <https://github.com/BtbN/FFmpeg-Builds/releases>) for clip export.
4. In a "Qt 6.8 MinGW" terminal:
   ```
   cmake -S . -B build -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release -DMPV_DIR=%CD%\deps\mpv
   cmake --build build --parallel
   ```
5. Put `libmpv-2.dll` and `ffmpeg.exe` next to `take.exe`, then run `windeployqt --qmldir qml take.exe`.

## Build on Linux

```
sudo apt install qt6-base-dev qt6-declarative-dev qml6-module-qtquick-controls qml6-module-qtquick-layouts \
  qml6-module-qtquick-dialogs qml6-module-qtquick-window qml6-module-qtqml-workerscript \
  qml6-module-qtquick-templates libmpv-dev ffmpeg cmake ninja-build
cmake -S . -B build -G Ninja && cmake --build build
./build/take_tests                       # unit tests
./build/take --selftest some-clip.mp4    # drives the real app through the review workflow
```

## How it is built

- `src/mpvobject.*`: the only code that talks to libmpv. Renders video into a Qt Quick item through
  mpv's OpenGL render API and exposes playback state as properties.
- `src/appcontroller.*`: queue, resume points, In/Out, exports (runs `ffmpeg` as a separate process).
- `src/markermodel.*`, `src/timecode.*`, `src/folderqueue.*`: pure logic, unit tested in `tests/`.
- `qml/`: the interface.

Troubleshooting: set `TAKE_MPV_LOG=1` to print mpv's log.

## Licences of parts

Qt (LGPL v3), libmpv LGPL build (LGPL v2.1+), FFmpeg executable (run as a separate program; the GPL
build is fine for that). Take's own licence is still to be chosen.
