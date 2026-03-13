from fastapi import APIRouter, Depends, HTTPException, Body
from pydantic import BaseModel
from typing import Optional, List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime
import json
import os
import httpx
import re

from ..db import SessionLocal
from ..models import AIConfigRow as SAAIConfigRow, Entry as SAEntry, EntryAI as SAEntryAI

router = APIRouter()

async def get_session() -> AsyncSession:
    async with SessionLocal() as session:
        yield session

def _env(key: str, default: str = "") -> str:
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

class EmbeddingRequest(BaseModel):
    text: str

async def _call_ai(messages: list[dict], max_tokens: int = 1024) -> str:
    key = AI_CFG["summary"]["api_key"] or AI_CFG["translation"]["api_key"]
    base = AI_CFG["summary"]["base_url"]
    model = AI_CFG["summary"]["model_name"]
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


async def _call_embedding(text: str) -> List[float]:
    key = AI_CFG["embedding"]["api_key"] or AI_CFG["summary"]["api_key"]
    base = AI_CFG["embedding"]["base_url"]
    model = AI_CFG["embedding"]["model_name"]
    
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
        AI_CFG["features"]["translation_language"] = arow.translation_language or AI_CFG["features"]["translation_language"]

@router.get("/ai/config")
async def get_ai_config(session: AsyncSession = Depends(get_session)) -> dict:
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
    AI_CFG["features"]["translation_language"] = row.translation_language or AI_CFG["features"]["translation_language"]
    return AI_CFG

@router.post("/ai/config")
@router.patch("/ai/config")
async def update_ai_config(payload: dict, session: AsyncSession = Depends(get_session)) -> dict:
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
        if "translation_language" in f:
            AI_CFG["features"]["translation_language"] = f["translation_language"]
            row.translation_language = f["translation_language"]
    row.updated_at = datetime.utcnow()
    await session.commit()
    return {"success": True, "config": AI_CFG}

@router.post("/ai/test")
async def test_ai() -> dict:
    import time
    start = time.time()
    try:
        content = await _call_ai([
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": "Say OK"},
        ], max_tokens=30)
        elapsed = time.time() - start
        return {"success": True, "message": "ok", "response_time": elapsed, "output": content}
    except HTTPException as e:
        return {"success": False, "message": str(e.status_code)}

@router.post("/ai/summary")
async def summarize(req: SummaryRequest, session: AsyncSession = Depends(get_session)) -> dict:
    lang = req.language or AI_CFG["features"]["translation_language"]
    
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
    text = await _call_ai([
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": prompt},
    ])

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
async def summarize_alias(req: SummaryRequest, session: AsyncSession = Depends(get_session)) -> dict:
    return await summarize(req, session)

@router.post("/ai/translate")
async def translate(req: TranslationRequest, session: AsyncSession = Depends(get_session)) -> dict:
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
    text = await _call_ai([
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": prompt},
    ])
    
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
    await session.commit()
    
    return {
        "entry_id": req.entry_id,
        "field_type": req.field_type,
        "target_language": lang,
        "translated_text": text,
    }

@router.post("/ai/translate-title")
async def translate_title(req: SummaryRequest, session: AsyncSession = Depends(get_session)) -> dict:
    lang = req.language or AI_CFG["features"]["translation_language"]
    
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
    text = await _call_ai([
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": prompt},
    ])
    
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

@router.post("/ai/embedding")
async def get_embedding(req: EmbeddingRequest, session: AsyncSession = Depends(get_session)) -> dict:
    embedding = await _call_embedding(req.text)
    return {
        "text": req.text,
        "embedding": embedding,
        "model": AI_CFG["embedding"]["model_name"],
        "success": bool(embedding)
    }

