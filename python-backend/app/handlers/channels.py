import re
from fastapi import APIRouter, Query, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional, List
from uuid import uuid4
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc, asc, delete
from ..db import SessionLocal
from ..models import Channel as SAChannel, ChannelSource as SAChannelSource, Feed as SAFeed, Entry as SAEntry, Category as SACategory, Tag as SATag, ChannelTag as SAChannelTag
from ..utils.filters import apply_date_filter_to_entries_query
from .auth import get_current_admin

router = APIRouter()

def extract_first_image(html_content: Optional[str]) -> Optional[str]:
    if not html_content:
        return None
    match = re.search(r'<img[^>]+src=["\']([^"\']+)["\']', html_content)
    if match:
        return match.group(1)
    return None

async def get_session() -> AsyncSession:
    async with SessionLocal() as session:
        yield session

class TagInfo(BaseModel):
    id: str
    name: str

class PreviewEntry(BaseModel):
    id: str
    title: Optional[str]
    cover_image: Optional[str] = None
    published_at: Optional[str] = None

class Channel(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    cover_url: Optional[str] = None
    is_public: bool
    owner_id: Optional[str] = None
    kind: Optional[str] = "topic"
    category_id: Optional[str] = None
    tags: List[TagInfo] = []
    preview_entries: Optional[List[PreviewEntry]] = []
    created_at: Optional[str] = None
    updated_at: Optional[str] = None

class CreateChannelRequest(BaseModel):
    name: str
    description: Optional[str] = None
    cover_url: Optional[str] = None
    is_public: Optional[bool] = True
    owner_id: Optional[str] = None
    category_id: Optional[str] = None
    tags: Optional[List[str]] = None

class UpdateChannelRequest(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    cover_url: Optional[str] = None
    is_public: Optional[bool] = None
    owner_id: Optional[str] = None
    category_id: Optional[str] = None
    tags: Optional[List[str]] = None

class ChannelSourceRequest(BaseModel):
    feed_id: str
    order_index: Optional[int] = None
    weight: Optional[int] = None

class ChannelSourceItem(BaseModel):
    feed_id: str
    url: str
    title: Optional[str] = None
    group_name: Optional[str] = None
    favicon_url: Optional[str] = None
    order_index: Optional[int] = None
    weight: Optional[int] = None
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

@router.get("/channels/square", response_model=List[Channel])
async def channel_square(
    q: Optional[str] = Query(default=None),
    limit: Optional[int] = Query(default=50),
    offset: Optional[int] = Query(default=0),
    session: AsyncSession = Depends(get_session),
) -> List[Channel]:
    query = select(SAChannel).where(SAChannel.is_public == True)
    if q:
        query = query.where(SAChannel.name.ilike(f"%{q}%"))
    query = query.order_by(desc(SAChannel.updated_at)).offset(offset).limit(min(limit, 1000))
    rows = (await session.execute(query)).scalars().all()
    
    if not rows:
        return []

    channel_ids = [c.id for c in rows]
    
    # Fetch tags
    tags_q = select(SAChannelTag.channel_id, SATag).join(SATag, SAChannelTag.tag_id == SATag.id).where(SAChannelTag.channel_id.in_(channel_ids))
    tags_result = (await session.execute(tags_q)).all()
    
    tags_map = {}
    for cid, tag in tags_result:
        if cid not in tags_map:
            tags_map[cid] = []
        tags_map[cid].append(TagInfo(id=tag.id, name=tag.name))

    items: List[Channel] = []
    for c in rows:
        # Fetch previews
        cs_q = select(SAChannelSource.feed_id).where(SAChannelSource.channel_id == c.id)
        feed_ids = (await session.execute(cs_q)).scalars().all()
        
        previews = []
        if feed_ids:
            entries_q = select(SAEntry).where(SAEntry.feed_id.in_(feed_ids)).order_by(desc(SAEntry.published_at)).limit(3)
            entries = (await session.execute(entries_q)).scalars().all()
            
            for e in entries:
                img = extract_first_image(e.content) or extract_first_image(e.summary)
                previews.append(PreviewEntry(
                    id=e.id,
                    title=e.title,
                    cover_image=img,
                    published_at=e.published_at.isoformat() + "Z" if e.published_at else None
                ))

        items.append(
            Channel(
                id=c.id,
                name=c.name,
                description=c.description,
                cover_url=c.cover_url,
                is_public=bool(c.is_public),
                owner_id=c.owner_id,
                kind=c.kind,
                category_id=c.category_id,
                tags=tags_map.get(c.id, []),
                preview_entries=previews,
                created_at=c.created_at.isoformat() + "Z" if c.created_at else None,
                updated_at=c.updated_at.isoformat() + "Z" if c.updated_at else None,
            )
        )
    return items

@router.get("/admin/channels", response_model=List[Channel])
async def list_channels(
    is_public: Optional[bool] = Query(default=None),
    limit: Optional[int] = Query(default=50),
    offset: Optional[int] = Query(default=0),
    session: AsyncSession = Depends(get_session),
    admin=Depends(get_current_admin)
) -> List[Channel]:
    q = select(SAChannel)
    if is_public is not None:
        q = q.where(SAChannel.is_public == bool(is_public))
    q = q.order_by(desc(SAChannel.updated_at)).offset(offset).limit(min(limit, 1000))
    rows = (await session.execute(q)).scalars().all()
    
    if not rows:
        return []

    channel_ids = [c.id for c in rows]
    
    # Fetch tags
    tags_q = select(SAChannelTag.channel_id, SATag).join(SATag, SAChannelTag.tag_id == SATag.id).where(SAChannelTag.channel_id.in_(channel_ids))
    tags_result = (await session.execute(tags_q)).all()
    
    tags_map = {}
    for cid, tag in tags_result:
        if cid not in tags_map:
            tags_map[cid] = []
        tags_map[cid].append(TagInfo(id=tag.id, name=tag.name))

    items: List[Channel] = []
    for c in rows:
        items.append(
            Channel(
                id=c.id,
                name=c.name,
                description=c.description,
                cover_url=c.cover_url,
                is_public=bool(c.is_public),
                owner_id=c.owner_id,
                category_id=c.category_id,
                tags=tags_map.get(c.id, []),
                created_at=c.created_at.isoformat() + "Z" if c.created_at else None,
                updated_at=c.updated_at.isoformat() + "Z" if c.updated_at else None,
            )
        )
    return items

@router.post("/admin/channels", response_model=Channel)
async def create_channel(payload: CreateChannelRequest, session: AsyncSession = Depends(get_session), admin=Depends(get_current_admin)) -> Channel:
    cid = str(uuid4())
    now = datetime.utcnow()
    row = SAChannel(
        id=cid,
        name=payload.name,
        description=payload.description,
        cover_url=payload.cover_url,
        is_public=bool(payload.is_public) if payload.is_public is not None else True,
        owner_id=payload.owner_id,
        category_id=payload.category_id,
        created_at=now,
        updated_at=now,
    )
    session.add(row)
    
    if payload.tags:
        for tag_id in payload.tags:
            session.add(SAChannelTag(channel_id=cid, tag_id=tag_id))
            
    await session.commit()
    
    # Fetch tags for response
    tags_response = []
    if payload.tags:
         tq = select(SATag).where(SATag.id.in_(payload.tags))
         trows = (await session.execute(tq)).scalars().all()
         tags_response = [TagInfo(id=t.id, name=t.name) for t in trows]

    return Channel(
        id=row.id,
        name=row.name,
        description=row.description,
        cover_url=row.cover_url,
        is_public=bool(row.is_public),
        owner_id=row.owner_id,
        category_id=row.category_id,
        tags=tags_response,
        created_at=row.created_at.isoformat() + "Z" if row.created_at else None,
        updated_at=row.updated_at.isoformat() + "Z" if row.updated_at else None,
    )

@router.get("/admin/channels/{id}", response_model=Channel)
async def get_channel(id: str, session: AsyncSession = Depends(get_session), admin=Depends(get_current_admin)) -> Channel:
    q = await session.execute(select(SAChannel).where(SAChannel.id == id))
    c = q.scalar_one_or_none()
    if not c:
        raise HTTPException(status_code=404)
        
    # Fetch tags
    tags_q = select(SATag).join(SAChannelTag, SAChannelTag.tag_id == SATag.id).where(SAChannelTag.channel_id == id)
    tags_rows = (await session.execute(tags_q)).scalars().all()
    tags_list = [TagInfo(id=t.id, name=t.name) for t in tags_rows]

    return Channel(
        id=c.id,
        name=c.name,
        description=c.description,
        cover_url=c.cover_url,
        is_public=bool(c.is_public),
        owner_id=c.owner_id,
        category_id=c.category_id,
        tags=tags_list,
        created_at=c.created_at.isoformat() + "Z" if c.created_at else None,
        updated_at=c.updated_at.isoformat() + "Z" if c.updated_at else None,
    )

@router.patch("/admin/channels/{id}", response_model=Channel)
@router.put("/admin/channels/{id}", response_model=Channel)
async def update_channel(id: str, payload: UpdateChannelRequest, session: AsyncSession = Depends(get_session), admin=Depends(get_current_admin)) -> Channel:
    q = await session.execute(select(SAChannel).where(SAChannel.id == id))
    c = q.scalar_one_or_none()
    if not c:
        raise HTTPException(status_code=404)
    if payload.name is not None:
        c.name = payload.name
    if payload.description is not None:
        c.description = payload.description
    if payload.cover_url is not None:
        c.cover_url = payload.cover_url
    if payload.is_public is not None:
        c.is_public = bool(payload.is_public)
    if payload.owner_id is not None:
        c.owner_id = payload.owner_id
    if payload.category_id is not None:
        c.category_id = payload.category_id
        
    if payload.tags is not None:
        # Update tags
        await session.execute(delete(SAChannelTag).where(SAChannelTag.channel_id == id))
        for tag_id in payload.tags:
            session.add(SAChannelTag(channel_id=id, tag_id=tag_id))
            
    c.updated_at = datetime.utcnow()
    await session.commit()
    
    # Fetch tags for response
    tags_q = select(SATag).join(SAChannelTag, SAChannelTag.tag_id == SATag.id).where(SAChannelTag.channel_id == id)
    tags_rows = (await session.execute(tags_q)).scalars().all()
    tags_list = [TagInfo(id=t.id, name=t.name) for t in tags_rows]

    return Channel(
        id=c.id,
        name=c.name,
        description=c.description,
        cover_url=c.cover_url,
        is_public=bool(c.is_public),
        owner_id=c.owner_id,
        category_id=c.category_id,
        tags=tags_list,
        created_at=c.created_at.isoformat() + "Z" if c.created_at else None,
        updated_at=c.updated_at.isoformat() + "Z" if c.updated_at else None,
    )

@router.delete("/admin/channels/{id}")
async def delete_channel(id: str, session: AsyncSession = Depends(get_session), admin=Depends(get_current_admin)) -> dict:
    q = await session.execute(select(SAChannel).where(SAChannel.id == id))
    c = q.scalar_one_or_none()
    if not c:
        raise HTTPException(status_code=404)
    await session.execute(delete(SAChannelSource).where(SAChannelSource.channel_id == id))
    await session.delete(c)
    await session.commit()
    return {"message": "Channel deleted successfully"}

@router.get("/admin/channels/{id}/sources", response_model=List[ChannelSourceItem])
async def list_channel_sources(
    id: str,
    session: AsyncSession = Depends(get_session),
    admin=Depends(get_current_admin)
) -> List[ChannelSourceItem]:
    q = await session.execute(
        select(SAChannelSource, SAFeed).where(SAChannelSource.channel_id == id, SAChannelSource.feed_id == SAFeed.id).order_by(asc(SAChannelSource.order_index), desc(SAChannelSource.created_at))
    )
    items: List[ChannelSourceItem] = []
    for cs, f in q.all():
        items.append(
            ChannelSourceItem(
                feed_id=f.id,
                url=f.url,
                title=f.title,
                group_name=f.category or "未分组",
                favicon_url=f.favicon,
                order_index=cs.order_index,
                weight=cs.weight,
                created_at=cs.created_at.isoformat() + "Z" if cs.created_at else None,
            )
        )
    return items

@router.post("/admin/channels/{id}/sources")
async def add_channel_source(id: str, payload: ChannelSourceRequest, session: AsyncSession = Depends(get_session), admin=Depends(get_current_admin)) -> dict:
    fq = await session.execute(select(SAFeed).where(SAFeed.id == payload.feed_id))
    f = fq.scalar_one_or_none()
    if not f:
        raise HTTPException(status_code=404)
    exists = (await session.execute(select(SAChannelSource).where(SAChannelSource.channel_id == id, SAChannelSource.feed_id == payload.feed_id))).scalar_one_or_none()
    if exists:
        return {"message": "Exists"}
    row = SAChannelSource(
        channel_id=id,
        feed_id=payload.feed_id,
        order_index=payload.order_index,
        weight=payload.weight,
        created_at=datetime.utcnow(),
    )
    session.add(row)
    await session.commit()
    return {"message": "Added"}

@router.delete("/admin/channels/{id}/sources/{feed_id}")
async def remove_channel_source(id: str, feed_id: str, session: AsyncSession = Depends(get_session), admin=Depends(get_current_admin)) -> dict:
    await session.execute(delete(SAChannelSource).where(SAChannelSource.channel_id == id, SAChannelSource.feed_id == feed_id))
    await session.commit()
    return {"message": "Removed"}

@router.get("/channels/{id}/entries", response_model=List[Entry])
async def channel_entries(
    id: str,
    unread_only: Optional[bool] = Query(default=None),
    date_range: Optional[str] = Query(default=None),
    time_field: Optional[str] = Query(default=None),
    limit: Optional[int] = Query(default=100),
    offset: Optional[int] = Query(default=0),
    order_by: Optional[str] = Query(default="created_at"),
    order: Optional[str] = Query(default="desc"),
    session: AsyncSession = Depends(get_session),
) -> List[Entry]:
    rows = (await session.execute(select(SAChannelSource.feed_id).where(SAChannelSource.channel_id == id))).scalars().all()
    if not rows:
        return []
    q = select(SAEntry, SAFeed.title).where(SAEntry.feed_id == SAFeed.id, SAEntry.feed_id.in_(rows))
    if unread_only:
        q = q.where(SAEntry.is_read == False)
    q = apply_date_filter_to_entries_query(q, date_range, time_field, SAEntry.created_at, SAEntry.published_at)
    if order_by == "published_at":
        q = q.order_by(desc(SAEntry.published_at) if order == "desc" else asc(SAEntry.published_at))
    else:
        q = q.order_by(desc(SAEntry.created_at) if order == "desc" else asc(SAEntry.created_at))
    q = q.offset(offset).limit(min(limit, 1000))
    result = await session.execute(q)
    items: List[Entry] = []
    for e, feed_title in result.all():
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
