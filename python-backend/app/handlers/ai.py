from fastapi import APIRouter, Depends, HTTPException, Body
from pydantic import BaseModel
from typing import Optional, List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from datetime import datetime
import json
import os
import httpx
import re
from uuid import uuid4

from ..db import SessionLocal
from ..models import AIConfigRow as SAAIConfigRow, Entry as SAEntry, EntryAI as SAEntryAI, AIDailyDigest as SAAIDailyDigest, UserMembership as SAUserMembership, UserUsage as SAUserUsage

from .auth import get_current_user, get_current_admin

router = APIRouter()

async def get_session() -> AsyncSession:
    async with SessionLocal() as session:
        yield session

from ..config import env_settings

def _env(key: str, default: str = "") -> str:
    # 优先从 env_settings 获取，回退到 os.getenv，最后 default
    val = getattr(env_settings, key.lower(), None)
    if val is not None and str(val).strip():
        return str(val)
    val = os.getenv(key)
    return val if val else default

AI_CFG = {
    "summary": {
        "api_key": _env("AURORA_AI_API_KEY"),
        "base_url": _env("AURORA_AI_BASE_URL", "http://10.110.3.61:9997/v1"),
        "model_name": _env("AURORA_AI_MODEL", "qwen3"),
        "has_api_key": bool(_env("AURORA_AI_API_KEY")),
    },
    "translation": {
        "api_key": _env("AURORA_AI_API_KEY"),
        "base_url": _env("AURORA_AI_BASE_URL", "http://10.110.3.61:9997/v1"),
        "model_name": _env("AURORA_AI_MODEL", "qwen3"),
        "has_api_key": bool(_env("AURORA_AI_API_KEY")),
    },
    "embedding": {
        "api_key": _env("AURORA_AI_API_KEY"),
        "base_url": _env("AURORA_AI_BASE_URL", "http://10.110.3.61:9997/v1"),
        "model_name": _env("AURORA_AI_EMBEDDING_MODEL", "Qwen3-Embedding-0.6B"),
        "has_api_key": bool(_env("AURORA_AI_API_KEY")),
    },
    "vector": {
        "milvus_host": _env("MILVUS_HOST", "10.110.3.25"),
        "milvus_port": _env("MILVUS_PORT", "19530"),
        "milvus_collection_name": _env("MILVUS_COLLECTION", "rss_entries"),
    },
    "features": {
        "auto_summary": False,
        "auto_translation": False,
        "auto_title_translation": False,
        "translation_language": "zh",
    },
}

class AIServiceConfig(BaseModel):
    api_key: str = ""
    base_url: str = ""
    model_name: str = "glm-4-flash"
    has_api_key: bool = False

class AIFeatureConfig(BaseModel):
    auto_summary: bool = False
    auto_translation: bool = False
    auto_title_translation: bool = False
    translation_language: str = "zh"

class AIConfig(BaseModel):
    summary: AIServiceConfig
    translation: AIServiceConfig
    embedding: AIServiceConfig
    features: AIFeatureConfig

class SummaryRequest(BaseModel):
    entry_id: str
    language: Optional[str] = None

class TranslationRequest(BaseModel):
    entry_id: str
    field_type: str
    target_language: str

class TextTranslationRequest(BaseModel):
    text: str
    target_language: str = "zh"

class EmbeddingRequest(BaseModel):
    text: str

class ResearchRequest(BaseModel):
    query: str
    limit: int = 8

from fastapi.responses import StreamingResponse

async def get_user_ai_context(user_id: str, session: AsyncSession) -> dict:
    """获取用户有效的AI配置，结合会员权限和个人配置"""
    # 获取用户会员状态
    q_mem = await session.execute(select(SAUserMembership).where(SAUserMembership.user_id == user_id))
    membership = q_mem.scalar_one_or_none()
    tier = membership.tier if membership else "free"
    
    # 获取用户个人AI配置
    q_cfg = await session.execute(select(SAAIConfigRow).where(SAAIConfigRow.id == user_id))
    user_cfg_row = q_cfg.scalar_one_or_none()
    
    user_has_key = False
    if user_cfg_row:
        user_has_key = bool(user_cfg_row.summary_api_key or user_cfg_row.translation_api_key)
        
    # 判断是否有权使用平台配置
    can_use_platform = tier in ("plus", "pro")
    
    if not user_has_key and not can_use_platform:
        raise HTTPException(status_code=403, detail="Free users must configure their own AI API Key or upgrade to Plus")
        
    config = dict(AI_CFG) # Copy default
    
    # 如果用户有自己的配置，覆盖默认配置
    if user_cfg_row:
        config["summary"] = {
            "api_key": user_cfg_row.summary_api_key or config["summary"]["api_key"],
            "base_url": user_cfg_row.summary_base_url or config["summary"]["base_url"],
            "model_name": user_cfg_row.summary_model_name or config["summary"]["model_name"],
            "has_api_key": bool(user_cfg_row.summary_api_key) or config["summary"]["has_api_key"]
        }
        config["translation"] = {
            "api_key": user_cfg_row.translation_api_key or config["translation"]["api_key"],
            "base_url": user_cfg_row.translation_base_url or config["translation"]["base_url"],
            "model_name": user_cfg_row.translation_model_name or config["translation"]["model_name"],
            "has_api_key": bool(user_cfg_row.translation_api_key) or config["translation"]["has_api_key"]
        }
        # 注意：嵌入模型和向量数据库配置是平台级别功能，不跟随用户个人配置
        # 始终使用平台默认配置，确保向量嵌入功能正常工作
        # config["embedding"] 保持使用 AI_CFG["embedding"] 的默认值
        # config["vector"] 保持使用 AI_CFG["vector"] 的默认值
        config["features"] = {
            "auto_summary": bool(user_cfg_row.auto_summary),
            "auto_translation": bool(user_cfg_row.auto_translation),
            "auto_title_translation": bool(user_cfg_row.auto_title_translation),
            "auto_quality_scoring": bool(getattr(user_cfg_row, "auto_quality_scoring", True)),
            "translation_language": user_cfg_row.translation_language or config["features"]["translation_language"],
        }
    
    # 记录调用次数(如果是使用平台额度)
    if not user_has_key and can_use_platform:
        today_str = datetime.utcnow().strftime("%Y-%m-%d")
        usage_id = f"{user_id}_{today_str}"
        q_usage = await session.execute(select(SAUserUsage).where(SAUserUsage.id == usage_id))
        usage = q_usage.scalar_one_or_none()
        if not usage:
            usage = SAUserUsage(id=usage_id, user_id=user_id, date_str=today_str, ai_calls=0)
            session.add(usage)
        
        # 暂时解除 Plus 和 Pro 的调用次数硬性限制
        # if tier == "plus" and usage.ai_calls >= 50:
        #     raise HTTPException(status_code=429, detail="Plus membership daily AI limit reached")
        
        usage.ai_calls += 1
        await session.commit()
        
    return config

async def _call_ai(messages: list[dict], max_tokens: int = 1024, config: dict = None) -> str:
    if config is None:
        config = AI_CFG
    key = config["summary"]["api_key"] or config["translation"]["api_key"]
    base = config["summary"]["base_url"]
    model = config["summary"]["model_name"]
    if not key:
        # allow no key if base url is local or specific
        pass 
    
    url = base.rstrip("/") + "/chat/completions"
    payload = {
        "model": model,
        "messages": messages,
        "max_tokens": max_tokens,
        "temperature": 0.3,
    }
    headers = {"Content-Type": "application/json"}
    if key:
        headers["Authorization"] = f"Bearer {key}"
    
    import asyncio
    max_retries = 3
    base_delay = 1.0

    for attempt in range(max_retries + 1):
        try:
            async with httpx.AsyncClient(timeout=60) as client:
                resp = await client.post(url, json=payload, headers=headers)
            
            if resp.status_code == 429:
                if attempt < max_retries:
                    delay = base_delay * (2 ** attempt)
                    await asyncio.sleep(delay)
                    continue
                else:
                    raise HTTPException(status_code=429, detail="Rate limit exceeded after retries")
            
            if resp.status_code >= 400:
                print(f"AI Error: {resp.status_code} {resp.text}")
                raise HTTPException(status_code=resp.status_code, detail=f"AI Service Error: {resp.text}")
            
            data = resp.json()
            choices = data.get("choices") or []
            if not choices:
                return ""
            msg = choices[0].get("message") or {}
            return msg.get("content") or ""
            
        except httpx.RequestError as e:
            print(f"AI Request Error: {e}")
            if attempt < max_retries:
                await asyncio.sleep(1)
                continue
            raise HTTPException(status_code=502, detail="AI Service Unavailable")
    return ""

async def _call_ai_stream(messages: list[dict], max_tokens: int = 1024, config: dict = None):
    if config is None:
        config = AI_CFG
    key = config["summary"]["api_key"] or config["translation"]["api_key"]
    base = config["summary"]["base_url"]
    model = config["summary"]["model_name"]
    
    if not base:
        yield f"data: {json.dumps({'error': 'AI configuration missing base_url'})}\n\n"
        return
        
    url = base.rstrip("/") + "/chat/completions"
    payload = {
        "model": model,
        "messages": messages,
        "max_tokens": max_tokens,
        "temperature": 0.3,
        "stream": True,
    }
    headers = {"Content-Type": "application/json"}
    if key:
        headers["Authorization"] = f"Bearer {key}"
        
    try:
        async with httpx.AsyncClient(timeout=120) as client:
            async with client.stream("POST", url, json=payload, headers=headers) as response:
                if response.status_code >= 400:
                    text = await response.aread()
                    yield f"data: {json.dumps({'error': f'HTTP {response.status_code}: {text.decode()}'})}\n\n"
                    return
                    
                async for line in response.aiter_lines():
                    if line.startswith("data: "):
                        data_str = line[6:]
                        if data_str.strip() == "[DONE]":
                            break
                        try:
                            data = json.loads(data_str)
                            choices = data.get("choices", [])
                            if choices:
                                delta = choices[0].get("delta", {})
                                content = delta.get("content")
                                if content:
                                    yield f"data: {json.dumps({'type': 'chunk', 'content': content})}\n\n"
                        except Exception:
                            pass
    except Exception as e:
        yield f"data: {json.dumps({'error': f'Request failed: {str(e)}'})}\n\n"

async def generate_trend_analysis(entries_text: str) -> dict:
    prompt = (
        "基于以下话题相关的多篇新闻摘要，生成一份趋势分析报告。请严格以 JSON 格式返回，包含以下字段：\n"
        "- trend_prediction: 简述未来发展趋势预测（中文，100字以内）\n"
        "- sentiment_score: 整体情感倾向打分 (浮点数 -1.0 负面 到 1.0 正面)\n"
        "- keywords: 5个核心关键词数组\n"
        "- summary: 话题整体摘要（中文，100字以内）\n"
        "注意：只返回 JSON，不要包含 Markdown 格式标记（如 ```json ... ```）。\n"
        "\n内容如下：\n" + entries_text
    )
    
    text = await _call_ai([
        {"role": "system", "content": "You are a helpful data analyst."},
        {"role": "user", "content": prompt},
    ])
    
    # Try to extract JSON
    json_text = text
    match = re.search(r"```(?:json)?\s*(.*?)\s*```", text, re.DOTALL)
    if match:
        json_text = match.group(1)
        
    try:
        return json.loads(json_text)
    except Exception:
        # Fallback
        return {
            "trend_prediction": "无法生成趋势预测",
            "sentiment_score": 0.0,
            "keywords": [],
            "summary": text[:200]
        }


async def _call_embedding(text: str, config: dict = None) -> List[float]:
    if config is None:
        config = AI_CFG
    
    # 嵌入模型配置优先使用用户配置，如果为空则回退到平台默认配置
    embedding_cfg = config.get("embedding", {})
    default_embedding_cfg = AI_CFG.get("embedding", {})
    
    key = embedding_cfg.get("api_key") or config.get("summary", {}).get("api_key") or default_embedding_cfg.get("api_key") or AI_CFG.get("summary", {}).get("api_key")
    base = embedding_cfg.get("base_url") or default_embedding_cfg.get("base_url") or AI_CFG.get("summary", {}).get("base_url")
    model = embedding_cfg.get("model_name") or default_embedding_cfg.get("model_name")
    
    if not base:
        print("Embedding Error: No base_url configured")
        return []
    
    url = base.rstrip("/") + "/embeddings"
    payload = {
        "model": model,
        "input": text
    }
    headers = {"Content-Type": "application/json"}
    if key:
        headers["Authorization"] = f"Bearer {key}"
        
    import asyncio
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(url, json=payload, headers=headers)
            
        if resp.status_code >= 400:
            print(f"Embedding Error: {resp.status_code} {resp.text}")
            return []
            
        data = resp.json()
        data_list = data.get("data") or []
        if not data_list:
            return []
        return data_list[0].get("embedding") or []
    except Exception as e:
        print(f"Embedding Exception: {e}")
        return []


async def init_ai_config(session: AsyncSession):
    q2 = await session.execute(select(SAAIConfigRow).where(SAAIConfigRow.id == "default"))
    arow = q2.scalar_one_or_none()
    if arow:
        AI_CFG["summary"]["api_key"] = arow.summary_api_key or ""
        AI_CFG["summary"]["base_url"] = arow.summary_base_url or AI_CFG["summary"]["base_url"]
        AI_CFG["summary"]["model_name"] = arow.summary_model_name or AI_CFG["summary"]["model_name"]
        AI_CFG["summary"]["has_api_key"] = bool(arow.summary_has_api_key)
        AI_CFG["translation"]["api_key"] = arow.translation_api_key or ""
        AI_CFG["translation"]["base_url"] = arow.translation_base_url or AI_CFG["translation"]["base_url"]
        AI_CFG["translation"]["model_name"] = arow.translation_model_name or AI_CFG["translation"]["model_name"]
        AI_CFG["translation"]["has_api_key"] = bool(arow.translation_has_api_key)
        AI_CFG["embedding"]["api_key"] = arow.embedding_api_key or ""
        AI_CFG["embedding"]["base_url"] = arow.embedding_base_url or AI_CFG["embedding"]["base_url"]
        AI_CFG["embedding"]["model_name"] = arow.embedding_model_name or AI_CFG["embedding"]["model_name"]
        AI_CFG["embedding"]["has_api_key"] = bool(arow.embedding_has_api_key)
        AI_CFG["vector"]["milvus_host"] = arow.milvus_host or AI_CFG["vector"]["milvus_host"]
        AI_CFG["vector"]["milvus_port"] = arow.milvus_port or AI_CFG["vector"]["milvus_port"]
        AI_CFG["vector"]["milvus_collection_name"] = arow.milvus_collection_name or AI_CFG["vector"]["milvus_collection_name"]
        AI_CFG["features"]["auto_summary"] = bool(arow.auto_summary)
        AI_CFG["features"]["auto_translation"] = bool(arow.auto_translation)
        AI_CFG["features"]["auto_title_translation"] = bool(arow.auto_title_translation)
        AI_CFG["features"]["auto_quality_scoring"] = bool(getattr(arow, "auto_quality_scoring", True))
        AI_CFG["features"]["translation_language"] = arow.translation_language or AI_CFG["features"]["translation_language"]

@router.get("/ai/config")
async def get_ai_config(session: AsyncSession = Depends(get_session), admin = Depends(get_current_admin)) -> dict:
    q = await session.execute(select(SAAIConfigRow).where(SAAIConfigRow.id == "default"))
    row = q.scalar_one_or_none()
    if not row:
        now = datetime.utcnow()
        row = SAAIConfigRow(
            id="default",
            summary_api_key=AI_CFG["summary"]["api_key"],
            summary_base_url=AI_CFG["summary"]["base_url"],
            summary_model_name=AI_CFG["summary"]["model_name"],
            summary_has_api_key=bool(AI_CFG["summary"]["api_key"]),
            translation_api_key=AI_CFG["translation"]["api_key"],
            translation_base_url=AI_CFG["translation"]["base_url"],
            translation_model_name=AI_CFG["translation"]["model_name"],
            translation_has_api_key=bool(AI_CFG["translation"]["api_key"]),
            embedding_api_key=AI_CFG["embedding"]["api_key"],
            embedding_base_url=AI_CFG["embedding"]["base_url"],
            embedding_model_name=AI_CFG["embedding"]["model_name"],
            embedding_has_api_key=bool(AI_CFG["embedding"]["api_key"]),
            milvus_host=AI_CFG["vector"]["milvus_host"],
            milvus_port=AI_CFG["vector"]["milvus_port"],
            milvus_collection_name=AI_CFG["vector"]["milvus_collection_name"],
            auto_summary=bool(AI_CFG["features"]["auto_summary"]),
            auto_translation=bool(AI_CFG["features"]["auto_translation"]),
            auto_title_translation=bool(AI_CFG["features"]["auto_title_translation"]),
            auto_quality_scoring=bool(AI_CFG["features"].get("auto_quality_scoring", True)),
            translation_language=AI_CFG["features"]["translation_language"],
            created_at=now,
            updated_at=now,
        )
        session.add(row)
        await session.commit()
    AI_CFG["summary"]["api_key"] = row.summary_api_key or ""
    AI_CFG["summary"]["base_url"] = row.summary_base_url or AI_CFG["summary"]["base_url"]
    AI_CFG["summary"]["model_name"] = row.summary_model_name or AI_CFG["summary"]["model_name"]
    AI_CFG["summary"]["has_api_key"] = bool(row.summary_has_api_key)
    AI_CFG["translation"]["api_key"] = row.translation_api_key or ""
    AI_CFG["translation"]["base_url"] = row.translation_base_url or AI_CFG["translation"]["base_url"]
    AI_CFG["translation"]["model_name"] = row.translation_model_name or AI_CFG["translation"]["model_name"]
    AI_CFG["translation"]["has_api_key"] = bool(row.translation_has_api_key)
    AI_CFG["embedding"]["api_key"] = row.embedding_api_key or ""
    AI_CFG["embedding"]["base_url"] = row.embedding_base_url or AI_CFG["embedding"]["base_url"]
    AI_CFG["embedding"]["model_name"] = row.embedding_model_name or AI_CFG["embedding"]["model_name"]
    AI_CFG["embedding"]["has_api_key"] = bool(row.embedding_has_api_key)
    AI_CFG["vector"]["milvus_host"] = row.milvus_host or AI_CFG["vector"]["milvus_host"]
    AI_CFG["vector"]["milvus_port"] = row.milvus_port or AI_CFG["vector"]["milvus_port"]
    AI_CFG["vector"]["milvus_collection_name"] = row.milvus_collection_name or AI_CFG["vector"]["milvus_collection_name"]
    AI_CFG["features"]["auto_summary"] = bool(row.auto_summary)
    AI_CFG["features"]["auto_translation"] = bool(row.auto_translation)
    AI_CFG["features"]["auto_title_translation"] = bool(row.auto_title_translation)
    AI_CFG["features"]["auto_quality_scoring"] = bool(getattr(row, "auto_quality_scoring", True))
    AI_CFG["features"]["translation_language"] = row.translation_language or AI_CFG["features"]["translation_language"]
    return AI_CFG

@router.put("/ai/config")
@router.post("/ai/config")
@router.patch("/ai/config")
async def update_ai_config(payload: dict, session: AsyncSession = Depends(get_session), admin = Depends(get_current_admin)) -> dict:
    q = await session.execute(select(SAAIConfigRow).where(SAAIConfigRow.id == "default"))
    row = q.scalar_one_or_none()
    if not row:
        now = datetime.utcnow()
        row = SAAIConfigRow(id="default", created_at=now, updated_at=now)
        session.add(row)
    if "summary" in payload and isinstance(payload["summary"], dict):
        s = payload["summary"]
        if isinstance(s.get("api_key"), str):
            AI_CFG["summary"]["api_key"] = s["api_key"]
            row.summary_api_key = s["api_key"]
            row.summary_has_api_key = bool(s["api_key"])
        if isinstance(s.get("base_url"), str):
            AI_CFG["summary"]["base_url"] = s["base_url"]
            row.summary_base_url = s["base_url"]
        if isinstance(s.get("model_name"), str):
            AI_CFG["summary"]["model_name"] = s["model_name"]
            row.summary_model_name = s["model_name"]
    if "translation" in payload and isinstance(payload["translation"], dict):
        t = payload["translation"]
        if isinstance(t.get("api_key"), str):
            AI_CFG["translation"]["api_key"] = t["api_key"]
            row.translation_api_key = t["api_key"]
            row.translation_has_api_key = bool(t["api_key"])
        if isinstance(t.get("base_url"), str):
            AI_CFG["translation"]["base_url"] = t["base_url"]
            row.translation_base_url = t["base_url"]
        if isinstance(t.get("model_name"), str):
            AI_CFG["translation"]["model_name"] = t["model_name"]
            row.translation_model_name = t["model_name"]
    if "embedding" in payload and isinstance(payload["embedding"], dict):
        e = payload["embedding"]
        if isinstance(e.get("api_key"), str):
            AI_CFG["embedding"]["api_key"] = e["api_key"]
            row.embedding_api_key = e["api_key"]
            row.embedding_has_api_key = bool(e["api_key"])
        if isinstance(e.get("base_url"), str):
            AI_CFG["embedding"]["base_url"] = e["base_url"]
            row.embedding_base_url = e["base_url"]
        if isinstance(e.get("model_name"), str):
            AI_CFG["embedding"]["model_name"] = e["model_name"]
            row.embedding_model_name = e["model_name"]
    if "vector" in payload and isinstance(payload["vector"], dict):
        v = payload["vector"]
        if isinstance(v.get("milvus_host"), str):
            AI_CFG["vector"]["milvus_host"] = v["milvus_host"]
            row.milvus_host = v["milvus_host"]
        if isinstance(v.get("milvus_port"), str):
            AI_CFG["vector"]["milvus_port"] = v["milvus_port"]
            row.milvus_port = v["milvus_port"]
        if isinstance(v.get("milvus_collection_name"), str):
            AI_CFG["vector"]["milvus_collection_name"] = v["milvus_collection_name"]
            row.milvus_collection_name = v["milvus_collection_name"]
    if "features" in payload and isinstance(payload["features"], dict):
        f = payload["features"]
        if "auto_summary" in f:
            AI_CFG["features"]["auto_summary"] = f["auto_summary"]
            row.auto_summary = bool(f["auto_summary"])
        if "auto_translation" in f:
            AI_CFG["features"]["auto_translation"] = f["auto_translation"]
            row.auto_translation = bool(f["auto_translation"])
        if "auto_title_translation" in f:
            AI_CFG["features"]["auto_title_translation"] = f["auto_title_translation"]
            row.auto_title_translation = bool(f["auto_title_translation"])
        if "auto_quality_scoring" in f:
            AI_CFG["features"]["auto_quality_scoring"] = f["auto_quality_scoring"]
            row.auto_quality_scoring = bool(f["auto_quality_scoring"])
        if "translation_language" in f:
            AI_CFG["features"]["translation_language"] = f["translation_language"]
            row.translation_language = f["translation_language"]
    row.updated_at = datetime.utcnow()
    await session.commit()
    return {"success": True, "config": AI_CFG}

@router.get("/ai/user/config")
async def get_user_ai_config_api(session: AsyncSession = Depends(get_session), current_user = Depends(get_current_user)) -> dict:
    q = await session.execute(select(SAAIConfigRow).where(SAAIConfigRow.id == current_user.id))
    row = q.scalar_one_or_none()
    
    config = {
        "summary": {"api_key": "", "base_url": "", "model_name": "", "has_api_key": False},
        "translation": {"api_key": "", "base_url": "", "model_name": "", "has_api_key": False},
        "embedding": {"api_key": "", "base_url": "", "model_name": "", "has_api_key": False},
        "vector": {"milvus_host": "", "milvus_port": "", "milvus_collection_name": ""},
        "features": {"auto_summary": False, "auto_translation": False, "auto_title_translation": False, "translation_language": "zh", "auto_quality_scoring": True}
    }
    
    if row:
        config["summary"]["api_key"] = row.summary_api_key or ""
        config["summary"]["base_url"] = row.summary_base_url or ""
        config["summary"]["model_name"] = row.summary_model_name or ""
        config["summary"]["has_api_key"] = bool(row.summary_has_api_key)
        
        config["translation"]["api_key"] = row.translation_api_key or ""
        config["translation"]["base_url"] = row.translation_base_url or ""
        config["translation"]["model_name"] = row.translation_model_name or ""
        config["translation"]["has_api_key"] = bool(row.translation_has_api_key)
        
        config["embedding"]["api_key"] = row.embedding_api_key or ""
        config["embedding"]["base_url"] = row.embedding_base_url or ""
        config["embedding"]["model_name"] = row.embedding_model_name or ""
        config["embedding"]["has_api_key"] = bool(row.embedding_has_api_key)
        
        config["vector"]["milvus_host"] = row.milvus_host or ""
        config["vector"]["milvus_port"] = row.milvus_port or ""
        config["vector"]["milvus_collection_name"] = row.milvus_collection_name or ""
        
        config["features"]["auto_summary"] = bool(row.auto_summary)
        config["features"]["auto_translation"] = bool(row.auto_translation)
        config["features"]["auto_title_translation"] = bool(row.auto_title_translation)
        config["features"]["auto_quality_scoring"] = bool(getattr(row, "auto_quality_scoring", True))
        config["features"]["translation_language"] = row.translation_language or "zh"
        
    return config

@router.put("/ai/user/config")
async def update_user_ai_config(payload: dict, session: AsyncSession = Depends(get_session), current_user = Depends(get_current_user)) -> dict:
    q = await session.execute(select(SAAIConfigRow).where(SAAIConfigRow.id == current_user.id))
    row = q.scalar_one_or_none()
    if not row:
        now = datetime.utcnow()
        row = SAAIConfigRow(id=current_user.id, created_at=now, updated_at=now)
        session.add(row)
        
    if "summary" in payload and isinstance(payload["summary"], dict):
        s = payload["summary"]
        if "api_key" in s:
            row.summary_api_key = s["api_key"]
            row.summary_has_api_key = bool(s["api_key"])
        if "base_url" in s: row.summary_base_url = s["base_url"]
        if "model_name" in s: row.summary_model_name = s["model_name"]
        
    if "translation" in payload and isinstance(payload["translation"], dict):
        t = payload["translation"]
        if "api_key" in t:
            row.translation_api_key = t["api_key"]
            row.translation_has_api_key = bool(t["api_key"])
        if "base_url" in t: row.translation_base_url = t["base_url"]
        if "model_name" in t: row.translation_model_name = t["model_name"]
        
    if "embedding" in payload and isinstance(payload["embedding"], dict):
        e = payload["embedding"]
        if "api_key" in e:
            row.embedding_api_key = e["api_key"]
            row.embedding_has_api_key = bool(e["api_key"])
        if "base_url" in e: row.embedding_base_url = e["base_url"]
        if "model_name" in e: row.embedding_model_name = e["model_name"]
        
    if "vector" in payload and isinstance(payload["vector"], dict):
        v = payload["vector"]
        if "milvus_host" in v: row.milvus_host = v["milvus_host"]
        if "milvus_port" in v: row.milvus_port = v["milvus_port"]
        if "milvus_collection_name" in v: row.milvus_collection_name = v["milvus_collection_name"]
        
    if "features" in payload and isinstance(payload["features"], dict):
        f = payload["features"]
        if "auto_summary" in f: row.auto_summary = bool(f["auto_summary"])
        if "auto_translation" in f: row.auto_translation = bool(f["auto_translation"])
        if "auto_title_translation" in f: row.auto_title_translation = bool(f["auto_title_translation"])
        if "auto_quality_scoring" in f: row.auto_quality_scoring = bool(f["auto_quality_scoring"])
        if "translation_language" in f: row.translation_language = f["translation_language"]
        
    row.updated_at = datetime.utcnow()
    await session.commit()
    return {"success": True}

@router.post("/ai/test")
async def test_ai(
    session: AsyncSession = Depends(get_session),
    current_user = Depends(get_current_user)
) -> dict:
    import time
    start = time.time()
    try:
        config = await get_user_ai_context(current_user.id, session)
        content = await _call_ai([
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": "Say OK"},
        ], max_tokens=30, config=config)
        elapsed = time.time() - start
        return {"success": True, "message": "ok", "response_time": elapsed, "output": content}
    except HTTPException as e:
        return {"success": False, "message": str(e.detail)}

@router.post("/ai/summary")
async def summarize(
    req: SummaryRequest, 
    session: AsyncSession = Depends(get_session),
    current_user = Depends(get_current_user)
) -> dict:
    config = await get_user_ai_context(current_user.id, session)
    lang = req.language or config["features"]["translation_language"]
    
    # Check if summary exists in DB
    q_ai = await session.execute(select(SAEntryAI).where(SAEntryAI.entry_id == req.entry_id))
    ai_entry = q_ai.scalar_one_or_none()
    
    if ai_entry and ai_entry.summary:
        try:
            data = json.loads(ai_entry.summary)
            if data.get("language") == lang:
                return {
                    "entry_id": req.entry_id,
                    "language": lang,
                    "summary": data.get("summary"),
                    "key_points": data.get("key_points")
                }
        except Exception:
            pass # Invalid JSON, regenerate

    q = await session.execute(select(SAEntry).where(SAEntry.id == req.entry_id))
    e = q.scalar_one_or_none()
    if not e:
        raise HTTPException(status_code=404)
        
    source = e.content or e.summary or e.title or ""
    source = source[:8000]
    prompt = (
        f"请用{lang}生成结构化摘要，并严格以 JSON 返回，字段如下：\n"
        "- summary: 一到两句中文总结\n"
        "- key_points: 至少 3 条关键信息，中文短句数组\n"
        "注意：只返回 JSON，对象且不包含额外文字、Markdown 或说明。\n\n"
        "文章内容：\n" + source
    )
    try:
        text = await _call_ai([
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": prompt},
        ], config=config)
    except Exception as e:
        print(f"Translation API error: {e}")
        raise HTTPException(status_code=500, detail=f"Translation failed: {str(e)}")

    json_text = text
    # Try to extract JSON from markdown code blocks
    match = re.search(r"```(?:json)?\s*(.*?)\s*```", text, re.DOTALL)
    if match:
        json_text = match.group(1)

    summary = text
    key_points: list[str] = []

    def parse_json_result(txt: str):
        try:
            return json.loads(txt)
        except Exception:
            return None

    parsed = parse_json_result(json_text)

    if parsed is None:
        # Fallback: try to find the first '{' and last '}'
        p1 = text.find('{')
        p2 = text.rfind('}')
        if p1 != -1 and p2 != -1:
             parsed = parse_json_result(text[p1:p2+1])

    if isinstance(parsed, dict):
        s = parsed.get("summary")
        if isinstance(s, str):
            summary = s
        kp = parsed.get("key_points")
        if isinstance(kp, list):
            key_points = [str(x) for x in kp if isinstance(x, (str, int, float))]
            
    # Save to DB
    if not ai_entry:
        ai_entry = SAEntryAI(entry_id=req.entry_id)
        session.add(ai_entry)
        
    save_data = {"summary": summary, "key_points": key_points, "language": lang}
    ai_entry.summary = json.dumps(save_data, ensure_ascii=False)
    ai_entry.updated_at = datetime.utcnow()
    await session.commit()

    return {"entry_id": req.entry_id, "language": lang, "summary": summary, "key_points": key_points}

@router.post("/ai/summarize")
async def summarize_alias(
    req: SummaryRequest, 
    session: AsyncSession = Depends(get_session),
    current_user = Depends(get_current_user)
) -> dict:
    return await summarize(req, session)

@router.post("/ai/translate")
async def translate(
    req: TranslationRequest, 
    session: AsyncSession = Depends(get_session),
    current_user = Depends(get_current_user)
) -> dict:
    config = await get_user_ai_context(current_user.id, session)
    q_ai = await session.execute(select(SAEntryAI).where(SAEntryAI.entry_id == req.entry_id))
    ai_entry = q_ai.scalar_one_or_none()
    lang = req.target_language
    
    if ai_entry and ai_entry.translation:
        try:
            data = json.loads(ai_entry.translation)
            field_data = data.get(req.field_type, {})
            if lang in field_data:
                return {
                    "entry_id": req.entry_id,
                    "field_type": req.field_type,
                    "target_language": lang,
                    "translated_text": field_data[lang],
                }
        except Exception:
            pass

    q = await session.execute(select(SAEntry).where(SAEntry.id == req.entry_id))
    e = q.scalar_one_or_none()
    if not e:
        raise HTTPException(status_code=404)
    # lang = req.target_language
    if req.field_type == "title":
        source = e.title or ""
        prompt = f"翻译成{lang}：\n\n" + source
    elif req.field_type == "content":
        source = (e.content or e.summary or "")[:8000]
        prompt = f"请将以下内容翻译为{lang}，保留格式：\n\n" + source
    else:
        raise HTTPException(status_code=400)
    try:
        text = await _call_ai([
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": prompt},
        ], config=config)
    except Exception as e:
        print(f"Translation API error: {e}")
        raise HTTPException(status_code=500, detail=f"Translation failed: {str(e)}")
    
    # Save to DB
    if not ai_entry:
        ai_entry = SAEntryAI(entry_id=req.entry_id)
        session.add(ai_entry)
        data = {}
    else:
        try:
            data = json.loads(ai_entry.translation) if ai_entry.translation else {}
        except Exception:
            data = {}
            
    if req.field_type not in data:
        data[req.field_type] = {}
    data[req.field_type][lang] = text
    
    ai_entry.translation = json.dumps(data, ensure_ascii=False)
    ai_entry.updated_at = datetime.utcnow()
    try:
        await session.commit()
    except Exception as e:
        await session.rollback()
        print(f"Error saving translation: {e}")
    
    return {
        "entry_id": req.entry_id,
        "field_type": req.field_type,
        "target_language": lang,
        "translated_text": text,
    }

@router.post("/ai/translate-title")
async def translate_title(
    req: SummaryRequest, 
    session: AsyncSession = Depends(get_session),
    current_user = Depends(get_current_user)
) -> dict:
    config = await get_user_ai_context(current_user.id, session)
    lang = req.language or config["features"]["translation_language"]
    
    q_ai = await session.execute(select(SAEntryAI).where(SAEntryAI.entry_id == req.entry_id))
    ai_entry = q_ai.scalar_one_or_none()
    
    if ai_entry and ai_entry.translation:
        try:
            data = json.loads(ai_entry.translation)
            if "title" in data and lang in data["title"]:
                 return {"entry_id": req.entry_id, "title": data["title"][lang], "language": lang}
        except Exception:
            pass

    q = await session.execute(select(SAEntry).where(SAEntry.id == req.entry_id))
    e = q.scalar_one_or_none()
    if not e:
        raise HTTPException(status_code=404)
        
    source = e.title or ""
    prompt = f"翻译标题为{lang}：\n\n" + source
    try:
        text = await _call_ai([
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": prompt},
        ], config=config)
    except Exception as e:
        print(f"Translation API error: {e}")
        raise HTTPException(status_code=500, detail=f"Translation failed: {str(e)}")
    
    # Save
    if not ai_entry:
        ai_entry = SAEntryAI(entry_id=req.entry_id)
        session.add(ai_entry)
        data = {}
    else:
        try:
            data = json.loads(ai_entry.translation) if ai_entry.translation else {}
        except Exception:
            data = {}
            
    if "title" not in data:
        data["title"] = {}
    data["title"][lang] = text
    
    ai_entry.translation = json.dumps(data, ensure_ascii=False)
    ai_entry.updated_at = datetime.utcnow()
    await session.commit()
    
    return {"entry_id": req.entry_id, "title": text, "language": lang}

@router.post("/ai/translate-text")
async def translate_text(
    req: TextTranslationRequest,
    current_user = Depends(get_current_user),
    session: AsyncSession = Depends(get_session)
) -> dict:
    """Translate arbitrary plain text (e.g. cluster topic names) without requiring entry_id"""
    config = await get_user_ai_context(current_user.id, session)
    lang = req.target_language or "zh"
    source = req.text.strip()
    if not source:
        return {"text": source, "translated": source, "language": lang}
    prompt = f"将以下文本翻译为{lang}，只输出翻译结果，不要解释：\n\n{source}"
    try:
        translated = await _call_ai([
            {"role": "system", "content": "You are a professional translator. Output only the translated text."},
            {"role": "user", "content": prompt},
        ], config=config)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Translation failed: {str(e)}")
    return {"text": source, "translated": translated.strip(), "language": lang}


@router.post("/ai/embedding")
async def get_embedding(
    req: EmbeddingRequest, 
    session: AsyncSession = Depends(get_session),
    current_user = Depends(get_current_user)
) -> dict:
    config = await get_user_ai_context(current_user.id, session)
    embedding = await _call_embedding(req.text, config=config)
    return {
        "text": req.text,
        "embedding": embedding,
        "model": config["embedding"]["model_name"],
        "success": bool(embedding)
    }

@router.post("/ai/research")
async def research(
    req: ResearchRequest,
    session: AsyncSession = Depends(get_session),
    current_user = Depends(get_current_user)
) -> dict:
    query = req.query.strip()
    if not query:
        raise HTTPException(status_code=400, detail="query cannot be empty")

    from .vector_store import vector_store

    hits = await vector_store.search(query, limit=max(4, min(req.limit * 2, 16)))
    entry_ids = []
    for hit in hits:
        entry_id = hit.get("entry_id")
        if entry_id and entry_id not in entry_ids:
            entry_ids.append(entry_id)

    if not entry_ids:
        return {
            "query": query,
            "title": f"{query} 研究",
            "summary": "未找到足够的相关文章，暂时无法生成研究结论。",
            "key_findings": [],
            "open_questions": ["尝试更具体的关键词，或等待更多相关文章被向量化。"],
            "references": [],
        }

    stmt = (
        select(SAEntry)
        .where(SAEntry.id.in_(entry_ids))
    )
    rows = (await session.execute(stmt)).scalars().all()
    entry_map = {entry.id: entry for entry in rows}

    references = []
    context_blocks = []
    ordered_refs = []
    for hit in hits:
        entry_id = hit.get("entry_id")
        if not entry_id or entry_id not in entry_map:
            continue
        entry = entry_map[entry_id]
        summary_text = (entry.summary or entry.content or "")[:700].replace("\n", " ")
        ordered_refs.append({
            "entry_id": entry.id,
            "title": entry.title or "无标题",
            "published_at": int(entry.published_at.timestamp()) if entry.published_at else 0,
            "score": hit.get("score") or 0.0,
            "feed_id": entry.feed_id,
        })
        references.append({
            "id": entry.id,
            "entry_id": entry.id,
            "title": entry.title or "无标题",
            "published_at": int(entry.published_at.timestamp()) if entry.published_at else 0,
            "score": hit.get("score") or 0.0,
            "feed_id": entry.feed_id,
        })
        context_blocks.append(
            f"[{len(context_blocks)+1}] 标题: {entry.title or '无标题'}\n"
            f"时间: {entry.published_at}\n"
            f"内容: {summary_text}\n"
        )
        if len(context_blocks) >= req.limit:
            break

    config = await get_user_ai_context(current_user.id, session)
    context_text = "\n".join(context_blocks)[:12000]
    prompt = (
        "你是一名研究分析助手。请基于提供的相关文章，为用户的问题生成一份结构化研究摘要。"
        "请严格返回 JSON，对象字段必须包含：\n"
        "- title: 研究标题，中文，20字以内\n"
        "- summary: 3到5句研究结论，中文\n"
        "- key_findings: 3到5条关键发现数组，中文短句\n"
        "- open_questions: 2到3条后续值得继续观察的问题数组，中文短句\n\n"
        f"用户问题：{query}\n\n"
        f"相关文章：\n{context_text}"
    )

    try:
        raw = await _call_ai([
            {"role": "system", "content": "你是一名严谨的研究分析助手，只返回 JSON。"},
            {"role": "user", "content": prompt},
        ], max_tokens=1200, config=config)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Research generation failed: {str(e)}")

    json_text = raw
    match = re.search(r"```(?:json)?\s*(.*?)\s*```", raw, re.DOTALL)
    if match:
        json_text = match.group(1)

    parsed = None
    try:
        parsed = json.loads(json_text)
    except Exception:
        p1 = raw.find("{")
        p2 = raw.rfind("}")
        if p1 != -1 and p2 != -1:
            try:
                parsed = json.loads(raw[p1:p2 + 1])
            except Exception:
                parsed = None

    if not isinstance(parsed, dict):
        parsed = {
            "title": f"{query} 研究",
            "summary": raw[:300] or "暂时无法生成结构化研究结论。",
            "key_findings": [],
            "open_questions": [],
        }

    return {
        "query": query,
        "title": parsed.get("title") or f"{query} 研究",
        "summary": parsed.get("summary") or "暂时无法生成研究结论。",
        "key_findings": [str(item) for item in parsed.get("key_findings", []) if str(item).strip()],
        "open_questions": [str(item) for item in parsed.get("open_questions", []) if str(item).strip()],
        "references": references[:req.limit],
    }

class SynthesisRequest(BaseModel):
    entry_ids: List[str]

@router.post("/ai/synthesis")
async def generate_synthesis(
    req: SynthesisRequest, 
    session: AsyncSession = Depends(get_session),
    current_user = Depends(get_current_user)
):
    config = await get_user_ai_context(current_user.id, session)
    if not req.entry_ids:
        raise HTTPException(status_code=400, detail="entry_ids cannot be empty")
        
    stmt = select(SAEntry).where(SAEntry.id.in_(req.entry_ids))
    result = await session.execute(stmt)
    entries = result.scalars().all()
    
    if not entries:
        raise HTTPException(status_code=404, detail="No entries found")
        
    # Prepare text for AI and references
    references = []
    entries_text = ""
    
    for idx, e in enumerate(entries, 1):
        references.append({
            "index": idx,
            "id": str(e.id),
            "title": e.title or "无标题",
            "url": e.url or "",
            "published_at": e.published_at.isoformat() + "Z" if e.published_at else None
        })
        
        content = e.summary or e.content or ""
        # Limit content per entry to avoid exceeding token limits
        content = content[:800].replace('\n', ' ') 
        
        entries_text += f"[{idx}] 标题: {e.title}\n内容: {content}\n\n"
        
    # Limit total text
    entries_text = entries_text[:15000]
    
    prompt = (
        "请作为一名专业的新闻编辑和分析师，基于以下提供的一组新闻文章，写一篇结构清晰、深入的综合分析报告。\n"
        "要求：\n"
        "1. 使用 Markdown 格式排版，包含一个吸引人的大标题（用一级标题 #）。\n"
        "2. 第一段是整体事件或话题的总结（导语）。\n"
        "3. 随后按照不同的主题或逻辑顺序划分章节（使用二级标题 ##）。\n"
        "4. 在叙述事实或引用观点时，必须在句子末尾或相关词语后使用Markdown链接格式的数字索引来进行引用，例如 [[1]](ref:1)、[[2]](ref:2) 或 [[1]](ref:1)[[3]](ref:3)。\n"
        "5. 语言要求流畅、专业，避免机械地逐篇罗列，要融会贯通。\n\n"
        "以下是文章内容：\n\n" + entries_text
    )
    
    async def event_generator():
        # First send the references
        yield f"data: {json.dumps({'type': 'references', 'data': references})}\n\n"
        
        # Then stream the markdown
        async for chunk in _call_ai_stream([
            {"role": "system", "content": "你是一位专业的新闻分析师和专栏作家，擅长将多篇相关报道整合为一篇深入的分析文章。"},
            {"role": "user", "content": prompt},
        ], max_tokens=2048, config=config):
            yield chunk
            
        yield f"data: {json.dumps({'type': 'done'})}\n\n"

    return StreamingResponse(event_generator(), media_type="text/event-stream")

async def score_article_quality(title: str, content: str) -> int:
    """
    Score the article quality from 0 to 100 based on title and content.
    Returns an integer score.
    """
    if not content:
        return 0
        
    prompt = (
        "You are an AI trained to evaluate the quality and signal-to-noise ratio of articles.\n"
        "Score the following article on a scale of 0 to 100, where 100 is the highest quality.\n"
        "Criteria:\n"
        "- High score (80-100): In-depth analysis, original research, comprehensive news reports.\n"
        "- Medium score (40-79): Standard news, short updates, tool releases.\n"
        "- Low score (0-39): Pure marketing, spam, clickbait, extremely short snippets without context.\n\n"
        "Return ONLY the integer score, nothing else.\n\n"
        f"Title: {title}\n\n"
        f"Content (first 2000 chars): {content[:2000]}"
    )
    
    try:
        text = await _call_ai([
            {"role": "system", "content": "You are a strict content quality evaluator. Output only a number between 0 and 100."},
            {"role": "user", "content": prompt},
        ], max_tokens=10)
        
        # Extract numbers from response
        match = re.search(r'\d+', text)
        if match:
            score = int(match.group(0))
            return min(max(score, 0), 100)
    except Exception as e:
        print(f"Failed to score article quality: {e}")
        
    # Fallback heuristic scoring
    score = 0
    word_count = len(content)
    if word_count > 1000:
        score += 50
    elif word_count > 300:
        score += 30
    elif word_count > 50:
        score += 10
        
    if title and len(title) > 10:
        score += 10
        
    return min(score, 100)

class DailyDigestRequest(BaseModel):
    entry_ids: List[str]

@router.post("/ai/daily-digest")
async def generate_daily_digest(
    req: DailyDigestRequest, 
    session: AsyncSession = Depends(get_session),
    current_user = Depends(get_current_user)
):
    if not req.entry_ids:
        raise HTTPException(status_code=400, detail="entry_ids cannot be empty")
        
    stmt = select(SAEntry).where(SAEntry.id.in_(req.entry_ids))
    result = await session.execute(stmt)
    entries = result.scalars().all()
    
    if not entries:
        raise HTTPException(status_code=404, detail="No entries found")
        
    references = []
    entries_text = ""
    
    for idx, e in enumerate(entries, 1):
        references.append({
            "index": idx,
            "id": str(e.id),
            "title": e.title or "无标题",
            "url": e.url or "",
            "published_at": e.published_at.isoformat() + "Z" if e.published_at else None
        })
        
        content = e.summary or e.content or ""
        content = content[:800].replace('\n', ' ') 
        entries_text += f"[{idx}] 标题: {e.title}\n内容: {content}\n\n"
        
    entries_text = entries_text[:15000]
    
    prompt = (
        "You are an AI news curator. Generate a structured daily digest from the provided feed content.\n\n"
        "## Output Format (Markdown):\n"
        "# ☀️ AI 每日简报 | 今天\n\n"
        "## 🔥 重大事件 (Important)\n"
        "- [重大事件1标题] — 背景与影响（限50字以内）\n"
        "- [重大事件2标题] — 背景与影响（限50字以内）\n\n"
        "## 📰 信息源高光 (Feed Highlights)\n"
        "- **[提取的来源或作者]** - 简短总结该条内容的核心信息，在句子末尾必须使用Markdown链接格式的数字索引来进行引用，例如 [[1]](ref:1)。\n"
        "- **[提取的来源或作者]** - 简短总结该条内容的核心信息 [[2]](ref:2)。\n\n"
        "## 💡 核心洞察 (Key Insights)\n"
        "- 从今天所有信息中提炼出的1-2个深度洞察。\n\n"
        "## Rules:\n"
        "1. Important section: Only truly significant news (breakthroughs, major events).\n"
        "2. Feed Highlights: Curate 8-12 most interesting posts.\n"
        "3. Language: Chinese (Simplified).\n"
        "4. ALWAYS use the citation format `[[index]](ref:index)` to link back to the source.\n\n"
        "Feed Content:\n" + entries_text
    )
    
    async def event_generator():
        yield f"data: {json.dumps({'type': 'references', 'data': references})}\n\n"
        
        full_text = ""
        async for chunk in _call_ai_stream([
            {"role": "system", "content": "You are an expert AI news editor creating high-quality daily digests."},
            {"role": "user", "content": prompt},
        ], max_tokens=2048):
            yield chunk
            # Try to extract content to save
            if chunk.startswith("data: "):
                try:
                    data = json.loads(chunk[6:])
                    if data.get("type") == "chunk":
                        full_text += data.get("content", "")
                except Exception:
                    pass
                    
        # Save digest
        try:
            today_str = datetime.utcnow().strftime("%Y-%m-%d")
            # delete old
            await session.execute(
                delete(SAAIDailyDigest).where(
                    SAAIDailyDigest.user_id == current_user.id,
                    SAAIDailyDigest.date_str == today_str
                )
            )
            
            new_digest = SAAIDailyDigest(
                id=str(uuid4()),
                user_id=current_user.id,
                date_str=today_str,
                content=full_text,
                references=json.dumps(references, ensure_ascii=False)
            )
            session.add(new_digest)
            await session.commit()
        except Exception as e:
            print(f"Failed to save daily digest: {e}")
            await session.rollback()
            
        yield f"data: {json.dumps({'type': 'done'})}\n\n"

    return StreamingResponse(event_generator(), media_type="text/event-stream")

@router.get("/ai/daily-digest/today")
async def get_today_digest(
    session: AsyncSession = Depends(get_session),
    current_user = Depends(get_current_user)
):
    today_str = datetime.utcnow().strftime("%Y-%m-%d")
    q = await session.execute(
        select(SAAIDailyDigest).where(
            SAAIDailyDigest.user_id == current_user.id,
            SAAIDailyDigest.date_str == today_str
        )
    )
    digest = q.scalar_one_or_none()
    if not digest:
        return {"exists": False}
        
    try:
        references = json.loads(digest.references)
    except Exception:
        references = []
        
    return {
        "exists": True,
        "content": digest.content,
        "references": references,
        "created_at": digest.created_at.isoformat() + "Z"
    }

class DeepDiveRequest(BaseModel):
    entry_id: str

@router.post("/ai/deep-dive")
async def generate_deep_dive(
    req: DeepDiveRequest, 
    session: AsyncSession = Depends(get_session),
    current_user = Depends(get_current_user)
):
    stmt = select(SAEntry).where(SAEntry.id == req.entry_id)
    result = await session.execute(stmt)
    entry = result.scalar_one_or_none()
    
    if not entry:
        raise HTTPException(status_code=404, detail="Entry not found")
        
    content = entry.content or entry.summary or ""
    content = content[:10000] # Provide more content for deep dive
    
    prompt = (
        "You are an expert analyst. Provide a deep dive analysis of the following article.\n\n"
        "## Output Format (Markdown):\n"
        "## 🔍 核心洞察 (Core Insights)\n"
        "- [洞察1]\n"
        "- [洞察2]\n\n"
        "## 🧠 深度解析 (Analysis & Context)\n"
        "[详细分析文章的背景、行业影响、潜在关联等]\n\n"
        "## 📌 一句话总结 (Takeaway)\n"
        "[一句话精辟总结]\n\n"
        "Article Title: " + (entry.title or "Untitled") + "\n\n"
        "Article Content:\n" + content
    )
    
    async def event_generator():
        async for chunk in _call_ai_stream([
            {"role": "system", "content": "You are a professional analyst providing deep dives on tech, news, and various topics."},
            {"role": "user", "content": prompt},
        ], max_tokens=1500):
            yield chunk
        yield f"data: {json.dumps({'type': 'done'})}\n\n"

    return StreamingResponse(event_generator(), media_type="text/event-stream")
