import codecs
import ctypes
import os
import re
import subprocess
import sys
import tempfile
import traceback
from importlib import metadata
from pathlib import Path
from urllib.parse import urlparse


APP_DIR = Path(__file__).resolve().parent
RUNTIME_DIR = APP_DIR / ".runtime"
VENV_PYTHONW = APP_DIR / ".venv" / "Scripts" / "pythonw.exe"
EMBEDDED_PYTHONW = RUNTIME_DIR / "python" / "pythonw.exe"
DENO_DATA_DIR = RUNTIME_DIR / "deno-data"
YTDLP_CACHE_DIR = RUNTIME_DIR / "yt-dlp-cache"
SETTINGS_PATH = RUNTIME_DIR / "settings.ini"


def show_native_setup_error(message):
    title = "Video Downloader"
    if os.name == "nt":
        ctypes.windll.user32.MessageBoxW(None, message, title, 0x10)
    else:
        print(f"{title}: {message}", file=sys.stderr)


def bootstrap_local_python():
    local_pythonw = next(
        (
            candidate
            for candidate in (VENV_PYTHONW, EMBEDDED_PYTHONW)
            if candidate.is_file()
        ),
        None,
    )
    if local_pythonw is None:
        show_native_setup_error(
            "Setup is missing or incomplete.\n\n"
            "Run Installer.bat, let it finish, then open this file again."
        )
        raise SystemExit(1)

    current = os.path.normcase(os.path.realpath(sys.executable))
    expected = os.path.normcase(os.path.realpath(local_pythonw))
    if current == expected:
        return

    try:
        subprocess.Popen(
            [str(local_pythonw), str(Path(__file__).resolve()), *sys.argv[1:]],
            cwd=str(APP_DIR),
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
    except OSError:
        show_native_setup_error(
            "The app's Python could not start.\n\n"
            "Run Installer.bat again to repair the setup."
        )
        raise SystemExit(1)

    raise SystemExit(0)


if __name__ == "__main__":
    bootstrap_local_python()


try:
    from PySide6.QtCore import (
        QEasingCurve,
        QEvent,
        QPoint,
        QParallelAnimationGroup,
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
        QGraphicsOpacityEffect,
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

        title = QLabel("Video Downloader")
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

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        self.button = ChevronButton(self._current)
        self.button.setObjectName("dropdownButton")
        self.button.setMinimumHeight(38)
        self.button.clicked.connect(self.toggle_popup)
        layout.addWidget(self.button)

        self.popup = QFrame(
            None,
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

        self.opacity_effect = QGraphicsOpacityEffect(self.popup)
        self.popup.setGraphicsEffect(self.opacity_effect)

    def currentText(self):
        return self._current

    def select(self, value):
        self._current = value
        self.button.setText(value)
        self.changed.emit(value)
        self.hide_popup()

    def toggle_popup(self):
        if self.popup.isVisible():
            self.hide_popup()
        else:
            self.show_popup()

    def show_popup(self):
        popup_height = len(self.items) * 34 + 12
        popup_width = self.width()

        button_top_left = self.mapToGlobal(QPoint(0, 0))
        below_y = button_top_left.y() + self.height() + 4

        screen = QApplication.screenAt(button_top_left)
        available = screen.availableGeometry() if screen else QRect()

        if available and below_y + popup_height > available.bottom():
            final_y = button_top_left.y() - popup_height - 4
            start_y = final_y + 8
        else:
            final_y = below_y
            start_y = final_y - 8

        end_rect = QRect(
            button_top_left.x(),
            final_y,
            popup_width,
            popup_height,
        )
        start_rect = QRect(
            button_top_left.x(),
            start_y,
            popup_width,
            popup_height,
        )

        QApplication.instance().installEventFilter(self)

        self.popup.setGeometry(start_rect)
        self.opacity_effect.setOpacity(0.0)
        self.popup.show()
        self.popup.raise_()

        geometry_animation = QPropertyAnimation(self.popup, b"geometry")
        geometry_animation.setDuration(150)
        geometry_animation.setStartValue(start_rect)
        geometry_animation.setEndValue(end_rect)
        geometry_animation.setEasingCurve(QEasingCurve.OutCubic)

        opacity_animation = QPropertyAnimation(
            self.opacity_effect,
            b"opacity",
        )
        opacity_animation.setDuration(150)
        opacity_animation.setStartValue(0.0)
        opacity_animation.setEndValue(1.0)
        opacity_animation.setEasingCurve(QEasingCurve.OutCubic)

        group = QParallelAnimationGroup(self)
        group.addAnimation(geometry_animation)
        group.addAnimation(opacity_animation)

        self._animation = group
        group.start()

    def hide_popup(self):
        if not self.popup.isVisible():
            return

        QApplication.instance().removeEventFilter(self)

        current_rect = self.popup.geometry()
        end_rect = QRect(
            current_rect.x(),
            current_rect.y() - 5,
            current_rect.width(),
            current_rect.height(),
        )

        geometry_animation = QPropertyAnimation(self.popup, b"geometry")
        geometry_animation.setDuration(100)
        geometry_animation.setStartValue(current_rect)
        geometry_animation.setEndValue(end_rect)
        geometry_animation.setEasingCurve(QEasingCurve.InCubic)

        opacity_animation = QPropertyAnimation(
            self.opacity_effect,
            b"opacity",
        )
        opacity_animation.setDuration(100)
        opacity_animation.setStartValue(self.opacity_effect.opacity())
        opacity_animation.setEndValue(0.0)
        opacity_animation.setEasingCurve(QEasingCurve.InCubic)

        group = QParallelAnimationGroup(self)
        group.addAnimation(geometry_animation)
        group.addAnimation(opacity_animation)
        group.finished.connect(self.popup.hide)

        self._animation = group
        group.start()

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
        if self.list_process is not None:
            return
        self.loaded = False
        self.load_sites()

    def load_sites(self):
        if self.list_process is not None:
            return

        self.list_widget.clear()
        self.output_buffer.clear()
        self.error_buffer.clear()
        self.count_label.setText("Loading…")

        self.version_process = QProcess(self)
        self.version_process.setProcessEnvironment(qprocess_environment())
        self.version_process.setWorkingDirectory(str(APP_DIR))
        self.version_process.finished.connect(self.version_finished)
        self.version_process.errorOccurred.connect(self.version_error)
        self.version_process.start(
            self.python_path,
            ["-m", "yt_dlp", "--ignore-config", "--version"],
        )

        self.list_process = QProcess(self)
        self.list_process.setProcessEnvironment(qprocess_environment())
        self.list_process.setWorkingDirectory(str(APP_DIR))
        self.list_process.readyReadStandardOutput.connect(self.read_list_output)
        self.list_process.readyReadStandardError.connect(self.read_list_error)
        self.list_process.finished.connect(self.list_finished)
        self.list_process.errorOccurred.connect(self.list_error)
        self.list_process.start(
            self.python_path,
            [
                "-m",
                "yt_dlp",
                "--ignore-config",
                "--no-warnings",
                "--list-extractors",
            ],
        )

    def read_list_output(self):
        if not self.list_process:
            return
        self.output_buffer.extend(bytes(self.list_process.readAllStandardOutput()))

    def read_list_error(self):
        if not self.list_process:
            return
        self.error_buffer.extend(bytes(self.list_process.readAllStandardError()))

    def show_list_failure(self):
        error_text = self.error_buffer.decode("utf-8", errors="replace").strip()
        self.count_label.setText(
            "Could not run yt-dlp. Re-run installer.bat to repair setup."
        )
        self.count_label.setToolTip(error_text[-1000:] if error_text else "")

    def version_finished(self, exit_code, exit_status):
        version = ""
        if self.version_process and exit_code == 0:
            version = bytes(
                self.version_process.readAllStandardOutput()
            ).decode("utf-8", errors="replace").strip()
        self.version_process = None

        if version:
            self.note_label.setText(
                f"From yt-dlp {version} installed on this PC. Re-run "
                "installer.bat to update yt-dlp and this list."
            )

    def version_error(self, error):
        if self.version_process and error == QProcess.FailedToStart:
            self.version_process = None

    def list_finished(self, exit_code, exit_status):
        self.read_list_output()
        self.read_list_error()
        self.list_process = None
        self.loaded = True

        if exit_code != 0:
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

    def list_error(self, error):
        self.read_list_error()
        self.list_process = None
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
        for process in (self.version_process, self.list_process):
            if process and process.state() != QProcess.NotRunning:
                process.terminate()
                if not process.waitForFinished(400):
                    process.kill()
                    process.waitForFinished(400)
        event.accept()


class VideoDownloader(QMainWindow):
    PROGRESS_RE = re.compile(
        r"PROGRESS:\s*([0-9.]+)%\|([^|]*)\|([^|]*)"
    )

    def __init__(self):
        super().__init__()

        self.setWindowTitle("Video Downloader")
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

    def preflight_components(self):
        issues = []

        if self.runtime_storage_error:
            issues.append("local runtime folder")

        if not self.command_works(
            [sys.executable, "-m", "yt_dlp", "--ignore-config", "--version"]
        ):
            issues.append("yt-dlp")

        try:
            metadata.version("yt-dlp-ejs")
        except metadata.PackageNotFoundError:
            issues.append("YouTube support")

        for command, label in (
            ("ffmpeg", "FFmpeg"),
            ("ffprobe", "FFprobe"),
            ("deno", "Deno"),
        ):
            executable = local_runtime_executable(command)
            if executable is None or not self.command_works(
                [executable, "--version" if command == "deno" else "-version"]
            ):
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
        folder = Path(self.download_folder).expanduser()
        try:
            folder.mkdir(parents=True, exist_ok=True)
            if not folder.is_dir():
                raise OSError("The selected path is not a folder.")
            with tempfile.NamedTemporaryFile(dir=folder):
                pass
        except OSError as error:
            self.status_label.setText("Choose another folder")
            self.append_log(f"Cannot save to that folder: {error}")
            return False

        self.download_folder = str(folder.resolve())
        self.path_label.setText(self.download_folder)
        self.save_preferences()
        return True

    def start_download(self):
        url = self.url_input.text().strip()
        if not url:
            self.status_label.setText("Paste a link")
            self.append_log("No URL entered.")
            return

        parsed_url = urlparse(url)
        if parsed_url.scheme.lower() not in {"http", "https"} or not parsed_url.netloc:
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

        args = [
            "-m",
            "yt_dlp",
            "--ignore-config",
            "--newline",
            "--windows-filenames",
            "--cache-dir",
            str(YTDLP_CACHE_DIR),
            "--concurrent-fragments",
            "8",
            "--progress-template",
            "download:PROGRESS:%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s",
            "-P",
            self.download_folder,
        ]

        ffmpeg_executable = local_runtime_executable("ffmpeg")
        if ffmpeg_executable is not None:
            args.extend(["--ffmpeg-location", str(ffmpeg_executable.parent)])

        if self.format_dropdown.currentText() == "MP3":
            args.extend(["-x", "--audio-format", "mp3", "--audio-quality", "0"])
        else:
            args.extend(["-t", "mp4"])
            quality = self.quality_dropdown.currentText()
            if quality != "Best":
                height = quality.removesuffix("p")
                args.extend(["-S", f"res:{height}"])

        args.extend(["--no-playlist", "--", url])

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

        data = bytes(self.process.readAllStandardOutput())
        if data:
            self.consume_process_text(self.process_decoder.decode(data))

    def flush_process_output(self):
        if not self.process or self.process_decoder is None:
            return

        data = bytes(self.process.readAllStandardOutput())
        text = self.process_decoder.decode(data, final=True)
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

    def handle_process_line(self, raw_line):
        line = raw_line.strip()
        if not line:
            return

        match = self.PROGRESS_RE.search(line)
        if match:
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
        try:
            subprocess.run(
                ["taskkill", "/PID", str(process_id), "/T", "/F"],
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
        elif exit_code == 0:
            self.progress_bar.setValue(100)
            self.status_label.setText("Done")
        else:
            self.status_label.setText("Failed")
            self.append_failure_summary(exit_code)

        self.process = None
        self.process_pid = 0
        self.cancel_requested = False
        self.process_decoder = None

    def append_failure_summary(self, exit_code):
        output = "\n".join(self.process_messages).lower()
        if "unsupported url" in output:
            message = "That website or link is not supported."
        elif "requested format is not available" in output:
            message = "That quality is unavailable. Try Best or another quality."
        elif "ffmpeg" in output or "ffprobe" in output:
            message = "FFmpeg could not be used. Run Installer.bat again."
        elif "javascript runtime" in output or "yt-dlp-ejs" in output:
            message = "YouTube support is incomplete. Run Installer.bat again."
        elif "http error 403" in output or "http error 429" in output:
            message = "The website blocked the request. Wait a while and try again."
        elif "sign in" in output or "private video" in output:
            message = "That video may be private or require an account."
        else:
            message = "The download failed. Check the messages above for details."
        self.append_log(f"{message} (code {exit_code})")

    def process_error(self, error):
        error_text = self.process.errorString() if self.process else str(error)
        if error == QProcess.FailedToStart:
            self.append_log(f"Could not start the downloader: {error_text}")
            self.running = False
            self.stop_timer.stop()
            self.download_button.setText("Download")
            self.set_controls_enabled(True)
            self.status_label.setText("Failed")
            self.process = None
            self.process_pid = 0
            self.cancel_requested = False
            self.process_decoder = None
            return

        if error == QProcess.Crashed and self.cancel_requested:
            return
        if self.running:
            self.append_log(f"Downloader process error: {error_text}")

    def closeEvent(self, event: QCloseEvent):
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


if __name__ == "__main__":
    app = QApplication(sys.argv)
    app.setStyle("Fusion")
    sys.excepthook = handle_unhandled_exception

    window = VideoDownloader()
    window.show()

    sys.exit(app.exec())
