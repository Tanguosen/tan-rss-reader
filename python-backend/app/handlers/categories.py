from fastapi import APIRouter, Query, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional, List
from uuid import uuid4
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc, asc, delete
from ..db import SessionLocal
from ..models import Category as SACategory
from .auth import get_current_admin

router = APIRouter()

async def get_session() -> AsyncSession:
    async with SessionLocal() as session:
        yield session

class Category(BaseModel):
    id: str
    name: str
    sort_order: int
    created_at: Optional[str] = None
    updated_at: Optional[str] = None

class CreateCategoryRequest(BaseModel):
    name: str
    sort_order: Optional[int] = 0

class UpdateCategoryRequest(BaseModel):
    name: Optional[str] = None
    sort_order: Optional[int] = None

@router.get("/categories", response_model=List[Category])
async def list_public_categories(session: AsyncSession = Depends(get_session)) -> List[Category]:
    q = select(SACategory).order_by(asc(SACategory.sort_order), desc(SACategory.created_at))
    rows = (await session.execute(q)).scalars().all()
    return [
        Category(
            id=r.id,
            name=r.name,
            sort_order=r.sort_order,
            created_at=r.created_at.isoformat() + "Z" if r.created_at else None,
            updated_at=r.updated_at.isoformat() + "Z" if r.updated_at else None,
        ) for r in rows
    ]

@router.get("/admin/categories", response_model=List[Category])
async def list_categories(session: AsyncSession = Depends(get_session), admin=Depends(get_current_admin)) -> List[Category]:
    q = select(SACategory).order_by(asc(SACategory.sort_order), desc(SACategory.created_at))
    rows = (await session.execute(q)).scalars().all()
    return [
        Category(
            id=r.id,
            name=r.name,
            sort_order=r.sort_order,
            created_at=r.created_at.isoformat() + "Z" if r.created_at else None,
            updated_at=r.updated_at.isoformat() + "Z" if r.updated_at else None,
        ) for r in rows
    ]

@router.post("/admin/categories", response_model=Category)
async def create_category(payload: CreateCategoryRequest, session: AsyncSession = Depends(get_session), admin=Depends(get_current_admin)) -> Category:
    cid = str(uuid4())
    now = datetime.utcnow()
    row = SACategory(
        id=cid,
        name=payload.name,
        sort_order=payload.sort_order if payload.sort_order is not None else 0,
        created_at=now,
        updated_at=now
    )
    session.add(row)
    try:
        await session.commit()
    except Exception as e:
        await session.rollback()
        raise HTTPException(status_code=400, detail="Category name likely already exists")
    
    return Category(
        id=row.id,
        name=row.name,
        sort_order=row.sort_order,
        created_at=row.created_at.isoformat() + "Z" if row.created_at else None,
        updated_at=row.updated_at.isoformat() + "Z" if row.updated_at else None,
    )

@router.patch("/admin/categories/{id}", response_model=Category)
async def update_category(id: str, payload: UpdateCategoryRequest, session: AsyncSession = Depends(get_session), admin=Depends(get_current_admin)) -> Category:
    q = await session.execute(select(SACategory).where(SACategory.id == id))
    c = q.scalar_one_or_none()
    if not c:
        raise HTTPException(status_code=404)
    
    if payload.name is not None:
        c.name = payload.name
    if payload.sort_order is not None:
        c.sort_order = payload.sort_order
    
    c.updated_at = datetime.utcnow()
    try:
        await session.commit()
    except Exception:
        await session.rollback()
        raise HTTPException(status_code=400, detail="Update failed")
    
    return Category(
        id=c.id,
        name=c.name,
        sort_order=c.sort_order,
        created_at=c.created_at.isoformat() + "Z" if c.created_at else None,
        updated_at=c.updated_at.isoformat() + "Z" if c.updated_at else None,
    )

@router.delete("/admin/categories/{id}")
async def delete_category(id: str, session: AsyncSession = Depends(get_session), admin=Depends(get_current_admin)):
    q = await session.execute(select(SACategory).where(SACategory.id == id))
    c = q.scalar_one_or_none()
    if not c:
        raise HTTPException(status_code=404)
    await session.delete(c)
    await session.commit()
    return {"message": "Deleted"}
