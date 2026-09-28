<div align="center">

# video + audio downloader

A little tool I made with AI to download videos and audio from yt-dlp-supported sites locally on 64-bit Windows.

<img src="Video%20%2B%20Audio%20Downloader.png" alt="Video + Audio Downloader app window" width="760">

</div>

## features

- Download supported video as MP4
- Extract supported audio as MP3
- Choose the video quality and save folder
- View supported sites inside the app
- Follow download progress in the built-in log
- Use a pinned yt-dlp and JavaScript runtime
- Keep downloader components private to the extracted folder
- Run without telemetry, analytics, or app accounts

## requirements

- 64-bit x64 or ARM64 Windows
- An internet connection during setup and downloads
- A URL supported by the installed yt-dlp release
- Permission to download the selected media

## installation

1. Download the latest release ZIP.
2. Extract the complete folder.
3. Double-click `Installer.bat`.
4. Press **Y** once to accept the Terms and bundled Tool License and approve setup.
5. Leave the setup window open until every check passes.
6. Double-click the `Video + Audio Downloader` shortcut created in the folder.

Keep the full extracted folder path at 72 characters or fewer so Windows can install the private packages reliably.

Setup keeps the private Python runtime, dependencies, settings, and every app component inside the extracted folder. It does not require administrator access, change PATH, or install global Python packages. The generated folder-local shortcut starts the app directly with that private runtime, so Microsoft Store or system Python is not required.

Setup pins and verifies official Python 3.14.7, pip, PySide6-Essentials, yt-dlp, yt-dlp-ejs, FFmpeg, FFprobe, and Deno. Downloaded runtime archives and dependency wheels are checked against pinned SHA-256 hashes before use. Setup automatically chooses the x64 or ARM64 dependency lock and verifies that bundled lock before installation or repair.

### v1.0.15 security update

- Require approved SHA-256 hashes for every Python dependency and its transitive dependencies during initial setup and repair.
- Reject a missing or changed bundled dependency lock before reusing or replacing packages.
- Keep the existing dependency versions, public download access, folder-local setup, and automatic x64/ARM64 selection unchanged.

Run `Installer.bat` again to repair the private components or after moving the complete folder. Setup preserves the selected save folder, format, and quality and recreates the shortcut for the folder's current location.

## usage

1. Paste a supported URL.
2. Select MP4 or MP3.
3. Choose the quality and save folder.
4. Click **Download**.
5. Leave the app open until the download and any conversion finish.

Site behavior changes over time. Run the newest installer whenever a supported site reports an extractor or JavaScript-runtime error.

## built with

- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- [yt-dlp-ejs](https://github.com/yt-dlp/ejs)
- [PySide6](https://doc.qt.io/qtforpython-6/)
- [FFmpeg](https://ffmpeg.org/)
- [Deno](https://deno.com/)
- [Python](https://www.python.org/)

## privacy and removal

The app has no telemetry, analytics, advertisements, or app accounts. Network requests occur only for the setup and downloads you start. Download and setup logs can contain media URLs and local folder paths, so review them before sharing.

To remove Video + Audio Downloader, close it and delete the extracted folder. This removes its folder-local shortcut, private runtime, dependencies, settings, logs, and app files. The app does not install a background service, add itself to startup, or create an uninstaller entry.

## troubleshooting

If setup stops, review `setup.log`, correct the listed problem, and run `Installer.bat` again. Setup reports success only after its dependencies, offline self-tests, and shortcut all pass.

Before any runtime download, setup checks the bundled app source, Windows ZIP extraction, and the ability to create and read a folder-local shortcut. A predictable prerequisite failure stops immediately with a short **How to fix** instruction. A Python, PyPI package, FFmpeg, or Deno failure also stops at that stage; `setup.log` records the underlying command or download error. Re-extract a missing or damaged release file from the official ZIP rather than substituting an unverified download.

If the `Video + Audio Downloader` shortcut does not open, run `Installer.bat` again and keep the complete extracted folder together. Setup recreates and validates the shortcut for the folder's current location.

If one site stops working, run the latest `Installer.bat` to refresh the pinned downloader components before retrying.

## license

Copyright 2026 Fleece. This project is source-available, not open source. The bundled [LICENSE](LICENSE) permits downloading, installing, and running an unmodified official release for lawful personal, non-commercial use. Modification, redistribution, sale, rebranding, and derivative versions remain prohibited. Third-party materials retain their own licenses.

## note

This project was made with AI.

Only download media you own or have permission to download.
