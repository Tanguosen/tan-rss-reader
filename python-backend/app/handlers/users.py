from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from typing import Optional, List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc, func
from ..db import SessionLocal
from ..models import User as SAUser, Subscription as SASubscription
from .auth import get_current_user, get_current_admin

router = APIRouter()

async def get_session() -> AsyncSession:
    async with SessionLocal() as session:
        yield session

class User(BaseModel):
    id: str
    username: str
    email: Optional[str] = None
    role: str
    is_active: bool
    created_at: Optional[str] = None

class UpdateUserRequest(BaseModel):
    role: Optional[str] = None
    is_active: Optional[bool] = None
    password: Optional[str] = None # Optional: Allow admin to reset password (maybe later)

@router.get("/me", response_model=User)
async def me(current: SAUser = Depends(get_current_user)) -> User:
    return User(
        id=current.id, 
        username=current.username, 
        email=current.email, 
        role=current.role, 
        is_active=bool(current.is_active),
        created_at=current.created_at.isoformat() + "Z" if current.created_at else None
    )

@router.get("/admin/users", response_model=List[User])
async def list_users(
    limit: int = 50,
    offset: int = 0,
    session: AsyncSession = Depends(get_session),
    admin: SAUser = Depends(get_current_admin)
) -> List[User]:
    q = select(SAUser).order_by(desc(SAUser.created_at)).offset(offset).limit(min(limit, 1000))
    result = await session.execute(q)
    users = result.scalars().all()
    return [
        User(
            id=u.id,
            username=u.username,
            email=u.email,
            role=u.role,
            is_active=bool(u.is_active),
            created_at=u.created_at.isoformat() + "Z" if u.created_at else None
        )
        for u in users
    ]

@router.patch("/admin/users/{id}", response_model=User)
async def update_user(
    id: str,
    payload: UpdateUserRequest,
    session: AsyncSession = Depends(get_session),
    admin: SAUser = Depends(get_current_admin)
) -> User:
    # Prevent self-demotion or self-deactivation to avoid locking out
    if id == admin.id:
        if payload.is_active is False:
             raise HTTPException(status_code=400, detail="Cannot deactivate your own account")
        if payload.role and payload.role != "admin":
             raise HTTPException(status_code=400, detail="Cannot demote your own account")

    q = await session.execute(select(SAUser).where(SAUser.id == id))
    user = q.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if payload.role:
        user.role = payload.role
    if payload.is_active is not None:
        user.is_active = payload.is_active
    
    await session.commit()
    return User(
        id=user.id,
        username=user.username,
        email=user.email,
        role=user.role,
        is_active=bool(user.is_active),
        created_at=user.created_at.isoformat() + "Z" if user.created_at else None
    )

@router.delete("/admin/users/{id}")
async def delete_user(
    id: str,
    session: AsyncSession = Depends(get_session),
    admin: SAUser = Depends(get_current_admin)
) -> dict:
    if id == admin.id:
        raise HTTPException(status_code=400, detail="Cannot delete your own account")

    q = await session.execute(select(SAUser).where(SAUser.id == id))
    user = q.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Delete related subscriptions
    await session.execute(select(SASubscription).where(SASubscription.user_id == id))
    # In a real app, you might want to cascade delete or keep data. 
    # For now, assuming cascade delete is set up in DB or we manually delete related.
    # We will just delete the user. SQLAlchemy relationships might need cascade if configured.
    
    await session.delete(user)
    await session.commit()
    return {"message": "User deleted successfully"}
