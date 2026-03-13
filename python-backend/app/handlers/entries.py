from fastapi import APIRouter, Query, Depends, HTTPException, Body
from typing import Union
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc, asc
from ..db import SessionLocal
from ..models import Entry as SAEntry, Feed as SAFeed
from ..utils.filters import apply_date_filter_to_entries_query

router = APIRouter()

async def get_session() -> AsyncSession:
    async with SessionLocal() as session:
        yield session

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

class UpdateEntryRequest(BaseModel):
    read: Optional[bool] = None
    starred: Optional[bool] = None

class BulkEntriesRequest(BaseModel):
    ids: List[str]

@router.get("/entries", response_model=List[Entry])
async def list_entries(
    feed_id: Optional[str] = Query(default=None),
    group_name: Optional[str] = Query(default=None),
    unread_only: Optional[bool] = Query(default=None),
    is_starred: Optional[bool] = Query(default=None),
    date_range: Optional[str] = Query(default=None),
    time_field: Optional[str] = Query(default=None),
    limit: Optional[int] = Query(default=100),
    offset: Optional[int] = Query(default=0),
    order_by: Optional[str] = Query(default="created_at"),
    order: Optional[str] = Query(default="desc"),
    session: AsyncSession = Depends(get_session),
) -> List[Entry]:
    q = select(SAEntry, SAFeed.title).where(SAEntry.feed_id == SAFeed.id)
    if feed_id is not None:
        q = q.where(SAEntry.feed_id == feed_id)
    if group_name is not None:
        q = q.where(SAFeed.category == group_name)
    if unread_only:
        q = q.where(SAEntry.is_read == False)
    if is_starred is not None:
        q = q.where(SAEntry.is_starred == bool(is_starred))
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

@router.get("/entries/starred", response_model=List[Entry])
async def list_starred_entries(
    limit: Optional[int] = Query(default=100),
    offset: Optional[int] = Query(default=0),
    session: AsyncSession = Depends(get_session),
) -> List[Entry]:
    q = select(SAEntry, SAFeed.title).where(SAEntry.feed_id == SAFeed.id, SAEntry.is_starred == True)
    q = q.order_by(desc(SAEntry.created_at)).offset(offset).limit(min(limit, 1000))
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

@router.get("/entries/starred/stats")
async def get_starred_stats(session: AsyncSession = Depends(get_session)) -> dict:
    count = (await session.execute(select(func.count(SAEntry.id)).where(SAEntry.is_starred == True))).scalar() or 0
    return {"count": int(count)}

@router.get("/entries/{id}", response_model=Entry)
async def get_entry(id: str, session: AsyncSession = Depends(get_session)) -> Entry:
    q = await session.execute(select(SAEntry, SAFeed.title).where(SAEntry.id == id, SAEntry.feed_id == SAFeed.id))
    row = q.first()
    if not row:
        raise HTTPException(status_code=404)
    e, feed_title = row
    return Entry(
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

@router.put("/entries/{id}", response_model=Entry)
@router.patch("/entries/{id}", response_model=Entry)
async def update_entry(id: str, payload: UpdateEntryRequest, session: AsyncSession = Depends(get_session)) -> Entry:
    q = await session.execute(select(SAEntry, SAFeed.title).where(SAEntry.id == id, SAEntry.feed_id == SAFeed.id))
    row = q.first()
    if not row:
        raise HTTPException(status_code=404)
    e, feed_title = row
    if payload.read is not None:
        e.is_read = bool(payload.read)
    if payload.starred is not None:
        e.is_starred = bool(payload.starred)
    e.updated_at = datetime.utcnow()
    await session.commit()
    return Entry(
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

@router.post("/entries/{id}/read")
async def mark_as_read(id: str, session: AsyncSession = Depends(get_session)) -> dict:
    q = await session.execute(select(SAEntry).where(SAEntry.id == id))
    e = q.scalar_one_or_none()
    if not e:
        raise HTTPException(status_code=404)
    e.is_read = True
    e.updated_at = datetime.utcnow()
    await session.commit()
    return {"success": True}

@router.post("/entries/{id}/unread")
async def mark_as_unread(id: str, session: AsyncSession = Depends(get_session)) -> dict:
    q = await session.execute(select(SAEntry).where(SAEntry.id == id))
    e = q.scalar_one_or_none()
    if not e:
        raise HTTPException(status_code=404)
    e.is_read = False
    e.updated_at = datetime.utcnow()
    await session.commit()
    return {"success": True}

@router.post("/entries/{id}/star")
async def star_entry(id: str, session: AsyncSession = Depends(get_session)) -> dict:
    q = await session.execute(select(SAEntry).where(SAEntry.id == id))
    e = q.scalar_one_or_none()
    if not e:
        raise HTTPException(status_code=404)
    e.is_starred = True
    e.updated_at = datetime.utcnow()
    await session.commit()
    return {"success": True}

@router.post("/entries/{id}/unstar")
async def unstar_entry(id: str, session: AsyncSession = Depends(get_session)) -> dict:
    q = await session.execute(select(SAEntry).where(SAEntry.id == id))
    e = q.scalar_one_or_none()
    if not e:
        raise HTTPException(status_code=404)
    e.is_starred = False
    e.updated_at = datetime.utcnow()
    await session.commit()
    return {"success": True}

@router.api_route("/entries/{id}/star", methods=["DELETE"])
async def unstar_entry_alias(id: str, session: AsyncSession = Depends(get_session)) -> dict:
    q = await session.execute(select(SAEntry).where(SAEntry.id == id))
    e = q.scalar_one_or_none()
    if not e:
        raise HTTPException(status_code=404)
    e.is_starred = False
    e.updated_at = datetime.utcnow()
    await session.commit()
    return {"success": True}

@router.post("/entries/bulk-star")
async def bulk_star_entries(payload: Union[dict, list] = Body(...), session: AsyncSession = Depends(get_session)) -> dict:
    ids: list[str] = []
    if isinstance(payload, list):
        ids = [str(i) for i in payload]
    elif isinstance(payload, dict) and isinstance(payload.get("ids"), list):
        ids = [str(i) for i in payload.get("ids")]
    for i in ids:
        q = await session.execute(select(SAEntry).where(SAEntry.id == i))
        e = q.scalar_one_or_none()
        if e:
            e.is_starred = True
            e.updated_at = datetime.utcnow()
    await session.commit()
    return {"success": True}

@router.post("/entries/bulk-unstar")
async def bulk_unstar_entries(payload: Union[dict, list] = Body(...), session: AsyncSession = Depends(get_session)) -> dict:
    ids: list[str] = []
    if isinstance(payload, list):
        ids = [str(i) for i in payload]
    elif isinstance(payload, dict) and isinstance(payload.get("ids"), list):
        ids = [str(i) for i in payload.get("ids")]
    for i in ids:
        q = await session.execute(select(SAEntry).where(SAEntry.id == i))
        e = q.scalar_one_or_none()
        if e:
            e.is_starred = False
            e.updated_at = datetime.utcnow()
    await session.commit()
    return {"success": True}
