#!/usr/bin/env python3
"""Run headless QML tests with disposable clock checkpoints, without recording."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

runner = shutil.which("qmltestrunner6") or shutil.which("qmltestrunner")
if not runner and Path("/usr/lib/qt6/bin/qmltestrunner").exists():
    runner = "/usr/lib/qt6/bin/qmltestrunner"
if not runner:
    sys.exit("Qt 6 qmltestrunner is required for QML integration tests")

with tempfile.TemporaryDirectory(prefix="voxwave-qml-") as directory:
    for name in ("early", "late"):
        folder = Path(directory) / name
        folder.mkdir()
        (folder / "voxwave-meeting-clock.json").write_text(json.dumps({
            "id": "test-meeting", "state": "paused", "startedAtMs": 100000,
            "pausedAtMs": 165000, "pausedTotalMs": 5000,
        }))
    environment = {**os.environ, "QT_QPA_PLATFORM": "offscreen", "VOXWAVE_TEST_RUNTIME": directory}
    result = subprocess.run(
        [runner, "-input", str(Path(__file__).parent / "qml")],
        env=environment,
        timeout=60,
    )
    if result.returncode:
        sys.exit(result.returncode)
    # Quickshell's QML modules are embedded in its executable, not loadable
    # plugins for qmltestrunner. Exercise actual FileViews/processes in that host.
    repository = Path(__file__).resolve().parent.parent
    # Quickshell requires imported components to live under its config root.
    for relative in ("components/MeetingSession.qml", "components/RestartingStream.qml", "lib/MeetingClock.js"):
        target = Path(directory) / relative
        target.parent.mkdir(exist_ok=True)
        shutil.copyfile(repository / relative, target)
    harness = Path(directory) / "shell.qml"
    harness.write_text((repository / "tests/integration/shell.qml").read_text()
                       .replace('"../../components"', '"components"'))
    result = subprocess.run(
        ["quickshell", "--no-color", "-p", str(harness)],
        env=environment, capture_output=True, text=True, timeout=15,
    )
    output = result.stdout + result.stderr
    if result.returncode or "PASS: SessionIO (3 scenarios)" not in output or "FAIL:" in output:
        print(output)
        sys.exit(1)
    print("PASS: SessionIO (3 scenarios)")
