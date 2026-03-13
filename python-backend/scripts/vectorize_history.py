import asyncio
import logging
import sys
import os
from typing import List
import argparse

# Add parent directory to path to import app modules
# We are in python-backend/scripts/, need to go up one level to python-backend/
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import select
from app.db import SessionLocal
from app.models import Entry
from app.handlers.vector_store import vector_store
from app.handlers.ai import init_ai_config

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

async def vectorize_entries(force: bool = False, limit: int = 0):
    logger.info("Starting historical data vectorization...")
    
    async with SessionLocal() as session:
        # 1. Initialize AI Config
        logger.info("Loading AI configuration...")
        await init_ai_config(session)
        
        # 2. Connect to Milvus
        logger.info("Connecting to Milvus...")
        await vector_store.connect()
        if not vector_store.connected:
            logger.error("Failed to connect to Milvus. Exiting.")
            return

        # 3. Fetch all entries
        logger.info("Fetching entries from database...")
        stmt = select(Entry)
        if limit > 0:
            stmt = stmt.limit(limit)
            
        result = await session.execute(stmt)
        entries = result.scalars().all()
        total_entries = len(entries)
        logger.info(f"Found {total_entries} entries to process.")

        if total_entries == 0:
            logger.info("No entries found. Exiting.")
            return

        # 4. Process entries
        logger.info(f"Starting vectorization (force={force})...")
        success_count = 0
        skip_count = 0
        fail_count = 0
        
        # Limit concurrency to avoid hitting rate limits or overwhelming services
        semaphore = asyncio.Semaphore(5) 

        async def process_entry(entry):
            nonlocal success_count, fail_count, skip_count
            
            try:
                entry_id = str(entry.id)
                
                # Check if exists in Milvus (unless force is True)
                if not force:
                    existing = await vector_store.query_vectors(
                        f'entry_id == "{entry_id}"', 
                        ["entry_id"]
                    )
                    if existing:
                        skip_count += 1
                        if skip_count % 50 == 0:
                            logger.info(f"Skipped {skip_count} existing entries...")
                        return

                # Check content availability
                text_content = entry.content or entry.summary or entry.title
                if not text_content:
                    logger.warning(f"Entry {entry_id} has no content/summary/title. Skipping.")
                    fail_count += 1
                    return

                # Basic cleaning
                import re
                clean_text = re.sub(r'<[^>]+>', '', text_content)
                clean_text = clean_text.strip()
                
                if not clean_text:
                    fail_count += 1
                    return

                async with semaphore:
                    success = await vector_store.add_entry(
                        entry_id=entry_id,
                        text=clean_text,
                        feed_id=str(entry.feed_id) if entry.feed_id else "",
                        published_at=int(entry.published_at.timestamp()) if entry.published_at else 0,
                        title=entry.title or ""
                    )
                
                if success:
                    success_count += 1
                    if success_count % 10 == 0:
                        logger.info(f"Progress: {success_count} vectorized, {skip_count} skipped, {fail_count} failed.")
                else:
                    fail_count += 1
                    logger.warning(f"Failed to vectorize entry {entry_id}")
            except Exception as e:
                logger.error(f"Error processing entry {entry.id}: {e}")
                fail_count += 1

        # Process in chunks to manage memory better if list is huge
        # But for async tasks creation, we can just create them all and gather
        # Semaphore limits execution concurrency
        tasks = [process_entry(e) for e in entries]
        await asyncio.gather(*tasks)

        logger.info("Vectorization completed.")
        logger.info(f"Total Entries: {total_entries}")
        logger.info(f"Successfully Vectorized: {success_count}")
        logger.info(f"Skipped (Existing): {skip_count}")
        logger.info(f"Failed: {fail_count}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Vectorize existing RSS entries.")
    parser.add_argument("--force", action="store_true", help="Force re-vectorization even if exists in Milvus")
    parser.add_argument("--limit", type=int, default=0, help="Limit number of entries to process (0 for all)")
    args = parser.parse_args()

    asyncio.run(vectorize_entries(force=args.force, limit=args.limit))
