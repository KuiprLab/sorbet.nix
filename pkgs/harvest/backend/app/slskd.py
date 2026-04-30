"""slskd HTTP API client.

Reference: https://github.com/slskd/slskd/blob/master/docs/swagger.md
We use API key auth header `X-API-Key` (slskd 0.21+).
"""

from __future__ import annotations

import asyncio
from typing import Any

import httpx


class SlskdClient:
    def __init__(self, base_url: str, api_key: str) -> None:
        self._client = httpx.AsyncClient(
            base_url=base_url.rstrip("/"),
            headers={
                "X-API-Key": api_key,
                "Accept": "application/json",
            },
            timeout=httpx.Timeout(45.0),
        )

    async def aclose(self) -> None:
        await self._client.aclose()

    async def health(self) -> bool:
        try:
            r = await self._client.get("/api/v0/application")
            return r.status_code == 200
        except httpx.HTTPError:
            return False

    async def search(
        self,
        query: str,
        timeout_seconds: int = 12,
        min_results: int = 25,
    ) -> list[dict[str, Any]]:
        """Start a search, poll until it has results or timeout, return responses.

        Returns a list of `SearchResponse` objects (one per peer that replied).
        """
        r = await self._client.post(
            "/api/v0/searches",
            json={
                "searchText": query,
                "fileLimit": 1000,
                "filterResponses": True,
                "minimumResponseFileCount": 1,
            },
        )
        r.raise_for_status()
        body = r.json()
        search_id = body.get("id") or body.get("searchId")
        if not search_id:
            return []

        deadline = asyncio.get_event_loop().time() + timeout_seconds
        responses: list[dict[str, Any]] = []
        while asyncio.get_event_loop().time() < deadline:
            await asyncio.sleep(1.5)
            rr = await self._client.get(f"/api/v0/searches/{search_id}/responses")
            if rr.status_code == 200:
                responses = rr.json() or []
                if len(responses) >= min_results:
                    break
            # Check completion
            sr = await self._client.get(f"/api/v0/searches/{search_id}")
            if sr.status_code == 200:
                state = sr.json().get("state", "")
                if "Completed" in state:
                    break

        # Best effort cleanup; ignore failures.
        try:
            await self._client.delete(f"/api/v0/searches/{search_id}")
        except httpx.HTTPError:
            pass

        return responses

    async def enqueue_downloads(
        self,
        username: str,
        files: list[dict[str, Any]],
    ) -> dict[str, Any]:
        """Enqueue files from a single peer.

        Each file dict needs `filename` and `size`.
        """
        payload = [{"filename": f["filename"], "size": f.get("size", 0)} for f in files]
        r = await self._client.post(
            f"/api/v0/transfers/downloads/{username}",
            json=payload,
        )
        r.raise_for_status()
        return {"queued": len(payload)}

    async def list_downloads(self) -> list[dict[str, Any]]:
        r = await self._client.get("/api/v0/transfers/downloads")
        r.raise_for_status()
        return r.json() or []
