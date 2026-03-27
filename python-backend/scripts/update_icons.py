import asyncio
import os
import sys
from urllib.parse import urlparse
import httpx

# Fix for import path if run directly
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import select
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.orm import sessionmaker
from app.db import database_url
from app.models import Feed, Channel, ChannelSource
from sqlalchemy.ext.asyncio import AsyncSession

async def update_icons():
    url = database_url()
    print(f"Connecting to database: {url}")
    engine = create_async_engine(url, echo=False)
    SessionLocal = sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False)

    async with SessionLocal() as session:
        # 1. Update Feeds
        print("--- Updating Feeds ---")
        q = await session.execute(select(Feed))
        feeds = q.scalars().all()
        
        updated_feeds = 0
        
        for feed in feeds:
            parsed = urlparse(feed.url)
            if parsed.netloc:
                # Use Google's favicon service as a much more reliable fallback
                # It handles missing icons, redirects, and provides a default icon if not found
                new_favicon = f"https://www.google.com/s2/favicons?domain={parsed.netloc}&sz=128"
                
                if feed.favicon != new_favicon:
                    feed.favicon = new_favicon
                    updated_feeds += 1
                    print(f"Updated Feed [{feed.title or feed.url}] favicon to: {new_favicon}")
        
        # 2. Update Channels based on their sources
        print("\n--- Updating Channels ---")
        q = await session.execute(select(Channel))
        channels = q.scalars().all()
        
        updated_channels = 0
        for channel in channels:
            # Find the first source's feed favicon unconditionally
            sq = await session.execute(
                select(Feed.favicon)
                .join(ChannelSource, ChannelSource.feed_id == Feed.id)
                .where(ChannelSource.channel_id == channel.id)
                .where(Feed.favicon != None)
                .limit(1)
            )
            first_favicon = sq.scalar_one_or_none()
            if first_favicon and channel.icon_url != first_favicon:
                channel.icon_url = first_favicon
                updated_channels += 1
                print(f"Updated Channel [{channel.name}] icon to: {first_favicon}")
        
        if updated_feeds > 0 or updated_channels > 0:
            await session.commit()
            print(f"\nSuccessfully committed changes. Updated {updated_feeds} feeds and {updated_channels} channels.")
        else:
            print("\nNo updates needed. All feeds and channels have icons.")

    await engine.dispose()

if __name__ == "__main__":
    asyncio.run(update_icons())