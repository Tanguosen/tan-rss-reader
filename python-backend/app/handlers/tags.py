from fastapi import APIRouter, Query, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional, List
from uuid import uuid4
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc, asc, delete
from ..db import SessionLocal
from ..models import Tag as SATag
from .auth import get_current_admin

router = APIRouter()

async def get_session() -> AsyncSession:
    async with SessionLocal() as session:
        yield session

class Tag(BaseModel):
    id: str
    name: str
    created_at: Optional[str] = None
    updated_at: Optional[str] = None

class CreateTagRequest(BaseModel):
    name: str

@router.get("/admin/tags", response_model=List[Tag])
async def list_tags(session: AsyncSession = Depends(get_session), admin=Depends(get_current_admin)) -> List[Tag]:
    q = select(SATag).order_by(desc(SATag.created_at))
    rows = (await session.execute(q)).scalars().all()
    return [
        Tag(
            id=r.id,
            name=r.name,
            created_at=r.created_at.isoformat() + "Z" if r.created_at else None,
            updated_at=r.updated_at.isoformat() + "Z" if r.updated_at else None,
        ) for r in rows
    ]

@router.post("/admin/tags", response_model=Tag)
async def create_tag(payload: CreateTagRequest, session: AsyncSession = Depends(get_session), admin=Depends(get_current_admin)) -> Tag:
    cid = str(uuid4())
    now = datetime.utcnow()
    row = SATag(
        id=cid,
        name=payload.name,
        created_at=now,
        updated_at=now
    )
    session.add(row)
    try:
        await session.commit()
    except Exception as e:
        await session.rollback()
        raise HTTPException(status_code=400, detail="Tag name likely already exists")
    
    return Tag(
        id=row.id,
        name=row.name,
        created_at=row.created_at.isoformat() + "Z" if row.created_at else None,
        updated_at=row.updated_at.isoformat() + "Z" if row.updated_at else None,
    )

@router.delete("/admin/tags/{id}")
async def delete_tag(id: str, session: AsyncSession = Depends(get_session), admin=Depends(get_current_admin)):
    q = await session.execute(select(SATag).where(SATag.id == id))
    c = q.scalar_one_or_none()
    if not c:
        raise HTTPException(status_code=404)
    await session.delete(c)
    await session.commit()
    return {"message": "Deleted"}
