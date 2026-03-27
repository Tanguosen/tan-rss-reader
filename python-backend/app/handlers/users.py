from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, field_validator
from typing import Optional, List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc, func
import re
from ..db import SessionLocal
from ..models import User as SAUser, Subscription as SASubscription, UserMembership as SAUserMembership
from .auth import get_current_user, get_current_admin, hash_password, verify_password

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
    tier: str = "free"

class UpdateUserRequest(BaseModel):
    role: Optional[str] = None
    is_active: Optional[bool] = None
    password: Optional[str] = None # Optional: Allow admin to reset password (maybe later)
    tier: Optional[str] = None

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

class UpdateMeRequest(BaseModel):
    email: Optional[str] = None          # None = 不修改，"" = 清空邮箱
    current_password: Optional[str] = None
    new_password: Optional[str] = None

    @field_validator('new_password')
    @classmethod
    def new_password_length(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and len(v) < 6:
            raise ValueError('密码长度不能少于6位')
        return v

    @field_validator('email')
    @classmethod
    def email_format(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v != '':
            if not re.match(r'^[^@\s]+@[^@\s]+\.[^@\s]+$', v):
                raise ValueError('邮箱格式不正确')
        return v

@router.patch("/me", response_model=User)
async def update_me(
    payload: UpdateMeRequest,
    session: AsyncSession = Depends(get_session),
    current: SAUser = Depends(get_current_user)
) -> User:
    """User updates own profile: email and/or password"""
    from datetime import datetime
    
    # 修改密码
    if payload.new_password is not None:
        if not payload.current_password:
            raise HTTPException(status_code=400, detail="修改密码需要提供当前密码")
        if not verify_password(payload.current_password, current.password_hash):
            raise HTTPException(status_code=400, detail="当前密码错误")
        current.password_hash = hash_password(payload.new_password)

    # 修改邮箱
    if payload.email is not None:
        email_val = payload.email.strip()
        if email_val == '':
            current.email = None
        else:
            # 检查邮箱是否已被其他用户使用
            other = (await session.execute(
                select(SAUser).where(SAUser.email == email_val, SAUser.id != current.id)
            )).scalar_one_or_none()
            if other:
                raise HTTPException(status_code=400, detail="该邮箱已被其他账户使用")
            current.email = email_val

    current.updated_at = datetime.utcnow()
    await session.commit()
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
    # Need to outer join with UserMembership to fetch tier, but SQLAlchemy result structure varies.
    q = select(SAUser, SAUserMembership).outerjoin(SAUserMembership, SAUser.id == SAUserMembership.user_id).order_by(desc(SAUser.created_at)).offset(offset).limit(min(limit, 1000))
    result = await session.execute(q)
    rows = result.all()
    
    users_list = []
    for row in rows:
        u = row[0] # SAUser
        m = row[1] # SAUserMembership (can be None)
        users_list.append(User(
            id=u.id,
            username=u.username,
            email=u.email,
            role=u.role,
            is_active=bool(u.is_active),
            created_at=u.created_at.isoformat() + "Z" if u.created_at else None,
            tier=m.tier if m else "free"
        ))
    return users_list

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
        
    tier_val = "free"
    if payload.tier is not None:
        q_mem = await session.execute(select(SAUserMembership).where(SAUserMembership.user_id == id))
        mem = q_mem.scalar_one_or_none()
        if not mem:
            from datetime import datetime
            import uuid
            now = datetime.utcnow()
            mem = SAUserMembership(
                id=str(uuid.uuid4()),
                user_id=id,
                tier=payload.tier,
                created_at=now,
                updated_at=now
            )
            session.add(mem)
        else:
            mem.tier = payload.tier
            
    q_mem_final = await session.execute(select(SAUserMembership).where(SAUserMembership.user_id == id))
    mem_final = q_mem_final.scalar_one_or_none()
    tier_val = mem_final.tier if mem_final else "free"
    
    await session.commit()
    return User(
        id=user.id,
        username=user.username,
        email=user.email,
        role=user.role,
        is_active=bool(user.is_active),
        created_at=user.created_at.isoformat() + "Z" if user.created_at else None,
        tier=tier_val
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
