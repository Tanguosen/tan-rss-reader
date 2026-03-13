from fastapi import APIRouter, HTTPException, Response, Depends, Request
from pydantic import BaseModel
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import uuid4
from datetime import datetime
from ..db import SessionLocal
from ..models import Feed as SAFeed, Channel as SAChannel, ChannelSource as SAChannelSource, Subscription as SASub, User as SAUser
from .auth import get_optional_user
from ..services.rss_fetcher import fetch_feed as rss_fetch

router = APIRouter()

async def get_session() -> AsyncSession:
    async with SessionLocal() as session:
        yield session

class OPMLImportRequest(BaseModel):
    content: str

def _parse_opml(content: str) -> list[dict]:
    import xml.etree.ElementTree as ET
    try:
        root = ET.fromstring(content)
    except ET.ParseError:
        raise HTTPException(status_code=400)
    outlines = []
    def walk(node, category: Optional[str]):
        for o in node.findall("outline"):
            xml_url = o.attrib.get("xmlUrl") or o.attrib.get("xmlurl")
            text = o.attrib.get("text") or o.attrib.get("title") or "Untitled"
            if xml_url:
                cat_attr = o.attrib.get("category")
                outlines.append({"title": text, "xml_url": xml_url, "category": (cat_attr or category)})
            walk(o, text)
    body = root.find("body")
    if body is None:
        body = root
    walk(body, None)
    return outlines

@router.post("/opml/import")
async def import_opml(request: Request, current: Optional[SAUser] = Depends(get_optional_user), session: AsyncSession = Depends(get_session)) -> dict:
    ct = (request.headers.get("content-type") or "").lower()
    src = None
    if "multipart/form-data" in ct or "application/x-www-form-urlencoded" in ct:
        form = await request.form()
        val = form.get("content")
        if isinstance(val, str) and val.strip():
            src = val
        else:
            f = form.get("file")
            if f is not None:
                data = await f.read()
                try:
                    src = data.decode("utf-8")
                except UnicodeDecodeError:
                    src = data.decode("latin-1")
    elif "application/json" in ct:
        data = await request.json()
        val = data.get("content") if isinstance(data, dict) else None
        if isinstance(val, str) and val.strip():
            src = val
    if src is None:
        raw = await request.body()
        if not raw:
            raise HTTPException(status_code=400)
        try:
            src = raw.decode("utf-8")
        except UnicodeDecodeError:
            src = raw.decode("latin-1")
    items = _parse_opml(src)
    created = 0
    skipped = 0
    errors: list[str] = []
    for it in items:
        url = it["xml_url"].strip()
        if not url:
            continue
        try:
            exists = (await session.execute(select(SAFeed).where(SAFeed.url == url))).scalar_one_or_none()
            if exists:
                skipped += 1
                # 确保存在对应单源频道
                fid = exists.id
                cs = (await session.execute(select(SAChannelSource).where(SAChannelSource.feed_id == fid))).scalar_one_or_none()
                channel_id = None
                if cs:
                    channel_id = cs.channel_id
                    ch = (await session.execute(select(SAChannel).where(SAChannel.id == channel_id))).scalar_one_or_none()
                    if ch:
                        ch.updated_at = datetime.utcnow()
                        await session.commit()
                else:
                    # 创建新的单源频道
                    channel_id = str(uuid4())
                    now = datetime.utcnow()
                    ch = SAChannel(
                        id=channel_id,
                        name=exists.title or url,
                        description=None,
                        cover_url=None,
                        is_public=False,
                        owner_id=(current.id if current else None),
                        kind="feed",
                        created_at=now,
                        updated_at=now,
                    )
                    session.add(ch)
                    session.add(SAChannelSource(channel_id=channel_id, feed_id=fid, order_index=0, weight=100, created_at=now))
                    await session.commit()
                # 可选为当前用户创建订阅
                if current and channel_id:
                    sub_exists = (await session.execute(select(SASub).where(SASub.user_id == current.id, SASub.channel_id == channel_id))).scalar_one_or_none()
                    if not sub_exists:
                        sid = str(uuid4())
                        now = datetime.utcnow()
                        sub = SASub(id=sid, user_id=current.id, channel_id=channel_id, notify=False, created_at=now, updated_at=now)
                        session.add(sub)
                        await session.commit()
                continue
            fid = str(uuid4())
            now = datetime.utcnow()
            row = SAFeed(
                id=fid,
                url=url,
                title=it.get("title") or url,
                category=it.get("group"),
                favicon=None,
                update_interval=None,
                last_updated=None,
                last_status=None,
                error_count=0,
                created_at=now,
                updated_at=now,
            )
            session.add(row)
            await session.commit()
            created += 1
            # 为新增源创建单源频道并可选订阅
            channel_id = str(uuid4())
            ch = SAChannel(
                id=channel_id,
                name=row.title or url,
                description=None,
                cover_url=None,
                is_public=False,
                owner_id=(current.id if current else None),
                kind="feed",
                created_at=now,
                updated_at=now,
            )
            session.add(ch)
            session.add(SAChannelSource(channel_id=channel_id, feed_id=fid, order_index=0, weight=100, created_at=now))
            await session.commit()
            # 导入后立即尝试抓取一次
            try:
                await rss_fetch(session, fid)
            except Exception:
                pass
            if current:
                sub_exists = (await session.execute(select(SASub).where(SASub.user_id == current.id, SASub.channel_id == channel_id))).scalar_one_or_none()
                if not sub_exists:
                    sid = str(uuid4())
                    sub = SASub(id=sid, user_id=current.id, channel_id=channel_id, notify=False, created_at=now, updated_at=now)
                    session.add(sub)
                    await session.commit()
        except Exception as e:
            errors.append(str(e))
    return {"imported": created, "skipped": skipped, "errors": errors}

@router.get("/opml/export")
async def export_opml(session: AsyncSession = Depends(get_session)) -> Response:
    rows = (await session.execute(select(SAFeed))).scalars().all()
    by_cat: dict[str, list[SAFeed]] = {}
    for f in rows:
        key = f.category or "未分组"
        by_cat.setdefault(key, []).append(f)
    import xml.etree.ElementTree as ET
    opml = ET.Element("opml", version="1.0")
    head = ET.SubElement(opml, "head")
    title = ET.SubElement(head, "title")
    title.text = "TAN RSS Feeds"
    body = ET.SubElement(opml, "body")
    for cat, feeds in by_cat.items():
        cat_node = ET.SubElement(body, "outline", text=cat)
        for f in feeds:
            ET.SubElement(
                cat_node,
                "outline",
                text=f.title or f.url,
                title=f.title or f.url,
                type="rss",
                xmlUrl=f.url,
            )
    xml_str = ET.tostring(opml, encoding="utf-8")
    return Response(content=xml_str, media_type="application/xml")
