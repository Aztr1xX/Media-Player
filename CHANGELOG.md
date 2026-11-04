# Changelog

Every push to `main` publishes a new release named `1.1.<build number>`, and installed copies of Slate
update themselves to it. Builds that only fixed the CI are left out below.
Downloads: [Releases](https://github.com/Aztr1xX/Slate/releases).

## 2026-11-04
- The GitHub repository is now **Aztr1xX/Slate**. The updater checks the new address and follows
  GitHub's redirect if the name ever changes again.
- New README with screenshots, plus LICENSE, third-party notices and this changelog.

## 1.1.12 (2026-10-31)
- Audio levels moved to their own side tab (Alt + 6).
- Scopes are drawn off the UI thread, so playback stays smooth while they are open.

## 1.1.11 (2026-10-31)
- Crop guide button next to the speed control; right-click it to pick the ratio.
- Picture zoom: Ctrl + scroll at the pointer, drag to pan, Z for 200% and fit.
- Live left and right audio meter, with buttons to listen to one channel alone.
- Copy the current frame to the clipboard (Ctrl + C).
- Fixed a rare crash when ending a side-by-side comparison.

## 1.1.10 (2026-10-31)
- Crop guide (G): 9:16, 4:5 and 1:1 frames over the picture, draggable sideways.
- Exports go to a `Slate exports` folder beside the clip, or a folder chosen in Settings.
- Media keys, a remembered side tab, a hint after exporting, and a command palette that always shows whole rows.

## 1.1.9 (2026-10-31)
- Built-in updates: Slate checks GitHub releases, downloads new versions in the background and
  installs them silently on restart.
- New app icon: a fanned stack of glass clip cards with a blue-to-violet glow.
- Centred play button, redrawn settings gear, and the volume percentage shown on hover.

## 1.0 (2026-10-31)
- Renamed from "Take" to **Slate**.
- Redesigned interface with a side panel for markers, clips, media info, transcript and scopes.
- Media info with loudness (LUFS) and variable frame rate warnings.
- Video scopes: luma waveform, RGB parade, histogram and vectorscope.
- Offline transcription with whisper.cpp, saved as SRT or text.
- Windows installer with Open with, Review folder in Slate and default app registration.

## First version (2026-10-31)
- libmpv playback in a Qt Quick interface, frame stepping, SMPTE timecode and a waveform timeline.
- Markers with notes, exported as an EDL for DaVinci Resolve, CSV or YouTube chapters.
- Lossless and frame-exact In to Out export, star ratings and natural-order folder playback.
