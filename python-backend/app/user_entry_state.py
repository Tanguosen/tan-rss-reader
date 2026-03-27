from __future__ import annotations

from datetime import datetime
from typing import Iterable, Optional, Sequence
from uuid import uuid4

from sqlalchemy import Select, and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from .models import Entry as SAEntry
from .models import UserEntryState as SAUserEntryState


def with_user_entry_state(
    stmt: Select,
    user_id: Optional[str],
    entry_model=SAEntry,
) -> Select:
    if not user_id:
        return stmt
    return stmt.outerjoin(
        SAUserEntryState,
        and_(
            SAUserEntryState.entry_id == entry_model.id,
            SAUserEntryState.user_id == user_id,
        ),
    )


def unread_filter(user_id: Optional[str], entry_model=SAEntry):
    if not user_id:
        return entry_model.is_read == False
    return or_(SAUserEntryState.id.is_(None), SAUserEntryState.is_read == False)


def starred_filter(user_id: Optional[str], entry_model=SAEntry):
    if not user_id:
        return entry_model.is_starred == True
    return SAUserEntryState.is_starred == True


def read_value(entry: SAEntry, state: Optional[SAUserEntryState], user_id: Optional[str]) -> bool:
    if user_id:
        return bool(state.is_read) if state else False
    return bool(entry.is_read)


def starred_value(entry: SAEntry, state: Optional[SAUserEntryState], user_id: Optional[str]) -> bool:
    if user_id:
        return bool(state.is_starred) if state else False
    return bool(entry.is_starred)


async def count_unread_for_feeds(
    session: AsyncSession,
    feed_ids: Sequence[str],
    user_id: Optional[str],
) -> dict[str, int]:
    if not feed_ids:
        return {}

    if not user_id:
        rows = (
            await session.execute(
                select(SAEntry.feed_id, func.count(SAEntry.id))
                .where(SAEntry.feed_id.in_(feed_ids), SAEntry.is_read == False)
                .group_by(SAEntry.feed_id)
            )
        ).all()
        return {feed_id: int(count) for feed_id, count in rows}

    rows = (
        await session.execute(
            select(SAEntry.feed_id, func.count(SAEntry.id))
            .outerjoin(
                SAUserEntryState,
                and_(
                    SAUserEntryState.entry_id == SAEntry.id,
                    SAUserEntryState.user_id == user_id,
                ),
            )
            .where(SAEntry.feed_id.in_(feed_ids))
            .where(or_(SAUserEntryState.id.is_(None), SAUserEntryState.is_read == False))
            .group_by(SAEntry.feed_id)
        )
    ).all()
    return {feed_id: int(count) for feed_id, count in rows}


async def upsert_user_entry_state(
    session: AsyncSession,
    user_id: str,
    entry_id: str,
    *,
    read: Optional[bool] = None,
    starred: Optional[bool] = None,
) -> SAUserEntryState:
    now = datetime.utcnow()
    row = (
        await session.execute(
            select(SAUserEntryState).where(
                SAUserEntryState.user_id == user_id,
                SAUserEntryState.entry_id == entry_id,
            )
        )
    ).scalar_one_or_none()

    if not row:
        row = SAUserEntryState(
            id=str(uuid4()),
            user_id=user_id,
            entry_id=entry_id,
            is_read=bool(read) if read is not None else False,
            is_starred=bool(starred) if starred is not None else False,
            created_at=now,
            updated_at=now,
        )
        session.add(row)
    else:
        if read is not None:
            row.is_read = bool(read)
        if starred is not None:
            row.is_starred = bool(starred)
        row.updated_at = now
    return row


async def bulk_mark_read_for_entries(
    session: AsyncSession,
    user_id: str,
    entry_ids: Iterable[str],
    *,
    read: bool,
) -> int:
    unique_ids = list(dict.fromkeys(entry_ids))
    if not unique_ids:
        return 0

    existing_rows = (
        await session.execute(
            select(SAUserEntryState).where(
                SAUserEntryState.user_id == user_id,
                SAUserEntryState.entry_id.in_(unique_ids),
            )
        )
    ).scalars().all()
    existing_map = {row.entry_id: row for row in existing_rows}
    now = datetime.utcnow()

    updated = 0
    for entry_id in unique_ids:
        row = existing_map.get(entry_id)
        if row:
            if row.is_read != bool(read):
                row.is_read = bool(read)
                row.updated_at = now
            updated += 1
            continue

        session.add(
            SAUserEntryState(
                id=str(uuid4()),
                user_id=user_id,
                entry_id=entry_id,
                is_read=bool(read),
                is_starred=False,
                created_at=now,
                updated_at=now,
            )
        )
        updated += 1
    return updated
