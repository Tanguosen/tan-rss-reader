from fastapi import APIRouter, HTTPException, Response, Query, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from ..db import SessionLocal
from ..models import SiteIcon
import httpx
from urllib.parse import urlparse
import mimetypes
import base64

router = APIRouter()

async def get_session() -> AsyncSession:
    async with SessionLocal() as session:
        yield session

@router.get("/icons")
async def get_all_icons(session: AsyncSession = Depends(get_session)) -> list:
    rows = (await session.execute(select(SiteIcon))).scalars().all()
    items = []
    for i in rows:
        items.append({
            "domain": i.domain,
            "mime": i.mime,
            "source_url": i.source_url,
            "last_fetched": i.last_fetched.isoformat() + "Z" if i.last_fetched else None,
        })
    return items

@router.get("/icons/{domain}")
async def get_icon(domain: str, session: AsyncSession = Depends(get_session)) -> Response:
    q = await session.execute(select(SiteIcon).where(SiteIcon.domain == domain))
    row = q.scalar_one_or_none()
    if not row or not row.data_base64:
        raise HTTPException(status_code=404)
    data = base64.b64decode(row.data_base64)
    mt = row.mime or "image/x-icon"
    return Response(content=data, media_type=mt)

async def fetch_icon_from_domain(domain: str) -> tuple[str, bytes]:
    for scheme in ["https", "http"]:
        url = f"{scheme}://{domain}/favicon.ico"
        try:
            async with httpx.AsyncClient(timeout=15) as client:
                resp = await client.get(url, follow_redirects=True)
            if resp.status_code < 400 and resp.content:
                ct = resp.headers.get("content-type", "").split(";")[0].strip()
                mt = ct if ct.startswith("image/") else (mimetypes.guess_type(url)[0] or "image/x-icon")
                return mt, resp.content
        except httpx.RequestError:
            continue
    raise HTTPException(status_code=502)

@router.post("/icons/{domain}/refresh")
async def refresh_icon(domain: str, session: AsyncSession = Depends(get_session)) -> dict:
    mt, content = await fetch_icon_from_domain(domain)
    b64 = base64.b64encode(content).decode("ascii")
    q = await session.execute(select(SiteIcon).where(SiteIcon.domain == domain))
    row = q.scalar_one_or_none()
    if row:
        row.mime = mt
        row.data_base64 = b64
        row.source_url = f"https://{domain}/favicon.ico"
        row.last_fetched = __import__("datetime").datetime.utcnow()
    else:
        row = SiteIcon(
            domain=domain,
            mime=mt,
            data_base64=b64,
            source_url=f"https://{domain}/favicon.ico",
            last_fetched=__import__("datetime").datetime.utcnow(),
        )
        session.add(row)
    await session.commit()
    return {"success": True}

@router.post("/icons/cleanup")
async def cleanup_icons(session: AsyncSession = Depends(get_session)) -> dict:
    await session.execute(delete(SiteIcon).where(SiteIcon.is_active == False))
    await session.commit()
    return {"success": True}

@router.get("/icons/proxy")
async def proxy_icon(url: str) -> Response:
    parsed = urlparse(url)
    if parsed.scheme not in ("http", "https"):
        raise HTTPException(status_code=400)
    try:
        async with httpx.AsyncClient(timeout=20) as client:
            resp = await client.get(url, follow_redirects=True)
    except httpx.RequestError:
        raise HTTPException(status_code=502)
    if resp.status_code >= 400:
        raise HTTPException(status_code=resp.status_code)
    ct = resp.headers.get("content-type", "").split(";")[0].strip()
    mt = ct if ct.startswith("image/") else (mimetypes.guess_type(url)[0] or "image/x-icon")
    return Response(content=resp.content, media_type=mt)
