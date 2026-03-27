from __future__ import annotations

import json
import re
from datetime import datetime
from typing import Dict, List, Optional, Sequence
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..db import SessionLocal
from ..models import (
    ChannelSource as SAChannelSource,
    Entry as SAEntry,
    EntryAI as SAEntryAI,
    Feed as SAFeed,
    Subscription as SASubscription,
    UserEntryHistory as SAUserEntryHistory,
    UserEntryState as SAUserEntryState,
)
from .ai import generate_trend_analysis
from .auth import get_current_user
from .vector_store import vector_store
from ..user_entry_state import read_value, starred_value

router = APIRouter()


async def get_session() -> AsyncSession:
    async with SessionLocal() as session:
        yield session


class TopicEntry(BaseModel):
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


class ReadingHistoryItem(TopicEntry):
    viewed_at: str
    view_count: int


class RecommendedTopic(BaseModel):
    id: str
    title: str
    summary: str
    reason: str
    key_points: List[str]
    score: float
    entry_count: int
    cover_image: Optional[str] = None
    seed_entry_id: Optional[str] = None
    entries: List[TopicEntry]


def _extract_translated_title(translation_json: Optional[str]) -> Optional[str]:
    if not translation_json:
        return None
    try:
        data = json.loads(translation_json)
        title_map = data.get("title")
        if isinstance(title_map, dict) and title_map:
            return title_map.get("zh-CN") or next(iter(title_map.values()))
    except Exception:
        return None
    return None


def _entry_to_model(
    entry: SAEntry,
    feed_title: Optional[str],
    translation_json: Optional[str] = None,
    state: Optional[SAUserEntryState] = None,
    user_id: Optional[str] = None,
) -> TopicEntry:
    return TopicEntry(
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


def _extract_cover_image(content: Optional[str]) -> Optional[str]:
    if not content:
        return None
    match = re.search(r'<img[^>]+src="([^">]+)"', content, flags=re.IGNORECASE)
    return match.group(1) if match else None


def _build_query_text(entry: SAEntry) -> str:
    parts = [entry.title or ""]
    if entry.summary:
        parts.append(entry.summary[:800])
    elif entry.content:
        parts.append(re.sub(r"<[^>]+>", " ", entry.content)[:1200])
    return "\n\n".join(part for part in parts if part).strip()


def _build_topic_fallback(seed_entry: SAEntry, topic_entries: Sequence[TopicEntry]) -> tuple[str, str, List[str]]:
    title = (seed_entry.title or "为你推荐的专题").strip()
    summary = ""
    for item in topic_entries:
        candidate = item.summary or item.content or ""
        if candidate:
            summary = re.sub(r"<[^>]+>", " ", candidate).strip()
            break
    if not summary:
        summary = "根据你最近阅读和订阅内容生成的相关推荐。"
    summary = re.sub(r"\s+", " ", summary)[:120]

    keywords: List[str] = []
    for item in topic_entries[:4]:
        text = item.translated_title or item.title or ""
        for token in re.split(r"[\s·|:：,，/]+", text):
            token = token.strip()
            if len(token) >= 2 and token not in keywords:
                keywords.append(token)
            if len(keywords) >= 4:
                break
        if len(keywords) >= 4:
            break
    return title[:36], summary, keywords[:4]


async def _get_subscribed_feed_ids(user_id: str, session: AsyncSession) -> List[str]:
    subscribed_channels = (
        await session.execute(
            select(SASubscription.channel_id).where(SASubscription.user_id == user_id)
        )
    ).scalars().all()
    if not subscribed_channels:
        return []

    feed_ids = (
        await session.execute(
            select(SAChannelSource.feed_id).where(SAChannelSource.channel_id.in_(subscribed_channels))
        )
    ).scalars().all()
    return list(dict.fromkeys(feed_ids))


async def _load_entry_rows_by_ids(
    entry_ids: Sequence[str],
    user_id: Optional[str],
    session: AsyncSession,
) -> Dict[str, tuple[SAEntry, Optional[str], Optional[str], Optional[SAUserEntryState]]]:
    if not entry_ids:
        return {}

    rows = (
        await session.execute(
            select(SAEntry, SAFeed.title, SAEntryAI.translation)
            .outerjoin(SAEntryAI, SAEntry.id == SAEntryAI.entry_id)
            .join(SAFeed, SAEntry.feed_id == SAFeed.id)
            .where(SAEntry.id.in_(entry_ids))
        )
    ).all()
    state_map: Dict[str, SAUserEntryState] = {}
    if user_id:
        states = (
            await session.execute(
                select(SAUserEntryState).where(
                    SAUserEntryState.user_id == user_id,
                    SAUserEntryState.entry_id.in_(entry_ids),
                )
            )
        ).scalars().all()
        state_map = {state.entry_id: state for state in states}
    return {
        entry.id: (entry, feed_title, translation_json, state_map.get(entry.id))
        for entry, feed_title, translation_json in rows
    }


async def _load_seed_entries(
    user_id: str,
    subscribed_feed_ids: Sequence[str],
    limit: int,
    session: AsyncSession,
) -> List[SAEntry]:
    history_stmt = (
        select(SAEntry)
        .join(SAUserEntryHistory, SAUserEntryHistory.entry_id == SAEntry.id)
        .where(SAUserEntryHistory.user_id == user_id)
        .order_by(desc(SAUserEntryHistory.last_viewed_at))
        .limit(limit)
    )
    if subscribed_feed_ids:
        history_stmt = history_stmt.where(SAEntry.feed_id.in_(subscribed_feed_ids))

    history_entries = (await session.execute(history_stmt)).scalars().all()
    if history_entries:
        return history_entries

    if not subscribed_feed_ids:
        return []

    fallback_stmt = (
        select(SAEntry)
        .where(SAEntry.feed_id.in_(subscribed_feed_ids))
        .order_by(desc(SAEntry.published_at), desc(SAEntry.created_at))
        .limit(limit)
    )
    return (await session.execute(fallback_stmt)).scalars().all()


@router.post("/me/history/{entry_id}/view")
async def record_entry_view(
    entry_id: str,
    current_user=Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    entry = (
        await session.execute(select(SAEntry.id).where(SAEntry.id == entry_id))
    ).scalar_one_or_none()
    if not entry:
        raise HTTPException(status_code=404, detail="Entry not found")

    now = datetime.utcnow()
    row = (
        await session.execute(
            select(SAUserEntryHistory).where(
                SAUserEntryHistory.user_id == current_user.id,
                SAUserEntryHistory.entry_id == entry_id,
            )
        )
    ).scalar_one_or_none()

    if row:
        row.view_count += 1
        row.last_viewed_at = now
        row.updated_at = now
    else:
        row = SAUserEntryHistory(
            id=str(uuid4()),
            user_id=current_user.id,
            entry_id=entry_id,
            view_count=1,
            first_viewed_at=now,
            last_viewed_at=now,
            created_at=now,
            updated_at=now,
        )
        session.add(row)

    await session.commit()
    return {"success": True, "entry_id": entry_id, "view_count": row.view_count}


@router.get("/me/history", response_model=List[ReadingHistoryItem])
async def list_reading_history(
    limit: int = Query(default=30, ge=1, le=100),
    current_user=Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> List[ReadingHistoryItem]:
    rows = (
        await session.execute(
            select(SAUserEntryHistory, SAEntry, SAFeed.title, SAEntryAI.translation)
            .join(SAEntry, SAUserEntryHistory.entry_id == SAEntry.id)
            .join(SAFeed, SAEntry.feed_id == SAFeed.id)
            .outerjoin(SAEntryAI, SAEntry.id == SAEntryAI.entry_id)
            .where(SAUserEntryHistory.user_id == current_user.id)
            .order_by(desc(SAUserEntryHistory.last_viewed_at))
            .limit(limit)
        )
    ).all()

    items: List[ReadingHistoryItem] = []
    for history, entry, feed_title, translation_json in rows:
        base = _entry_to_model(entry, feed_title, translation_json, None, current_user.id)
        items.append(
            ReadingHistoryItem(
                **base.model_dump(),
                viewed_at=history.last_viewed_at.isoformat() + "Z",
                view_count=history.view_count,
            )
        )
    return items


@router.get("/me/topics/recommended", response_model=List[RecommendedTopic])
async def list_recommended_topics(
    limit: int = Query(default=6, ge=1, le=12),
    current_user=Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> List[RecommendedTopic]:
    subscribed_feed_ids = await _get_subscribed_feed_ids(current_user.id, session)
    seed_entries = await _load_seed_entries(
        current_user.id,
        subscribed_feed_ids,
        limit=min(limit * 2, 10),
        session=session,
    )
    if not seed_entries:
        return []

    topics: List[RecommendedTopic] = []
    seen_entry_sets: List[set[str]] = []

    for seed_entry in seed_entries:
        query_text = _build_query_text(seed_entry)
        if not query_text:
            continue

        try:
            neighbors = await vector_store.search(query_text, limit=12)
        except Exception:
            neighbors = []

        topic_entry_ids: List[str] = [seed_entry.id]
        for hit in neighbors:
            entry_id = hit.get("entry_id")
            feed_id = hit.get("feed_id")
            if not entry_id or entry_id == seed_entry.id:
                continue
            if subscribed_feed_ids and feed_id not in subscribed_feed_ids:
                continue
            if entry_id not in topic_entry_ids:
                topic_entry_ids.append(entry_id)
            if len(topic_entry_ids) >= 8:
                break

        if len(topic_entry_ids) < 2:
            continue

        current_set = set(topic_entry_ids)
        if any(len(current_set & existing) / max(1, len(current_set | existing)) >= 0.6 for existing in seen_entry_sets):
            continue

        entry_map = await _load_entry_rows_by_ids(topic_entry_ids, current_user.id, session)
        ordered_items: List[TopicEntry] = []
        for entry_id in topic_entry_ids:
            row = entry_map.get(entry_id)
            if not row:
                continue
            ordered_items.append(_entry_to_model(*row))

        if len(ordered_items) < 2:
            continue

        analysis_summary = ""
        key_points: List[str] = []
        topic_title = ""
        if len(topics) < 2:
            try:
                analysis_input = "\n\n".join(
                    f"标题: {item.translated_title or item.title}\n内容: {(item.summary or item.content or '')[:300]}"
                    for item in ordered_items[:5]
                )[:4000]
                analysis = await generate_trend_analysis(analysis_input)
                analysis_summary = (analysis.get("summary") or "").strip()
                key_points = [
                    str(item).strip()
                    for item in analysis.get("keywords", [])
                    if str(item).strip()
                ][:4]
                if key_points:
                    topic_title = " / ".join(key_points[:2])[:36]
            except Exception:
                pass

        fallback_title, fallback_summary, fallback_keywords = _build_topic_fallback(seed_entry, ordered_items)
        if not topic_title:
            topic_title = fallback_title
        if not analysis_summary:
            analysis_summary = fallback_summary
        if not key_points:
            key_points = fallback_keywords

        seen_entry_sets.append(current_set)
        topics.append(
            RecommendedTopic(
                id=f"topic-{seed_entry.id}",
                title=topic_title,
                summary=analysis_summary,
                reason=f"基于你最近阅读《{(seed_entry.title or '该文章')[:24]}》以及订阅内容生成",
                key_points=key_points,
                score=round(min(0.99, 0.55 + 0.05 * (len(ordered_items) - 1)), 2),
                entry_count=len(ordered_items),
                cover_image=next(
                    (_extract_cover_image(item.content) for item in ordered_items if _extract_cover_image(item.content)),
                    None,
                ),
                seed_entry_id=seed_entry.id,
                entries=ordered_items,
            )
        )
        if len(topics) >= limit:
            break

    return topics
