import asyncio
import os
import sqlite3
from sqlalchemy.ext.asyncio import create_async_engine
from app.models import Base
from app.db import database_url
from pathlib import Path

# Fix for import path if run directly
import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

async def create_tables():
    url = database_url()
    print(f"Database URL: {url}")
    engine = create_async_engine(url, echo=True)
    
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    await engine.dispose()
    print("Created new tables (if not exist).")

def add_columns():
    # Parse DB path from URL (assuming sqlite+aiosqlite:////path/to/db)
    url = database_url()
    if "sqlite+aiosqlite:///" in url:
        db_path = url.replace("sqlite+aiosqlite:///", "")
    else:
        print("Skipping column addition: Not SQLite or unknown format")
        return

    print(f"Connecting to SQLite DB at: {db_path}")
    if not os.path.exists(db_path):
        print("DB file does not exist yet.")
        return

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Check if category_id exists in channels
    cursor.execute("PRAGMA table_info(channels)")
    columns = [info[1] for info in cursor.fetchall()]
    
    if "category_id" not in columns:
        print("Adding category_id column to channels table...")
        try:
            cursor.execute("ALTER TABLE channels ADD COLUMN category_id VARCHAR")
            conn.commit()
            print("Column added.")
        except Exception as e:
            print(f"Error adding column: {e}")
    else:
        print("Column category_id already exists in channels.")

    if "icon_url" not in columns:
        print("Adding icon_url column to channels table...")
        try:
            cursor.execute("ALTER TABLE channels ADD COLUMN icon_url VARCHAR")
            conn.commit()
            print("Column icon_url added.")
        except Exception as e:
            print(f"Error adding column icon_url: {e}")
    else:
        print("Column icon_url already exists in channels.")

    # Check ai_configs columns
    cursor.execute("PRAGMA table_info(ai_configs)")
    ai_columns = [info[1] for info in cursor.fetchall()]
    
    new_ai_cols = {
        "embedding_api_key": "VARCHAR",
        "embedding_base_url": "VARCHAR",
        "embedding_model_name": "VARCHAR",
        "embedding_has_api_key": "BOOLEAN DEFAULT 0",
        "milvus_host": "VARCHAR",
        "milvus_port": "VARCHAR",
        "milvus_collection_name": "VARCHAR"
    }
    
    for col, dtype in new_ai_cols.items():
        if col not in ai_columns:
            print(f"Adding {col} to ai_configs...")
            try:
                cursor.execute(f"ALTER TABLE ai_configs ADD COLUMN {col} {dtype}")
                conn.commit()
                print(f"Column {col} added.")
            except Exception as e:
                print(f"Error adding {col}: {e}")

    # Check entries columns
    cursor.execute("PRAGMA table_info(entries)")
    entries_columns = [info[1] for info in cursor.fetchall()]
    
    if "dedup_key" not in entries_columns:
        print("Adding dedup_key column to entries table...")
        try:
            cursor.execute("ALTER TABLE entries ADD COLUMN dedup_key VARCHAR")
            conn.commit()
            print("Column dedup_key added to entries.")
        except Exception as e:
            print(f"Error adding dedup_key: {e}")
            
    # Check ai_daily_digests
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='ai_daily_digests'")
    if not cursor.fetchone():
        print("Creating ai_daily_digests table...")
        try:
            cursor.execute("""
            CREATE TABLE ai_daily_digests (
                id VARCHAR NOT NULL, 
                user_id VARCHAR NOT NULL, 
                date_str VARCHAR NOT NULL, 
                content TEXT NOT NULL, 
                references TEXT NOT NULL, 
                created_at DATETIME NOT NULL, 
                updated_at DATETIME NOT NULL, 
                PRIMARY KEY (id), 
                FOREIGN KEY(user_id) REFERENCES users (id)
            )
            """)
            cursor.execute("CREATE INDEX ix_ai_daily_digests_user_id ON ai_daily_digests (user_id)")
            cursor.execute("CREATE INDEX ix_ai_daily_digests_date_str ON ai_daily_digests (date_str)")
            conn.commit()
            print("Table ai_daily_digests created.")
        except Exception as e:
            print(f"Error creating ai_daily_digests: {e}")

    conn.close()

if __name__ == "__main__":
    # Add columns first (synchronous)
    add_columns()
    # Create tables (async)
    asyncio.run(create_tables())
