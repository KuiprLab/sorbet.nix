"""MusicBrainz client: search albums/tracks, fetch release tracks + cover art."""

from __future__ import annotations

import asyncio
from typing import Any

import httpx

MB_BASE = "https://musicbrainz.org/ws/2"
CAA_BASE = "https://coverartarchive.org"


class MusicBrainzClient:
    def __init__(self, user_agent: str) -> None:
        self._user_agent = user_agent
        self._client = httpx.AsyncClient(
            headers={"User-Agent": user_agent, "Accept": "application/json"},
            timeout=httpx.Timeout(20.0),
        )
        # MB asks for max ~1 req/s for anonymous use.
        self._rate_lock = asyncio.Lock()
        self._last_call = 0.0

    async def _throttle(self) -> None:
        async with self._rate_lock:
            now = asyncio.get_event_loop().time()
            wait = 1.0 - (now - self._last_call)
            if wait > 0:
                await asyncio.sleep(wait)
            self._last_call = asyncio.get_event_loop().time()

    async def aclose(self) -> None:
        await self._client.aclose()

    async def search_release_groups(
        self, query: str, artist: str | None = None, limit: int = 15
    ) -> list[dict[str, Any]]:
        await self._throttle()
        q = f'releasegroup:"{query}"'
        if artist:
            q += f' AND artist:"{artist}"'
        r = await self._client.get(
            f"{MB_BASE}/release-group",
            params={"query": q, "fmt": "json", "limit": limit},
        )
        r.raise_for_status()
        data = r.json()
        out: list[dict[str, Any]] = []
        for rg in data.get("release-groups", []):
            artist_credit = rg.get("artist-credit", [])
            artist_name = artist_credit[0].get("name") if artist_credit else "Unknown"
            out.append(
                {
                    "id": rg.get("id"),
                    "type": "release-group",
                    "title": rg.get("title"),
                    "artist": artist_name,
                    "primary_type": rg.get("primary-type"),
                    "first_release_date": rg.get("first-release-date"),
                    "cover_url": (
                        f"{CAA_BASE}/release-group/{rg.get('id')}/front-250"
                        if rg.get("id")
                        else None
                    ),
                }
            )
        return out

    async def search_recordings(
        self, query: str, artist: str | None = None, limit: int = 25
    ) -> list[dict[str, Any]]:
        await self._throttle()
        q = f'recording:"{query}"'
        if artist:
            q += f' AND artist:"{artist}"'
        r = await self._client.get(
            f"{MB_BASE}/recording",
            params={"query": q, "fmt": "json", "limit": limit},
        )
        r.raise_for_status()
        data = r.json()
        out: list[dict[str, Any]] = []
        for rec in data.get("recordings", []):
            artist_credit = rec.get("artist-credit", [])
            artist_name = artist_credit[0].get("name") if artist_credit else "Unknown"
            releases = rec.get("releases", []) or []
            release = releases[0] if releases else {}
            out.append(
                {
                    "id": rec.get("id"),
                    "type": "recording",
                    "title": rec.get("title"),
                    "artist": artist_name,
                    "length_ms": rec.get("length"),
                    "release_id": release.get("id"),
                    "release_title": release.get("title"),
                    "cover_url": (
                        f"{CAA_BASE}/release/{release.get('id')}/front-250"
                        if release.get("id")
                        else None
                    ),
                }
            )
        return out

    async def release_group_tracks(self, rg_id: str) -> dict[str, Any]:
        """Fetch the most-canonical release for a release-group + its tracks."""
        await self._throttle()
        r = await self._client.get(
            f"{MB_BASE}/release-group/{rg_id}",
            params={
                "fmt": "json",
                "inc": "releases+artist-credits",
            },
        )
        r.raise_for_status()
        rg = r.json()

        releases = rg.get("releases", []) or []
        if not releases:
            return {
                "id": rg.get("id"),
                "title": rg.get("title"),
                "artist": _artist_name(rg.get("artist-credit", [])),
                "tracks": [],
            }
        # Prefer official album-type, earliest release.
        releases.sort(
            key=lambda r: (
                r.get("status") != "Official",
                r.get("date") or "9999",
            )
        )
        chosen = releases[0]
        await self._throttle()
        rr = await self._client.get(
            f"{MB_BASE}/release/{chosen['id']}",
            params={
                "fmt": "json",
                "inc": "recordings+artist-credits",
            },
        )
        rr.raise_for_status()
        release = rr.json()

        tracks: list[dict[str, Any]] = []
        for medium in release.get("media", []) or []:
            for track in medium.get("tracks", []) or []:
                rec = track.get("recording", {}) or {}
                tracks.append(
                    {
                        "id": rec.get("id") or track.get("id"),
                        "position": track.get("position"),
                        "number": track.get("number"),
                        "title": track.get("title") or rec.get("title"),
                        "length_ms": rec.get("length") or track.get("length"),
                    }
                )
        return {
            "id": rg.get("id"),
            "release_id": release.get("id"),
            "title": rg.get("title"),
            "artist": _artist_name(rg.get("artist-credit", [])),
            "first_release_date": rg.get("first-release-date"),
            "primary_type": rg.get("primary-type"),
            "cover_url": f"{CAA_BASE}/release-group/{rg.get('id')}/front-500",
            "tracks": tracks,
        }


def _artist_name(credits: list[dict[str, Any]]) -> str:
    if not credits:
        return "Unknown"
    return credits[0].get("name") or "Unknown"
