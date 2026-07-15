<div align="center">

# video + audio downloader

a simple app for downloading video or audio on 64-bit Windows (x64 or ARM64).

</div>

<p align="center">
  <img src="Video Downloader.png" alt="video + audio downloader" width="691">
</p>

## features

- download video as MP4
- extract audio as MP3
- choose the video quality and save location
- view supported sites inside the app
- follow download progress in the built-in log

## installation

1. download the latest ZIP from the [releases page](../../releases/latest)
2. extract the folder
3. run `Installer.bat`
4. open `Video Downloader.pyw`

The installer gets the required components from their official sources and keeps the app-specific packages, settings, caches, and downloaded runtimes inside the app folder. It does not require administrator access or change your system PATH, file associations, or globally installed Python packages.

If compatible Python is already installed, the app uses a private `.venv` for its packages. That environment still relies on the existing Python installation for Python itself. If compatible Python is not installed, setup offers to download a fully private embedded Python runtime into the app folder.

Run `Installer.bat` again whenever you want to update yt-dlp or repair the app's local files. Your selected save folder, format, and quality are kept.

## usage

1. paste a supported link
2. select MP4 or MP3
3. choose the quality and save folder
4. click **Download**

## built with

- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- [yt-dlp-ejs](https://github.com/yt-dlp/ejs)
- [PySide6](https://doc.qt.io/qtforpython-6/)
- [FFmpeg](https://ffmpeg.org/)
- [Deno](https://deno.com/)
- [Python](https://www.python.org/)

## privacy and removal

The app has no telemetry, analytics, accounts, or usage tracking. To remove everything installed specifically for the downloader, close it and delete its folder.

## note

This project was made with AI.

Only download media you own or have permission to download.
