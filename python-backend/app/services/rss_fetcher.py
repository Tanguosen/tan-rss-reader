import feedparser
import httpx
import re
import asyncio
import logging
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import uuid4
from ..models import Feed, Entry
from ..handlers.vector_store import vector_store

logger = logging.getLogger(__name__)

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

async def _vectorize_entries(entries_data: List[Dict[str, Any]]):
    """Background task to vectorizing new entries"""
    try:
        # Ensure connection
        await vector_store.connect()
        if not vector_store.connected:
            return

        count = 0
        for item in entries_data:
            try:
                success = await vector_store.add_entry(
                    entry_id=item["id"],
                    text=item["text"],
                    feed_id=item["feed_id"],
                    published_at=item["published_at"],
                    title=item["title"]
                )
                if success:
                    count += 1
            except Exception as e:
                logger.error(f"Failed to vectorize entry {item['id']}: {e}")
                
        if count > 0:
            logger.info(f"Auto-vectorized {count}/{len(entries_data)} new entries")
    except Exception as e:
        logger.error(f"Auto-vectorization task error: {e}")

async def fetch_feed(session: AsyncSession, feed_id: str) -> FetchResult:
    q = await session.execute(select(Feed).where(Feed.id == feed_id))
    feed = q.scalar_one()
    start = datetime.now(timezone.utc)
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
        "Accept": "application/rss+xml, application/atom+xml, application/xml;q=0.9, text/xml;q=0.8, */*;q=0.1",
        "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
        "Referer": feed.url.rsplit('/', 1)[0] + "/",
        "Cache-Control": "no-cache",
    }
    
    target_url = feed.url
    # Special handling for Arxiv RSS -> API to ensure content availability
    arxiv_match = re.match(r"https?://export\.arxiv\.org/rss/([\w\.-]+)", feed.url)
    if arxiv_match:
        category = arxiv_match.group(1)
        # Use API to get recent papers, bypassing daily RSS limitations
        target_url = f"https://export.arxiv.org/api/query?search_query=cat:{category}&sortBy=submittedDate&sortOrder=descending&max_results=50"

    try:
        async with httpx.AsyncClient(timeout=30, follow_redirects=True, headers=headers) as client:
            resp = await client.get(target_url)
            # 某些站点需要末尾斜杠或重定向后路径不同，尝试一次带斜杠
            if resp.status_code in (404, 403) and not feed.url.endswith("/") and target_url == feed.url:
                resp = await client.get(feed.url + "/")
    except httpx.RequestError:
        feed.last_status = "network error"
        feed.error_count = (feed.error_count or 0) + 1
        feed.last_updated = datetime.utcnow()
        await session.commit()
        elapsed_ms = int((datetime.now(timezone.utc) - start).total_seconds() * 1000)
        return FetchResult(False, "network error", 0, 0, elapsed_ms)
    if resp.status_code >= 400:
        feed.last_status = f"HTTP {resp.status_code}"
        feed.error_count = (feed.error_count or 0) + 1
        feed.last_updated = datetime.utcnow()
        await session.commit()
        elapsed_ms = int((datetime.now(timezone.utc) - start).total_seconds() * 1000)
        return FetchResult(False, "http error", 0, 0, elapsed_ms)
    content_bytes = resp.content
    parsed = feedparser.parse(content_bytes)
    total = len(parsed.entries or [])
    new_count = 0
    new_entries_data: List[Dict[str, Any]] = []
    
    for item in parsed.entries or []:
        link = getattr(item, "link", None)
        if not link:
            continue
        existing = await session.execute(select(Entry).where(Entry.feed_id == feed_id, Entry.url == link))
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
        wc = 0
        if content_val:
            wc = len(content_val.split())
        rt = None
        if wc > 0:
            rt = max(1, int(wc / 200))
        
        entry_id = str(uuid4())
        entry = Entry(
            id=entry_id,
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
            reading_time=rt,
            word_count=wc or None,
        )
        session.add(entry)
        new_count += 1
        
        # Prepare data for vectorization
        ts = int(published_dt.timestamp()) if published_dt else 0
        text_content = f"{title}\n\n{content_val or summary or ''}"
        # Truncate to safe limit (e.g. 8000 chars)
        if len(text_content) > 8000:
            text_content = text_content[:8000]
            
        new_entries_data.append({
            "id": entry_id,
            "text": text_content,
            "feed_id": feed_id,
            "published_at": ts,
            "title": title[:512]
        })

    feed.last_updated = datetime.utcnow()
    if total == 0 and getattr(parsed, "bozo", False):
        feed.last_status = "parse error"
        feed.error_count = (feed.error_count or 0) + 1
    else:
        feed.last_status = "success"
        feed.error_count = 0
    await session.commit()
    
    # Trigger background vectorization
    if new_entries_data:
        asyncio.create_task(_vectorize_entries(new_entries_data))
        
    elapsed_ms = int((datetime.now(timezone.utc) - start).total_seconds() * 1000)
    return FetchResult(True, "ok", total, new_count, elapsed_ms)
