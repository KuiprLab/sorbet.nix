"""Harvest API + static frontend host.

Routes:
  GET  /api/health              -> service status
  POST /api/login               -> set session cookie
  POST /api/logout              -> clear cookie
  GET  /api/me                  -> current user (or 401)
  GET  /api/search              -> MusicBrainz search (album|track)
  GET  /api/release-group/{id}  -> tracklist + cover
  POST /api/slskd/search        -> soulseek search by query
  POST /api/jobs                -> enqueue download(s)
  GET  /api/jobs                -> list jobs
  GET  /api/jobs/{id}           -> job detail
  GET  /api/target-folders      -> available destination folders

Anything else falls through to the SvelteKit static build.
"""

from __future__ import annotations

import os
from collections import defaultdict
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Any

from fastapi import Depends, FastAPI, HTTPException, Query, Request, Response
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from .auth import (
    COOKIE_NAME,
    SESSION_TTL_SECONDS,
    check_credentials,
    issue_token,
    require_user,
)
from .config import load_settings
from .jobs import JobManager
from .musicbrainz import MusicBrainzClient
from .slskd import SlskdClient


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = load_settings()
    mb = MusicBrainzClient(user_agent=settings.musicbrainz_user_agent)
    slskd = SlskdClient(base_url=settings.slskd_url, api_key=settings.slskd_api_key)
    jobs = JobManager(settings=settings, slskd=slskd)
    app.state.settings = settings
    app.state.mb = mb
    app.state.slskd = slskd
    app.state.jobs = jobs
    try:
        yield
    finally:
        await mb.aclose()
        await slskd.aclose()


app = FastAPI(title="Harvest", lifespan=lifespan)


# --- Models ----------------------------------------------------------------


class LoginIn(BaseModel):
    username: str
    password: str


class SlskdSearchIn(BaseModel):
    query: str = Field(min_length=2, max_length=200)


class FileSelection(BaseModel):
    filename: str
    size: int = 0
    extension: str | None = None


class JobIn(BaseModel):
    title: str
    artist: str
    target_folder: str
    peer: str
    files: list[FileSelection]


# --- Auth ------------------------------------------------------------------


@app.post("/api/login")
async def login(body: LoginIn, request: Request, response: Response):
    settings = request.app.state.settings
    if not check_credentials(settings, body.username, body.password):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    token = issue_token(settings, body.username)
    response.set_cookie(
        COOKIE_NAME,
        token,
        max_age=SESSION_TTL_SECONDS,
        httponly=True,
        samesite="lax",
        secure=False,  # caddy terminates TLS; browser sees https on the vhost
        path="/",
    )
    return {"username": body.username}


@app.post("/api/logout")
async def logout(response: Response):
    response.delete_cookie(COOKIE_NAME, path="/")
    return {"ok": True}


@app.get("/api/me")
async def me(user: str = Depends(require_user)):
    return {"username": user}


# --- Status ----------------------------------------------------------------


@app.get("/api/health")
async def health(request: Request):
    settings = request.app.state.settings
    slskd: SlskdClient = request.app.state.slskd
    slskd_ok = await slskd.health()
    return {
        "status": "ok",
        "version": os.environ.get("HARVEST_VERSION", "dev"),
        "slskd": slskd_ok,
        "beets_inbox_writable": _writable("/inbox"),
        "target_folders": list(settings.target_folders.keys()),
    }


def _writable(p: str) -> bool:
    path = Path(p)
    return path.exists() and os.access(path, os.W_OK)


@app.get("/api/target-folders")
async def target_folders(request: Request, _user: str = Depends(require_user)):
    settings = request.app.state.settings
    return {"folders": list(settings.target_folders.keys())}


# --- MusicBrainz -----------------------------------------------------------


@app.get("/api/search")
async def search(
    request: Request,
    q: str = Query(..., min_length=2, max_length=200),
    artist: str | None = Query(None, max_length=200),
    kind: str = Query("album", pattern="^(album|track)$"),
    _user: str = Depends(require_user),
):
    mb: MusicBrainzClient = request.app.state.mb
    if kind == "album":
        results = await mb.search_release_groups(q, artist=artist)
    else:
        results = await mb.search_recordings(q, artist=artist)
    return {"results": results}


@app.get("/api/release-group/{rg_id}")
async def release_group(
    rg_id: str, request: Request, _user: str = Depends(require_user)
):
    mb: MusicBrainzClient = request.app.state.mb
    return await mb.release_group_tracks(rg_id)


# --- slskd -----------------------------------------------------------------


@app.post("/api/slskd/search")
async def slskd_search(
    body: SlskdSearchIn,
    request: Request,
    _user: str = Depends(require_user),
):
    slskd: SlskdClient = request.app.state.slskd
    responses = await slskd.search(body.query)

    # Group flat: list of peers with their files (highest free-slot first).
    peers: list[dict[str, Any]] = []
    for r in responses:
        files = r.get("files") or []
        if not files:
            continue
        peers.append(
            {
                "username": r.get("username"),
                "has_free_upload_slot": r.get("hasFreeUploadSlot", False),
                "upload_speed": r.get("uploadSpeed", 0),
                "queue_length": r.get("queueLength", 0),
                "file_count": len(files),
                "files": [
                    {
                        "filename": f.get("filename"),
                        "size": f.get("size", 0),
                        "extension": f.get("extension"),
                        "bit_rate": f.get("bitRate"),
                        "length": f.get("length"),
                        "is_locked": f.get("isLocked", False),
                    }
                    for f in files
                ],
            }
        )
    peers.sort(
        key=lambda p: (
            not p["has_free_upload_slot"],
            -p["upload_speed"],
            p["queue_length"],
        )
    )
    return {"peers": peers}


# --- Jobs ------------------------------------------------------------------


@app.post("/api/jobs")
async def create_job(body: JobIn, request: Request, _user: str = Depends(require_user)):
    jm: JobManager = request.app.state.jobs
    if not body.files:
        raise HTTPException(status_code=400, detail="No files selected")
    try:
        job = await jm.submit(
            title=body.title,
            artist=body.artist,
            target_folder_label=body.target_folder,
            peer=body.peer,
            files=[f.model_dump() for f in body.files],
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    return _serialize_job(job)


@app.get("/api/jobs")
async def list_jobs(request: Request, _user: str = Depends(require_user)):
    jm: JobManager = request.app.state.jobs
    return {"jobs": [_serialize_job(j) for j in jm.list_jobs()]}


@app.get("/api/jobs/{job_id}")
async def get_job(job_id: str, request: Request, _user: str = Depends(require_user)):
    jm: JobManager = request.app.state.jobs
    job = jm.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="No such job")
    return _serialize_job(job)


def _serialize_job(j: Any) -> dict[str, Any]:
    return {
        "id": j.id,
        "title": j.title,
        "artist": j.artist,
        "target_folder": j.target_folder,
        "peer": j.peer,
        "state": j.state,
        "message": j.message,
        "files": j.files,
        "started_at": j.started_at,
        "finished_at": j.finished_at,
    }


# --- Static frontend (SvelteKit `adapter-static` build) --------------------


_STATIC_DIR = Path(os.environ.get("HARVEST_STATIC_DIR", "/app/static"))


if _STATIC_DIR.exists():
    app.mount(
        "/_app",
        StaticFiles(directory=_STATIC_DIR / "_app"),
        name="sveltekit-assets",
    )

    @app.get("/{full_path:path}", include_in_schema=False)
    async def spa_fallback(full_path: str):
        # Don't shadow API routes
        if full_path.startswith("api/"):
            raise HTTPException(status_code=404)
        candidate = _STATIC_DIR / full_path
        if candidate.is_file():
            return FileResponse(candidate)
        index = _STATIC_DIR / "index.html"
        if index.is_file():
            return FileResponse(index)
        return JSONResponse({"detail": "frontend not built"}, status_code=503)

else:

    @app.get("/", include_in_schema=False)
    async def root_no_static():
        return JSONResponse(
            {
                "detail": "Harvest API only — frontend not bundled",
                "static_dir": str(_STATIC_DIR),
            }
        )


# Defensive: prevent generic 200 collisions on /api/* preflight from cookie deps
@app.exception_handler(HTTPException)
async def http_exc(_: Request, exc: HTTPException):
    headers = getattr(exc, "headers", None)
    return JSONResponse(
        {"detail": exc.detail}, status_code=exc.status_code, headers=headers
    )


# Used only for type checker silence; defaultdict imported for future use.
_ = defaultdict
