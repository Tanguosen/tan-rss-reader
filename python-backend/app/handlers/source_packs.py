import re
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from typing import Optional, List
from uuid import uuid4
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc
from ..db import SessionLocal
from ..models import SourcePack as SASourcePack, Channel as SAChannel, ChannelSource as SAChannelSource, Subscription as SASubscription, Feed as SAFeed
from .auth import get_current_user, get_current_admin
import json

router = APIRouter()

async def get_session() -> AsyncSession:
    async with SessionLocal() as session:
        yield session

class SourceInfo(BaseModel):
    name: str
    type: str = "channel"
    config: dict = {}

class SourcePackResponse(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    slug: Optional[str] = None
    sources: List[SourceInfo] = []
    is_public: bool
    install_count: int = 0
    created_at: Optional[str] = None
    updated_at: Optional[str] = None

class CreatePackRequest(BaseModel):
    name: str
    description: Optional[str] = None
    sources_json: str = "[]"

@router.get("/packs", response_model=List[SourcePackResponse])
async def list_packs(
    limit: Optional[int] = Query(default=50),
    offset: Optional[int] = Query(default=0),
    session: AsyncSession = Depends(get_session),
) -> List[SourcePackResponse]:
    query = select(SASourcePack).where(SASourcePack.is_public == True).order_by(desc(SASourcePack.install_count), desc(SASourcePack.created_at)).offset(offset).limit(min(limit, 100))
    rows = (await session.execute(query)).scalars().all()
    
    items: List[SourcePackResponse] = []
    for p in rows:
        sources = []
        try:
            sources_data = json.loads(p.sources_json) if p.sources_json else []
            for s in sources_data:
                sources.append(SourceInfo(
                    name=s.get("name", ""),
                    type=s.get("type", "channel"),
                    config=s.get("config", {})
                ))
        except:
            sources = []
        
        items.append(SourcePackResponse(
            id=p.id,
            name=p.name,
            description=p.description,
            slug=p.slug,
            sources=sources,
            is_public=bool(p.is_public),
            install_count=p.install_count or 0,
            created_at=p.created_at.isoformat() + "Z" if p.created_at else None,
            updated_at=p.updated_at.isoformat() + "Z" if p.updated_at else None,
        ))
    return items

@router.get("/packs/{slug}", response_model=SourcePackResponse)
async def get_pack(slug: str, session: AsyncSession = Depends(get_session)) -> SourcePackResponse:
    query = select(SASourcePack).where(SASourcePack.slug == slug)
    p = (await session.execute(query)).scalar_one_or_none()
    if not p:
        raise HTTPException(status_code=404, detail="Pack not found")
    
    sources = []
    try:
        sources_data = json.loads(p.sources_json) if p.sources_json else []
        for s in sources_data:
            sources.append(SourceInfo(
                name=s.get("name", ""),
                type=s.get("type", "channel"),
                config=s.get("config", {})
            ))
    except:
        sources = []
    
    return SourcePackResponse(
        id=p.id,
        name=p.name,
        description=p.description,
        slug=p.slug,
        sources=sources,
        is_public=bool(p.is_public),
        install_count=p.install_count or 0,
        created_at=p.created_at.isoformat() + "Z" if p.created_at else None,
        updated_at=p.updated_at.isoformat() + "Z" if p.updated_at else None,
    )

@router.post("/packs", response_model=SourcePackResponse)
async def create_pack(
    req: CreatePackRequest,
    current=Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> SourcePackResponse:
    slug = re.sub(r'[^a-z0-9]+', '-', req.name.lower()).strip('-')[:50]
    base_slug = slug
    counter = 1
    while True:
        existing = (await session.execute(select(SASourcePack).where(SASourcePack.slug == slug))).scalar_one_or_none()
        if not existing:
            break
        slug = f"{base_slug}-{counter}"
        counter += 1
    
    pack_id = str(uuid4())
    now = datetime.utcnow()
    row = SASourcePack(
        id=pack_id,
        name=req.name,
        description=req.description,
        slug=slug,
        sources_json=req.sources_json,
        created_by=current.id,
        is_public=True,
        install_count=0,
        created_at=now,
        updated_at=now,
    )
    session.add(row)
    await session.commit()
    
    sources = []
    try:
        sources_data = json.loads(req.sources_json) if req.sources_json else []
        for s in sources_data:
            sources.append(SourceInfo(
                name=s.get("name", ""),
                type=s.get("type", "channel"),
                config=s.get("config", {})
            ))
    except:
        sources = []
    
    return SourcePackResponse(
        id=row.id,
        name=row.name,
        description=row.description,
        slug=row.slug,
        sources=sources,
        is_public=bool(row.is_public),
        install_count=row.install_count,
        created_at=row.created_at.isoformat() + "Z" if row.created_at else None,
        updated_at=row.updated_at.isoformat() + "Z" if row.updated_at else None,
    )

@router.post("/packs/{slug}/install")
async def install_pack(
    slug: str,
    current=Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    query = select(SASourcePack).where(SASourcePack.slug == slug)
    pack = (await session.execute(query)).scalar_one_or_none()
    if not pack:
        raise HTTPException(status_code=404, detail="Pack not found")
    
    sources_data = []
    try:
        sources_data = json.loads(pack.sources_json) if pack.sources_json else []
    except:
        raise HTTPException(status_code=400, detail="Invalid sources data")
    
    added = 0
    skipped = 0
    
    for s in sources_data:
        channel_name = s.get("name", "")
        if not channel_name:
            skipped += 1
            continue
        
        channel_q = await session.execute(select(SAChannel).where(SAChannel.name == channel_name))
        channel = channel_q.scalar_one_or_none()
        if not channel:
            skipped += 1
            continue
        
        existing_sub = (await session.execute(select(SASubscription).where(
            SASubscription.user_id == current.id,
            SASubscription.channel_id == channel.id
        ))).scalar_one_or_none()
        
        if existing_sub:
            skipped += 1
            continue
        
        sub_id = str(uuid4())
        now = datetime.utcnow()
        new_sub = SASubscription(
            id=sub_id,
            user_id=current.id,
            channel_id=channel.id,
            notify=False,
            created_at=now,
            updated_at=now,
        )
        session.add(new_sub)
        added += 1
    
    pack.install_count = (pack.install_count or 0) + 1
    pack.updated_at = datetime.utcnow()
    await session.commit()
    
    return {"ok": True, "added": added, "skipped": skipped}

@router.get("/my/packs", response_model=List[SourcePackResponse])
async def list_my_packs(
    limit: Optional[int] = Query(default=50),
    offset: Optional[int] = Query(default=0),
    current=Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> List[SourcePackResponse]:
    query = select(SASourcePack).where(SASourcePack.created_by == current.id).order_by(desc(SASourcePack.created_at)).offset(offset).limit(min(limit, 100))
    rows = (await session.execute(query)).scalars().all()
    
    items: List[SourcePackResponse] = []
    for p in rows:
        sources = []
        try:
            sources_data = json.loads(p.sources_json) if p.sources_json else []
            for s in sources_data:
                sources.append(SourceInfo(
                    name=s.get("name", ""),
                    type=s.get("type", "channel"),
                    config=s.get("config", {})
                ))
        except:
            sources = []
        
        items.append(SourcePackResponse(
            id=p.id,
            name=p.name,
            description=p.description,
            slug=p.slug,
            sources=sources,
            is_public=bool(p.is_public),
            install_count=p.install_count or 0,
            created_at=p.created_at.isoformat() + "Z" if p.created_at else None,
            updated_at=p.updated_at.isoformat() + "Z" if p.updated_at else None,
        ))
    return items

@router.delete("/packs/{pack_id}")
async def delete_pack(
    pack_id: str,
    current=Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> dict:
    query = select(SASourcePack).where(SASourcePack.id == pack_id)
    pack = (await session.execute(query)).scalar_one_or_none()
    if not pack:
        raise HTTPException(status_code=404, detail="Pack not found")
    if current.role != "admin" and pack.created_by != current.id:
        raise HTTPException(status_code=403, detail="Not authorized to delete this pack")
    
    await session.delete(pack)
    await session.commit()
    return {"ok": True}