import atexit
import codecs
import ctypes
import os
import re
import subprocess
import sys
import tempfile
import traceback
from ctypes import wintypes
from importlib import metadata
from pathlib import Path
from urllib.parse import urlparse


APP_DIR = Path(__file__).resolve().parent
APP_NAME = "Video + Audio Downloader"
APP_VERSION = "1.0.15"
PYSIDE_VERSION = "6.11.2"
YTDLP_VERSION = "2026.8.19"
YTDLP_EJS_VERSION = "0.8.0"
FFMPEG_VERSION = "9.0.2"
DENO_VERSION = "2.9.7"
FRAGMENT_WORKERS = max(1, min(4, (os.cpu_count() or 2) // 2))
PROCESS_READ_CHUNK_BYTES = 65536
PROCESS_LINE_HEAD_CHARS = 4096
PROCESS_LINE_TAIL_CHARS = 4096
PROCESS_LINE_TRUNCATION = " ... [output truncated; beginning and end shown] ... "
SITES_STDOUT_MAX_BYTES = 4 * 1024 * 1024
SITES_STDERR_MAX_BYTES = 256 * 1024
RUNTIME_DIR = APP_DIR / ".runtime"
SETUP_LOCK_DIR = RUNTIME_DIR / "setup.lock"
VENV_PYTHONW = APP_DIR / ".venv" / "Scripts" / "pythonw.exe"
VENV_PYTHON = APP_DIR / ".venv" / "Scripts" / "python.exe"
EMBEDDED_PYTHONW = RUNTIME_DIR / "python" / "pythonw.exe"
EMBEDDED_PYTHON = RUNTIME_DIR / "python" / "python.exe"
DENO_DATA_DIR = RUNTIME_DIR / "deno-data"
YTDLP_CACHE_DIR = RUNTIME_DIR / "yt-dlp-cache"
SETTINGS_PATH = RUNTIME_DIR / "settings.ini"
APP_MUTEX_NAMES = (
    r"Global\FleeceVideoDownloaderApp",
    r"Local\FleeceVideoDownloaderApp",
)
APP_MUTEX_HANDLE = None
ERROR_ALREADY_EXISTS = 183
ERROR_ACCESS_DENIED = 5

if os.name == "nt":
    NATIVE_KERNEL32 = ctypes.WinDLL("kernel32", use_last_error=True)
    NATIVE_KERNEL32.CreateMutexW.argtypes = (
        ctypes.c_void_p,
        wintypes.BOOL,
        wintypes.LPCWSTR,
    )
    NATIVE_KERNEL32.CreateMutexW.restype = wintypes.HANDLE
    NATIVE_KERNEL32.CloseHandle.argtypes = (wintypes.HANDLE,)
    NATIVE_KERNEL32.CloseHandle.restype = wintypes.BOOL
    NATIVE_KERNEL32.GetSystemDirectoryW.argtypes = (
        wintypes.LPWSTR,
        wintypes.UINT,
    )
    NATIVE_KERNEL32.GetSystemDirectoryW.restype = wintypes.UINT
else:
    NATIVE_KERNEL32 = None


def show_native_setup_error(message):
    title = APP_NAME
    if os.name == "nt":
        ctypes.windll.user32.MessageBoxW(None, message, title, 0x10)
    else:
        print(f"{title}: {message}", file=sys.stderr)


def release_app_mutex():
    global APP_MUTEX_HANDLE
    if APP_MUTEX_HANDLE is None or NATIVE_KERNEL32 is None:
        return
    NATIVE_KERNEL32.CloseHandle(APP_MUTEX_HANDLE)
    APP_MUTEX_HANDLE = None


def _try_create_named_mutex(name):
    if NATIVE_KERNEL32 is None:
        return "unavailable", None
    ctypes.set_last_error(0)
    handle = NATIVE_KERNEL32.CreateMutexW(None, False, name)
    error_code = ctypes.get_last_error()
    if handle and error_code == ERROR_ALREADY_EXISTS:
        NATIVE_KERNEL32.CloseHandle(handle)
        return "exists", None
    if handle:
        return "acquired", handle
    if error_code == ERROR_ACCESS_DENIED:
        return "denied", None
    return "failed", None


def acquire_app_mutex():
    global APP_MUTEX_HANDLE
    if NATIVE_KERNEL32 is None:
        return True
    for index, name in enumerate(APP_MUTEX_NAMES):
        status, handle = _try_create_named_mutex(name)
        if status == "acquired":
            APP_MUTEX_HANDLE = handle
            atexit.register(release_app_mutex)
            return True
        if status == "exists":
            return False
        if index == 0 and status == "denied":
            continue
        return False
    return False


def bootstrap_local_python():
    current = os.path.normcase(os.path.realpath(sys.executable))
    for local_python, local_pythonw in (
        (VENV_PYTHON, VENV_PYTHONW),
        (EMBEDDED_PYTHON, EMBEDDED_PYTHONW),
    ):
        if not local_python.is_file() or not local_pythonw.is_file():
            continue

        valid_executables = {
            os.path.normcase(os.path.realpath(local_python)),
            os.path.normcase(os.path.realpath(local_pythonw)),
        }
        if current in valid_executables and sys.flags.isolated:
            return

        if current not in valid_executables:
            try:
                validation = subprocess.run(
                    [str(local_python), "-I", "-c", "pass"],
                    stdin=subprocess.DEVNULL,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    timeout=60,
                    creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
                )
            except (OSError, subprocess.SubprocessError):
                continue

            if validation.returncode != 0:
                continue

        try:
            subprocess.Popen(
                [
                    str(local_pythonw),
                    "-I",
                    str(Path(__file__).resolve()),
                    *sys.argv[1:],
                ],
                cwd=str(APP_DIR),
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
            )
        except OSError:
            continue

        raise SystemExit(0)

    show_native_setup_error(
        "Setup is missing, incomplete, or no longer usable.\n\n"
        "Run Installer.bat, let it finish, then open the Video + Audio Downloader "
        "shortcut again."
    )
    raise SystemExit(1)


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
    bootstrap_local_python()


try:
    from PySide6.QtCore import (
        QEasingCurve,
        QEvent,
        QPoint,
        QProcess,
        QProcessEnvironment,
        QPropertyAnimation,
        QRect,
        QSettings,
        QStandardPaths,
        QTimer,
        Qt,
        Signal,
    )
    from PySide6.QtGui import (
        QCloseEvent,
        QMouseEvent,
        QPainter,
        QPen,
        QTextCursor,
    )
    from PySide6.QtWidgets import (
        QApplication,
        QFileDialog,
        QFrame,
        QHBoxLayout,
        QLabel,
        QLineEdit,
        QListWidget,
        QMainWindow,
        QPushButton,
        QProgressBar,
        QSizePolicy,
        QTextEdit,
        QVBoxLayout,
        QWidget,
    )
except Exception:
    if __name__ == "__main__":
        show_native_setup_error(
            "Setup is incomplete and the app window cannot load.\n\n"
            "Run Installer.bat again to repair the setup."
        )
        raise SystemExit(1)
    raise


RUNTIME_PATHS = (
    RUNTIME_DIR / "ffmpeg" / "bin",
    RUNTIME_DIR / "ffmpeg",
    RUNTIME_DIR / "deno",
    RUNTIME_DIR / "bin",
    RUNTIME_DIR,
)


def runtime_path_value(existing_path=None):
    existing_path = existing_path if existing_path is not None else os.environ.get(
        "PATH", ""
    )
    entries = [str(path) for path in RUNTIME_PATHS if path.is_dir()]
    if existing_path:
        entries.append(existing_path)
    return os.pathsep.join(entries)


def qprocess_environment():
    environment = QProcessEnvironment.systemEnvironment()
    environment.insert("PATH", runtime_path_value(environment.value("PATH")))
    environment.insert("PYTHONUTF8", "1")
    environment.insert("PYTHONIOENCODING", "utf-8")
    environment.insert("DENO_DIR", str(DENO_DATA_DIR))
    return environment


def subprocess_environment():
    environment = os.environ.copy()
    environment["PATH"] = runtime_path_value(environment.get("PATH", ""))
    environment["PYTHONUTF8"] = "1"
    environment["PYTHONIOENCODING"] = "utf-8"
    environment["DENO_DIR"] = str(DENO_DATA_DIR)
    return environment


def handle_unhandled_exception(error_type, error, trace):
    try:
        RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
        (RUNTIME_DIR / "error.log").write_text(
            "".join(traceback.format_exception(error_type, error, trace)),
            encoding="utf-8",
        )
    except OSError:
        pass
    show_native_setup_error(
        "The app stopped because of an unexpected error.\n\n"
        "Run Installer.bat again. If it still happens, check .runtime\\error.log."
    )
    application = QApplication.instance()
    if application is not None:
        application.quit()


def local_runtime_executable(name):
    filename = f"{name}.exe" if os.name == "nt" else name
    for directory in RUNTIME_PATHS:
        candidate = directory / filename
        if candidate.is_file():
            return candidate
    return None


def system_taskkill_executable():
    if NATIVE_KERNEL32 is None:
        return None
    buffer = ctypes.create_unicode_buffer(32768)
    length = NATIVE_KERNEL32.GetSystemDirectoryW(buffer, len(buffer))
    if not length or length >= len(buffer):
        return None
    candidate = Path(buffer.value) / "taskkill.exe"
    return candidate if candidate.is_file() else None


def yt_dlp_arguments(*arguments):
    return [
        "-I",
        "-m",
        "yt_dlp",
        "--ignore-config",
        "--no-plugin-dirs",
        *arguments,
    ]


def is_valid_download_url(url):
    try:
        parsed_url = urlparse(url)
        return (
            parsed_url.scheme.lower() in {"http", "https"}
            and bool(parsed_url.netloc)
            and bool(parsed_url.hostname)
        )
    except ValueError:
        return False


def prepare_download_folder(folder_value):
    folder = Path(folder_value).expanduser()
    folder.mkdir(parents=True, exist_ok=True)
    if not folder.is_dir():
        raise OSError("The selected path is not a folder.")
    with tempfile.NamedTemporaryFile(dir=folder):
        pass
    return folder.resolve(strict=True)


def extend_bounded_bytes(buffer, data, limit):
    available = max(0, limit - len(buffer))
    kept = data[:available]
    buffer.extend(kept)
    return len(data) - len(kept)


def bounded_process_line(text):
    content_limit = PROCESS_LINE_HEAD_CHARS + PROCESS_LINE_TAIL_CHARS
    if len(text) <= content_limit:
        return text
    return (
        text[:PROCESS_LINE_HEAD_CHARS]
        + PROCESS_LINE_TRUNCATION
        + text[-PROCESS_LINE_TAIL_CHARS:]
    )


def build_download_arguments(url, download_folder, output_format, quality):
    args = yt_dlp_arguments(
        "--newline",
        "--windows-filenames",
        "--no-remote-components",
        "--check-formats",
        "--cache-dir",
        str(YTDLP_CACHE_DIR),
        "--concurrent-fragments",
        str(FRAGMENT_WORKERS),
        "--progress-template",
        "download:PROGRESS:%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s",
        "-P",
        str(download_folder),
    )

    deno_executable = local_runtime_executable("deno")
    if deno_executable is not None:
        args.extend(
            [
                "--no-js-runtimes",
                "--js-runtimes",
                f"deno:{deno_executable}",
            ]
        )

    ffmpeg_executable = local_runtime_executable("ffmpeg")
    if ffmpeg_executable is not None:
        args.extend(["--ffmpeg-location", str(ffmpeg_executable.parent)])

    if output_format == "MP3":
        args.extend(["-x", "--audio-format", "mp3", "--audio-quality", "0"])
    else:
        args.extend(["-t", "mp4"])
        if quality != "Best":
            args.extend(["-S", f"res:{quality.removesuffix('p')}"])

    args.extend(["--no-playlist", "--", url])
    return args


def download_failure_message(messages):
    output = "\n".join(messages).lower()
    if "unsupported url" in output:
        return "That website or link is not supported."
    if "video unavailable" in output or "this video is unavailable" in output:
        return "That video is unavailable or was removed."
    if "requested format is not available" in output:
        return "That quality is unavailable. Try Best or another quality."
    if "sign in" in output or "private video" in output:
        return "That video may be private or require an account."
    if "http error 429" in output or "too many requests" in output:
        return "The website temporarily limited requests. Wait and try again."
    if "http error 403" in output or "403 forbidden" in output:
        return (
            "The website rejected the media request. Run Installer.bat to "
            "refresh site support, then wait and try again."
        )
    if any(
        marker in output
        for marker in (
            "connection timed out",
            "network is unreachable",
            "temporary failure in name resolution",
        )
    ):
        return "The network request failed. Check the connection and try again."
    if "no space left on device" in output or "disk full" in output:
        return "The save drive is full. Free some space and try again."
    if "permission denied" in output or "access is denied" in output:
        return "The selected folder cannot be written. Choose another folder."
    if "javascript runtime" in output or "yt-dlp-ejs" in output:
        return "YouTube support is incomplete. Run Installer.bat again."
    if any(
        marker in output
        for marker in (
            "ffmpeg not found",
            "ffprobe not found",
            "ffmpeg exited with code",
            "postprocessing:",
        )
    ):
        return "FFmpeg could not complete the media conversion. Run Installer.bat again."
    return "The download failed. Check the messages above for details."


class TrafficLightButton(QPushButton):
    def __init__(self, color_name, tooltip, parent=None):
        super().__init__(parent)
        self.setObjectName(color_name)
        self.setToolTip(tooltip)
        self.setFixedSize(13, 13)
        self.setCursor(Qt.PointingHandCursor)


class TitleBar(QFrame):
    def __init__(self, host):
        super().__init__(host)
        self.host = host
        self.drag_offset = QPoint()
        self.setObjectName("titleBar")
        self.setFixedHeight(38)

        layout = QHBoxLayout(self)
        layout.setContentsMargins(14, 0, 14, 0)
        layout.setSpacing(8)

        maximize_button = TrafficLightButton("maximizeDot", "Maximize")
        minimize_button = TrafficLightButton("minimizeDot", "Minimize")
        close_button = TrafficLightButton("closeDot", "Close")

        close_button.clicked.connect(host.close)
        minimize_button.clicked.connect(host.showMinimized)
        maximize_button.clicked.connect(self.toggle_maximized)

        controls = QHBoxLayout()
        controls.setContentsMargins(0, 0, 0, 0)
        controls.setSpacing(8)
        controls.addWidget(maximize_button)
        controls.addWidget(minimize_button)
        controls.addWidget(close_button)

        controls_holder = QWidget()
        controls_holder.setFixedWidth(64)
        controls_holder.setLayout(controls)

        title = QLabel(APP_NAME)
        title.setObjectName("windowTitle")
        title.setAlignment(Qt.AlignCenter)

        left_spacer = QWidget()
        left_spacer.setFixedWidth(64)

        layout.addWidget(left_spacer)
        layout.addStretch()
        layout.addWidget(title)
        layout.addStretch()
        layout.addWidget(controls_holder)

    def toggle_maximized(self):
        if self.host.isMaximized():
            self.host.showNormal()
        else:
            self.host.showMaximized()

    def mouseDoubleClickEvent(self, event: QMouseEvent):
        if event.button() == Qt.LeftButton:
            self.toggle_maximized()
            event.accept()

    def mousePressEvent(self, event: QMouseEvent):
        if event.button() == Qt.LeftButton:
            self.drag_offset = (
                event.globalPosition().toPoint()
                - self.host.frameGeometry().topLeft()
            )
            event.accept()

    def mouseMoveEvent(self, event: QMouseEvent):
        if event.buttons() & Qt.LeftButton and not self.host.isMaximized():
            self.host.move(event.globalPosition().toPoint() - self.drag_offset)
            event.accept()


class WindowHeader(QFrame):
    def __init__(self, window, title_text):
        super().__init__(window)
        self.win = window
        self.drag_offset = QPoint()
        self.setObjectName("titleBar")
        self.setFixedHeight(38)

        layout = QHBoxLayout(self)
        layout.setContentsMargins(14, 0, 14, 0)
        layout.setSpacing(8)

        close_button = TrafficLightButton("closeDot", "Close")
        close_button.clicked.connect(window.close)

        title = QLabel(title_text)
        title.setObjectName("windowTitle")
        title.setAlignment(Qt.AlignCenter)

        left_spacer = QWidget()
        left_spacer.setFixedWidth(13)

        layout.addWidget(left_spacer)
        layout.addStretch()
        layout.addWidget(title)
        layout.addStretch()
        layout.addWidget(close_button)

    def mousePressEvent(self, event: QMouseEvent):
        if event.button() == Qt.LeftButton:
            self.drag_offset = (
                event.globalPosition().toPoint()
                - self.win.frameGeometry().topLeft()
            )
            event.accept()

    def mouseMoveEvent(self, event: QMouseEvent):
        if event.buttons() & Qt.LeftButton:
            self.win.move(event.globalPosition().toPoint() - self.drag_offset)
            event.accept()


class ChevronButton(QPushButton):
    def paintEvent(self, event):
        super().paintEvent(event)

        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        painter.setPen(QPen(Qt.white, 1.4))

        x = self.width() - 20
        y = self.height() // 2 - 1
        painter.drawLine(x - 4, y - 2, x, y + 2)
        painter.drawLine(x, y + 2, x + 4, y - 2)


class AnimatedDropdown(QWidget):
    changed = Signal(str)

    def __init__(self, items, parent=None):
        super().__init__(parent)
        self.items = list(items)
        self._current = self.items[0]
        self._animation = None
        self._closing = False

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        self.button = ChevronButton(self._current)
        self.button.setObjectName("dropdownButton")
        self.button.setMinimumHeight(38)
        self.button.clicked.connect(self.toggle_popup)
        layout.addWidget(self.button)

        self.popup = QFrame(
            self,
            Qt.Tool | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint,
        )
        self.popup.setObjectName("dropdownPopup")
        self.popup.setAttribute(Qt.WA_TranslucentBackground)

        outer = QVBoxLayout(self.popup)
        outer.setContentsMargins(0, 0, 0, 0)

        surface = QFrame()
        surface.setObjectName("dropdownSurface")

        surface_layout = QVBoxLayout(surface)
        surface_layout.setContentsMargins(5, 5, 5, 5)
        surface_layout.setSpacing(2)

        for item in self.items:
            option = QPushButton(item)
            option.setObjectName("dropdownOption")
            option.setMinimumHeight(32)
            option.clicked.connect(
                lambda checked=False, value=item: self.select(value)
            )
            surface_layout.addWidget(option)

        outer.addWidget(surface)

    def currentText(self):
        return self._current

    def select(self, value):
        self._current = value
        self.button.setText(value)
        self.changed.emit(value)
        self.hide_popup()

    def toggle_popup(self):
        if self.popup.isVisible() and not self._closing:
            self.hide_popup()
        else:
            self.show_popup()

    def show_popup(self):
        self._stop_popup_animation()
        self._closing = False
        popup_height = len(self.items) * 34 + 12
        popup_width = self.width()

        button_top_left = self.mapToGlobal(QPoint(0, 0))
        below_y = button_top_left.y() + self.height() + 4

        screen = QApplication.screenAt(button_top_left)
        available = screen.availableGeometry() if screen else QRect()

        if available and below_y + popup_height > available.bottom():
            final_y = button_top_left.y() - popup_height - 4
        else:
            final_y = below_y

        final_x = button_top_left.x()
        if available:
            final_x = max(
                available.left(),
                min(final_x, available.right() - popup_width + 1),
            )
            final_y = max(
                available.top(),
                min(final_y, available.bottom() - popup_height + 1),
            )

        end_rect = QRect(final_x, final_y, popup_width, popup_height)
        QApplication.instance().installEventFilter(self)

        self.popup.setGeometry(end_rect)
        self.popup.setWindowOpacity(0.0)
        self.popup.show()
        self.popup.raise_()

        opacity_animation = QPropertyAnimation(
            self.popup, b"windowOpacity", self
        )
        opacity_animation.setDuration(110)
        opacity_animation.setStartValue(0.0)
        opacity_animation.setEndValue(1.0)
        opacity_animation.setEasingCurve(QEasingCurve.OutCubic)
        self._animation = opacity_animation
        opacity_animation.finished.connect(
            lambda current=opacity_animation: self._popup_animation_finished(
                current, False
            )
        )
        opacity_animation.start()

    def hide_popup(self):
        if not self.popup.isVisible():
            return
        self._stop_popup_animation()
        self._closing = True
        QApplication.instance().removeEventFilter(self)
        opacity_animation = QPropertyAnimation(
            self.popup, b"windowOpacity", self
        )
        opacity_animation.setDuration(75)
        opacity_animation.setStartValue(self.popup.windowOpacity())
        opacity_animation.setEndValue(0.0)
        opacity_animation.setEasingCurve(QEasingCurve.InCubic)
        self._animation = opacity_animation
        opacity_animation.finished.connect(
            lambda current=opacity_animation: self._popup_animation_finished(
                current, True
            )
        )
        opacity_animation.start()

    def _stop_popup_animation(self):
        if self._animation is None:
            return
        animation = self._animation
        self._animation = None
        animation.stop()
        animation.deleteLater()

    def _popup_animation_finished(self, animation, hide_after):
        if self._animation is animation:
            self._animation = None
        if hide_after:
            self.popup.hide()
            self.popup.setWindowOpacity(1.0)
            self._closing = False
        animation.deleteLater()

    def eventFilter(self, watched, event):
        if self.popup.isVisible() and event.type() == QEvent.MouseButtonPress:
            global_position = event.globalPosition().toPoint()

            popup_rect = self.popup.frameGeometry()
            button_rect = QRect(
                self.button.mapToGlobal(QPoint(0, 0)),
                self.button.size(),
            )

            if (
                not popup_rect.contains(global_position)
                and not button_rect.contains(global_position)
            ):
                self.hide_popup()

        return super().eventFilter(watched, event)


class SitesWindow(QWidget):
    def __init__(self, python_path):
        super().__init__()
        self.python_path = python_path
        self.loaded = False
        self.list_process = None
        self.version_process = None
        self.output_buffer = bytearray()
        self.error_buffer = bytearray()
        self.output_truncated = False
        self.error_truncated = False

        self.setWindowTitle("Supported sites")
        self.setWindowFlags(Qt.Window | Qt.FramelessWindowHint)
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.resize(440, 560)
        self.setMinimumSize(380, 420)

        self.build_ui()

    def build_ui(self):
        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)

        window_frame = QFrame()
        window_frame.setObjectName("windowFrame")
        outer.addWidget(window_frame)

        frame_layout = QVBoxLayout(window_frame)
        frame_layout.setContentsMargins(0, 0, 0, 0)
        frame_layout.setSpacing(0)

        header = WindowHeader(self, "Supported sites")
        frame_layout.addWidget(header)

        content = QVBoxLayout()
        content.setContentsMargins(18, 14, 18, 16)
        content.setSpacing(10)

        self.note_label = QLabel(
            "This list comes from the yt-dlp installed on this PC, so it "
            "matches your version. Re-run installer.bat to update yt-dlp "
            "and this list."
        )
        self.note_label.setObjectName("note")
        self.note_label.setWordWrap(True)
        content.addWidget(self.note_label)

        self.search_input = QLineEdit()
        self.search_input.setPlaceholderText("Search sites")
        self.search_input.setClearButtonEnabled(True)
        self.search_input.textChanged.connect(self.apply_filter)
        content.addWidget(self.search_input)

        self.count_label = QLabel("Loading…")
        self.count_label.setObjectName("count")
        content.addWidget(self.count_label)

        self.list_widget = QListWidget()
        self.list_widget.setUniformItemSizes(True)
        content.addWidget(self.list_widget, 1)

        footer = QHBoxLayout()
        self.refresh_button = QPushButton("Refresh")
        self.refresh_button.setObjectName("small")
        self.refresh_button.clicked.connect(self.refresh)
        footer.addStretch()
        footer.addWidget(self.refresh_button)
        content.addLayout(footer)

        frame_layout.addLayout(content)

    def showEvent(self, event):
        super().showEvent(event)
        if not self.loaded:
            self.load_sites()

    def refresh(self):
        if self.list_process is not None or self.version_process is not None:
            return
        self.loaded = False
        self.load_sites()

    def load_sites(self):
        if self.list_process is not None or self.version_process is not None:
            return

        self.list_widget.clear()
        self.output_buffer.clear()
        self.error_buffer.clear()
        self.output_truncated = False
        self.error_truncated = False
        self.count_label.setText("Loading…")

        version_process = QProcess(self)
        self.version_process = version_process
        version_process.setProcessEnvironment(qprocess_environment())
        version_process.setWorkingDirectory(str(APP_DIR))
        version_process.finished.connect(
            lambda exit_code, exit_status, process=version_process: (
                self.version_finished(process, exit_code, exit_status)
            )
        )
        version_process.errorOccurred.connect(
            lambda error, process=version_process: self.version_error(process, error)
        )
        version_process.start(
            self.python_path,
            yt_dlp_arguments("--version"),
        )

        list_process = QProcess(self)
        self.list_process = list_process
        list_process.setProcessEnvironment(qprocess_environment())
        list_process.setWorkingDirectory(str(APP_DIR))
        list_process.readyReadStandardOutput.connect(
            lambda process=list_process: self.read_list_output(process)
        )
        list_process.readyReadStandardError.connect(
            lambda process=list_process: self.read_list_error(process)
        )
        list_process.finished.connect(
            lambda exit_code, exit_status, process=list_process: (
                self.list_finished(process, exit_code, exit_status)
            )
        )
        list_process.errorOccurred.connect(
            lambda error, process=list_process: self.list_error(process, error)
        )
        list_process.start(
            self.python_path,
            yt_dlp_arguments(
                "--no-warnings",
                "--list-extractors",
            ),
        )

    def read_list_output(self, process):
        if self.list_process is not process:
            return
        data = bytes(process.readAllStandardOutput())
        dropped = extend_bounded_bytes(
            self.output_buffer,
            data,
            SITES_STDOUT_MAX_BYTES,
        )
        if dropped and not self.output_truncated:
            self.output_truncated = True
            process.kill()

    def read_list_error(self, process):
        if self.list_process is not process:
            return
        data = bytes(process.readAllStandardError())
        dropped = extend_bounded_bytes(
            self.error_buffer,
            data,
            SITES_STDERR_MAX_BYTES,
        )
        if dropped and not self.error_truncated:
            self.error_truncated = True
            process.kill()

    def show_list_failure(self):
        error_text = self.error_buffer.decode("utf-8", errors="replace").strip()
        self.count_label.setText(
            "Could not run yt-dlp. Re-run installer.bat to repair setup."
        )
        if self.output_truncated or self.error_truncated:
            self.count_label.setToolTip(
                "yt-dlp returned unexpectedly large output, so the list was stopped."
            )
        else:
            self.count_label.setToolTip(error_text[-1000:] if error_text else "")

    def version_finished(self, process, exit_code, exit_status):
        if self.version_process is not process:
            return
        version = ""
        if exit_status == QProcess.NormalExit and exit_code == 0:
            version = bytes(process.readAllStandardOutput()).decode(
                "utf-8", errors="replace"
            ).strip()
        self.version_process = None
        process.deleteLater()

        if version:
            self.note_label.setText(
                f"From yt-dlp {version} installed on this PC. Re-run "
                "installer.bat to update yt-dlp and this list."
            )

    def version_error(self, process, error):
        if self.version_process is process and error == QProcess.FailedToStart:
            self.version_process = None
            process.deleteLater()

    def list_finished(self, process, exit_code, exit_status):
        if self.list_process is not process:
            return
        self.read_list_output(process)
        self.read_list_error(process)
        self.list_process = None
        self.loaded = True
        process.deleteLater()

        if (
            exit_status != QProcess.NormalExit
            or exit_code != 0
            or self.output_truncated
            or self.error_truncated
        ):
            self.show_list_failure()
            return

        output_text = self.output_buffer.decode("utf-8", errors="replace")

        names = sorted(
            {
                line.strip()
                for line in output_text.splitlines()
                if line.strip()
            },
            key=str.lower,
        )

        if not names:
            self.count_label.setText(
                "Could not load the list. Make sure yt-dlp is installed."
            )
            return

        self.list_widget.addItems(names)
        self.apply_filter(self.search_input.text())

    def list_error(self, process, error):
        if self.list_process is not process:
            return
        self.read_list_error(process)
        if error == QProcess.FailedToStart:
            self.list_process = None
            self.loaded = True
            process.deleteLater()
            self.show_list_failure()

    def apply_filter(self, text):
        text = text.strip().lower()
        total = self.list_widget.count()
        visible = 0

        for index in range(total):
            item = self.list_widget.item(index)
            matches = text in item.text().lower()
            item.setHidden(not matches)
            if matches:
                visible += 1

        if text:
            self.count_label.setText(f"{visible} of {total} sites")
        else:
            self.count_label.setText(f"{total} sites")

    def closeEvent(self, event: QCloseEvent):
        processes = (self.version_process, self.list_process)
        self.version_process = None
        self.list_process = None
        if any(process is not None for process in processes):
            self.loaded = False
        for process in processes:
            if process and process.state() != QProcess.NotRunning:
                process.terminate()
                if not process.waitForFinished(400):
                    process.kill()
                    process.waitForFinished(400)
            if process:
                process.deleteLater()
        event.accept()


class VideoDownloader(QMainWindow):
    PROGRESS_RE = re.compile(
        r"PROGRESS:\s*([0-9.]+)%\|([^|]*)\|([^|]*)"
    )

    def __init__(self):
        super().__init__()

        self.setWindowTitle(APP_NAME)
        self.setWindowFlags(Qt.Window | Qt.FramelessWindowHint)
        self.setAttribute(Qt.WA_TranslucentBackground)

        self.resize(660, 600)
        self.setMinimumSize(620, 560)

        self.runtime_storage_error = ""
        try:
            RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
            DENO_DATA_DIR.mkdir(parents=True, exist_ok=True)
            YTDLP_CACHE_DIR.mkdir(parents=True, exist_ok=True)
        except OSError as error:
            self.runtime_storage_error = str(error)

        self.settings = QSettings(str(SETTINGS_PATH), QSettings.IniFormat)
        default_downloads = QStandardPaths.writableLocation(
            QStandardPaths.DownloadLocation
        )
        if not default_downloads:
            default_downloads = str(Path.home() / "Downloads")
        saved_downloads = self.settings.value("download_folder", "") or ""
        self.download_folder = str(Path(saved_downloads or default_downloads))

        self.process = None
        self.running = False
        self.cancel_requested = False
        self.process_pid = 0
        self.process_decoder = None
        self.process_line_buffer = ""
        self.process_messages = []
        self.last_log_message = ""
        self.sites_window = None
        self.components_ready = True
        self.component_issues = []

        self.stop_timer = QTimer(self)
        self.stop_timer.setSingleShot(True)
        self.stop_timer.timeout.connect(self.force_stop_download)

        self.apply_style()
        self.build_ui()
        self.restore_preferences()
        self.preflight_components()

    def apply_style(self):
        QApplication.instance().setStyleSheet(
            """
            QWidget {
                color: #f5f5f5;
                font-family: "Segoe UI";
                font-size: 13px;
            }

            QFrame#windowFrame {
                background: #070707;
                border: 1px solid #252525;
                border-radius: 14px;
            }

            QFrame#titleBar {
                background: #070707;
                border: none;
                border-bottom: 1px solid #1c1c1c;
                border-top-left-radius: 14px;
                border-top-right-radius: 14px;
            }

            QLabel#windowTitle {
                color: #bdbdbd;
                font-size: 12px;
                font-weight: 600;
            }

            QPushButton#closeDot,
            QPushButton#minimizeDot,
            QPushButton#maximizeDot {
                border: none;
                border-radius: 6px;
                min-height: 13px;
                max-height: 13px;
                min-width: 13px;
                max-width: 13px;
                padding: 0;
            }

            QPushButton#closeDot {
                background: #ff5f57;
            }

            QPushButton#minimizeDot {
                background: #febc2e;
            }

            QPushButton#maximizeDot {
                background: #28c840;
            }

            QPushButton#closeDot:hover,
            QPushButton#minimizeDot:hover,
            QPushButton#maximizeDot:hover {
                border: 1px solid rgba(0, 0, 0, 90);
            }

            QLabel#label {
                color: #b8b8b8;
                font-size: 12px;
                font-weight: 600;
            }

            QLabel#status {
                color: #8b8b8b;
                font-size: 12px;
            }

            QLabel#note {
                color: #7a7a7a;
                font-size: 11px;
            }

            QLabel#count {
                color: #8b8b8b;
                font-size: 11px;
            }

            QFrame#panel {
                background: #0d0d0d;
                border: 1px solid #242424;
                border-radius: 14px;
            }

            QLineEdit {
                background: #0a0a0a;
                border: 1px solid #292929;
                border-radius: 10px;
                min-height: 38px;
                padding: 0 12px;
                selection-background-color: #ffffff;
                selection-color: #000000;
            }

            QLineEdit:focus {
                border: 1px solid #ffffff;
            }

            QPushButton {
                background: #151515;
                border: 1px solid #2b2b2b;
                border-radius: 10px;
                min-height: 38px;
                padding: 0 14px;
                font-weight: 600;
            }

            QPushButton:hover {
                background: #1d1d1d;
                border-color: #3a3a3a;
            }

            QPushButton:pressed {
                background: #101010;
            }

            QPushButton#primary {
                background: #ffffff;
                color: #000000;
                border: none;
                min-height: 42px;
            }

            QPushButton#primary:hover {
                background: #e7e7e7;
            }

            QPushButton#small {
                min-height: 28px;
                max-height: 28px;
                border-radius: 8px;
                padding: 0 10px;
                color: #bdbdbd;
                font-size: 11px;
            }

            QPushButton#dropdownButton {
                background: #0a0a0a;
                border: 1px solid #292929;
                border-radius: 10px;
                min-height: 38px;
                padding: 0 38px 0 12px;
                text-align: left;
                font-weight: 500;
            }

            QPushButton#dropdownButton:hover {
                background: #101010;
                border-color: #3b3b3b;
            }

            QFrame#dropdownSurface {
                background: #111111;
                border: 1px solid #303030;
                border-radius: 11px;
            }

            QPushButton#dropdownOption {
                background: transparent;
                border: none;
                border-radius: 7px;
                min-height: 32px;
                padding: 0 10px;
                text-align: left;
                font-weight: 500;
            }

            QPushButton#dropdownOption:hover {
                background: #242424;
            }

            QFrame#pathFrame {
                background: #0a0a0a;
                border: 1px solid #292929;
                border-radius: 10px;
            }

            QLabel#pathLabel {
                color: #d7d7d7;
                padding-left: 11px;
            }

            QTextEdit {
                background: #090909;
                color: #c8c8c8;
                border: 1px solid #242424;
                border-radius: 10px;
                padding: 8px;
                font-family: "Cascadia Mono", "Consolas";
                font-size: 11px;
                selection-background-color: #ffffff;
                selection-color: #000000;
            }

            QListWidget {
                background: #0a0a0a;
                border: 1px solid #242424;
                border-radius: 10px;
                padding: 4px;
                outline: none;
            }

            QListWidget::item {
                padding: 7px 9px;
                border-radius: 6px;
                color: #cfcfcf;
            }

            QListWidget::item:hover {
                background: #161616;
            }

            QListWidget::item:selected {
                background: #242424;
                color: #ffffff;
            }

            QProgressBar {
                background: #121212;
                border: none;
                border-radius: 3px;
                min-height: 6px;
                max-height: 6px;
            }

            QProgressBar::chunk {
                background: #ffffff;
                border-radius: 3px;
            }

            QScrollBar:vertical {
                width: 8px;
                background: transparent;
            }

            QScrollBar::handle:vertical {
                background: #333333;
                border-radius: 4px;
                min-height: 24px;
            }

            QScrollBar::add-line:vertical,
            QScrollBar::sub-line:vertical {
                height: 0;
            }
            """
        )

    def build_ui(self):
        label_gap = 6
        group_gap = 10
        side_button_width = 84

        central = QWidget()
        self.setCentralWidget(central)

        outer = QVBoxLayout(central)
        outer.setContentsMargins(0, 0, 0, 0)

        window_frame = QFrame()
        window_frame.setObjectName("windowFrame")
        outer.addWidget(window_frame)

        window_layout = QVBoxLayout(window_frame)
        window_layout.setContentsMargins(0, 0, 0, 0)
        window_layout.setSpacing(0)

        self.title_bar = TitleBar(self)
        window_layout.addWidget(self.title_bar)

        content = QWidget()
        window_layout.addWidget(content, 1)

        page = QVBoxLayout(content)
        page.setContentsMargins(22, 18, 22, 18)
        page.setSpacing(0)

        panel = QFrame()
        panel.setObjectName("panel")
        panel.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)

        layout = QVBoxLayout(panel)
        layout.setContentsMargins(18, 16, 18, 16)
        layout.setSpacing(group_gap)

        url_group = QVBoxLayout()
        url_group.setSpacing(label_gap)
        url_label = QLabel("URL")
        url_label.setObjectName("label")
        url_group.addWidget(url_label)

        url_row = QHBoxLayout()
        url_row.setSpacing(8)
        self.url_input = QLineEdit()
        self.url_input.setPlaceholderText("Paste a link")
        self.url_input.setClearButtonEnabled(True)
        self.url_input.returnPressed.connect(self.download_or_cancel)
        self.paste_button = QPushButton("Paste")
        self.paste_button.setFixedWidth(side_button_width)
        self.paste_button.clicked.connect(self.paste_url)
        url_row.addWidget(self.url_input, 1)
        url_row.addWidget(self.paste_button)
        url_group.addLayout(url_row)
        layout.addLayout(url_group)

        selectors = QHBoxLayout()
        selectors.setSpacing(10)

        format_column = QVBoxLayout()
        format_column.setSpacing(label_gap)
        format_label = QLabel("Format")
        format_label.setObjectName("label")
        self.format_dropdown = AnimatedDropdown(["MP4", "MP3"])
        self.format_dropdown.changed.connect(self.format_changed)
        format_column.addWidget(format_label)
        format_column.addWidget(self.format_dropdown)

        quality_column = QVBoxLayout()
        quality_column.setSpacing(label_gap)
        quality_label = QLabel("Quality")
        quality_label.setObjectName("label")
        self.quality_dropdown = AnimatedDropdown(
            ["Best", "2160p", "1440p", "1080p", "720p", "480p"]
        )
        self.quality_dropdown.changed.connect(self.save_preferences)
        quality_column.addWidget(quality_label)
        quality_column.addWidget(self.quality_dropdown)

        selectors.addLayout(format_column, 1)
        selectors.addLayout(quality_column, 1)
        layout.addLayout(selectors)

        save_group = QVBoxLayout()
        save_group.setSpacing(label_gap)
        output_label = QLabel("Save to")
        output_label.setObjectName("label")
        save_group.addWidget(output_label)

        path_row = QHBoxLayout()
        path_row.setSpacing(8)
        path_frame = QFrame()
        path_frame.setObjectName("pathFrame")
        path_frame.setMinimumHeight(38)
        path_layout = QHBoxLayout(path_frame)
        path_layout.setContentsMargins(0, 0, 0, 0)
        self.path_label = QLabel(self.download_folder)
        self.path_label.setObjectName("pathLabel")
        self.path_label.setTextInteractionFlags(Qt.NoTextInteraction)
        path_layout.addWidget(self.path_label)
        self.browse_button = QPushButton("Browse")
        self.browse_button.setFixedWidth(side_button_width)
        self.browse_button.clicked.connect(self.choose_folder)
        path_row.addWidget(path_frame, 1)
        path_row.addWidget(self.browse_button)
        save_group.addLayout(path_row)
        layout.addLayout(save_group)

        self.download_button = QPushButton("Download")
        self.download_button.setObjectName("primary")
        self.download_button.clicked.connect(self.download_or_cancel)
        layout.addWidget(self.download_button)

        progress_group = QVBoxLayout()
        progress_group.setSpacing(label_gap)
        self.progress_bar = QProgressBar()
        self.progress_bar.setTextVisible(False)
        self.progress_bar.setRange(0, 100)
        self.progress_bar.setValue(0)
        progress_group.addWidget(self.progress_bar)
        self.status_label = QLabel("Ready")
        self.status_label.setObjectName("status")
        progress_group.addWidget(self.status_label)
        layout.addLayout(progress_group)

        log_group = QVBoxLayout()
        log_group.setSpacing(label_gap)
        log_header = QHBoxLayout()
        log_header.setSpacing(6)
        log_label = QLabel("Log")
        log_label.setObjectName("label")
        sites_button = QPushButton("Supported sites")
        sites_button.setObjectName("small")
        sites_button.clicked.connect(self.open_sites)
        clear_button = QPushButton("Clear")
        clear_button.setObjectName("small")
        clear_button.clicked.connect(self.clear_log)
        log_header.addWidget(log_label)
        log_header.addStretch()
        log_header.addWidget(sites_button)
        log_header.addWidget(clear_button)
        log_group.addLayout(log_header)
        self.log_box = QTextEdit()
        self.log_box.setReadOnly(True)
        self.log_box.document().setMaximumBlockCount(1500)
        self.log_box.setPlaceholderText("No activity")
        self.log_box.setMinimumHeight(120)
        log_group.addWidget(self.log_box, 1)
        layout.addLayout(log_group, 1)

        page.addWidget(panel, 1)

    def restore_preferences(self):
        format_value = str(self.settings.value("format", "MP4") or "MP4")
        quality_value = str(self.settings.value("quality", "Best") or "Best")

        if format_value not in self.format_dropdown.items:
            format_value = "MP4"
        if quality_value not in self.quality_dropdown.items:
            quality_value = "Best"

        self.format_dropdown._current = format_value
        self.format_dropdown.button.setText(format_value)
        self.quality_dropdown._current = quality_value
        self.quality_dropdown.button.setText(quality_value)
        self.format_changed(format_value)

    def save_preferences(self, value=None):
        self.settings.setValue("download_folder", self.download_folder)
        self.settings.setValue("format", self.format_dropdown.currentText())
        self.settings.setValue("quality", self.quality_dropdown.currentText())
        self.settings.sync()

    @staticmethod
    def command_works(command):
        try:
            result = subprocess.run(
                [str(part) for part in command],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=8,
                env=subprocess_environment(),
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
            )
        except (OSError, subprocess.SubprocessError):
            return False
        return result.returncode == 0

    @staticmethod
    def command_starts_with(command, prefix):
        try:
            result = subprocess.run(
                [str(part) for part in command],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=8,
                env=subprocess_environment(),
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
                text=True,
                encoding="utf-8",
                errors="replace",
            )
        except (OSError, subprocess.SubprocessError):
            return False
        return result.returncode == 0 and result.stdout.startswith(prefix)

    def preflight_components(self):
        issues = []

        if self.runtime_storage_error:
            issues.append("local runtime folder")

        try:
            installed_pyside = metadata.version("PySide6-Essentials")
        except (metadata.PackageNotFoundError, OSError, ValueError):
            installed_pyside = ""
        if installed_pyside != PYSIDE_VERSION:
            issues.append("PySide6")

        try:
            installed_ytdlp = metadata.version("yt-dlp")
        except (metadata.PackageNotFoundError, OSError, ValueError):
            installed_ytdlp = ""
        if installed_ytdlp != YTDLP_VERSION:
            issues.append("yt-dlp")

        try:
            installed_ejs = metadata.version("yt-dlp-ejs")
        except (metadata.PackageNotFoundError, OSError, ValueError):
            installed_ejs = ""
        if installed_ejs != YTDLP_EJS_VERSION:
            issues.append("YouTube support")

        for command, label in (
            ("ffmpeg", "FFmpeg"),
            ("ffprobe", "FFprobe"),
            ("deno", "Deno"),
        ):
            if local_runtime_executable(command) is None:
                issues.append(label)

        self.component_issues = issues
        self.components_ready = not issues
        if self.components_ready:
            return

        self.download_button.setEnabled(False)
        self.status_label.setText("Setup incomplete")
        self.append_log("Run Installer.bat again to repair the setup.")
        self.append_log("Missing or unavailable: " + ", ".join(issues))

    def open_sites(self):
        if self.sites_window is None:
            self.sites_window = SitesWindow(sys.executable)

        geometry = self.frameGeometry()
        offset = self.sites_window.rect().center()
        self.sites_window.move(geometry.center() - offset)
        self.sites_window.show()
        self.sites_window.raise_()
        self.sites_window.activateWindow()

    def format_changed(self, value):
        is_mp3 = value == "MP3"
        self.quality_dropdown.setEnabled(not is_mp3)
        if is_mp3:
            self.quality_dropdown.button.setText("Audio")
        else:
            self.quality_dropdown.button.setText(
                self.quality_dropdown.currentText()
            )
        self.save_preferences()

    def paste_url(self):
        text = QApplication.clipboard().text().strip()
        if text:
            self.url_input.setText(text)
            self.status_label.setText(
                "Ready" if self.components_ready else "Setup incomplete"
            )

    def choose_folder(self):
        folder = QFileDialog.getExistingDirectory(
            self,
            "Choose Folder",
            self.download_folder,
        )
        if folder:
            self.download_folder = folder
            self.path_label.setText(folder)
            self.save_preferences()

    def clear_log(self):
        self.log_box.clear()
        self.last_log_message = ""
        if not self.running:
            self.status_label.setText(
                "Ready" if self.components_ready else "Setup incomplete"
            )
            self.progress_bar.setValue(0)

    def append_log(self, message):
        message = message.strip()
        if not message or message == self.last_log_message:
            return

        self.last_log_message = message
        cursor = self.log_box.textCursor()
        cursor.movePosition(QTextCursor.End)
        if not self.log_box.document().isEmpty():
            cursor.insertBlock()
        cursor.insertText(message)
        self.log_box.setTextCursor(cursor)

        scrollbar = self.log_box.verticalScrollBar()
        scrollbar.setValue(scrollbar.maximum())

    def download_or_cancel(self):
        if self.running:
            self.cancel_download()
        elif not self.components_ready:
            self.status_label.setText("Setup incomplete")
            self.append_log("Run Installer.bat again to repair the setup.")
        else:
            self.start_download()

    def validate_download_folder(self):
        try:
            folder = prepare_download_folder(self.download_folder)
        except (OSError, RuntimeError, ValueError) as error:
            self.status_label.setText("Choose another folder")
            self.append_log(f"Cannot save to that folder: {error}")
            return False

        self.download_folder = str(folder)
        self.path_label.setText(self.download_folder)
        self.save_preferences()
        return True

    def start_download(self):
        url = self.url_input.text().strip()
        if not url:
            self.status_label.setText("Paste a link")
            self.append_log("No URL entered.")
            return

        if not is_valid_download_url(url):
            self.status_label.setText("Invalid link")
            self.append_log("Enter a complete http:// or https:// link.")
            return

        if not self.validate_download_folder():
            return

        self.log_box.clear()
        self.last_log_message = ""
        self.progress_bar.setValue(0)
        self.cancel_requested = False
        self.process_pid = 0
        self.process_decoder = codecs.getincrementaldecoder("utf-8")(
            errors="replace"
        )
        self.process_line_buffer = ""
        self.process_messages = []

        args = build_download_arguments(
            url,
            self.download_folder,
            self.format_dropdown.currentText(),
            self.quality_dropdown.currentText(),
        )

        self.process = QProcess(self)
        self.process.setProcessEnvironment(qprocess_environment())
        self.process.setWorkingDirectory(str(APP_DIR))
        self.process.setProcessChannelMode(QProcess.MergedChannels)
        self.process.started.connect(self.process_started)
        self.process.readyReadStandardOutput.connect(self.read_process_output)
        self.process.finished.connect(self.process_finished)
        self.process.errorOccurred.connect(self.process_error)

        self.running = True
        self.download_button.setText("Cancel")
        self.status_label.setText("Starting…")
        self.set_controls_enabled(False)

        self.process.start(sys.executable, args)

    def set_controls_enabled(self, enabled):
        self.url_input.setEnabled(enabled)
        self.paste_button.setEnabled(enabled)
        self.browse_button.setEnabled(enabled)
        self.format_dropdown.setEnabled(enabled)
        self.quality_dropdown.setEnabled(
            enabled and self.format_dropdown.currentText() != "MP3"
        )

    def read_process_output(self):
        if not self.process or self.process_decoder is None:
            return

        while True:
            data = bytes(self.process.read(PROCESS_READ_CHUNK_BYTES))
            if not data:
                break
            self.consume_process_text(self.process_decoder.decode(data))

    def flush_process_output(self):
        if not self.process or self.process_decoder is None:
            return

        while True:
            data = bytes(self.process.read(PROCESS_READ_CHUNK_BYTES))
            if not data:
                break
            self.consume_process_text(self.process_decoder.decode(data))

        text = self.process_decoder.decode(b"", final=True)
        self.process_decoder = None
        self.consume_process_text(text, final=True)

    def consume_process_text(self, text, final=False):
        self.process_line_buffer += text

        while "\n" in self.process_line_buffer:
            raw_line, self.process_line_buffer = self.process_line_buffer.split(
                "\n", 1
            )
            self.handle_process_line(raw_line.rstrip("\r"))

        if final and self.process_line_buffer:
            self.handle_process_line(self.process_line_buffer.rstrip("\r"))
            self.process_line_buffer = ""
        elif not final:
            self.process_line_buffer = bounded_process_line(
                self.process_line_buffer
            )

    def handle_process_line(self, raw_line):
        oversized = len(raw_line) > (
            PROCESS_LINE_HEAD_CHARS + PROCESS_LINE_TAIL_CHARS
        )
        line = bounded_process_line(raw_line).strip()
        if not line:
            return

        match = self.PROGRESS_RE.search(line)
        if match and not oversized:
            percent_text, speed, eta = match.groups()

            try:
                percent = int(float(percent_text.strip()))
                self.progress_bar.setValue(max(0, min(percent, 100)))
            except ValueError:
                pass

            status_parts = [
                part.strip()
                for part in (speed, eta)
                if part.strip() and part.strip() != "NA"
            ]
            self.status_label.setText(" • ".join(status_parts) or "Downloading…")
            return

        clean_line = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", line)
        self.process_messages.append(clean_line)
        if len(self.process_messages) > 200:
            del self.process_messages[:-200]
        self.append_log(clean_line)

    def process_started(self):
        if self.process:
            self.process_pid = int(self.process.processId())
            if self.cancel_requested:
                self.process.terminate()

    def cancel_download(self):
        if self.process and self.process.state() != QProcess.NotRunning:
            self.cancel_requested = True
            self.status_label.setText("Stopping…")
            self.process_pid = int(self.process.processId()) or self.process_pid
            self.process.terminate()
            self.stop_timer.start(1200)

    @staticmethod
    def kill_process_tree(process_id):
        if os.name != "nt" or not process_id:
            return
        taskkill = system_taskkill_executable()
        if taskkill is None:
            return
        try:
            subprocess.run(
                [str(taskkill), "/PID", str(process_id), "/T", "/F"],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=5,
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
            )
        except (OSError, subprocess.SubprocessError):
            pass

    def force_stop_download(self):
        process = self.process
        if not process:
            return
        process_id = int(process.processId()) or self.process_pid
        self.kill_process_tree(process_id)
        if process.state() != QProcess.NotRunning:
            process.kill()

    def process_finished(self, exit_code, exit_status):
        self.flush_process_output()
        finished_process = self.process
        was_cancelled = self.cancel_requested
        process_id = self.process_pid
        self.stop_timer.stop()

        if was_cancelled:
            self.kill_process_tree(process_id)

        self.running = False
        self.download_button.setText("Download")
        self.set_controls_enabled(True)

        if was_cancelled:
            self.status_label.setText("Cancelled")
        elif exit_status == QProcess.NormalExit and exit_code == 0:
            self.progress_bar.setValue(100)
            self.status_label.setText("Done")
        else:
            self.status_label.setText("Failed")
            self.append_failure_summary(exit_code)

        self.process = None
        if finished_process is not None:
            finished_process.deleteLater()
        self.process_pid = 0
        self.cancel_requested = False
        self.process_decoder = None

    def append_failure_summary(self, exit_code):
        message = download_failure_message(self.process_messages)
        self.append_log(f"{message} (code {exit_code})")

    def process_error(self, error):
        failed_process = self.process
        error_text = failed_process.errorString() if failed_process else str(error)
        if error == QProcess.FailedToStart:
            self.append_log(f"Could not start the downloader: {error_text}")
            self.running = False
            self.stop_timer.stop()
            self.download_button.setText("Download")
            self.set_controls_enabled(True)
            self.status_label.setText("Failed")
            self.process = None
            if failed_process is not None:
                failed_process.deleteLater()
            self.process_pid = 0
            self.cancel_requested = False
            self.process_decoder = None
            return

        if error == QProcess.Crashed and self.cancel_requested:
            return
        if self.running:
            self.append_log(f"Downloader process error: {error_text}")

    def closeEvent(self, event: QCloseEvent):
        self.format_dropdown.hide_popup()
        self.quality_dropdown.hide_popup()
        self.save_preferences()
        if self.sites_window is not None:
            self.sites_window.close()

        if self.process and self.process.state() != QProcess.NotRunning:
            process = self.process
            process_id = int(process.processId()) or self.process_pid
            self.cancel_requested = True
            process.terminate()
            process.waitForFinished(750)
            self.kill_process_tree(process_id)
            if process.state() != QProcess.NotRunning:
                process.kill()
                process.waitForFinished(750)

        event.accept()


def run_self_test(output_dir):
    assert APP_VERSION == "1.0.15"
    output_dir = Path(output_dir).resolve()
    checks = []

    assert APP_DIR == Path(__file__).resolve().parent
    checks.append("application paths resolve beside the script")

    expected_interpreters = {
        os.path.normcase(os.path.realpath(path))
        for path in (VENV_PYTHON, VENV_PYTHONW, EMBEDDED_PYTHON, EMBEDDED_PYTHONW)
        if path.is_file()
    }
    assert os.path.normcase(os.path.realpath(sys.executable)) in expected_interpreters
    checks.append("the app is using its own private Python")

    runtime_path = runtime_path_value("")
    assert str(RUNTIME_DIR / "ffmpeg") in runtime_path
    assert str(RUNTIME_DIR / "deno") in runtime_path
    checks.append("the child-process path includes both private media runtimes")

    for command, argument, prefix in (
        ("ffmpeg", "-version", f"ffmpeg version {FFMPEG_VERSION}"),
        ("ffprobe", "-version", f"ffprobe version {FFMPEG_VERSION}"),
        ("deno", "--version", f"deno {DENO_VERSION}"),
    ):
        executable = local_runtime_executable(command)
        assert executable is not None
        assert VideoDownloader.command_starts_with([executable, argument], prefix)
    checks.append("FFmpeg, FFprobe, and Deno start without network access")

    assert metadata.version("PySide6-Essentials") == PYSIDE_VERSION
    assert metadata.version("yt-dlp") == YTDLP_VERSION
    assert metadata.version("yt-dlp-ejs") == YTDLP_EJS_VERSION
    checks.append("the pinned Python components match this release")

    class PreflightHarness:
        runtime_storage_error = ""
        components_ready = False
        component_issues = []

        class WidgetHarness:
            def setEnabled(self, value):
                raise AssertionError("healthy setup unexpectedly disabled downloads")

            def setText(self, value):
                raise AssertionError("healthy setup unexpectedly changed status")

        download_button = WidgetHarness()
        status_label = WidgetHarness()

        def append_log(self, message):
            raise AssertionError("healthy setup unexpectedly logged a repair error")

    original_subprocess_run = subprocess.run

    def reject_startup_subprocess(*args, **kwargs):
        raise AssertionError("startup readiness scan launched a child process")

    subprocess.run = reject_startup_subprocess
    try:
        preflight_harness = PreflightHarness()
        VideoDownloader.preflight_components(preflight_harness)
        assert preflight_harness.components_ready
        assert preflight_harness.component_issues == []
    finally:
        subprocess.run = original_subprocess_run
    checks.append("startup readiness scan uses only local metadata and paths")

    private_version_args = yt_dlp_arguments("--version")
    assert private_version_args == [
        "-I",
        "-m",
        "yt_dlp",
        "--ignore-config",
        "--no-plugin-dirs",
        "--version",
    ]
    assert VideoDownloader.command_works([sys.executable, *private_version_args])
    checks.append("yt-dlp starts isolated from user packages, plugins, and config")

    test_url = "https://example.invalid/watch?v=offline-test"
    mp4_args = build_download_arguments(test_url, output_dir, "MP4", "720p")
    mp3_args = build_download_arguments(test_url, output_dir, "MP3", "Best")
    assert 1 <= FRAGMENT_WORKERS <= 4
    assert mp4_args[:5] == [
        "-I",
        "-m",
        "yt_dlp",
        "--ignore-config",
        "--no-plugin-dirs",
    ]
    assert mp4_args[mp4_args.index("--concurrent-fragments") + 1] == str(
        FRAGMENT_WORKERS
    )
    assert "--check-formats" in mp4_args
    assert "--no-remote-components" in mp4_args
    assert "--no-js-runtimes" in mp4_args
    assert "--js-runtimes" in mp4_args
    assert "--ffmpeg-location" in mp4_args
    assert mp4_args[-3:] == ["--no-playlist", "--", test_url]
    assert mp4_args[mp4_args.index("-S") + 1] == "res:720"
    assert mp3_args[mp3_args.index("--audio-format") + 1] == "mp3"
    checks.append("download commands are private, bounded, and format-specific")

    assert is_valid_download_url("https://example.com/watch?v=1")
    assert not is_valid_download_url("ftp://example.com/file")
    assert not is_valid_download_url("http://[")
    assert not is_valid_download_url("https://[::1")
    checks.append("malformed and unsupported URLs are rejected without exceptions")

    with tempfile.TemporaryDirectory(prefix="fleece-video-folder-test-") as test_root:
        writable_folder = prepare_download_folder(Path(test_root) / "downloads")
        assert writable_folder.is_dir() and writable_folder.is_absolute()
        file_path = Path(test_root) / "not-a-folder"
        file_path.write_text("test", encoding="utf-8")
        try:
            prepare_download_folder(file_path)
        except OSError:
            pass
        else:
            raise AssertionError("a file path was accepted as a download folder")
    checks.append("download-folder preparation reports invalid paths safely")

    if os.name == "nt":
        taskkill_path = system_taskkill_executable()
        assert taskkill_path is not None and taskkill_path.is_absolute()
        assert taskkill_path.name.lower() == "taskkill.exe"
        assert taskkill_path.parent.name.lower() == "system32"
    checks.append("forced cancellation resolves taskkill from System32")

    class SitesCoordinationHarness:
        def __init__(self):
            self.list_process = None
            self.version_process = None
            self.loaded = True
            self.load_count = 0

        def load_sites(self):
            self.load_count += 1

    sites_harness = SitesCoordinationHarness()
    sites_harness.list_process = object()
    SitesWindow.refresh(sites_harness)
    assert sites_harness.load_count == 0
    sites_harness.list_process = None
    sites_harness.version_process = object()
    SitesWindow.refresh(sites_harness)
    assert sites_harness.load_count == 0
    active_list_process = sites_harness.list_process = object()
    SitesWindow.list_finished(sites_harness, object(), 0, None)
    assert sites_harness.list_process is active_list_process

    sites_close_calls = []

    class SitesCloseProcess:
        def state(self):
            return QProcess.Running

        def terminate(self):
            sites_close_calls.append("terminate")

        def waitForFinished(self, timeout):
            sites_close_calls.append(("wait", timeout))
            return False

        def kill(self):
            sites_close_calls.append("kill")

        def deleteLater(self):
            sites_close_calls.append("delete")

    class SitesCloseHarness:
        version_process = SitesCloseProcess()
        list_process = SitesCloseProcess()
        loaded = True

    sites_close_harness = SitesCloseHarness()
    sites_close_event = QCloseEvent()
    SitesWindow.closeEvent(sites_close_harness, sites_close_event)
    assert sites_close_event.isAccepted()
    assert sites_close_harness.version_process is None
    assert sites_close_harness.list_process is None
    assert not sites_close_harness.loaded
    assert sites_close_calls.count("terminate") == 2
    assert sites_close_calls.count("kill") == 2
    assert sites_close_calls.count("delete") == 2

    class LoadedSitesCloseHarness:
        version_process = None
        list_process = None
        loaded = True

    loaded_sites_harness = LoadedSitesCloseHarness()
    SitesWindow.closeEvent(loaded_sites_harness, QCloseEvent())
    assert loaded_sites_harness.loaded
    checks.append("supported-sites jobs close cleanly and stale callbacks cannot overlap")

    class SitesBufferProcess:
        def __init__(self, stdout=b"", stderr=b""):
            self.stdout = stdout
            self.stderr = stderr
            self.kill_count = 0

        def readAllStandardOutput(self):
            data, self.stdout = self.stdout, b""
            return data

        def readAllStandardError(self):
            data, self.stderr = self.stderr, b""
            return data

        def kill(self):
            self.kill_count += 1

    class SitesBufferHarness:
        def __init__(self, process):
            self.list_process = process
            self.output_buffer = bytearray()
            self.error_buffer = bytearray()
            self.output_truncated = False
            self.error_truncated = False

    stdout_process = SitesBufferProcess(
        stdout=b"x" * (SITES_STDOUT_MAX_BYTES + 257)
    )
    stdout_harness = SitesBufferHarness(stdout_process)
    SitesWindow.read_list_output(stdout_harness, stdout_process)
    assert len(stdout_harness.output_buffer) == SITES_STDOUT_MAX_BYTES
    assert stdout_harness.output_truncated
    assert stdout_process.kill_count == 1

    stderr_process = SitesBufferProcess(
        stderr=b"x" * (SITES_STDERR_MAX_BYTES + 257)
    )
    stderr_harness = SitesBufferHarness(stderr_process)
    SitesWindow.read_list_error(stderr_harness, stderr_process)
    assert len(stderr_harness.error_buffer) == SITES_STDERR_MAX_BYTES
    assert stderr_harness.error_truncated
    assert stderr_process.kill_count == 1
    checks.append("supported-sites child output is capped and oversized jobs stop")

    rejection = download_failure_message(
        [
            "ffmpeg version 9.0.2",
            "HTTP error 403 Forbidden",
            "ERROR: ffmpeg exited with code 1",
        ]
    )
    conversion = download_failure_message(["ERROR: ffmpeg exited with code 1"])
    assert rejection.startswith("The website rejected")
    assert conversion.startswith("FFmpeg could not complete")
    checks.append("media-request failures are not mislabeled as FFmpeg damage")

    normal_line = "normal yt-dlp output"
    assert bounded_process_line(normal_line) == normal_line
    error_tail = "HTTP error 403 Forbidden"
    preserved_head = "HEAD:" + "h" * (
        PROCESS_LINE_HEAD_CHARS - len("HEAD:")
    )
    preserved_tail = "t" * (
        PROCESS_LINE_TAIL_CHARS - len(error_tail)
    ) + error_tail
    oversized_line = preserved_head + "middle" * 10000 + preserved_tail
    expected_line = (
        preserved_head + PROCESS_LINE_TRUNCATION + preserved_tail
    )
    assert bounded_process_line(oversized_line) == expected_line
    assert expected_line.count(PROCESS_LINE_TRUNCATION) == 1
    assert download_failure_message([expected_line]).startswith(
        "The website rejected"
    )

    class OutputHarness:
        PROGRESS_RE = VideoDownloader.PROGRESS_RE

        def __init__(self):
            self.process_line_buffer = ""
            self.process_messages = []
            self.logged_lines = []

        def append_log(self, message):
            self.logged_lines.append(message)

        def handle_process_line(self, raw_line):
            VideoDownloader.handle_process_line(self, raw_line)

    displayed = OutputHarness()
    displayed.handle_process_line(oversized_line)
    assert displayed.process_messages == [expected_line]
    assert displayed.logged_lines == [expected_line]

    progress_prefix = "PROGRESS: 10%|1 MiB/s|3s"
    progress_head = progress_prefix + "p" * (
        PROCESS_LINE_HEAD_CHARS - len(progress_prefix)
    )
    oversized_progress = (
        progress_head + "middle" * 10000 + preserved_tail
    )
    expected_progress = (
        progress_head + PROCESS_LINE_TRUNCATION + preserved_tail
    )
    progress_display = OutputHarness()
    progress_display.handle_process_line(oversized_progress)
    assert progress_display.process_messages == [expected_progress]
    assert progress_display.logged_lines == [expected_progress]
    assert download_failure_message(
        progress_display.process_messages
    ).startswith("The website rejected")

    streamed = OutputHarness()
    for chunk in (
        preserved_head + "a" * 20000,
        "b" * 20000,
    ):
        VideoDownloader.consume_process_text(streamed, chunk)
        assert len(streamed.process_line_buffer) <= len(expected_line)
    VideoDownloader.consume_process_text(
        streamed,
        preserved_tail + "\nordinary\nunfinished",
        final=True,
    )
    assert streamed.process_line_buffer == ""
    assert streamed.process_messages == [
        expected_line,
        "ordinary",
        "unfinished",
    ]
    assert streamed.logged_lines == streamed.process_messages
    checks.append("oversized process output keeps bounded error context")

    if NATIVE_KERNEL32 is not None:
        test_name = rf"Local\FleeceVideoDownloaderSelfTest-{os.getpid()}"
        first_status, first_handle = _try_create_named_mutex(test_name)
        second_handle = None
        try:
            assert first_status == "acquired" and first_handle
            second_status, second_handle = _try_create_named_mutex(test_name)
            assert second_status == "exists" and second_handle is None
        finally:
            if second_handle:
                NATIVE_KERNEL32.CloseHandle(second_handle)
            if first_handle:
                NATIVE_KERNEL32.CloseHandle(first_handle)
    checks.append("a second app-instance mutex is rejected")

    output_dir.mkdir(parents=True, exist_ok=True)
    marker = output_dir / "self-test-passed.txt"
    marker.write_text("\n".join(checks) + "\n", encoding="utf-8")
    print(f"Video + Audio Downloader self-test passed ({len(checks)} checks).")
    return 0


def main():
    diagnostic_mode = "--self-test" in sys.argv
    if not diagnostic_mode:
        if not acquire_app_mutex():
            show_native_setup_error("Video + Audio Downloader is already open.")
            return 1
        if SETUP_LOCK_DIR.is_dir():
            release_app_mutex()
            show_native_setup_error(
                "Video + Audio Downloader setup is currently running.\n\n"
                "Let Installer.bat finish, then open the shortcut again."
            )
            return 1

    if diagnostic_mode:
        index = sys.argv.index("--self-test")
        output = (
            sys.argv[index + 1]
            if index + 1 < len(sys.argv)
            else RUNTIME_DIR / "self-test"
        )
        try:
            return run_self_test(output)
        except Exception:
            traceback.print_exc()
            return 1

    try:
        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(
            "fleece.video-downloader"
        )
    except (AttributeError, OSError):
        pass

    app = QApplication(sys.argv)
    app.setApplicationVersion(APP_VERSION)
    app.setApplicationName(APP_NAME)
    app.setOrganizationName("Fleece")
    app.setStyle("Fusion")
    sys.excepthook = handle_unhandled_exception

    window = VideoDownloader()
    window.show()

    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
