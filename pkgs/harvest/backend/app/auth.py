"""Tiny session auth: signed cookie, single shared admin user."""

from __future__ import annotations

import hmac
import secrets
import time
from hashlib import sha256

from fastapi import Cookie, HTTPException, Request

from .config import Settings

COOKIE_NAME = "harvest_session"
SESSION_TTL_SECONDS = 60 * 60 * 24 * 7  # 7 days


def _sign(secret: str, payload: str) -> str:
    return hmac.new(secret.encode(), payload.encode(), sha256).hexdigest()


def issue_token(settings: Settings, username: str) -> str:
    issued = int(time.time())
    payload = f"{username}.{issued}"
    sig = _sign(settings.session_secret, payload)
    return f"{payload}.{sig}"


def verify_token(settings: Settings, token: str | None) -> str | None:
    if not token:
        return None
    parts = token.split(".")
    if len(parts) != 3:
        return None
    username, issued, sig = parts
    payload = f"{username}.{issued}"
    expected = _sign(settings.session_secret, payload)
    if not hmac.compare_digest(sig, expected):
        return None
    try:
        if int(issued) + SESSION_TTL_SECONDS < int(time.time()):
            return None
    except ValueError:
        return None
    if username != settings.username:
        return None
    return username


def check_credentials(settings: Settings, username: str, password: str) -> bool:
    if not settings.password:
        return False
    return secrets.compare_digest(
        username, settings.username
    ) and secrets.compare_digest(password, settings.password)


async def require_user(
    request: Request,
    harvest_session: str | None = Cookie(default=None),
) -> str:
    settings: Settings = request.app.state.settings
    user = verify_token(settings, harvest_session)
    if not user:
        raise HTTPException(status_code=401, detail="Not authenticated")
    return user
