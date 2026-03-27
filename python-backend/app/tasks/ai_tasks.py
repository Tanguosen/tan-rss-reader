import asyncio
import logging
from typing import List, Dict, Any
from app.celery_app import celery_app

logger = logging.getLogger(__name__)

def run_async(coro):
    try:
        loop = asyncio.get_event_loop()
    except RuntimeError:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
    return loop.run_until_complete(coro)

@celery_app.task(name="app.tasks.ai_tasks.batch_quality_scoring")
def batch_quality_scoring_task(entries_data: List[Dict[str, Any]]):
    """Celery task for batch AI quality scoring"""
    from app.handlers.ai import score_article_quality, AI_CFG
    from app.db import SessionLocal
    from app.models import Entry
    from sqlalchemy import update

    if not AI_CFG["features"].get("auto_quality_scoring", True):
        return {"status": "skipped", "reason": "auto_quality_scoring disabled"}

    async def _do_scoring():
        try:
            async with SessionLocal() as session:
                scored = 0
                for item in entries_data:
                    try:
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
                return {"status": "success", "scored": scored}
        except Exception as e:
            logger.error(f"Batch quality scoring task error: {e}")
            return {"status": "error", "message": str(e)}

    return run_async(_do_scoring())

@celery_app.task(name="app.tasks.ai_tasks.vectorize_entries")
def vectorize_entries_task(entries_data: List[Dict[str, Any]]):
    """Celery task for vectorizing new entries"""
    from app.handlers.vector_store import vector_store

    async def _do_vectorize():
        try:
            await vector_store.connect()
            if not vector_store.connected:
                return {"status": "skipped", "reason": "vector store not connected"}

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
            return {"status": "success", "vectorized": count}
        except Exception as e:
            logger.error(f"Auto-vectorization task error: {e}")
            return {"status": "error", "message": str(e)}

    return run_async(_do_vectorize())
