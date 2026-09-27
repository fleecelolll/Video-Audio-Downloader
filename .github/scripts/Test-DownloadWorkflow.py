"""Exercise one real offline media download through the released app's command builder."""

from __future__ import annotations

import functools
import http.server
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
import threading


def run(*command: str, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command,
        check=False,
        capture_output=True,
        text=True,
        timeout=120,
        env=env,
    )
    if result.returncode:
        raise AssertionError(
            f"Workflow command failed ({result.returncode}): {command}\n"
            f"stdout: {result.stdout[-4000:]}\nstderr: {result.stderr[-4000:]}"
        )
    return result


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, _format: str, *_args: object) -> None:
        pass


def main() -> None:
    root = Path(sys.argv[1]).resolve()
    app_file = root / "Video + Audio Downloader.pyw"
    ffmpeg = root / ".runtime" / "ffmpeg" / "ffmpeg.exe"
    ffprobe = root / ".runtime" / "ffmpeg" / "ffprobe.exe"
    for path in (app_file, ffmpeg, ffprobe):
        assert path.is_file(), f"Missing installed component: {path.name}"
    app = runpy.run_path(str(app_file), run_name="video_release_workflow")

    with tempfile.TemporaryDirectory(prefix="fleece-media-workflow-") as temporary:
        fixture = Path(temporary)
        source = fixture / "source.wav"
        output = fixture / "saved media"
        output.mkdir()
        run(
            str(ffmpeg),
            "-hide_banner", "-loglevel", "error", "-nostdin",
            "-f", "lavfi", "-i", "sine=frequency=440:duration=1",
            "-c:a", "pcm_s16le", str(source),
        )
        assert source.stat().st_size > 1000

        handler = functools.partial(QuietHandler, directory=str(fixture))
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            url = f"http://127.0.0.1:{server.server_port}/source.wav"
            assert app["is_valid_download_url"](url)
            command = [
                sys.executable,
                *app["build_download_arguments"](url, output, "MP3", "Best"),
            ]
            environment = app["subprocess_environment"]()
            run(*command, env=environment)
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=5)

        files = list(output.glob("*.mp3"))
        assert len(files) == 1, f"Expected exactly one MP3, found: {list(output.iterdir())}"
        assert files[0].stat().st_size > 1000
        probe = run(
            str(ffprobe), "-v", "error", "-show_entries",
            "format=format_name,duration", "-of", "json", str(files[0]),
        )
        metadata = json.loads(probe.stdout)["format"]
        assert "mp3" in metadata["format_name"]
        assert float(metadata["duration"]) > 0.5
    print("Real local WAV-to-MP3 download and conversion passed through the app command builder.")


if __name__ == "__main__":
    main()
