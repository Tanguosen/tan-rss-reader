from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from typing import Optional, List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc, asc
from uuid import uuid4
from datetime import datetime
from ..db import SessionLocal
from ..models import Subscription as SASub, Channel as SAChannel, ChannelSource as SAChannelSource, Feed as SAFeed, Entry as SAEntry
from .auth import get_current_user
from ..utils.filters import apply_date_filter_to_entries_query

router = APIRouter()

async def get_session() -> AsyncSession:
    async with SessionLocal() as session:
        yield session

class Channel(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    cover_url: Optional[str] = None
    is_public: bool
    kind: Optional[str] = "topic"

class Subscription(BaseModel):
    id: str
    channel_id: str
    notify: bool
    created_at: Optional[str] = None

class Entry(BaseModel):
    id: str
    feed_id: str
    feed_title: Optional[str] = None
    title: Optional[str] = None
    url: Optional[str] = None
    author: Optional[str] = None
    summary: Optional[str] = None
    content: Optional[str] = None
    published_at: Optional[str] = None
    inserted_at: Optional[str] = None
    read: bool
    starred: bool

@router.get("/me/subscriptions", response_model=List[Channel])
async def my_subscriptions(current=Depends(get_current_user), session: AsyncSession = Depends(get_session)) -> List[Channel]:
    q = await session.execute(select(SASub.channel_id).where(SASub.user_id == current.id))
    cids = q.scalars().all()
    if not cids:
        return []
    cq = await session.execute(select(SAChannel).where(SAChannel.id.in_(cids)).order_by(desc(SAChannel.updated_at)))
    items: List[Channel] = []
    for c in cq.scalars().all():
        items.append(Channel(id=c.id, name=c.name, description=c.description, cover_url=c.cover_url, is_public=bool(c.is_public), kind=c.kind))
    return items

@router.post("/channels/{id}/subscribe", response_model=Subscription)
async def subscribe(id: str, current=Depends(get_current_user), session: AsyncSession = Depends(get_session)) -> Subscription:
    cq = await session.execute(select(SAChannel).where(SAChannel.id == id))
    c = cq.scalar_one_or_none()
    if not c:
        raise HTTPException(status_code=404)
    exists = (await session.execute(select(SASub).where(SASub.user_id == current.id, SASub.channel_id == id))).scalar_one_or_none()
    if exists:
        return Subscription(id=exists.id, channel_id=exists.channel_id, notify=bool(exists.notify), created_at=exists.created_at.isoformat() + "Z" if exists.created_at else None)
    sid = str(uuid4())
    now = datetime.utcnow()
    row = SASub(id=sid, user_id=current.id, channel_id=id, notify=False, created_at=now, updated_at=now)
    session.add(row)
    await session.commit()
    return Subscription(id=row.id, channel_id=row.channel_id, notify=bool(row.notify), created_at=row.created_at.isoformat() + "Z" if row.created_at else None)

@router.delete("/channels/{id}/subscribe")
async def unsubscribe(id: str, current=Depends(get_current_user), session: AsyncSession = Depends(get_session)) -> dict:
    q = await session.execute(select(SASub).where(SASub.user_id == current.id, SASub.channel_id == id))
    row = q.scalar_one_or_none()
    if not row:
        raise HTTPException(status_code=404)
    await session.delete(row)
    await session.commit()
    return {"success": True}

@router.get("/me/subscriptions/entries", response_model=List[Entry])
async def my_subscription_entries(
    unread_only: Optional[bool] = Query(default=None),
    date_range: Optional[str] = Query(default=None),
    time_field: Optional[str] = Query(default=None),
    limit: Optional[int] = Query(default=100),
    offset: Optional[int] = Query(default=0),
    order_by: Optional[str] = Query(default="created_at"),
    order: Optional[str] = Query(default="desc"),
    current=Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> List[Entry]:
    q1 = await session.execute(select(SASub.channel_id).where(SASub.user_id == current.id))
    cids = q1.scalars().all()
    if not cids:
        return []
    q2 = await session.execute(select(SAChannelSource.feed_id).where(SAChannelSource.channel_id.in_(cids)))
    feed_ids = list(set(q2.scalars().all()))
    if not feed_ids:
        return []
    q = select(SAEntry, SAFeed.title).where(SAEntry.feed_id == SAFeed.id, SAEntry.feed_id.in_(feed_ids))
    if unread_only:
        q = q.where(SAEntry.is_read == False)
    q = apply_date_filter_to_entries_query(q, date_range, time_field, SAEntry.created_at, SAEntry.published_at)
    if order_by == "published_at":
        q = q.order_by(desc(SAEntry.published_at) if order == "desc" else asc(SAEntry.published_at))
    else:
        q = q.order_by(desc(SAEntry.created_at) if order == "desc" else asc(SAEntry.created_at))
    q = q.offset(offset).limit(min(limit, 1000))
    rows = await session.execute(q)
    items: List[Entry] = []
    for e, feed_title in rows.all():
        items.append(
            Entry(
                id=e.id,
                feed_id=e.feed_id,
                feed_title=feed_title,
                title=e.title,
                url=e.url,
                author=e.author,
                summary=e.summary,
                content=e.content,
                published_at=e.published_at.isoformat() + "Z" if e.published_at else None,
                inserted_at=e.created_at.isoformat() + "Z" if e.created_at else None,
                read=bool(e.is_read),
                starred=bool(e.is_starred),
            )
        )
    return items
