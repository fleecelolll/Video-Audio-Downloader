<div align="center">

# video + audio downloader

A little tool I made with AI to download videos and audio from yt-dlp-supported sites locally on 64-bit Windows.

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
4. open the `Video Downloader` shortcut created in the folder

The shortcut starts the tool with its private Python environment. You can copy the shortcut to your Desktop or pin it to the taskbar.

The download contains only the installer and app. Setup gets the required components from their official sources and keeps the app-specific packages, settings, caches, and downloaded runtimes inside the app folder. It does not require administrator access, change your system PATH, or install global Python packages.

Setup also installs one small shared launcher in `%LOCALAPPDATA%\Fleece Tools\Python Launcher` and sets `.pyw` files to open with it for your Windows account. The launcher always uses the selected tool's sibling `.venv\Scripts\pythonw.exe`, then its sibling `.runtime\python\pythonw.exe`. It never uses another tool's private Python.

Before the first Fleece Tools association change, setup exports any existing per-user `.pyw` settings to that shared folder. If the previous setting cannot be backed up safely, setup stops without overwriting it. A later non-Fleece choice is also left alone.

If compatible Python is already installed, the app uses a private `.venv` for its packages. That environment still relies on the existing Python installation for Python itself. If compatible Python is not installed, setup offers to download a fully private embedded Python runtime into the app folder.

Run `Installer.bat` again whenever you want to repair the pinned downloader components. After downloading a newer release, run its installer to update those components. Setup also recreates the shortcut for the folder's current location, so run it again after moving the folder. Your selected save folder, format, and quality are kept.

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

The app has no telemetry, analytics, accounts, or usage tracking. To remove only Video Downloader, close it and delete its folder. The app does not install a background service, add itself to startup, or create an uninstaller entry.

The shared `.pyw` launcher is used by every installed Fleece Tool, so removing one tool does not remove it. To restore the `.pyw` settings that existed before Fleece Tools first configured them, run `%LOCALAPPDATA%\Fleece Tools\Python Launcher\Restore pyw association.cmd`. The restore helper refuses to overwrite a newer non-Fleece choice. After restoring, and after removing every Fleece Tool that uses it, you can delete the shared `Python Launcher` folder. The registry backup files can contain local application names and paths, so review them before sharing.

## note

This project was made with AI.

Only download media you own or have permission to download.
