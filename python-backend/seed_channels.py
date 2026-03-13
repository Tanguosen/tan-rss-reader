import asyncio
import sys
import os

# Add the current directory to sys.path to make imports work
sys.path.append(os.getcwd())

from app.db import SessionLocal, engine, Base
from app.models import Channel, Feed, ChannelSource
from datetime import datetime
from uuid import uuid4

async def seed():
    # Ensure tables exist
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with SessionLocal() as session:
        print("Seeding data...")
        
        # 1. Create Feeds if not exist
        feeds_data = [
            {"title": "TechCrunch", "url": "https://techcrunch.com/feed/", "category": "Tech"},
            {"title": "The Verge", "url": "https://www.theverge.com/rss/index.xml", "category": "Tech"},
            {"title": "Hacker News", "url": "https://news.ycombinator.com/rss", "category": "Tech"},
            {"title": "BBC News", "url": "http://feeds.bbci.co.uk/news/world/rss.xml", "category": "News"},
        ]
        
        created_feeds = []
        for fd in feeds_data:
            from sqlalchemy import select
            res = await session.execute(select(Feed).where(Feed.url == fd["url"]))
            existing = res.scalar_one_or_none()
            if existing:
                print(f"Feed exists: {fd['title']}")
                created_feeds.append(existing)
            else:
                new_feed = Feed(
                    id=str(uuid4()),
                    title=fd["title"],
                    url=fd["url"],
                    category=fd["category"],
                    created_at=datetime.utcnow(),
                    updated_at=datetime.utcnow()
                )
                session.add(new_feed)
                created_feeds.append(new_feed)
                print(f"Created feed: {fd['title']}")
        
        await session.commit()
        
        # 2. Create Channels
        channels_data = [
            {"name": "Tech News", "desc": "Latest technology news and updates.", "is_public": True, "feeds": ["TechCrunch", "The Verge", "Hacker News"]},
            {"name": "World News", "desc": "Global news coverage.", "is_public": True, "feeds": ["BBC News"]},
            {"name": "Private Reading", "desc": "My private collection.", "is_public": False, "feeds": []}
        ]
        
        for cd in channels_data:
            from sqlalchemy import select
            res = await session.execute(select(Channel).where(Channel.name == cd["name"]))
            existing = res.scalar_one_or_none()
            
            channel_id = None
            if existing:
                print(f"Channel exists: {cd['name']}")
                channel_id = existing.id
            else:
                new_channel = Channel(
                    id=str(uuid4()),
                    name=cd["name"],
                    description=cd["desc"],
                    is_public=cd["is_public"],
                    created_at=datetime.utcnow(),
                    updated_at=datetime.utcnow()
                )
                session.add(new_channel)
                await session.commit() # Commit to get ID if needed, or just commit later
                channel_id = new_channel.id
                print(f"Created channel: {cd['name']}")
            
            # Link Feeds
            if channel_id:
                # Get current sources
                res_sources = await session.execute(select(ChannelSource).where(ChannelSource.channel_id == channel_id))
                current_source_feed_ids = [row.feed_id for row in res_sources.scalars().all()]
                
                target_feeds = [f for f in created_feeds if f.title in cd["feeds"]]
                for tf in target_feeds:
                    if tf.id not in current_source_feed_ids:
                        new_source = ChannelSource(
                            channel_id=channel_id,
                            feed_id=tf.id,
                            created_at=datetime.utcnow()
                        )
                        session.add(new_source)
                        print(f"  Added source {tf.title} to {cd['name']}")
        
        await session.commit()
        print("Seeding complete.")

if __name__ == "__main__":
    asyncio.run(seed())
