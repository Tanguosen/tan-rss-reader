from fastapi import APIRouter, HTTPException, Query
from urllib.parse import urlparse
import asyncio
import httpx
import time
import urllib.robotparser
from typing import Any, Optional

router = APIRouter()

_ROBOTS_CACHE: dict[str, dict[str, Any]] = {}
_ROBOTS_CACHE_LOCK = asyncio.Lock()
_HTML_CACHE: dict[str, dict[str, Any]] = {}
_HTML_CACHE_LOCK = asyncio.Lock()


def _now_ts() -> float:
    return time.time()


def _robots_cache_key(p: Any) -> str:
    return f"{p.scheme}://{p.netloc}"


async def _get_robots_parser(
    client: httpx.AsyncClient,
    base: str,
    ua: str,
    ttl_seconds: int,
) -> urllib.robotparser.RobotFileParser:
    async with _ROBOTS_CACHE_LOCK:
        cached = _ROBOTS_CACHE.get(base)
        if cached and (_now_ts() - cached["ts"]) < ttl_seconds:
            return cached["parser"]

    robots_url = f"{base}/robots.txt"
    parser = urllib.robotparser.RobotFileParser()
    parser.set_url(robots_url)

    try:
        resp = await client.get(robots_url)
        if resp.status_code == 200:
            parser.parse(resp.text.splitlines())
        else:
            parser.parse([])
    except httpx.RequestError:
        parser.parse([])

    async with _ROBOTS_CACHE_LOCK:
        _ROBOTS_CACHE[base] = {"parser": parser, "ts": _now_ts()}

    return parser


async def _assert_robots_allowed(
    client: httpx.AsyncClient,
    url: str,
    ua: str,
    robots_ttl_seconds: int,
) -> None:
    p = urlparse(url)
    base = _robots_cache_key(p)
    parser = await _get_robots_parser(client=client, base=base, ua=ua, ttl_seconds=robots_ttl_seconds)
    allowed = parser.can_fetch(ua, url)
    if not allowed:
        raise HTTPException(status_code=403, detail="Blocked by robots.txt")


def _build_headers(
    ua: str,
    lang: str,
    referer: Optional[str],
    cookie: Optional[str],
) -> dict[str, str]:
    headers = {
        "User-Agent": ua,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
        "Accept-Language": lang,
        "Cache-Control": "no-cache",
        "Pragma": "no-cache",
        "Sec-Fetch-Dest": "document",
        "Sec-Fetch-Mode": "navigate",
        "Sec-Fetch-Site": "none",
        "Upgrade-Insecure-Requests": "1",
    }
    if referer:
        headers["Referer"] = referer
    if cookie:
        headers["Cookie"] = cookie
    return headers


@router.get("/proxy/fetch")
async def proxy_fetch(
    url: str,
    ua: str = Query(default="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36"),
    lang: str = Query(default="en-US,en;q=0.9"),
    referer: Optional[str] = Query(default=None),
    cookie: Optional[str] = Query(default=None),
    force: bool = Query(default=False),
    respect_robots: bool = Query(default=True),
) -> dict:
    p = urlparse(url)
    if p.scheme not in ("http", "https"):
        raise HTTPException(status_code=400)
    headers = _build_headers(ua=ua, lang=lang, referer=referer, cookie=cookie)

    cache_ttl_seconds = 6 * 60 * 60
    if not force:
        async with _HTML_CACHE_LOCK:
            cached = _HTML_CACHE.get(url)
            if cached and (_now_ts() - cached["ts"]) < cache_ttl_seconds:
                return {
                    "content": cached["content"],
                    "final_url": cached["final_url"],
                    "from_cache": True,
                    "fetched_at": cached["ts"],
                }
    try:
        async with httpx.AsyncClient(timeout=30, headers=headers, follow_redirects=True) as client:
            if respect_robots:
                await _assert_robots_allowed(client=client, url=url, ua=ua, robots_ttl_seconds=24 * 60 * 60)
            resp = await client.get(url)
    except httpx.RequestError:
        raise HTTPException(status_code=502)
    if resp.status_code >= 400:
        raise HTTPException(status_code=resp.status_code)
    content_type = resp.headers.get("content-type", "")
    if "text/html" not in content_type and "application/xhtml+xml" not in content_type:
        raise HTTPException(status_code=415, detail="Unsupported content-type")
    final_url = str(resp.url)

    ts = _now_ts()
    async with _HTML_CACHE_LOCK:
        _HTML_CACHE[url] = {"content": resp.text, "final_url": final_url, "ts": ts}

    return {"content": resp.text, "final_url": final_url, "from_cache": False, "fetched_at": ts}
