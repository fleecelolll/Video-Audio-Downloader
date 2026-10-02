"""Synthetic offline regressions. No real downloads, account state or UI control.

Run with this app's private python.exe -I, optionally --output PATH.json.
"""
import argparse
import codecs
import importlib.machinery
import importlib.util
import inspect
import json
import os
import sys
import tempfile
import threading
import time
import tracemalloc
import unittest
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
APP_DIR = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader("audit_downloader", str(APP_DIR / "Video + Audio Downloader.pyw"))
spec = importlib.util.spec_from_loader(loader.name, loader)
dl = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = dl
loader.exec_module(dl)
app = dl.QApplication.instance() or dl.QApplication([])
app.setStyle("Fusion")
metrics = {"network_requests": 0, "real_media_downloads": 0, "synthetic_only": True}


class OfflineRegression(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="downloader-offline-audit-")
        self.settings_patch = patch.object(dl, "SETTINGS_PATH", Path(self.temporary.name) / "settings.ini")
        self.settings_patch.start()
        before = time.perf_counter()
        self.window = dl.VideoDownloader()
        metrics["max_startup_seconds"] = max(metrics.get("max_startup_seconds", 0), time.perf_counter() - before)
        self.assertLess(metrics["max_startup_seconds"], 5)

    def tearDown(self):
        if self.window.process is not None and not isinstance(self.window.process, dl.QProcess):
            self.window.process = None
            self.window.running = False
        self.window.close()
        self.window.deleteLater()
        app.processEvents()
        self.settings_patch.stop()
        self.temporary.cleanup()

    def test_url_validation(self):
        for url in (None, 12, "", "ftp://example.invalid/file", "http://[", "https://example.invalid:bad/a", "https://example.invalid:70000/a", "https://example.invalid:0/a", "https://user:secret@example.invalid/a", "https://exa mple.invalid/a", "https://example.invalid\n.evil.invalid/a", "https://example.invalid/\x00"):
            with self.subTest(url=url):
                self.assertFalse(dl.is_valid_download_url(url))
        for url in ("https://example.invalid/watch?v=a%20b", "https://[::1]:443/watch", "HTTP://example.invalid:80/watch", "https://例え.test/watch"):
            self.assertTrue(dl.is_valid_download_url(url))

    def test_folder_safety(self):
        root = Path(self.temporary.name)
        target = root / "synthetic existing.txt"
        target.write_text("do not overwrite", encoding="utf-8")
        with self.assertRaises(OSError):
            dl.prepare_download_folder(target)
        self.assertEqual(target.read_text(encoding="utf-8"), "do not overwrite")
        folder = dl.prepare_download_folder(root / "new folder")
        self.assertTrue(folder.is_absolute())
        self.assertEqual(list(folder.iterdir()), [])

    def test_argument_isolation_and_missing_dependency(self):
        url = "https://example.invalid/watch?v=x&y=1"
        with patch.object(dl, "local_runtime_executable", return_value=None):
            args = dl.build_download_arguments(url, Path(self.temporary.name), "MP3", "Best")
            self.assertEqual(args[-2:], ["--", url])
            self.assertIn("--no-remote-components", args)
            dl.VideoDownloader.preflight_components(self.window)
        self.assertFalse(self.window.components_ready)
        self.assertEqual(self.window.status_label.text(), "Setup incomplete")
        self.assertIn("FFmpeg", self.window.component_issues)
        self.assertFalse(self.window.download_button.isEnabled())

    def test_parse_linear_and_bounded_history(self):
        class Parser:
            process_line_buffer = ""
            lines = 0
            def handle_process_line(self, line):
                self.lines += 1
        parser = Parser()
        tracemalloc.start()
        before = time.perf_counter()
        dl.VideoDownloader.consume_process_text(parser, "synthetic-output\n" * 40000)
        elapsed = time.perf_counter() - before
        peak = tracemalloc.get_traced_memory()[1]
        tracemalloc.stop()
        self.assertEqual(parser.lines, 40000)
        self.assertLess(elapsed, 0.25)
        self.assertLess(peak, 8 * 1024 * 1024)
        metrics.update(parse_40k_lines_seconds=elapsed, parse_40k_lines_peak_bytes=peak)
        self.window.consume_process_text("\n".join(str(index) for index in range(1700)) + "\n")
        self.assertEqual(len(self.window.process_messages), 200)
        self.assertLessEqual(self.window.log_box.document().blockCount(), 1500)

    def test_plain_logs_progress_and_split_utf8(self):
        self.window.append_log("<b>synthetic plain text</b>")
        self.assertIn("<b>synthetic plain text</b>", self.window.log_box.toPlainText())
        decoder = codecs.getincrementaldecoder("utf-8")(errors="replace")
        data = "synthetic café 🚀\n".encode()
        for byte in data:
            self.window.consume_process_text(decoder.decode(bytes([byte])))
        self.window.consume_process_text(decoder.decode(b"", final=True), final=True)
        self.assertEqual(self.window.process_messages[-1], "synthetic café 🚀")
        self.window.handle_process_line("PROGRESS: 42.2%|1 MiB/s|3s")
        self.assertEqual(self.window.progress_bar.value(), 42)
        self.window.handle_process_line("PROGRESS: ....%|NA|NA")

    def test_stale_callbacks_and_duplicate_start(self):
        process = self.window.process = object()
        self.window.running = True
        self.window.url_input.setText("https://example.invalid/watch")
        with patch.object(self.window, "validate_download_folder", side_effect=AssertionError("duplicate launch")):
            self.window.start_download()
        old = object()
        self.window.process_finished(1, dl.QProcess.CrashExit, old)
        self.window.process_error(dl.QProcess.FailedToStart, old)
        self.window.process_started(old)
        self.window.read_process_output(old)
        self.assertIs(self.window.process, process)
        self.assertTrue(self.window.running)
        self.window.process = None
        self.window.running = False

    def test_persistence_failure_and_recovery(self):
        class Settings:
            error = True
            def setValue(self, *values):
                pass
            def sync(self):
                pass
            def status(self):
                return dl.QSettings.Status.AccessError if self.error else dl.QSettings.Status.NoError
        original = self.window.settings
        settings = self.window.settings = Settings()
        try:
            self.assertFalse(self.window.save_preferences())
            self.assertFalse(self.window.save_preferences())
            self.assertEqual(self.window.log_box.toPlainText().count("Local preferences could not be saved"), 1)
            settings.error = False
            self.assertTrue(self.window.save_preferences())
            self.assertFalse(self.window._settings_error_reported)
        finally:
            self.window.settings = original

    def test_failure_messages_actionable(self):
        for text in ("getaddrinfo failed", "read timed out", "connection refused"):
            self.assertIn("Check the connection", dl.download_failure_message([text]))
        self.assertIn("system clock", dl.download_failure_message(["CERTIFICATE_VERIFY_FAILED"]))
        self.assertTrue(dl.download_failure_message(["HTTP error 403", "ffmpeg exited with code 1"]).startswith("The website rejected"))

    def test_cancel_tree_does_not_block_event_loop(self):
        started = threading.Event()
        release = threading.Event()
        class Process:
            kills = 0
            def processId(self):
                return 12345
            def state(self):
                return dl.QProcess.Running
            def kill(self):
                self.kills += 1
        process = self.window.process = Process()
        def fake_tree_stop(pid):
            started.set()
            release.wait(2)
        with patch.object(self.window, "kill_process_tree", side_effect=fake_tree_stop):
            before = time.perf_counter()
            self.window.force_stop_download()
            elapsed = time.perf_counter() - before
            self.assertLess(elapsed, 0.1)
            self.assertTrue(started.wait(1))
            marker = []
            dl.QTimer.singleShot(0, lambda: marker.append(True))
            app.processEvents()
            self.assertEqual(marker, [True])
            release.set()
            deadline = time.perf_counter() + 1
            while not process.kills and time.perf_counter() < deadline:
                app.processEvents()
                time.sleep(0.001)
            self.assertEqual(process.kills, 1)
        metrics["cancel_dispatch_seconds"] = elapsed
        self.window.process = None

    def test_synthetic_child_output_event_responsiveness(self):
        window = self.window
        process = window.process = dl.QProcess(window)
        window.process_decoder = codecs.getincrementaldecoder("utf-8")(errors="replace")
        window.running = True
        process.setProcessChannelMode(dl.QProcess.MergedChannels)
        if len(inspect.signature(window.read_process_output).parameters):
            process.readyReadStandardOutput.connect(lambda: window.read_process_output(process))
            process.finished.connect(lambda code, status: window.process_finished(code, status, process))
        else:
            process.readyReadStandardOutput.connect(window.read_process_output)
            process.finished.connect(window.process_finished)
        ticks = []
        timer = dl.QTimer()
        timer.setInterval(5)
        timer.timeout.connect(lambda: ticks.append(time.perf_counter()))
        timer.start()
        before = time.perf_counter()
        process.start(sys.executable, ["-I", "-c", "import sys; sys.stdout.write(''.join(f'synthetic-line-{i}\\n' for i in range(10000))); sys.stdout.flush()"])
        deadline = time.perf_counter() + 8
        while window.running and time.perf_counter() < deadline:
            app.processEvents()
            time.sleep(0.001)
        timer.stop()
        self.assertFalse(window.running)
        self.assertEqual(window.status_label.text(), "Done")
        self.assertGreater(len(ticks), 2)
        max_gap = max(b - a for a, b in zip(ticks, ticks[1:]))
        elapsed = time.perf_counter() - before
        self.assertLess(max_gap, 0.25)
        self.assertLess(elapsed, 8)
        self.assertLessEqual(len(window.process_messages), 200)
        metrics.update(synthetic_child_lines=10000, synthetic_child_seconds=elapsed, output_timer_ticks=len(ticks), output_max_timer_gap_seconds=max_gap)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    options = parser.parse_args()
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(OfflineRegression))
    metrics.update(tests=result.testsRun, failures=len(result.failures), errors=len(result.errors), limits={"startup_seconds": 5, "parse_seconds": 0.25, "parse_peak_bytes": 8388608, "cancel_dispatch_seconds": 0.1, "child_seconds": 8, "timer_gap_seconds": 0.25})
    if options.output:
        options.output.parent.mkdir(parents=True, exist_ok=True)
        options.output.write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(metrics, indent=2))
    raise SystemExit(not result.wasSuccessful())
