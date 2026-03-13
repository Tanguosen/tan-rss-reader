from fastapi import APIRouter, HTTPException, Depends
from urllib.parse import urlparse
import httpx
import feedparser
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from ..db import SessionLocal
from ..config import SETTINGS
from ..models import AppSettingsRow
from .auth import get_current_admin, get_current_user
from .tasks import TASK_SCHEDULER

router = APIRouter()

async def get_session() -> AsyncSession:
    async with SessionLocal() as session:
        yield session

@router.get("/settings")
async def get_settings(session: AsyncSession = Depends(get_session)) -> dict:
    q = await session.execute(select(AppSettingsRow).where(AppSettingsRow.id == "default"))
    row = q.scalar_one_or_none()
    if not row:
        now = datetime.utcnow()
        row = AppSettingsRow(
            id="default",
            fetch_interval_minutes=SETTINGS.fetch_interval_minutes,
            items_per_page=SETTINGS.items_per_page,
            enable_date_filter=SETTINGS.enable_date_filter,
            default_date_range=SETTINGS.default_date_range,
            time_field=SETTINGS.time_field,
            show_entry_summary=SETTINGS.show_entry_summary,
            max_auto_title_translations=SETTINGS.max_auto_title_translations,
            translation_display_mode=SETTINGS.translation_display_mode,
            branding_toggle=SETTINGS.branding_toggle,
            rsshub_url=SETTINGS.rsshub_url,
            created_at=now,
            updated_at=now,
        )
        session.add(row)
        await session.commit()
    data = {
        "fetch_interval_minutes": row.fetch_interval_minutes,
        "items_per_page": row.items_per_page,
        "enable_date_filter": bool(row.enable_date_filter),
        "default_date_range": row.default_date_range,
        "time_field": row.time_field,
        "show_entry_summary": bool(row.show_entry_summary),
        "max_auto_title_translations": row.max_auto_title_translations,
        "translation_display_mode": row.translation_display_mode,
        "branding_toggle": bool(getattr(row, "branding_toggle", False)),
        "rsshub_url": row.rsshub_url,
    }
    SETTINGS.__init__(**data)
    return data

@router.put("/settings")
@router.patch("/settings")
async def update_settings(payload: dict, session: AsyncSession = Depends(get_session), admin=Depends(get_current_admin)) -> dict:
    q = await session.execute(select(AppSettingsRow).where(AppSettingsRow.id == "default"))
    row = q.scalar_one_or_none()
    if not row:
        now = datetime.utcnow()
        row = AppSettingsRow(id="default", created_at=now, updated_at=now)
        session.add(row)
    for k, v in payload.items():
        if hasattr(row, k) and v is not None:
            setattr(row, k, v)
    row.updated_at = datetime.utcnow()
    await session.commit()
    data = {
        "fetch_interval_minutes": row.fetch_interval_minutes,
        "items_per_page": row.items_per_page,
        "enable_date_filter": bool(row.enable_date_filter),
        "default_date_range": row.default_date_range,
        "time_field": row.time_field,
        "show_entry_summary": bool(row.show_entry_summary),
        "max_auto_title_translations": row.max_auto_title_translations,
        "translation_display_mode": row.translation_display_mode,
        "branding_toggle": bool(getattr(row, "branding_toggle", False)),
        "rsshub_url": row.rsshub_url,
    }
    SETTINGS.__init__(**data)
    if "fetch_interval_minutes" in payload:
        TASK_SCHEDULER.start_scheduler()
    return data

@router.get("/settings/rsshub-url")
async def get_rsshub_url(session: AsyncSession = Depends(get_session)) -> dict:
    q = await session.execute(select(AppSettingsRow).where(AppSettingsRow.id == "default"))
    row = q.scalar_one_or_none()
    if not row:
        return {"rsshub_url": SETTINGS.rsshub_url}
    return {"rsshub_url": row.rsshub_url}

@router.post("/settings/rsshub-url")
async def set_rsshub_url(payload: dict, session: AsyncSession = Depends(get_session), admin=Depends(get_current_admin)) -> dict:
    val = payload.get("rsshub_url")
    if not isinstance(val, str):
        raise HTTPException(status_code=400)
    p = urlparse(val)
    if p.scheme not in ("http", "https"):
        raise HTTPException(status_code=400)
    v = val.rstrip("/")
    q = await session.execute(select(AppSettingsRow).where(AppSettingsRow.id == "default"))
    row = q.scalar_one_or_none()
    if not row:
        now = datetime.utcnow()
        row = AppSettingsRow(id="default", rsshub_url=v, created_at=now, updated_at=now)
        session.add(row)
    else:
        row.rsshub_url = v
        row.updated_at = datetime.utcnow()
    await session.commit()
    SETTINGS.rsshub_url = v
    return {"success": True, "rsshub_url": v}

@router.post("/settings/test-rsshub-quick")
async def test_rsshub_quick(session: AsyncSession = Depends(get_session)) -> dict:
    q = await session.execute(select(AppSettingsRow).where(AppSettingsRow.id == "default"))
    row = q.scalar_one_or_none()
    base = (row.rsshub_url if row else SETTINGS.rsshub_url).rstrip("/")
    candidates = [
        "/github/issue/DIYgod/RSSHub",
        "/bilibili/user/dynamic/2",
        "/twitter/user/DIYgod",
    ]
    last_error = None
    for route in candidates:
        test_url = f"{base}{route}"
        start = datetime.utcnow()
        try:
            async with httpx.AsyncClient(timeout=20) as client:
                resp = await client.get(test_url, follow_redirects=True)
            if resp.status_code >= 400:
                last_error = f"HTTP {resp.status_code}"
                continue
            parsed = feedparser.parse(resp.text)
            elapsed = (datetime.utcnow() - start).total_seconds()
            return {
                "success": True,
                "message": "ok",
                "rsshub_url": base,
                "tested_at": datetime.utcnow().isoformat() + "Z",
                "test_url": test_url,
                "response_time": elapsed,
                "entries_count": len(parsed.entries),
                "feed_title": getattr(parsed.feed, "title", ""),
            }
        except httpx.RequestError as e:
            last_error = str(e)
            continue
    return {
        "success": False,
        "message": last_error or "unknown error",
        "rsshub_url": base,
        "tested_at": datetime.utcnow().isoformat() + "Z",
        "test_url": f"{base}{candidates[-1]}",
    }
