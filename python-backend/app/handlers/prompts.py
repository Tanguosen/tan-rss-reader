from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from uuid import uuid4

from ..db import SessionLocal
from ..models import UserAIPrompt as SAUserAIPrompt
from .auth import get_current_user

router = APIRouter()

async def get_session() -> AsyncSession:
    async with SessionLocal() as session:
        yield session

class PromptCreate(BaseModel):
    name: str
    prompt_type: str
    content: str

class PromptUpdate(BaseModel):
    name: Optional[str] = None
    prompt_type: Optional[str] = None
    content: Optional[str] = None

class PromptResponse(BaseModel):
    id: str
    name: str
    prompt_type: str
    content: str
    created_at: str
    updated_at: str

@router.get("/ai/prompts", response_model=List[PromptResponse])
async def list_prompts(
    session: AsyncSession = Depends(get_session),
    current_user = Depends(get_current_user)
):
    q = await session.execute(select(SAUserAIPrompt).where(SAUserAIPrompt.user_id == current_user.id))
    prompts = q.scalars().all()
    
    return [
        PromptResponse(
            id=p.id,
            name=p.name,
            prompt_type=p.prompt_type,
            content=p.content,
            created_at=p.created_at.isoformat() + "Z" if p.created_at else "",
            updated_at=p.updated_at.isoformat() + "Z" if p.updated_at else ""
        )
        for p in prompts
    ]

@router.post("/ai/prompts", response_model=PromptResponse)
async def create_prompt(
    payload: PromptCreate,
    session: AsyncSession = Depends(get_session),
    current_user = Depends(get_current_user)
):
    now = datetime.utcnow()
    p_id = str(uuid4())
    p = SAUserAIPrompt(
        id=p_id,
        user_id=current_user.id,
        name=payload.name,
        prompt_type=payload.prompt_type,
        content=payload.content,
        created_at=now,
        updated_at=now
    )
    session.add(p)
    await session.commit()
    
    return PromptResponse(
        id=p.id,
        name=p.name,
        prompt_type=p.prompt_type,
        content=p.content,
        created_at=now.isoformat() + "Z",
        updated_at=now.isoformat() + "Z"
    )

@router.put("/ai/prompts/{prompt_id}", response_model=PromptResponse)
async def update_prompt(
    prompt_id: str,
    payload: PromptUpdate,
    session: AsyncSession = Depends(get_session),
    current_user = Depends(get_current_user)
):
    q = await session.execute(select(SAUserAIPrompt).where(SAUserAIPrompt.id == prompt_id, SAUserAIPrompt.user_id == current_user.id))
    p = q.scalar_one_or_none()
    if not p:
        raise HTTPException(status_code=404, detail="Prompt not found")
        
    if payload.name is not None:
        p.name = payload.name
    if payload.prompt_type is not None:
        p.prompt_type = payload.prompt_type
    if payload.content is not None:
        p.content = payload.content
        
    p.updated_at = datetime.utcnow()
    await session.commit()
    
    return PromptResponse(
        id=p.id,
        name=p.name,
        prompt_type=p.prompt_type,
        content=p.content,
        created_at=p.created_at.isoformat() + "Z",
        updated_at=p.updated_at.isoformat() + "Z"
    )

@router.delete("/ai/prompts/{prompt_id}")
async def delete_prompt(
    prompt_id: str,
    session: AsyncSession = Depends(get_session),
    current_user = Depends(get_current_user)
):
    q = await session.execute(select(SAUserAIPrompt).where(SAUserAIPrompt.id == prompt_id, SAUserAIPrompt.user_id == current_user.id))
    p = q.scalar_one_or_none()
    if not p:
        raise HTTPException(status_code=404, detail="Prompt not found")
        
    await session.delete(p)
    await session.commit()
    return {"success": True}
