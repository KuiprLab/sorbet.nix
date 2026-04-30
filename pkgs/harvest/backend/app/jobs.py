"""In-memory job tracker for downloads + post-completion file moves."""

from __future__ import annotations

import asyncio
import shutil
import time
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from .config import Settings
from .slskd import SlskdClient


@dataclass
class Job:
    id: str
    title: str
    artist: str
    target_folder: str
    target_path: str
    peer: str
    files: list[dict[str, Any]]
    state: str = "queued"  # queued | downloading | moving | done | error
    message: str = ""
    started_at: float = field(default_factory=time.time)
    finished_at: float | None = None


class JobManager:
    def __init__(self, settings: Settings, slskd: SlskdClient) -> None:
        self._settings = settings
        self._slskd = slskd
        self._jobs: dict[str, Job] = {}
        self._tasks: dict[str, asyncio.Task[None]] = {}
        self._lock = asyncio.Lock()

    def list_jobs(self) -> list[Job]:
        return sorted(self._jobs.values(), key=lambda j: j.started_at, reverse=True)

    def get(self, job_id: str) -> Job | None:
        return self._jobs.get(job_id)

    async def submit(
        self,
        *,
        title: str,
        artist: str,
        target_folder_label: str,
        peer: str,
        files: list[dict[str, Any]],
    ) -> Job:
        target_path = self._settings.target_folders.get(target_folder_label)
        if not target_path:
            raise ValueError(f"Unknown target folder: {target_folder_label!r}")
        job = Job(
            id=uuid.uuid4().hex[:12],
            title=title,
            artist=artist,
            target_folder=target_folder_label,
            target_path=target_path,
            peer=peer,
            files=files,
        )
        async with self._lock:
            self._jobs[job.id] = job
            self._tasks[job.id] = asyncio.create_task(self._run(job))
        return job

    async def _run(self, job: Job) -> None:
        try:
            job.state = "downloading"
            job.message = f"Queueing {len(job.files)} file(s) from {job.peer}"
            await self._slskd.enqueue_downloads(job.peer, job.files)

            # Track expected filenames (basename) on disk.
            expected = [
                Path(f["filename"]).name for f in job.files if f.get("filename")
            ]
            await self._wait_for_completion(job, expected)

            job.state = "moving"
            job.message = f"Moving to {job.target_path}"
            moved = self._move_results(job, expected)
            job.message = f"Moved {moved} file(s) to {job.target_path}"
            job.state = "done"
        except Exception as exc:  # noqa: BLE001
            job.state = "error"
            job.message = f"{type(exc).__name__}: {exc}"
        finally:
            job.finished_at = time.time()

    async def _wait_for_completion(self, job: Job, expected_names: list[str]) -> None:
        """Poll slskd transfers until all our files are Completed/Succeeded."""
        deadline = time.time() + 60 * 60 * 2  # 2h hard cap
        target_set = set(expected_names)
        while time.time() < deadline:
            await asyncio.sleep(5.0)
            transfers = await self._slskd.list_downloads()
            ours = []
            for user_block in transfers:
                if user_block.get("username") != job.peer:
                    continue
                for d in user_block.get("directories", []) or []:
                    for f in d.get("files", []) or []:
                        name = Path(f.get("filename", "")).name
                        if name in target_set:
                            ours.append(f)

            if not ours:
                # slskd may have cleaned up if all done; check disk too.
                if self._all_present_on_disk(expected_names):
                    return
                continue

            states = [str(f.get("state", "")) for f in ours]
            if all("Completed, Succeeded" in s for s in states):
                return
            if any("Errored" in s or "Cancelled" in s for s in states):
                bad = [s for s in states if "Errored" in s or "Cancelled" in s]
                raise RuntimeError(f"slskd transfer failed: {bad[0]}")

            done = sum("Completed, Succeeded" in s for s in states)
            job.message = f"Downloading… {done}/{len(expected_names)} complete"
        raise TimeoutError("slskd download timed out after 2h")

    def _all_present_on_disk(self, expected_names: list[str]) -> bool:
        root = self._settings.slskd_downloads_dir
        if not root.exists():
            return False
        found = {p.name for p in root.rglob("*") if p.is_file()}
        return all(name in found for name in expected_names)

    def _move_results(self, job: Job, expected_names: list[str]) -> int:
        src_root = self._settings.slskd_downloads_dir
        dst_root = Path(job.target_path)
        dst_root.mkdir(parents=True, exist_ok=True)
        moved = 0
        wanted = set(expected_names)
        for p in src_root.rglob("*"):
            if not p.is_file() or p.name not in wanted:
                continue
            # Preserve immediate parent dir name (album folder) from slskd.
            rel_parent = p.parent.name if p.parent != src_root else ""
            dst_dir = dst_root / rel_parent if rel_parent else dst_root
            dst_dir.mkdir(parents=True, exist_ok=True)
            dst = dst_dir / p.name
            shutil.move(str(p), str(dst))
            moved += 1
        # Clean up now-empty source dirs.
        for d in sorted(src_root.rglob("*"), reverse=True):
            if d.is_dir() and not any(d.iterdir()):
                try:
                    d.rmdir()
                except OSError:
                    pass
        return moved
