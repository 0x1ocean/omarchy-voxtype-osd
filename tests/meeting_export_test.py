import importlib.machinery
import importlib.util
from contextlib import closing
import json
from pathlib import Path
import sqlite3
import subprocess
import tempfile
import unittest
from unittest.mock import patch

script = Path(__file__).resolve().parents[1] / "scripts/voxtype-meeting-export"
loader = importlib.machinery.SourceFileLoader("meeting_export", str(script))
spec = importlib.util.spec_from_loader(loader.name, loader)
exporter = importlib.util.module_from_spec(spec)
loader.exec_module(exporter)


class MeetingExportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.database = self.root / "index.db"
        self.notes = self.root / "notes/meetings"
        self.state = self.root / "state/exports.json"
        with closing(sqlite3.connect(self.database)) as db, db:
            db.execute("CREATE TABLE meetings (id TEXT, started_at INTEGER, status TEXT, storage_path TEXT, chunk_count INTEGER)")
        self.render = patch.object(exporter.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "# Test meeting\n\n**You** [00:01]: Hello\n"))
        self.cli = self.render.start()
        self.addCleanup(self.render.stop)

    def meeting(self, number=1, status="completed", ready=True):
        meeting_id = f"00000000-0000-0000-0000-{number:012d}"
        folder = self.root / meeting_id
        folder.mkdir()
        if ready:
            (folder / "transcript.json").write_text(json.dumps({"total_chunks": 2, "segments": []}))
        with closing(sqlite3.connect(self.database)) as db, db:
            db.execute("INSERT INTO meetings VALUES (?, ?, ?, ?, 2)", (meeting_id, 1700000000 + number, status, str(folder)))
        return meeting_id, folder

    def run_export(self):
        return exporter.export_completed(self.database, self.notes, self.state)

    def test_completed_only_and_preserves_user_edits_on_retry(self):
        meeting_id, _ = self.meeting()
        self.meeting(2, status="active")
        self.assertEqual(self.run_export(), 0)
        files = list(self.notes.glob("*.md"))
        self.assertEqual(len(files), 1)
        self.assertIn(meeting_id, files[0].read_text())
        self.assertIn("--timestamps", self.cli.call_args.args[0])
        files[0].write_text("My edited notes")
        self.assertEqual(self.run_export(), 0)
        self.assertEqual(files[0].read_text(), "My edited notes")
        self.assertEqual(self.cli.call_count, 1)

    def test_failed_export_retries_without_a_partial_note(self):
        self.meeting()
        self.cli.side_effect = subprocess.CalledProcessError(1, ["voxtype"])
        self.assertEqual(self.run_export(), 1)
        self.assertEqual(list(self.notes.glob("*.md")), [])
        self.assertFalse(self.state.exists())
        self.cli.side_effect = None
        self.assertEqual(self.run_export(), 0)
        self.assertEqual(len(list(self.notes.glob("*.md"))), 1)

    def test_waits_for_complete_transcript_even_if_index_is_completed(self):
        _, folder = self.meeting(ready=False)
        self.assertEqual(self.run_export(), 1)
        (folder / "transcript.json").write_text('{"total_chunks":1}')
        self.assertEqual(self.run_export(), 1)
        self.cli.assert_not_called()
        (folder / "transcript.json").write_text('{"total_chunks":2}')
        self.assertEqual(self.run_export(), 0)
        self.cli.assert_called_once()

    def test_recovers_receipt_after_interruption_without_duplicate_note(self):
        self.meeting()
        self.assertEqual(self.run_export(), 0)
        self.state.unlink()
        self.assertEqual(self.run_export(), 0)
        self.assertEqual(len(list(self.notes.glob("*.md"))), 1)
        self.cli.assert_called_once()

    def test_malformed_transcript_does_not_block_other_meetings(self):
        _, folder = self.meeting()
        (folder / "transcript.json").write_text('[]')
        second_id, _ = self.meeting(2)
        self.assertEqual(self.run_export(), 1)
        files = list(self.notes.glob("*.md"))
        self.assertEqual(len(files), 1)
        self.assertIn(second_id, files[0].read_text())

    def test_changed_transcript_is_retried_without_publishing(self):
        _, folder = self.meeting()
        def mutate(*args, **kwargs):
            (folder / "transcript.json").write_text('{"total_chunks":3}')
            return subprocess.CompletedProcess([], 0, "# Incomplete export")
        self.cli.side_effect = mutate
        self.assertEqual(self.run_export(), 1)
        self.assertEqual(list(self.notes.glob("*.md")), [])

    def test_filename_collision_preserves_unrelated_note(self):
        meeting_id, _ = self.meeting()
        date = exporter.datetime.fromtimestamp(1700000001).astimezone()
        self.notes.mkdir(parents=True)
        existing = self.notes / f"{date:%Y-%m-%d %H-%M-%S} {meeting_id[:8]}.md"
        existing.write_text("My own note")
        self.assertEqual(self.run_export(), 0)
        self.assertEqual(existing.read_text(), "My own note")
        self.assertEqual(len(list(self.notes.glob("*.md"))), 2)

    def test_removed_exported_note_is_not_recreated(self):
        self.meeting()
        self.assertEqual(self.run_export(), 0)
        next(self.notes.glob("*.md")).unlink()
        self.assertEqual(self.run_export(), 0)
        self.assertEqual(list(self.notes.glob("*.md")), [])
        self.cli.assert_called_once()


if __name__ == "__main__":
    unittest.main()
