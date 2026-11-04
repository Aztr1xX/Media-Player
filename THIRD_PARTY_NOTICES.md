# Third-party notices

Slate is built on, and ships with, the open source projects below. Each keeps its own licence;
Slate's own licence ([LICENSE](LICENSE)) does not apply to them.

| Component | Used for | Licence | How it is included |
| --- | --- | --- | --- |
| [Qt 6](https://www.qt.io/) | Interface, networking, SVG | LGPL v3 | Dynamically linked DLLs next to `Slate.exe` |
| [libmpv](https://mpv.io/) (LGPL build from [zhongfly/mpv-winbuild](https://github.com/zhongfly/mpv-winbuild)) | Playback engine | LGPL v2.1 or later | Dynamically linked `libmpv-2.dll` |
| [FFmpeg](https://ffmpeg.org/) (shared build from [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds)) | Waveforms, loudness, thumbnails, clip export | GPL (this build) | Separate `ffmpeg.exe` and `ffprobe.exe` programs that Slate runs |
| [whisper.cpp](https://github.com/ggml-org/whisper.cpp) | Offline transcription | MIT | Separate `whisper-cli.exe` program that Slate runs |
| [yt-dlp](https://github.com/yt-dlp/yt-dlp) | Opening URLs | Unlicense | Separate `yt-dlp.exe` program used by libmpv |
| [Inno Setup](https://jrsoftware.org/isinfo.php) | Building the Windows installer | Inno Setup licence | Build tool only |

Because Qt and libmpv are loaded as ordinary DLLs, they can be swapped for other builds of the same
versions, as the LGPL requires. FFmpeg, whisper.cpp and yt-dlp run as independent programs and are not
linked into Slate. Their source code is available from the project pages above.

Speech models for transcription are downloaded on first use from the whisper.cpp model repository and
are covered by their own terms.
