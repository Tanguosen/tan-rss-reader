from fastapi import APIRouter, Query, Depends, HTTPException, Body
from pydantic import BaseModel
from typing import Optional, List, Union
from sqlalchemy import select, func, desc, asc, or_
from sqlalchemy.ext.asyncio import AsyncSession

from ..db import SessionLocal
from ..models import Entry as SAEntry, Feed as SAFeed, EntryAI as SAEntryAI, UserEntryState as SAUserEntryState
from ..user_entry_state import (
    read_value,
    starred_filter,
    starred_value,
    unread_filter,
    upsert_user_entry_state,
    with_user_entry_state,
)
from ..utils.filters import apply_date_filter_to_entries_query
from .auth import get_current_user

router = APIRouter()


async def get_session() -> AsyncSession:
    async with SessionLocal() as session:
        yield session


class Entry(BaseModel):
    id: str
    feed_id: str
    feed_title: Optional[str] = None
    title: Optional[str] = None
    translated_title: Optional[str] = None
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


def _extract_translated_title(translation_json: Optional[str]) -> Optional[str]:
    if not translation_json:
        return None
    try:
        import json

        data = json.loads(translation_json)
        if "title" in data and isinstance(data["title"], dict):
            return data["title"].get("zh-CN") or list(data["title"].values())[0]
    except Exception:
        return None
    return None


def _build_entry_response(
    entry: SAEntry,
    feed_title: Optional[str],
    translation_json: Optional[str],
    state: Optional[SAUserEntryState],
    user_id: Optional[str],
) -> Entry:
    return Entry(
        id=entry.id,
        feed_id=entry.feed_id,
        feed_title=feed_title,
        title=entry.title,
        translated_title=_extract_translated_title(translation_json),
        url=entry.url,
        author=entry.author,
        summary=entry.summary,
        content=entry.content,
        published_at=entry.published_at.isoformat() + "Z" if entry.published_at else None,
        inserted_at=entry.created_at.isoformat() + "Z" if entry.created_at else None,
        read=read_value(entry, state, user_id),
        starred=starred_value(entry, state, user_id),
    )


@router.get("/entries", response_model=List[Entry])
async def list_entries(
    feed_id: Optional[str] = Query(default=None),
    group_name: Optional[str] = Query(default=None),
    unread_only: Optional[bool] = Query(default=None),
    is_starred: Optional[bool] = Query(default=None),
    high_quality_only: Optional[bool] = Query(default=None),
    date_range: Optional[str] = Query(default=None),
    time_field: Optional[str] = Query(default=None),
    limit: Optional[int] = Query(default=100),
    offset: Optional[int] = Query(default=0),
    order_by: Optional[str] = Query(default="created_at"),
    order: Optional[str] = Query(default="desc"),
    session: AsyncSession = Depends(get_session),
    current_user=Depends(get_current_user),
) -> List[Entry]:
    q = (
        select(SAEntry, SAFeed.title, SAEntryAI.translation, SAUserEntryState)
        .outerjoin(SAEntryAI, SAEntry.id == SAEntryAI.entry_id)
        .where(SAEntry.feed_id == SAFeed.id)
    )
    q = with_user_entry_state(q, current_user.id, SAEntry)
    if feed_id is not None:
        q = q.where(SAEntry.feed_id == feed_id)
    if group_name is not None:
        q = q.where(SAFeed.category == group_name)
    if unread_only:
        q = q.where(unread_filter(current_user.id, SAEntry))
    if is_starred is not None:
        q = q.where(
            starred_filter(current_user.id, SAEntry)
            if bool(is_starred)
            else or_(SAUserEntryState.id.is_(None), SAUserEntryState.is_starred == False)
        )
    if high_quality_only:
        q = q.where(or_(SAEntry.quality_score >= 60, SAEntry.word_count >= 100))
    q = apply_date_filter_to_entries_query(q, date_range, time_field, SAEntry.created_at, SAEntry.published_at)
    if order_by == "published_at":
        q = q.order_by(desc(SAEntry.published_at) if order == "desc" else asc(SAEntry.published_at))
    else:
        q = q.order_by(desc(SAEntry.created_at) if order == "desc" else asc(SAEntry.created_at))
    q = q.offset(offset).limit(min(limit, 1000))
    rows = await session.execute(q)
    return [
        _build_entry_response(e, feed_title, translation_json, state, current_user.id)
        for e, feed_title, translation_json, state in rows.all()
    ]


@router.get("/entries/starred", response_model=List[Entry])
async def list_starred_entries(
    limit: Optional[int] = Query(default=100),
    offset: Optional[int] = Query(default=0),
    session: AsyncSession = Depends(get_session),
    current_user=Depends(get_current_user),
) -> List[Entry]:
    q = (
        select(SAEntry, SAFeed.title, SAEntryAI.translation, SAUserEntryState)
        .outerjoin(SAEntryAI, SAEntry.id == SAEntryAI.entry_id)
        .where(SAEntry.feed_id == SAFeed.id)
    )
    q = with_user_entry_state(q, current_user.id, SAEntry).where(starred_filter(current_user.id, SAEntry))
    q = q.order_by(desc(SAEntry.created_at)).offset(offset).limit(min(limit, 1000))
    rows = await session.execute(q)
    return [
        _build_entry_response(e, feed_title, translation_json, state, current_user.id)
        for e, feed_title, translation_json, state in rows.all()
    ]


@router.get("/entries/starred/stats")
async def get_starred_stats(
    session: AsyncSession = Depends(get_session),
    current_user=Depends(get_current_user),
) -> dict:
    count = (
        await session.execute(
            select(func.count(SAUserEntryState.id)).where(
                SAUserEntryState.user_id == current_user.id,
                SAUserEntryState.is_starred == True,
            )
        )
    ).scalar() or 0
    return {"count": int(count)}


@router.get("/entries/{id}", response_model=Entry)
async def get_entry(
    id: str,
    session: AsyncSession = Depends(get_session),
    current_user=Depends(get_current_user),
) -> Entry:
    row = (
        await session.execute(
            select(SAEntry, SAFeed.title, SAEntryAI.translation, SAUserEntryState)
            .outerjoin(SAEntryAI, SAEntry.id == SAEntryAI.entry_id)
            .outerjoin(
                SAUserEntryState,
                (SAUserEntryState.entry_id == SAEntry.id) & (SAUserEntryState.user_id == current_user.id),
            )
            .where(SAEntry.id == id, SAEntry.feed_id == SAFeed.id)
        )
    ).first()
    if not row:
        raise HTTPException(status_code=404)
    return _build_entry_response(*row, current_user.id)


@router.put("/entries/{id}", response_model=Entry)
@router.patch("/entries/{id}", response_model=Entry)
async def update_entry(
    id: str,
    payload: UpdateEntryRequest,
    session: AsyncSession = Depends(get_session),
    current_user=Depends(get_current_user),
) -> Entry:
    row = (
        await session.execute(select(SAEntry, SAFeed.title, SAEntryAI.translation).outerjoin(SAEntryAI, SAEntry.id == SAEntryAI.entry_id).where(SAEntry.id == id, SAEntry.feed_id == SAFeed.id))
    ).first()
    if not row:
        raise HTTPException(status_code=404)
    entry, feed_title, translation_json = row
    await upsert_user_entry_state(
        session,
        current_user.id,
        entry.id,
        read=payload.read,
        starred=payload.starred,
    )
    await session.commit()
    state = (
        await session.execute(
            select(SAUserEntryState).where(
                SAUserEntryState.user_id == current_user.id,
                SAUserEntryState.entry_id == entry.id,
            )
        )
    ).scalar_one_or_none()
    return _build_entry_response(entry, feed_title, translation_json, state, current_user.id)


@router.post("/entries/{id}/read")
async def mark_as_read(
    id: str,
    session: AsyncSession = Depends(get_session),
    current_user=Depends(get_current_user),
) -> dict:
    entry = (await session.execute(select(SAEntry.id).where(SAEntry.id == id))).scalar_one_or_none()
    if not entry:
        raise HTTPException(status_code=404)
    await upsert_user_entry_state(session, current_user.id, id, read=True)
    await session.commit()
    return {"success": True}


@router.post("/entries/{id}/unread")
async def mark_as_unread(
    id: str,
    session: AsyncSession = Depends(get_session),
    current_user=Depends(get_current_user),
) -> dict:
    entry = (await session.execute(select(SAEntry.id).where(SAEntry.id == id))).scalar_one_or_none()
    if not entry:
        raise HTTPException(status_code=404)
    await upsert_user_entry_state(session, current_user.id, id, read=False)
    await session.commit()
    return {"success": True}


@router.post("/entries/{id}/star")
async def star_entry(
    id: str,
    session: AsyncSession = Depends(get_session),
    current_user=Depends(get_current_user),
) -> dict:
    entry = (await session.execute(select(SAEntry.id).where(SAEntry.id == id))).scalar_one_or_none()
    if not entry:
        raise HTTPException(status_code=404)
    await upsert_user_entry_state(session, current_user.id, id, starred=True)
    await session.commit()
    return {"success": True}


@router.post("/entries/{id}/unstar")
async def unstar_entry(
    id: str,
    session: AsyncSession = Depends(get_session),
    current_user=Depends(get_current_user),
) -> dict:
    entry = (await session.execute(select(SAEntry.id).where(SAEntry.id == id))).scalar_one_or_none()
    if not entry:
        raise HTTPException(status_code=404)
    await upsert_user_entry_state(session, current_user.id, id, starred=False)
    await session.commit()
    return {"success": True}


@router.api_route("/entries/{id}/star", methods=["DELETE"])
async def unstar_entry_alias(
    id: str,
    session: AsyncSession = Depends(get_session),
    current_user=Depends(get_current_user),
) -> dict:
    entry = (await session.execute(select(SAEntry.id).where(SAEntry.id == id))).scalar_one_or_none()
    if not entry:
        raise HTTPException(status_code=404)
    await upsert_user_entry_state(session, current_user.id, id, starred=False)
    await session.commit()
    return {"success": True}


@router.post("/entries/bulk-star")
async def bulk_star_entries(
    payload: Union[dict, list] = Body(...),
    session: AsyncSession = Depends(get_session),
    current_user=Depends(get_current_user),
) -> dict:
    ids: list[str] = []
    if isinstance(payload, list):
        ids = [str(i) for i in payload]
    elif isinstance(payload, dict) and isinstance(payload.get("ids"), list):
        ids = [str(i) for i in payload.get("ids")]
    for entry_id in ids:
        if (await session.execute(select(SAEntry.id).where(SAEntry.id == entry_id))).scalar_one_or_none():
            await upsert_user_entry_state(session, current_user.id, entry_id, starred=True)
    await session.commit()
    return {"success": True}


@router.post("/entries/bulk-unstar")
async def bulk_unstar_entries(
    payload: Union[dict, list] = Body(...),
    session: AsyncSession = Depends(get_session),
    current_user=Depends(get_current_user),
) -> dict:
    ids: list[str] = []
    if isinstance(payload, list):
        ids = [str(i) for i in payload]
    elif isinstance(payload, dict) and isinstance(payload.get("ids"), list):
        ids = [str(i) for i in payload.get("ids")]
    for entry_id in ids:
        if (await session.execute(select(SAEntry.id).where(SAEntry.id == entry_id))).scalar_one_or_none():
            await upsert_user_entry_state(session, current_user.id, entry_id, starred=False)
    await session.commit()
    return {"success": True}
