from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import List, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime
import logging

from ..db import SessionLocal
from ..models import Entry
from .vector_store import vector_store
from .clustering import clustering_service
from .ai import AI_CFG, generate_trend_analysis

router = APIRouter()
logger = logging.getLogger(__name__)

async def get_session() -> AsyncSession:
    async with SessionLocal() as session:
        yield session

class SearchRequest(BaseModel):
    query: str
    limit: int = 10
    feed_id: Optional[str] = None

class IndexRequest(BaseModel):
    force: bool = False

class ClusterRequest(BaseModel):
    days: int = 1
    min_samples: int = 2
    eps: float = 0.3

class ClusterAnalysisRequest(BaseModel):
    entry_ids: List[str]

@router.post("/vector/connect")
async def connect_milvus():
    await vector_store.connect()
    return {"connected": vector_store.connected}

@router.post("/vector/cluster")
async def cluster_vectors(req: ClusterRequest):
    results = await clustering_service.cluster_entries(
        days=req.days,
        min_samples=req.min_samples,
        eps=req.eps
    )
    return {"clusters": results}

@router.post("/vector/cluster/analyze")
async def analyze_cluster(req: ClusterAnalysisRequest, session: AsyncSession = Depends(get_session)):
    if not req.entry_ids:
         return {"timeline": [], "analysis": {}, "stats": {}}
         
    # Fetch entries
    stmt = select(Entry).where(Entry.id.in_(req.entry_ids)).order_by(Entry.published_at.asc())
    result = await session.execute(stmt)
    entries = result.scalars().all()
    
    if not entries:
        raise HTTPException(status_code=404, detail="No entries found")
        
    # Prepare timeline
    timeline = []
    text_content = ""
    
    for e in entries:
        timeline.append({
            "id": str(e.id),
            "title": e.title,
            "published_at": int(e.published_at.timestamp()) if e.published_at else 0,
            "source": "RSS Feed", # Ideally fetch feed title but avoiding N+1 lazy load if not eager loaded
            "summary": e.summary[:200] if e.summary else (e.content[:200] if e.content else "")
        })
        # Add to text content for AI (limit per entry to avoid huge context)
        text_content += f"标题: {e.title}\n时间: {e.published_at}\n内容: {(e.summary or e.content or '')[:500]}\n\n"
        
    # Limit total text content
    text_content = text_content[:12000]
    
    # AI Analysis
    analysis = await generate_trend_analysis(text_content)
    
    # Stats (simple time distribution)
    # Group by date
    from collections import defaultdict
    date_counts = defaultdict(int)
    for e in entries:
        if e.published_at:
            date_str = e.published_at.strftime("%Y-%m-%d")
            date_counts[date_str] += 1
            
    stats = {
        "time_distribution": [{"date": k, "count": v} for k, v in sorted(date_counts.items())]
    }
    
    return {
        "timeline": timeline,
        "analysis": analysis,
        "stats": stats
    }

@router.post("/vector/search")
async def search_vectors(req: SearchRequest):
    results = await vector_store.search(req.query, req.limit, req.feed_id)
    return {"results": results}

async def background_index_entries(session: AsyncSession, force: bool = False):
    # Fetch entries. For simplicity, fetch recent 100 or all.
    # In production, this should be paginated and tracked.
    
    # We need to know which entries are already indexed?
    # Milvus doesn't easily tell us "what's missing" efficiently without tracking.
    # We can add a column `vectorized` to `EntryAI` or `Entry` table.
    # Or just query all entries and upsert (Milvus upsert handles duplicates if PK matches, but we use auto-id).
    # Our `add_entry` handles deletion of old entry_id.
    
    # Let's fetch last 100 entries for now.
    q = select(Entry).order_by(Entry.published_at.desc()).limit(100)
    result = await session.execute(q)
    entries = result.scalars().all()
    
    count = 0
    for entry in entries:
        text = f"{entry.title}\n\n{entry.content or entry.summary or ''}"
        # Truncate text to avoid token limits? _call_embedding usually handles it or model truncates.
        text = text[:8000] 
        
        success = await vector_store.add_entry(
            entry_id=entry.id,
            text=text,
            feed_id=entry.feed_id,
            published_at=int(entry.published_at.timestamp()) if entry.published_at else 0,
            title=entry.title or ""
        )
        if success:
            count += 1
            
    logger.info(f"Indexed {count} entries.")

@router.post("/vector/index")
async def trigger_indexing(req: IndexRequest, background_tasks: BackgroundTasks):
    # Create a new session for background task
    session = SessionLocal()
    background_tasks.add_task(run_indexing_task, session, req.force)
    return {"message": "Indexing started in background"}

async def run_indexing_task(session: AsyncSession, force: bool):
    try:
        await background_index_entries(session, force)
    finally:
        await session.close()
