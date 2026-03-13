import os
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import DeclarativeBase

class Base(DeclarativeBase):
    pass

from pathlib import Path

def database_url() -> str:
    url = os.getenv("PY_BACKEND_DB_URL")
    if url:
        return url
    # Use path relative to this file to ensure consistency regardless of CWD
    # app/db.py -> app -> python-backend
    base_dir = Path(__file__).resolve().parent.parent
    data_dir = base_dir / "data"
    path = data_dir / "rss.db"
    
    os.makedirs(data_dir, exist_ok=True)
    return f"sqlite+aiosqlite:///{path}"

engine = create_async_engine(database_url(), future=True)
SessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

