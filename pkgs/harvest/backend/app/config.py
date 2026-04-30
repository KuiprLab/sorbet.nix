"""Runtime configuration loaded from environment + slskd.yml."""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path

import yaml


@dataclass(frozen=True)
class Settings:
    # Auth
    username: str
    password: str  # plaintext; LAN-only deploy, secret stored via sops
    session_secret: str

    # slskd
    slskd_url: str
    slskd_api_key: str

    # Folders shown in the "target folder" dropdown.
    # Maps display label -> absolute path inside the container.
    target_folders: dict[str, str]

    # Watched download dir on host (mounted into container).
    # The downloads dir slskd writes to (we read completion status from here).
    slskd_downloads_dir: Path = field(default_factory=lambda: Path("/downloads"))

    # MusicBrainz
    musicbrainz_user_agent: str = "Harvest/0.1.0 ( https://harvest.int.kuipr.de )"

    # Bind
    host: str = "0.0.0.0"
    port: int = 9765


def _parse_target_folders(raw: str | None) -> dict[str, str]:
    """Parse `Library=/inbox,Direct=/music` style env into a dict.

    Default: hand off to beets-watch via /inbox.
    """
    if not raw:
        return {"Library (auto-tag via beets)": "/inbox"}
    out: dict[str, str] = {}
    for pair in raw.split(","):
        pair = pair.strip()
        if not pair or "=" not in pair:
            continue
        label, path = pair.split("=", 1)
        out[label.strip()] = path.strip()
    return out


def _load_slskd_api_key(slskd_yml_path: str | None) -> str:
    """Extract the first API key from slskd.yml (web.authentication.api_keys).

    slskd schema (relevant slice):
        web:
          authentication:
            api_keys:
              <name>:
                key: "..."
                role: "ReadWrite" | ...
    """
    if not slskd_yml_path:
        return ""
    p = Path(slskd_yml_path)
    if not p.exists():
        return ""
    try:
        data = yaml.safe_load(p.read_text()) or {}
    except yaml.YAMLError:
        return ""
    keys = data.get("web", {}).get("authentication", {}).get("api_keys", {})
    if not isinstance(keys, dict):
        return ""
    for entry in keys.values():
        if isinstance(entry, dict) and entry.get("key"):
            return str(entry["key"])
    return ""


def load_settings() -> Settings:
    slskd_yml = os.environ.get("HARVEST_SLSKD_YML", "/run/secrets/slskd.yml")
    api_key = os.environ.get("HARVEST_SLSKD_API_KEY") or _load_slskd_api_key(slskd_yml)

    return Settings(
        username=os.environ.get("HARVEST_USERNAME", "admin"),
        password=os.environ.get("HARVEST_PASSWORD", ""),
        session_secret=os.environ.get("HARVEST_SESSION_SECRET", "change-me-in-sops"),
        slskd_url=os.environ.get("HARVEST_SLSKD_URL", "http://gluetun:5030"),
        slskd_api_key=api_key,
        target_folders=_parse_target_folders(os.environ.get("HARVEST_TARGET_FOLDERS")),
        slskd_downloads_dir=Path(
            os.environ.get("HARVEST_SLSKD_DOWNLOADS", "/downloads")
        ),
        host=os.environ.get("HARVEST_HOST", "0.0.0.0"),
        port=int(os.environ.get("HARVEST_PORT", "9765")),
    )
