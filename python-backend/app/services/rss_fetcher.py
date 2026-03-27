import feedparser
import httpx
import re
import asyncio
import hashlib
import logging
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any
from uuid import uuid4

logger = logging.getLogger(__name__)

def compute_dedup_key(url: str, title: Optional[str] = None, content: Optional[str] = None) -> str:
    normalized_url = url.strip().lower()
    if normalized_url.startswith("http://"):
        normalized_url = "https://" + normalized_url[7:]
    elif not normalized_url.startswith("https://"):
        normalized_url = "https://" + normalized_url

    key_material = normalized_url
    if title:
        key_material = f"{key_material}|{title.strip().lower()[:200]}"
    if content:
        content_hash = hashlib.md5(content.encode('utf-8', errors='ignore')).hexdigest()[:16]
        key_material = f"{key_material}|{content_hash}"

    return hashlib.sha256(key_material.encode('utf-8')).hexdigest()[:32]

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

async def _batch_quality_scoring(entries_data: List[Dict[str, Any]]):
    from sqlalchemy.ext.asyncio import AsyncSession
    from sqlalchemy import update
    from ..db import SessionLocal
    from ..models import Entry

    try:
        async with SessionLocal() as session:
            scored = 0
            for item in entries_data:
                try:
                    from ..handlers.ai import score_article_quality, AI_CFG
                    if not AI_CFG["features"].get("auto_quality_scoring", True):
                        return
                    score = await score_article_quality(item["title"], item["content"])
                    await session.execute(
                        update(Entry)
                        .where(Entry.id == item["id"])
                        .values(quality_score=score)
                    )
                    scored += 1
                except Exception as e:
                    logger.error(f"Failed to score entry {item['id']}: {e}")
                    continue
            await session.commit()
            if scored > 0:
                logger.info(f"Batch quality scoring completed for {scored} entries")
    except Exception as e:
        logger.error(f"Batch quality scoring task error: {e}")

async def _vectorize_entries(entries_data: List[Dict[str, Any]]):
    from ..handlers.vector_store import vector_store

    try:
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

async def fetch_feed(session, feed_id: str) -> FetchResult:
    from sqlalchemy import select
    from sqlalchemy.ext.asyncio import AsyncSession
    from ..models import Feed, Entry

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
    arxiv_match = re.match(r"https?://export\.arxiv\.org/rss/([\w\.-]+)", feed.url)
    if arxiv_match:
        category = arxiv_match.group(1)
        target_url = f"https://export.arxiv.org/api/query?search_query=cat:{category}&sortBy=submittedDate&sortOrder=descending&max_results=50"

    try:
        async with httpx.AsyncClient(timeout=30, follow_redirects=True, headers=headers) as client:
            resp = await client.get(target_url)
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
    skipped_dedup = 0
    new_entries_data: List[Dict[str, Any]] = []
    new_entries_for_scoring: List[Dict[str, Any]] = []

    dedup_keys_in_batch = set()

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

        dedup_key = compute_dedup_key(link, title, content_val)

        if dedup_key in dedup_keys_in_batch:
            skipped_dedup += 1
            continue

        existing_dedup = await session.execute(select(Entry).where(Entry.dedup_key == dedup_key))
        if existing_dedup.scalar_one_or_none():
            skipped_dedup += 1
            continue

        dedup_keys_in_batch.add(dedup_key)

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

        quality_score = 0
        if wc > 1000:
            quality_score += 50
        elif wc > 300:
            quality_score += 30
        elif wc > 50:
            quality_score += 10
        if title and len(title) > 10:
            quality_score += 10
        quality_score = min(quality_score, 100)

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
            word_count=wc,
            quality_score=quality_score,
            dedup_key=dedup_key
        )
        session.add(entry)
        new_count += 1

        ts = int(published_dt.timestamp()) if published_dt else 0
        text_content = f"{title}\n\n{content_val or summary or ''}"
        if len(text_content) > 8000:
            text_content = text_content[:8000]

        new_entries_data.append({
            "id": entry_id,
            "text": text_content,
            "feed_id": feed_id,
            "published_at": ts,
            "title": title[:512]
        })

        new_entries_for_scoring.append({
            "id": entry_id,
            "title": title,
            "content": content_val or summary or ""
        })

    if hasattr(parsed, 'feed'):
        if not feed.title and getattr(parsed.feed, 'title', None):
            feed.title = parsed.feed.title
            
        # Try to extract favicon from the parsed feed if not already set
        if not feed.favicon:
            if hasattr(parsed.feed, 'image') and hasattr(parsed.feed.image, 'href'):
                feed.favicon = parsed.feed.image.href
            elif hasattr(parsed.feed, 'icon'):
                feed.favicon = parsed.feed.icon
            elif hasattr(parsed.feed, 'logo'):
                feed.favicon = parsed.feed.logo
            elif hasattr(parsed.feed, 'link'):
                from urllib.parse import urlparse
                parsed_link = urlparse(parsed.feed.link)
                if parsed_link.netloc:
                    feed.favicon = f"{parsed_link.scheme}://{parsed_link.netloc}/favicon.ico"

    feed.last_updated = datetime.utcnow()
    if total == 0 and getattr(parsed, "bozo", False):
        feed.last_status = "parse error"
        feed.error_count = (feed.error_count or 0) + 1
    else:
        feed.last_status = "success"
        feed.error_count = 0
    await session.commit()

    import os
    use_celery = os.getenv("USE_CELERY", "false").lower() == "true"

    if new_entries_data:
        if use_celery:
            try:
                from ..celery_app import celery_app
                celery_app.send_task("app.tasks.ai_tasks.vectorize_entries", args=[new_entries_data])
            except Exception as e:
                logger.warning(f"Failed to queue celery task for vectorization, falling back to asyncio: {e}")
                asyncio.create_task(_vectorize_entries(new_entries_data))
        else:
            asyncio.create_task(_vectorize_entries(new_entries_data))
            
    if new_entries_for_scoring:
        if use_celery:
            try:
                from ..celery_app import celery_app
                celery_app.send_task("app.tasks.ai_tasks.batch_quality_scoring", args=[new_entries_for_scoring])
            except Exception as e:
                logger.warning(f"Failed to queue celery task for scoring, falling back to asyncio: {e}")
                asyncio.create_task(_batch_quality_scoring(new_entries_for_scoring))
        else:
            asyncio.create_task(_batch_quality_scoring(new_entries_for_scoring))

    elapsed_ms = int((datetime.now(timezone.utc) - start).total_seconds() * 1000)
    msg = "ok"
    if skipped_dedup > 0:
        msg = f"ok, {skipped_dedup} duplicate(s) skipped by dedup_key"
    return FetchResult(True, msg, total, new_count, elapsed_ms)
