from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional, List
from uuid import uuid4
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc, asc
import httpx
from urllib.parse import urlparse
import feedparser

from ..db import SessionLocal
from ..models import RSSHubConfig as SARSSHubConfig
from ..config import SETTINGS

router = APIRouter()

async def get_session() -> AsyncSession:
    async with SessionLocal() as session:
        yield session

class CreateRSSHubConfigRequest(BaseModel):
    url: str
    priority: int = 0

class UpdateRSSHubConfigRequest(BaseModel):
    url: Optional[str] = None
    priority: Optional[int] = None
    is_active: Optional[bool] = None

@router.get("/rsshub/configs")
async def list_rsshub_configs(session: AsyncSession = Depends(get_session)) -> dict:
    q = select(SARSSHubConfig).order_by(desc(SARSSHubConfig.is_active)).order_by(asc(SARSSHubConfig.priority))
    rows = (await session.execute(q)).scalars().all()
    items = []
    for c in rows:
        items.append({
            "id": c.id,
            "url": c.url,
            "priority": c.priority,
            "is_active": bool(c.is_active),
            "last_tested": c.last_tested.isoformat() + "Z" if c.last_tested else None,
            "response_time": c.response_time,
            "error_count": c.error_count,
            "created_at": c.created_at.isoformat() + "Z" if c.created_at else None,
            "updated_at": c.updated_at.isoformat() + "Z" if c.updated_at else None,
        })
    return {"success": True, "configs": items}

@router.get("/rsshub/configs/best")
async def get_best_rsshub_mirror(session: AsyncSession = Depends(get_session)) -> dict:
    q = select(SARSSHubConfig).where(SARSSHubConfig.is_active == True).order_by(desc(SARSSHubConfig.priority)).order_by(desc(SARSSHubConfig.last_tested)).limit(1)
    c = (await session.execute(q)).scalar_one_or_none()
    if not c:
        return {"success": False, "config": None}
    return {"success": True, "config": {
        "id": c.id,
        "url": c.url,
        "priority": c.priority,
        "is_active": bool(c.is_active),
        "last_tested": c.last_tested.isoformat() + "Z" if c.last_tested else None,
        "response_time": c.response_time,
        "error_count": c.error_count,
        "created_at": c.created_at.isoformat() + "Z" if c.created_at else None,
        "updated_at": c.updated_at.isoformat() + "Z" if c.updated_at else None,
    }}

@router.post("/rsshub/configs/test-active")
async def test_all_active_rsshub_configs(session: AsyncSession = Depends(get_session)) -> dict:
    rows = (await session.execute(select(SARSSHubConfig).where(SARSSHubConfig.is_active == True))).scalars().all()
    results = []
    for c in rows:
        base = c.url.rstrip("/")
        test_url = base + "/api/health"
        import time
        start = time.time()
        ok = False
        rt_ms = None
        try:
            async with httpx.AsyncClient(timeout=10) as client:
                resp = await client.get(test_url, follow_redirects=True)
            if resp.status_code < 400:
                ok = True
                rt_ms = int((time.time() - start) * 1000)
        except httpx.RequestError:
            ok = False
        now = datetime.utcnow()
        c.last_tested = now
        c.response_time = rt_ms
        c.is_active = ok
        c.error_count = 0 if ok else (c.error_count + 1)
        c.updated_at = now
        results.append({
            "id": c.id,
            "url": c.url,
            "priority": c.priority,
            "is_active": bool(ok),
            "last_tested": now.isoformat() + "Z",
            "response_time": rt_ms,
            "error_count": c.error_count,
        })
    await session.commit()
    return {"success": True, "results": results}

@router.get("/rsshub/configs/{id}")
async def get_rsshub_config(id: str, session: AsyncSession = Depends(get_session)) -> dict:
    q = await session.execute(select(SARSSHubConfig).where(SARSSHubConfig.id == id))
    c = q.scalar_one_or_none()
    if not c:
        raise HTTPException(status_code=404)
    return {
        "id": c.id,
        "url": c.url,
        "priority": c.priority,
        "is_active": bool(c.is_active),
        "last_tested": c.last_tested.isoformat() + "Z" if c.last_tested else None,
        "response_time": c.response_time,
        "error_count": c.error_count,
        "created_at": c.created_at.isoformat() + "Z" if c.created_at else None,
        "updated_at": c.updated_at.isoformat() + "Z" if c.updated_at else None,
    }

@router.post("/rsshub/configs")
async def create_rsshub_config(payload: CreateRSSHubConfigRequest, session: AsyncSession = Depends(get_session)) -> dict:
    exists = (await session.execute(select(SARSSHubConfig).where(SARSSHubConfig.url == payload.url))).scalar_one_or_none()
    if exists:
        raise HTTPException(status_code=409)
    now = datetime.utcnow()
    rid = str(uuid4())
    row = SARSSHubConfig(
        id=rid,
        url=payload.url,
        priority=payload.priority,
        is_active=True,
        last_tested=None,
        response_time=None,
        error_count=0,
        created_at=now,
        updated_at=now,
    )
    session.add(row)
    await session.commit()
    return {"success": True, "config": {
        "id": rid,
        "url": payload.url,
        "priority": payload.priority,
        "is_active": True,
        "last_tested": None,
        "response_time": None,
        "error_count": 0,
        "created_at": now.isoformat() + "Z",
        "updated_at": now.isoformat() + "Z",
    }}

@router.put("/rsshub/configs/{id}")
@router.patch("/rsshub/configs/{id}")
async def update_rsshub_config(id: str, payload: UpdateRSSHubConfigRequest, session: AsyncSession = Depends(get_session)) -> dict:
    q = await session.execute(select(SARSSHubConfig).where(SARSSHubConfig.id == id))
    c = q.scalar_one_or_none()
    if not c:
        raise HTTPException(status_code=404)
    if payload.url is not None:
        dup = (await session.execute(select(SARSSHubConfig).where(SARSSHubConfig.url == payload.url, SARSSHubConfig.id != id))).scalar_one_or_none()
        if dup:
            raise HTTPException(status_code=409)
        c.url = payload.url
    if payload.priority is not None:
        c.priority = int(payload.priority)
    if payload.is_active is not None:
        c.is_active = bool(payload.is_active)
    c.updated_at = datetime.utcnow()
    await session.commit()
    return {"success": True}

@router.delete("/rsshub/configs/{id}")
async def delete_rsshub_config(id: str, session: AsyncSession = Depends(get_session)) -> dict:
    q = await session.execute(select(SARSSHubConfig).where(SARSSHubConfig.id == id))
    c = q.scalar_one_or_none()
    if not c:
        raise HTTPException(status_code=404)
    await session.delete(c)
    await session.commit()
    return {"success": True}

@router.post("/rsshub/configs/{id}/test")
async def test_rsshub_config(id: str, session: AsyncSession = Depends(get_session)) -> dict:
    q = await session.execute(select(SARSSHubConfig).where(SARSSHubConfig.id == id))
    c = q.scalar_one_or_none()
    if not c:
        raise HTTPException(status_code=404)
    base = c.url.rstrip("/")
    test_url = base + "/api/health"
    import time
    start = time.time()
    ok = False
    rt_ms = None
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(test_url, follow_redirects=True)
        if resp.status_code < 400:
            ok = True
            rt_ms = int((time.time() - start) * 1000)
    except httpx.RequestError:
        ok = False
    now = datetime.utcnow()
    c.last_tested = now
    c.response_time = rt_ms
    c.is_active = ok
    c.error_count = 0 if ok else (c.error_count + 1)
    c.updated_at = now
    await session.commit()
    return {"success": ok, "config": {
        "id": c.id,
        "url": c.url,
        "priority": c.priority,
        "is_active": bool(c.is_active),
        "last_tested": c.last_tested.isoformat() + "Z" if c.last_tested else None,
        "response_time": c.response_time,
        "error_count": c.error_count,
        "created_at": c.created_at.isoformat() + "Z" if c.created_at else None,
        "updated_at": c.updated_at.isoformat() + "Z" if c.updated_at else None,
    }, "test_url": test_url}

@router.post("/settings/test-rsshub-quick")
async def test_rsshub_quick() -> dict:
    base = SETTINGS.rsshub_url.rstrip("/")
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
