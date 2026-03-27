from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, timedelta
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from ..db import SessionLocal
from ..models import UserMembership as SAUserMembership, UserUsage as SAUserUsage
from .auth import get_current_user

router = APIRouter()

async def get_session() -> AsyncSession:
    async with SessionLocal() as session:
        yield session

class MembershipStatus(BaseModel):
    tier: str
    expires_at: Optional[str]
    is_active: bool
    today_ai_calls: int

class SubscribeRequest(BaseModel):
    tier: str
    months: int = 1

@router.get("/membership/status", response_model=MembershipStatus)
async def get_membership_status(
    session: AsyncSession = Depends(get_session),
    current_user = Depends(get_current_user)
):
    q = await session.execute(select(SAUserMembership).where(SAUserMembership.user_id == current_user.id))
    mem = q.scalar_one_or_none()
    
    tier = mem.tier if mem else "free"
    expires_at = mem.expires_at if mem else None
    
    is_active = False
    if tier in ("plus", "pro"):
        if not expires_at or expires_at > datetime.utcnow():
            is_active = True
        else:
            tier = "free" # expired
    
    today_str = datetime.utcnow().strftime("%Y-%m-%d")
    usage_id = f"{current_user.id}_{today_str}"
    q_usage = await session.execute(select(SAUserUsage).where(SAUserUsage.id == usage_id))
    usage = q_usage.scalar_one_or_none()
    today_calls = usage.ai_calls if usage else 0
    
    return MembershipStatus(
        tier=tier,
        expires_at=expires_at.isoformat() + "Z" if expires_at else None,
        is_active=is_active,
        today_ai_calls=today_calls
    )

@router.post("/membership/subscribe")
async def subscribe_membership(
    req: SubscribeRequest,
    session: AsyncSession = Depends(get_session),
    current_user = Depends(get_current_user)
):
    if req.tier not in ("plus", "pro", "free"):
        raise HTTPException(status_code=400, detail="Invalid tier")
        
    q = await session.execute(select(SAUserMembership).where(SAUserMembership.user_id == current_user.id))
    mem = q.scalar_one_or_none()
    
    now = datetime.utcnow()
    
    if req.tier == "free":
        if mem:
            mem.tier = "free"
            mem.expires_at = None
            mem.updated_at = now
            await session.commit()
        return {"success": True, "message": "Downgraded to free"}
        
    # Fake payment processing here
    # In real world, verify payment before extending time
    
    extra_time = timedelta(days=30 * req.months)
    
    if not mem:
        import uuid
        mem_id = str(uuid.uuid4())
        mem = SAUserMembership(
            id=mem_id,
            user_id=current_user.id,
            tier=req.tier,
            expires_at=now + extra_time,
            created_at=now,
            updated_at=now
        )
        session.add(mem)
    else:
        mem.tier = req.tier
        if mem.expires_at and mem.expires_at > now:
            mem.expires_at = mem.expires_at + extra_time
        else:
            mem.expires_at = now + extra_time
        mem.updated_at = now
        
    await session.commit()
    
    return {
        "success": True, 
        "message": f"Successfully subscribed to {req.tier} for {req.months} months",
        "expires_at": mem.expires_at.isoformat() + "Z"
    }
