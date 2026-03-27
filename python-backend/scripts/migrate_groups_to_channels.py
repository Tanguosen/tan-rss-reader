#!/usr/bin/env python3
"""
Migration script: Convert Feed categories to personal Channels

This script migrates existing Feed.category data to personal Channels:
1. Scans feeds table for all non-null categories
2. Creates personal channels (is_public=False) for each unique user+category combination
3. Links feeds to channels via ChannelSource
4. Creates subscriptions for users to their personal channels
"""

import asyncio
import sys
import os
from uuid import uuid4
from datetime import datetime

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession
from app.db import SessionLocal
from app.models import Feed, Channel, ChannelSource, Subscription, User


async def migrate_groups_to_channels():
    """Main migration function"""
    print("=" * 60)
    print("Starting migration: Feed categories -> Personal Channels")
    print("=" * 60)
    
    async with SessionLocal() as session:
        # Step 1: Get all feeds with categories using raw SQL (category column may be removed from model)
        print("\n[Step 1] Scanning feeds with categories...")
        result = await session.execute(
            text("SELECT id, category, title FROM feeds WHERE category IS NOT NULL AND category != ''")
        )
        feeds_with_category = result.all()
        print(f"Found {len(feeds_with_category)} feeds with categories")
        
        if not feeds_with_category:
            print("No feeds with categories found. Migration complete.")
            return
        
        # Step 2: Get all users
        print("\n[Step 2] Fetching all users...")
        result = await session.execute(select(User.id, User.username))
        users = result.all()
        print(f"Found {len(users)} users")
        
        if not users:
            print("No users found. Skipping migration.")
            return
        
        # Step 3: For each user, create personal channels from categories
        print("\n[Step 3] Creating personal channels...")
        channels_created = 0
        sources_linked = 0
        subscriptions_created = 0
        
        for user in users:
            user_id = user.id
            username = user.username
            
            # Get unique categories from feeds
            categories = set()
            for feed_id, category, title in feeds_with_category:
                if category and category.strip():
                    categories.add(category.strip())
            
            if not categories:
                continue
            
            print(f"\n  Processing user: {username} ({user_id})")
            print(f"  Categories found: {', '.join(categories)}")
            
            # Create or get personal channel for each category
            for category_name in categories:
                # Check if user already has a channel with this name (use raw SQL to avoid autoflush issues)
                result = await session.execute(
                    text("SELECT id FROM channels WHERE name = :name AND owner_id = :owner_id AND is_public = 0"),
                    {"name": category_name, "owner_id": user_id}
                )
                existing_row = result.fetchone()
                
                if existing_row:
                    channel_id = existing_row[0]
                    print(f"    - Reusing existing channel: {category_name}")
                else:
                    # Create new personal channel with unique name for this user
                    channel_id = str(uuid4())
                    now = datetime.utcnow()
                    # Make channel name unique by appending user_id suffix for personal channels
                    unique_name = f"{category_name}"
                    new_channel = Channel(
                        id=channel_id,
                        name=unique_name,
                        description=f"Personal channel for {category_name}",
                        is_public=False,
                        owner_id=user_id,
                        kind="personal",
                        created_at=now,
                        updated_at=now
                    )
                    session.add(new_channel)
                    await session.flush()  # Flush immediately to catch any constraint errors
                    channels_created += 1
                    print(f"    - Created new channel: {category_name}")
                
                # Link feeds in this category to the channel
                for feed_id, feed_category, feed_title in feeds_with_category:
                    if feed_category and feed_category.strip() == category_name:
                        # Check if already linked
                        existing_link = await session.execute(
                            select(ChannelSource).where(
                                ChannelSource.channel_id == channel_id,
                                ChannelSource.feed_id == feed_id
                            )
                        )
                        if not existing_link.scalar_one_or_none():
                            now = datetime.utcnow()
                            link = ChannelSource(
                                channel_id=channel_id,
                                feed_id=feed_id,
                                order_index=0,
                                weight=100,
                                created_at=now
                            )
                            session.add(link)
                            sources_linked += 1
                
                # Create subscription for user to this channel
                existing_sub = await session.execute(
                    select(Subscription).where(
                        Subscription.user_id == user_id,
                        Subscription.channel_id == channel_id
                    )
                )
                if not existing_sub.scalar_one_or_none():
                    now = datetime.utcnow()
                    sub = Subscription(
                        id=str(uuid4()),
                        user_id=user_id,
                        channel_id=channel_id,
                        notify=False,
                        created_at=now,
                        updated_at=now
                    )
                    session.add(sub)
                    subscriptions_created += 1
        
        # Commit all changes
        print("\n[Step 4] Committing changes...")
        await session.commit()
        
        # Print summary
        print("\n" + "=" * 60)
        print("Migration Summary:")
        print("=" * 60)
        print(f"  Personal channels created: {channels_created}")
        print(f"  Feed-channel links created: {sources_linked}")
        print(f"  User subscriptions created: {subscriptions_created}")
        print("\nMigration completed successfully!")
        print("\nNote: The 'category' column in feeds table should be")
        print("      removed in a future schema migration after verifying")
        print("      the data migration was successful.")


async def verify_migration():
    """Verify the migration results"""
    print("\n" + "=" * 60)
    print("Verifying migration...")
    print("=" * 60)
    
    async with SessionLocal() as session:
        # Count personal channels
        result = await session.execute(
            select(Channel).where(Channel.is_public == False)
        )
        personal_channels = result.scalars().all()
        print(f"\nPersonal channels (is_public=False): {len(personal_channels)}")
        
        # Count channel sources
        result = await session.execute(select(ChannelSource))
        sources = result.scalars().all()
        print(f"Total channel-feed links: {len(sources)}")
        
        # Count subscriptions
        result = await session.execute(select(Subscription))
        subscriptions = result.scalars().all()
        print(f"Total subscriptions: {len(subscriptions)}")
        
        # Show sample data
        if personal_channels:
            print("\nSample personal channels:")
            for ch in personal_channels[:5]:
                print(f"  - {ch.name} (owner: {ch.owner_id})")


if __name__ == "__main__":
    try:
        asyncio.run(migrate_groups_to_channels())
        asyncio.run(verify_migration())
    except Exception as e:
        print(f"\nMigration failed with error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
