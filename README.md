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
4. Press **Y** once to approve setup.
5. Leave the setup window open until every check passes.
6. Double-click the `Video + Audio Downloader` shortcut created in the folder.

Keep the full extracted folder path at 72 characters or fewer so Windows can install the private packages reliably.

Setup keeps the private Python runtime and all app-specific components inside the extracted folder. It does not require administrator access, change PATH, or install global Python packages. The shortcut starts the app with that private runtime, so Microsoft Store or system Python is not required.

Setup pins and verifies official Python 3.14.7, pip, PySide6-Essentials, yt-dlp, yt-dlp-ejs, FFmpeg, FFprobe, and Deno. Downloaded runtime archives are checked against pinned SHA-256 hashes before use.

Setup also installs one small shared per-user launcher in `%LOCALAPPDATA%\Fleece Tools\Python Launcher` and safely associates `.pyw` files with it for the current Windows account. It backs up an existing per-user association before the first change and never borrows another tool's Python runtime.

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

To remove only Video + Audio Downloader, close it and delete the extracted folder. The app does not install a background service, add itself to startup, or create an uninstaller entry.

The shared `.pyw` launcher can be used by every installed Fleece Tool, so removing one tool does not remove it. To restore the association that existed before Fleece Tools first configured it, run `%LOCALAPPDATA%\Fleece Tools\Python Launcher\Restore pyw association.cmd` after closing every Fleece Tool.

## troubleshooting

If setup stops, review `setup.log`, correct the listed problem, and run `Installer.bat` again. Setup reports success only after its dependencies, offline self-tests, and shortcut all pass.

If the `Video + Audio Downloader` shortcut does not open, run `Installer.bat` again and keep the complete extracted folder together. Setup recreates and validates the shortcut for the folder's current location.

If one site stops working, run the latest `Installer.bat` to refresh the pinned downloader components before retrying.

## source use

The source is public for transparency and security review. Copyright 2026 Fleece. All rights reserved. No permission is granted to use, copy, modify, redistribute, sell, or publish derivative versions. See [LICENSE](LICENSE).

## note

This project was made with AI.

Only download media you own or have permission to download.
