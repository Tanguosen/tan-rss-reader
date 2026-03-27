#!/usr/bin/env python3
"""
Script to update channels table: remove unique constraint from name column
SQLite doesn't support ALTER TABLE DROP CONSTRAINT, so we need to recreate the table
"""

import asyncio
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import text
from app.db import SessionLocal


async def update_channel_table():
    """Remove unique constraint from channels.name"""
    print("Updating channels table to remove unique constraint from name column...")
    
    async with SessionLocal() as session:
        # SQLite approach: check if we need to migrate
        # First, check current table structure
        result = await session.execute(
            text("SELECT sql FROM sqlite_master WHERE type='table' AND name='channels'")
        )
        table_sql = result.scalar()
        
        if table_sql and 'UNIQUE' in table_sql.upper():
            print("Found unique constraint in channels table, migrating...")
            
            # SQLite migration: rename old table, create new one, copy data
            await session.execute(text("BEGIN TRANSACTION"))
            
            try:
                # 1. Rename old table
                await session.execute(text("ALTER TABLE channels RENAME TO channels_old"))
                
                # 2. Create new table without unique constraint
                await session.execute(text("""
                    CREATE TABLE channels (
                        id TEXT PRIMARY KEY,
                        name TEXT NOT NULL,
                        description TEXT,
                        icon_url TEXT,
                        cover_url TEXT,
                        is_public BOOLEAN DEFAULT 1,
                        owner_id TEXT,
                        kind TEXT DEFAULT 'topic',
                        category_id TEXT,
                        created_at DATETIME,
                        updated_at DATETIME,
                        FOREIGN KEY (category_id) REFERENCES categories (id)
                    )
                """))
                
                # 3. Copy data from old table
                await session.execute(text("""
                    INSERT INTO channels 
                    SELECT * FROM channels_old
                """))
                
                # 4. Drop old table
                await session.execute(text("DROP TABLE channels_old"))
                
                # 5. Recreate indexes
                await session.execute(text("""
                    CREATE INDEX IF NOT EXISTS idx_channels_owner 
                    ON channels (owner_id)
                """))
                await session.execute(text("""
                    CREATE INDEX IF NOT EXISTS idx_channels_public 
                    ON channels (is_public)
                """))
                
                await session.commit()
                print("Migration completed successfully!")
                
            except Exception as e:
                await session.rollback()
                print(f"Migration failed: {e}")
                raise
        else:
            print("No unique constraint found on channels.name, skipping migration")
        
        # Verify the change
        result = await session.execute(
            text("SELECT sql FROM sqlite_master WHERE type='table' AND name='channels'")
        )
        new_table_sql = result.scalar()
        print(f"\nNew table schema:\n{new_table_sql}")


if __name__ == "__main__":
    try:
        asyncio.run(update_channel_table())
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
