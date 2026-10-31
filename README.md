# Slate

A fast media player for reviewing clips before you edit them. Plays almost anything (libmpv + FFmpeg),
and adds the tools a YouTube editor actually uses: frame stepping, markers that go straight into
DaVinci Resolve, a waveform timeline, silence skipping, star ratings and an offline transcript.

## Install on Windows

1. Open the repo's **Releases** page and download `Slate-Setup-1.0.0.exe` from **Slate (latest build)**.
   (Every push to `main` rebuilds it. The same files are also attached to each run of the
   **Windows build** action as `Slate-installer`.)
2. Run it. SmartScreen warns because the app isn't code-signed: choose **More info → Run anyway**.
   Pick **Install for me only** (no admin needed) or for all users.
3. Leave **Make Slate my default video player** ticked on the last page. Windows Settings opens on
   Slate's page: press **Set default** at the top (Windows 11), or pick Slate for each file type you want.

You can do step 3 any time from Slate: **Settings → Windows → Open Default apps**.

The installer also adds:

- Start menu entry (and a desktop shortcut if you tick it), and an uninstaller in Settings → Apps
- **Open with → Slate** for video and audio files
- **Review folder in Slate** on the folder right-click menu (Windows 11: under "Show more options")
- `ffmpeg`, `ffprobe`, `whisper-cli` (transcription) and `yt-dlp` (URLs), so nothing else needs installing

A portable zip (`Slate-portable.zip`) is published next to the installer if you'd rather not install.

Opening another file from Explorer while Slate is open reuses the same window
(turn that off in Settings → General).

## What it does

- **Plays** video, audio and URLs, with hardware decoding where it's reliable. Drop a file or folder;
  the folder becomes the clip list, in natural order (clip 2 before clip 10).
- **Timeline** with the audio waveform, In/Out range, markers and a hover preview of the frame.
  Ctrl+wheel zooms around the pointer; double-click resets.
- **Frame accurate**: step frames both ways, SMPTE timecode and frame number, exact seeks on release.
- **Markers** in three kinds (Note, Good take, Mistake) with notes, saved automatically per file.
- **Exports**: In→Out clip losslessly (instant) or frame-exact (re-encode), markers as an EDL for
  Resolve, CSV, YouTube chapters (checked against YouTube's rules), the current frame as PNG.
  Exports go next to the clip, or to a folder you choose in Settings → Exports.
- **Clips panel**: thumbnails, durations and 1–5 star ratings, with a rating filter.
  Right-click a clip to compare it side by side with the current one.
- **Media info**: codec, resolution, real frame rate (flags variable frame rate, which causes
  audio drift in editors), colour and HDR, bitrate, and loudness in LUFS against YouTube's −14 LUFS.
- **Scopes**: luma waveform, RGB parade, histogram and vectorscope.
- **Transcript**: runs on your computer with whisper.cpp (downloads a speech model the first time).
  Click a line to jump there, search it, save as SRT subtitles or text.
- **Skip silences** while playing (Ctrl+Shift+K), J/K/L shuttle, 0.25× to 4× with pitch kept.
- **Command palette** (Ctrl+K) for every action, and fully remappable shortcuts (Settings → Shortcuts).

## Keyboard (defaults)

| Key | Action |
| --- | --- |
| Space | Play / pause |
| , and . | Previous / next frame |
| ← → | Back / forward 5 s (Shift: 1 s) |
| J K L | Rewind / stop / play (press L again for faster) |
| I, O, X | Set In, set Out, clear both; Ctrl+L loops between them |
| M | Add marker; Ctrl+← / Ctrl+→ jump between markers |
| 1–5, 0 | Rate the clip, clear the rating |
| [ ] = | Slower / faster / normal speed |
| Ctrl+E | Export In→Out losslessly (Ctrl+Shift+E: frame-exact) |
| Ctrl+Shift+S | Save current frame as PNG |
| PgUp / PgDn | Previous / next clip in the folder |
| Ctrl+= / Ctrl+- / Ctrl+0 | Zoom the timeline in / out / show all |
| Alt+1…5 | Markers, clips, info, transcript, scopes |
| H | Hide the side panel; F or double-click: full screen |
| Ctrl+K | Search all actions; Ctrl+, opens Settings |

## Using markers in DaVinci Resolve

Choose **Export → Markers for DaVinci Resolve (EDL)**. In Resolve, open the clip's timeline, right-click
it in the Media Pool and choose **Timelines → Import → Timeline Markers from EDL…**. Colours carry over
(Note = yellow, Good take = green, Mistake = red) and the EDL starts at 01:00:00:00 to match Resolve's
default timeline start.

## Build it yourself

The easy way is to push to GitHub: `.github/workflows/windows.yml` builds Slate with Qt 6.8 + MinGW,
runs the unit tests and an automated self-test of the packaged app, builds the installer with
Inno Setup (`packaging/windows/slate.iss`) and publishes it as a release.

By hand on Windows: install Qt 6.8 (MinGW 64-bit), unpack `mpv-dev-lgpl-x86_64-*.7z` from
zhongfly/mpv-winbuild to `deps\mpv`, then in a Qt MinGW terminal:

```
cmake -S . -B build -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release -DMPV_DIR=%CD%\deps\mpv
cmake --build build --parallel
```

Put `libmpv-2.dll`, `ffmpeg.exe`, `ffprobe.exe` (and optionally `whisper-cli.exe` with its DLLs and
`yt-dlp.exe`) next to `Slate.exe`, then run `windeployqt --qmldir qml Slate.exe`.

On Linux:

```
sudo apt install qt6-base-dev qt6-declarative-dev qt6-svg-dev libmpv-dev ffmpeg cmake ninja-build \
  qml6-module-qtquick-controls qml6-module-qtquick-layouts qml6-module-qtquick-dialogs \
  qml6-module-qtquick-window qml6-module-qtqml-workerscript qml6-module-qtquick-templates
cmake -S . -B build -G Ninja && cmake --build build
./build/slate_tests                        # unit tests
./build/slate --selftest some-clip.mp4     # drives the real app through the review workflow
./build/slate --tour shots/ some-clip.mp4  # saves a screenshot of every screen
```

## How it is built

- `src/mpvobject.*`: the only code that talks to libmpv. Renders into Qt Quick through mpv's OpenGL
  render API and exposes playback state as properties.
- `src/media.*`: background analysis with ffmpeg/ffprobe (waveform, loudness, thumbnails, stream facts),
  cached per file.
- `src/transcript.*`: whisper.cpp transcription. `src/visuals.*`: waveform and scope drawing.
- `src/appcontroller.*`: clip list, resume points, In/Out, ratings, settings, exports.
- `src/markermodel.*`, `src/timecode.*`, `src/folderqueue.*`: pure logic, unit tested in `tests/`.
- `qml/`: the interface. `packaging/windows/`: icon, version info and installer.

Troubleshooting: set `SLATE_MPV_LOG=1` to print mpv's log. Your own `mpv.conf` and scripts can go in
the folder shown in Settings → Playback.

## Licences of parts

Qt (LGPL v3), libmpv LGPL build (LGPL v2.1+), FFmpeg, whisper.cpp (MIT) and yt-dlp (Unlicense) run as
separate programs. Slate itself is a personal project: all rights reserved.
