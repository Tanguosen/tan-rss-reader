import feedparser
import httpx
from datetime import datetime, timezone
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from uuid import uuid4
from .models import Feed, Entry

class FetchResult:
    def __init__(self, success: bool, message: str, entries_count: int, new_entries_count: int, response_time_ms: int):
        self.success = success
        self.message = message
        self.entries_count = entries_count
        self.new_entries_count = new_entries_count
        self.response_time_ms = response_time_ms

    def dict(self) -> dict:
        return {
            "success": self.success,
            "message": self.message,
            "entries_count": self.entries_count,
            "new_entries_count": self.new_entries_count,
            "response_time_ms": self.response_time_ms,
        }

async def fetch_feed(session: AsyncSession, feed_id: str) -> FetchResult:
    q = await session.execute(select(Feed).where(Feed.id == feed_id))
    feed = q.scalar_one()
    start = datetime.now(timezone.utc)
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.get(feed.url)
        if resp.status_code >= 400:
            feed.last_status = f"HTTP {resp.status_code}"
            feed.error_count = (feed.error_count or 0) + 1
            feed.last_updated = datetime.utcnow()
            await session.commit()
            return FetchResult(False, "http error", 0, 0, 0)
        text = resp.text
    parsed = feedparser.parse(text)
    total = len(parsed.entries)
    new_count = 0
    for item in parsed.entries:
        link = getattr(item, "link", None)
        if not link:
            continue
        existing = await session.execute(
            select(Entry).where(Entry.feed_id == feed_id, Entry.url == link)
        )
        if existing.scalar_one_or_none():
            continue
        title = getattr(item, "title", None) or "Untitled"
        author = getattr(item, "author", None)
        summary = getattr(item, "summary", None)
        content_val: Optional[str] = None
        contents = getattr(item, "content", None)
        if contents and isinstance(contents, list) and contents:
            content_val = getattr(contents[0], "value", None) or summary
        else:
            content_val = summary
        published_dt: Optional[datetime] = None
        p = getattr(item, "published_parsed", None) or getattr(item, "updated_parsed", None)
        if p:
            try:
                published_dt = datetime(*p[:6], tzinfo=timezone.utc)
            except Exception:
                published_dt = None
        entry = Entry(
            id=str(uuid4()),
            feed_id=feed_id,
            title=title,
            url=link,
            author=author,
            content=content_val,
            summary=summary,
            published_at=published_dt,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow(),
            is_read=False,
            is_starred=False,
            reading_time=None,
            word_count=None,
        )
        session.add(entry)
        new_count += 1
    feed.last_updated = datetime.utcnow()
    feed.last_status = "success"
    feed.error_count = 0
    await session.commit()
    elapsed_ms = int((datetime.now(timezone.utc) - start).total_seconds() * 1000)
    return FetchResult(True, "ok", total, new_count, elapsed_ms)

