from fastapi import APIRouter, Query, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional, List
from uuid import uuid4
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc, asc, or_
from ..db import SessionLocal
from ..models import Feed as SAFeed, Entry as SAEntry, Channel as SAChannel, ChannelSource as SAChannelSource, Subscription as SASub, User as SAUser
from ..services.rss_fetcher import fetch_feed as rss_fetch
from ..utils.filters import apply_date_filter_to_entries_query
from .auth import get_optional_user, get_current_admin

router = APIRouter()

async def get_session() -> AsyncSession:
    async with SessionLocal() as session:
        yield session

class Feed(BaseModel):
    id: str
    url: str
    title: Optional[str] = None
    group_name: str
    favicon_url: Optional[str] = None
    unread_count: int
    last_checked_at: Optional[str] = None
    last_error: Optional[str] = None
    channel_id: Optional[str] = None

class CreateFeedRequest(BaseModel):
    url: str
    title: Optional[str] = None
    group_name: Optional[str] = None
    update_interval: Optional[int] = None

class UpdateFeedRequest(BaseModel):
    title: Optional[str] = None
    group_name: Optional[str] = None
    update_interval: Optional[int] = None

@router.get("/feeds", response_model=List[Feed])
async def list_feeds(
    limit: Optional[int] = Query(default=1000),
    offset: Optional[int] = Query(default=0),
    search: Optional[str] = Query(None),
    date_range: Optional[str] = Query(None),
    time_field: Optional[str] = Query(None),
    order_by: Optional[str] = Query(None),
    order: Optional[str] = Query(None),
    session: AsyncSession = Depends(get_session),
    user=Depends(get_optional_user),
) -> List[Feed]:
    # If user is logged in, show their subscriptions
    if user:
        stmt = (
            select(SAFeed, SASub.id, SAChannel.id)
            .join(SAChannelSource, SAChannelSource.feed_id == SAFeed.id)
            .join(SAChannel, SAChannel.id == SAChannelSource.channel_id)
            .join(SASub, SASub.channel_id == SAChannel.id)
            .where(SASub.user_id == user.id)
        )
        if search:
            stmt = stmt.where(or_(SAFeed.title.ilike(f"%{search}%"), SAFeed.url.ilike(f"%{search}%")))
            
        stmt = stmt.order_by(desc(SAFeed.created_at)).offset(offset).limit(limit)
        rows = (await session.execute(stmt)).all()
        
        feeds = []
        for f, sub_id, channel_id in rows:
            # Count unread
            unread_q = select(func.count(SAEntry.id)).where(SAEntry.feed_id == f.id, SAEntry.is_read == False)
            unread = (await session.execute(unread_q)).scalar() or 0
            
            feeds.append(
                Feed(
                    id=f.id,
                    url=f.url,
                    title=f.title,
                    group_name=f.category or "未分组",
                    favicon_url=f.favicon,
                    unread_count=int(unread),
                    last_checked_at=f.last_updated.isoformat() if f.last_updated else None,
                    last_error=f.last_status,
                    channel_id=channel_id
                )
            )
        return feeds
    
    # If no user (or public mode logic), return all feeds or empty
    # For now, let's just return all feeds for backward compatibility/demo
    q = select(SAFeed).order_by(desc(SAFeed.created_at))
    if search:
        q = q.where(or_(SAFeed.title.ilike(f"%{search}%"), SAFeed.url.ilike(f"%{search}%")))
    q = q.offset(offset).limit(limit)
    rows = (await session.execute(q)).scalars().all()
    
    feeds = []
    for f in rows:
        unread_q = select(func.count(SAEntry.id)).where(SAEntry.feed_id == f.id, SAEntry.is_read == False)
        unread = (await session.execute(unread_q)).scalar() or 0
        feeds.append(
            Feed(
                id=f.id,
                url=f.url,
                title=f.title,
                group_name=f.category or "未分组",
                favicon_url=f.favicon,
                unread_count=int(unread),
                last_checked_at=f.last_updated.isoformat() if f.last_updated else None,
                last_error=f.last_status,
            )
        )
    return feeds

@router.get("/admin/feeds", response_model=List[Feed])
async def list_admin_feeds(
    limit: Optional[int] = Query(default=50),
    offset: Optional[int] = Query(default=0),
    search: Optional[str] = Query(None),
    session: AsyncSession = Depends(get_session),
    admin=Depends(get_current_admin),
) -> List[Feed]:
    q = select(SAFeed).order_by(desc(SAFeed.created_at))
    if search:
        q = q.where(or_(SAFeed.title.ilike(f"%{search}%"), SAFeed.url.ilike(f"%{search}%")))
    
    q = q.offset(offset).limit(min(limit, 1000))
    rows = (await session.execute(q)).scalars().all()
    feeds: List[Feed] = []
    for f in rows:
        feeds.append(
            Feed(
                id=f.id,
                url=f.url,
                title=f.title,
                group_name=f.category or "未分组",
                favicon_url=f.favicon,
                unread_count=0,
                last_checked_at=f.last_updated.isoformat() if f.last_updated else None,
                last_error=f.last_status,
                update_interval=f.update_interval
            )
        )
    return feeds

@router.post("/admin/feeds", response_model=Feed)
async def create_admin_feed(
    payload: CreateFeedRequest,
    session: AsyncSession = Depends(get_session),
    admin=Depends(get_current_admin),
) -> Feed:
    existing = (await session.execute(select(SAFeed).where(SAFeed.url == payload.url))).scalar_one_or_none()
    if existing:
        # Just return existing if found
        return Feed(
            id=existing.id,
            url=existing.url,
            title=existing.title,
            group_name=existing.category or "未分组",
            favicon_url=existing.favicon,
            unread_count=0,
            last_checked_at=existing.last_updated.isoformat() + "Z" if existing.last_updated else None,
            last_error=existing.last_status,
        )

    fid = str(uuid4())
    title = payload.title if payload.title else payload.url
    group = payload.group_name if payload.group_name else None
    now = datetime.utcnow()
    
    # Create Feed
    row = SAFeed(
        id=fid,
        title=title,
        url=payload.url,
        category=group,
        favicon=None,
        update_interval=payload.update_interval,
        last_updated=None,
        last_status=None,
        error_count=0,
        created_at=now,
        updated_at=now,
    )
    session.add(row)
    
    # Create Shadow Channel (System Invariant)
    channel_id = str(uuid4())
    ch = SAChannel(
        id=channel_id,
        name=title,
        description=None,
        cover_url=None,
        is_public=False,
        owner_id=None, # System owned
        kind="feed",
        created_at=now,
        updated_at=now,
    )
    session.add(ch)
    session.add(SAChannelSource(channel_id=channel_id, feed_id=fid, order_index=0, weight=100, created_at=now))
    
    await session.commit()
    
    # Trigger fetch
    try:
        from ..services.rss_fetcher import fetch_feed as rss_fetch
        await rss_fetch(session, fid)
    except Exception:
        pass

    return Feed(
        id=fid,
        url=payload.url,
        title=title,
        group_name=group or "未分组",
        favicon_url=None,
        unread_count=0,
        last_checked_at=None,
        last_error=None,
        channel_id=channel_id,
    )

@router.put("/admin/feeds/{id}", response_model=Feed)
async def update_admin_feed(
    id: str, 
    payload: UpdateFeedRequest, 
    session: AsyncSession = Depends(get_session),
    admin=Depends(get_current_admin)
) -> Feed:
    q = await session.execute(select(SAFeed).where(SAFeed.id == id))
    f = q.scalar_one_or_none()
    if not f:
        raise HTTPException(status_code=404)
    if payload.title is not None:
        f.title = payload.title
    if payload.group_name is not None:
        f.category = payload.group_name
    if payload.update_interval is not None:
        f.update_interval = payload.update_interval
    f.updated_at = datetime.utcnow()
    await session.commit()
    return Feed(
        id=f.id,
        url=f.url,
        title=f.title,
        group_name=f.category or "未分组",
        favicon_url=f.favicon,
        unread_count=0,
        last_checked_at=f.last_updated.isoformat() + "Z" if f.last_updated else None,
        last_error=f.last_status,
    )

@router.delete("/admin/feeds/{id}")
async def delete_admin_feed(
    id: str, 
    session: AsyncSession = Depends(get_session),
    admin=Depends(get_current_admin)
) -> dict:
    q = await session.execute(select(SAFeed).where(SAFeed.id == id))
    f = q.scalar_one_or_none()
    if not f:
        raise HTTPException(status_code=404)
    await session.delete(f)
    await session.commit()
    return {"message": "Feed deleted successfully"}

async def list_feeds(
    group_name: Optional[str] = Query(default=None),
    date_range: Optional[str] = Query(default=None),
    time_field: Optional[str] = Query(default=None),
    limit: Optional[int] = Query(default=50),
    offset: Optional[int] = Query(default=0),
    session: AsyncSession = Depends(get_session),
    current: Optional[SAUser] = Depends(get_optional_user),
) -> List[Feed]:
    q = select(SAFeed)
    
    if current:
        # Filter by user subscriptions
        q = q.join(SAChannelSource, SAChannelSource.feed_id == SAFeed.id)\
             .join(SAChannel, SAChannel.id == SAChannelSource.channel_id)\
             .join(SASub, SASub.channel_id == SAChannel.id)\
             .where(SASub.user_id == current.id)\
             .distinct()

    if group_name is not None:
        q = q.where(SAFeed.category == group_name)
    q = q.order_by(desc(SAFeed.created_at)).offset(offset).limit(min(limit, 1000))
    rows = (await session.execute(q)).scalars().all()
    feeds: List[Feed] = []
    for f in rows:
        eq = select(func.count(SAEntry.id)).where(SAEntry.feed_id == f.id, SAEntry.is_read == False)
        eq = apply_date_filter_to_entries_query(eq, date_range, time_field, SAEntry.created_at, SAEntry.published_at)
        unread = (await session.execute(eq)).scalar() or 0
        feeds.append(
            Feed(
                id=f.id,
                url=f.url,
                title=f.title,
                group_name=f.category or "未分组",
                favicon_url=f.favicon,
                unread_count=int(unread),
                last_checked_at=f.last_updated.isoformat() + "Z" if f.last_updated else None,
                last_error=f.last_status,
            )
        )
    return feeds

@router.post("/feeds", response_model=Feed)
async def create_feed(payload: CreateFeedRequest, current: Optional[SAUser] = Depends(get_optional_user), session: AsyncSession = Depends(get_session)) -> Feed:
    existing = (await session.execute(select(SAFeed).where(SAFeed.url == payload.url))).scalar_one_or_none()
    if existing:
        fid = existing.id
        now = datetime.utcnow()
        cs_row = (await session.execute(select(SAChannelSource).where(SAChannelSource.feed_id == fid))).scalar_one_or_none()
        channel_id: Optional[str] = None
        if cs_row:
            channel_id = cs_row.channel_id
            ch = (await session.execute(select(SAChannel).where(SAChannel.id == channel_id))).scalar_one_or_none()
            if ch:
                ch.updated_at = now
                await session.commit()
        else:
            channel_id = str(uuid4())
            ch = SAChannel(
                id=channel_id,
                name=existing.title or payload.url,
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
        try:
            from ..services.rss_fetcher import fetch_feed as rss_fetch
            await rss_fetch(session, fid)
        except Exception:
            pass
        if current and channel_id:
            sub_exists = (await session.execute(select(SASub).where(SASub.user_id == current.id, SASub.channel_id == channel_id))).scalar_one_or_none()
            if not sub_exists:
                sid = str(uuid4())
                sub = SASub(id=sid, user_id=current.id, channel_id=channel_id, notify=False, created_at=now, updated_at=now)
                session.add(sub)
                await session.commit()
        return Feed(
            id=fid,
            url=existing.url,
            title=existing.title,
            group_name=existing.category or "未分组",
            favicon_url=existing.favicon,
            unread_count=0,
            last_checked_at=existing.last_updated.isoformat() + "Z" if existing.last_updated else None,
            last_error=existing.last_status,
            channel_id=channel_id,
        )
    fid = str(uuid4())
    title = payload.title if payload.title else payload.url
    group = payload.group_name if payload.group_name else None
    now = datetime.utcnow()
    row = SAFeed(
        id=fid,
        title=title,
        url=payload.url,
        category=group,
        favicon=None,
        update_interval=payload.update_interval,
        last_updated=None,
        last_status=None,
        error_count=0,
        created_at=now,
        updated_at=now,
    )
    session.add(row)
    await session.commit()
    existing_cs = await session.execute(select(SAChannelSource).where(SAChannelSource.feed_id == fid))
    cs_row = existing_cs.scalar_one_or_none()
    channel_id: str
    if cs_row:
        channel_id = cs_row.channel_id
        ch_q = await session.execute(select(SAChannel).where(SAChannel.id == channel_id))
        ch = ch_q.scalar_one_or_none()
        if ch:
            ch.updated_at = datetime.utcnow()
            await session.commit()
    else:
        channel_id = str(uuid4())
        ch = SAChannel(
            id=channel_id,
            name=title,
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
    try:
        from ..services.rss_fetcher import fetch_feed as rss_fetch
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
    return Feed(
        id=fid,
        url=payload.url,
        title=title,
        group_name=group or "未分组",
        favicon_url=None,
        unread_count=0,
        last_checked_at=None,
        last_error=None,
        channel_id=channel_id,
    )

@router.get("/feeds/{id}", response_model=Feed)
async def get_feed(id: str, session: AsyncSession = Depends(get_session)) -> Feed:
    q = await session.execute(select(SAFeed).where(SAFeed.id == id))
    f = q.scalar_one_or_none()
    if not f:
        raise HTTPException(status_code=404)
    eq = select(func.count(SAEntry.id)).where(SAEntry.feed_id == id, SAEntry.is_read == False)
    unread = (await session.execute(eq)).scalar() or 0
    return Feed(
        id=f.id,
        url=f.url,
        title=f.title,
        group_name=f.category or "未分组",
        favicon_url=f.favicon,
        unread_count=int(unread),
        last_checked_at=f.last_updated.isoformat() + "Z" if f.last_updated else None,
        last_error=f.last_status,
    )

@router.put("/feeds/{id}", response_model=Feed)
@router.patch("/feeds/{id}", response_model=Feed)
async def update_feed(id: str, payload: UpdateFeedRequest, session: AsyncSession = Depends(get_session)) -> Feed:
    q = await session.execute(select(SAFeed).where(SAFeed.id == id))
    f = q.scalar_one_or_none()
    if not f:
        raise HTTPException(status_code=404)
    if payload.title is not None:
        f.title = payload.title
    if payload.group_name is not None:
        f.category = payload.group_name
    if payload.update_interval is not None:
        f.update_interval = payload.update_interval
    f.updated_at = datetime.utcnow()
    await session.commit()
    eq = select(func.count(SAEntry.id)).where(SAEntry.feed_id == id, SAEntry.is_read == False)
    unread = (await session.execute(eq)).scalar() or 0
    return Feed(
        id=f.id,
        url=f.url,
        title=f.title,
        group_name=f.category or "未分组",
        favicon_url=f.favicon,
        unread_count=int(unread),
        last_checked_at=f.last_updated.isoformat() + "Z" if f.last_updated else None,
        last_error=f.last_status,
    )

@router.delete("/feeds/{id}")
async def delete_feed(id: str, session: AsyncSession = Depends(get_session), admin=Depends(get_current_admin)) -> dict:
    q = await session.execute(select(SAFeed).where(SAFeed.id == id))
    f = q.scalar_one_or_none()
    if not f:
        raise HTTPException(status_code=404)
    await session.delete(f)
    await session.commit()
    return {"message": "Feed deleted successfully"}

@router.post("/feeds/{id}/refresh")
async def refresh_feed(id: str, session: AsyncSession = Depends(get_session)) -> dict:
    res = await rss_fetch(session, id)
    return res.dict()
    return res.dict()
