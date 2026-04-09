from __future__ import annotations

from datetime import datetime
from uuid import uuid4

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from .models import (
    ChannelSource as SAChannelSource,
    Entry as SAEntry,
    Subscription as SASubscription,
    UserEntryState as SAUserEntryState,
)


async def ensure_feed_and_channel_source_columns(session: AsyncSession) -> None:
    statements = [
        "ALTER TABLE feeds ADD COLUMN owner_id VARCHAR",
        "ALTER TABLE channel_sources ADD COLUMN title_override VARCHAR",
        "ALTER TABLE channel_sources ADD COLUMN update_interval_override INTEGER",
    ]
    for statement in statements:
        try:
            await session.execute(text(statement))
        except Exception:
            pass
    await session.commit()


async def migrate_global_entry_state_to_user_state(session: AsyncSession) -> dict:
    existing_state_count = (
        await session.execute(select(SAUserEntryState.id).limit(1))
    ).scalar_one_or_none()
    if existing_state_count is not None:
        return {"created": 0, "skipped": True}

    subscription_rows = (
        await session.execute(
            select(SASubscription.user_id, SAChannelSource.feed_id)
            .join(SAChannelSource, SAChannelSource.channel_id == SASubscription.channel_id)
        )
    ).all()
    if not subscription_rows:
        return {"created": 0, "skipped": False}

    user_feed_ids: dict[str, set[str]] = {}
    for user_id, feed_id in subscription_rows:
        user_feed_ids.setdefault(user_id, set()).add(feed_id)

    feed_ids = sorted({feed_id for feed_set in user_feed_ids.values() for feed_id in feed_set})
    if not feed_ids:
        return {"created": 0, "skipped": False}

    flagged_entries = (
        await session.execute(
            select(SAEntry).where(
                SAEntry.feed_id.in_(feed_ids),
                (SAEntry.is_read == True) | (SAEntry.is_starred == True),
            )
        )
    ).scalars().all()
    if not flagged_entries:
        return {"created": 0, "skipped": False}

    entries_by_feed: dict[str, list[SAEntry]] = {}
    for entry in flagged_entries:
        entries_by_feed.setdefault(entry.feed_id, []).append(entry)

    now = datetime.utcnow()
    created = 0

    for user_id, subscribed_feeds in user_feed_ids.items():
        for feed_id in subscribed_feeds:
            for entry in entries_by_feed.get(feed_id, []):
                session.add(
                    SAUserEntryState(
                        id=str(uuid4()),
                        user_id=user_id,
                        entry_id=entry.id,
                        is_read=bool(entry.is_read),
                        is_starred=bool(entry.is_starred),
                        created_at=now,
                        updated_at=now,
                    )
                )
                created += 1

    await session.commit()
    return {"created": created, "skipped": False}
