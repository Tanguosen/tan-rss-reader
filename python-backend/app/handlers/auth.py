from fastapi import APIRouter, Depends, HTTPException, Header
from pydantic import BaseModel, field_validator
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from uuid import uuid4
from datetime import datetime, timedelta
import os
import jwt
import bcrypt
import re
from ..db import SessionLocal
from ..models import User as SAUser
from sqlalchemy.exc import IntegrityError

router = APIRouter()

def _env(key: str, default: str = "") -> str:
    val = os.getenv(key)
    return val if val else default

AUTH_SECRET = _env("AURORA_AUTH_SECRET", "dev-secret")
AUTH_EXPIRE_MINUTES = int(_env("AURORA_AUTH_EXPIRE_MINUTES", "20160")) # 14 days

async def get_session() -> AsyncSession:
    async with SessionLocal() as session:
        yield session

class RegisterRequest(BaseModel):
    username: str
    password: str
    email: Optional[str] = None

    @field_validator('username')
    @classmethod
    def username_alphanumeric(cls, v: str) -> str:
        if not re.match(r'^[a-zA-Z0-9_-]+$', v):
            raise ValueError('Username must be alphanumeric (letters, numbers, _, -)')
        if len(v) < 3:
            raise ValueError('Username must be at least 3 characters')
        return v

    @field_validator('password')
    @classmethod
    def password_length(cls, v: str) -> str:
        if len(v) < 6:
            raise ValueError('Password must be at least 6 characters')
        return v

    @field_validator('email')
    @classmethod
    def email_valid(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            v = v.strip()
            if not v:
                return None
            if not re.match(r'^[^@\s]+@[^@\s]+\.[^@\s]+$', v):
                 raise ValueError('Invalid email format')
        return v

class LoginRequest(BaseModel):
    username: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"

class User(BaseModel):
    id: str
    username: str
    email: Optional[str] = None
    role: str
    is_active: bool

def create_access_token(sub: str, role: str) -> str:
    now = datetime.utcnow()
    payload = {"sub": sub, "role": role, "iat": int(now.timestamp()), "exp": int((now + timedelta(minutes=AUTH_EXPIRE_MINUTES)).timestamp())}
    return jwt.encode(payload, AUTH_SECRET, algorithm="HS256")

def verify_password(plain: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(plain.encode('utf-8'), hashed.encode('utf-8'))
    except Exception:
        return False

def hash_password(plain: str) -> str:
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(plain.encode('utf-8'), salt).decode('utf-8')

async def get_current_user(authorization: Optional[str] = Header(default=None), session: AsyncSession = Depends(get_session)) -> SAUser:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401)
    token = authorization.split(" ", 1)[1]
    try:
        data = jwt.decode(token, AUTH_SECRET, algorithms=["HS256"])
        uid = data.get("sub")
    except Exception:
        raise HTTPException(status_code=401)
    q = await session.execute(select(SAUser).where(SAUser.id == uid))
    user = q.scalar_one_or_none()
    if not user or not user.is_active:
        raise HTTPException(status_code=401)
    return user

async def get_current_admin(current_user: SAUser = Depends(get_current_user)) -> SAUser:
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin privileges required")
    return current_user

async def get_optional_user(authorization: Optional[str] = Header(default=None), session: AsyncSession = Depends(get_session)) -> Optional[SAUser]:
    if not authorization or not authorization.lower().startswith("bearer "):
        return None
    token = authorization.split(" ", 1)[1]
    try:
        data = jwt.decode(token, AUTH_SECRET, algorithms=["HS256"])
        uid = data.get("sub")
    except Exception:
        return None
    q = await session.execute(select(SAUser).where(SAUser.id == uid))
    user = q.scalar_one_or_none()
    if not user or not user.is_active:
        return None
    return user

@router.post("/auth/register", response_model=User)
async def register(payload: RegisterRequest, session: AsyncSession = Depends(get_session)) -> User:
    exists = (await session.execute(select(SAUser).where(SAUser.username == payload.username))).scalar_one_or_none()
    if exists:
        raise HTTPException(status_code=400, detail="Username already exists")
    email_cleaned = None
    if payload.email is not None:
        e = payload.email.strip()
        if e:
            # Check email uniqueness explicitly to avoid IntegrityError
            email_exists = (await session.execute(select(SAUser).where(SAUser.email == e))).scalar_one_or_none()
            if email_exists:
                raise HTTPException(status_code=400, detail="Email already exists")
            email_cleaned = e
    
    # Check if this is the first user
    user_count = (await session.execute(select(func.count(SAUser.id)))).scalar()
    role = "admin" if user_count == 0 else "user"

    uid = str(uuid4())
    now = datetime.utcnow()
    row = SAUser(
        id=uid,
        username=payload.username,
        email=email_cleaned,
        password_hash=hash_password(payload.password),
        role=role,
        is_active=True,
        created_at=now,
        updated_at=now,
    )
    session.add(row)
    try:
        await session.commit()
    except IntegrityError:
        # Fallback guard in case of race conditions
        await session.rollback()
        raise HTTPException(status_code=400)
    return User(id=row.id, username=row.username, email=row.email, role=row.role, is_active=bool(row.is_active))

@router.post("/auth/login", response_model=TokenResponse)
async def login(payload: LoginRequest, session: AsyncSession = Depends(get_session)) -> TokenResponse:
    q = await session.execute(select(SAUser).where(SAUser.username == payload.username))
    user = q.scalar_one_or_none()
    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401)
    token = create_access_token(user.id, user.role)
    return TokenResponse(access_token=token)
