from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from datetime import datetime
from typing import Optional
from ..db import SessionLocal
from ..models import Feed as SAFeed, SiteIcon as SASiteIcon
from ..services.rss_fetcher import fetch_feed as rss_fetch
from ..config import SETTINGS

try:
    from apscheduler.schedulers.asyncio import AsyncIOScheduler
    from apscheduler.triggers.interval import IntervalTrigger
    _aps_available = True
except Exception:
    _aps_available = False
    AsyncIOScheduler = None
    IntervalTrigger = None

router = APIRouter()

async def get_session() -> AsyncSession:
    async with SessionLocal() as session:
        yield session

def health_payload() -> dict:
    return {
        "status": "healthy",
        "database": "connected",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "uptime": "N/A",
    }

class TaskExecutionResult(BaseModel):
    task_id: str
    task_name: str
    started_at: str
    completed_at: Optional[str] = None
    success: bool
    message: str
    duration_ms: Optional[int] = None

class ScheduledTask(BaseModel):
    id: str
    name: str
    task_type: str
    cron_expression: Optional[str] = None
    enabled: bool = True
    last_run: Optional[str] = None
    next_run: Optional[str] = None
    run_count: int = 0
    success_count: int = 0
    error_count: int = 0
    last_error: Optional[str] = None

class TaskScheduler:
    def __init__(self):
        self.tasks: dict[str, ScheduledTask] = {
            "feed-refresh": ScheduledTask(id="feed-refresh", name="RSS Feed Refresh", task_type="FeedRefresh"),
            "icon-cleanup": ScheduledTask(id="icon-cleanup", name="Icon Cleanup", task_type="IconCleanup"),
            "health-check": ScheduledTask(id="health-check", name="Health Check", task_type="HealthCheck"),
        }
        self.history: dict[str, list[TaskExecutionResult]] = {tid: [] for tid in self.tasks.keys()}
        self.scheduler = None

    def get_tasks(self) -> list[ScheduledTask]:
        return list(self.tasks.values())

    def toggle_task(self, task_id: str, enabled: bool) -> None:
        t = self.tasks.get(task_id)
        if not t:
            raise KeyError("task not found")
        t.enabled = enabled

    async def refresh_all_feeds(self, session: AsyncSession) -> TaskExecutionResult:
        import time
        start_ts = time.time()
        started_at = datetime.utcnow().isoformat() + "Z"
        rows = (await session.execute(select(SAFeed).where((SAFeed.error_count == None) | (SAFeed.error_count < 5)))).scalars().all()
        ok = 0
        err = 0
        message = ""
        for f in rows:
            try:
                await rss_fetch(session, f.id)
                ok += 1
            except Exception as e:
                err += 1
                message = str(e)
                continue
        message = f"Refreshed {len(rows)} feeds, {ok} successful, {err} failed"
        success = err == 0
        completed_at = datetime.utcnow().isoformat() + "Z"
        duration_ms = int((time.time() - start_ts) * 1000)
        return TaskExecutionResult(task_id="feed-refresh", task_name="RSS Feed Refresh", started_at=started_at, completed_at=completed_at, success=success, message=message, duration_ms=duration_ms)

    def start_scheduler(self) -> dict:
        if not _aps_available:
            return {"success": False, "running": False, "message": "apscheduler not installed"}
        if self.scheduler is None:
            self.scheduler = AsyncIOScheduler()
        minutes = max(1, int(getattr(SETTINGS, "fetch_interval_minutes", 15) or 15))
        async def _wrap_job():
            async with SessionLocal() as s:
                try:
                    await self.refresh_all_feeds(s)
                except Exception:
                    pass
        self.scheduler.add_job(_wrap_job, IntervalTrigger(minutes=minutes), id="feed-refresh-job", replace_existing=True)
        if not self.scheduler.running:
            self.scheduler.start()
        return {"success": True, "running": True, "interval_minutes": minutes}

    def stop_scheduler(self) -> dict:
        if self.scheduler and self.scheduler.running:
            self.scheduler.remove_all_jobs()
            self.scheduler.shutdown(wait=False)
        return {"success": True, "running": False}

    async def execute_task_manually(self, task_id: str, session: AsyncSession) -> TaskExecutionResult:
        t = self.tasks.get(task_id)
        if not t:
            raise KeyError("task not found")
        import time
        start_ts = time.time()
        started_at = datetime.utcnow().isoformat() + "Z"
        message = ""
        success = True
        if task_id == "feed-refresh":
            result = await self.refresh_all_feeds(session)
            message = result.message
            success = result.success
        elif task_id == "icon-cleanup":
            await session.execute(delete(SASiteIcon).where(SASiteIcon.is_active == False))
            await session.commit()
            message = "Icon cleanup done"
            success = True
        elif task_id == "health-check":
            payload = health_payload()
            message = f"Health ok: {payload.get('status')}"
            success = True
        else:
            message = "Unknown task"
            success = False
        completed_at = datetime.utcnow().isoformat() + "Z"
        duration_ms = int((time.time() - start_ts) * 1000)
        t.run_count += 1
        t.last_run = completed_at
        if success:
            t.success_count += 1
            t.last_error = None
        else:
            t.error_count += 1
            t.last_error = message
        result = TaskExecutionResult(
            task_id=task_id,
            task_name=t.name,
            started_at=started_at,
            completed_at=completed_at,
            success=success,
            message=message,
            duration_ms=duration_ms,
        )
        self.history.setdefault(task_id, []).insert(0, result)
        self.history[task_id] = self.history[task_id][:50]
        return result

TASK_SCHEDULER = TaskScheduler()

@router.get("/tasks")
async def get_tasks() -> dict:
    return {"success": True, "tasks": [t.model_dump() for t in TASK_SCHEDULER.get_tasks()]}

@router.get("/tasks/{task_id}/history")
async def get_task_history(task_id: str) -> dict:
    hist = TASK_SCHEDULER.history.get(task_id, [])
    return {"success": True, "task_id": task_id, "history": [h.model_dump() for h in hist]}

@router.post("/tasks/{task_id}")
async def execute_task(task_id: str, session: AsyncSession = Depends(get_session)) -> dict:
    try:
        res = await TASK_SCHEDULER.execute_task_manually(task_id, session)
        return {"success": res.success, "message": res.message, "result": res.model_dump()}
    except KeyError:
        raise HTTPException(status_code=404)

class ToggleTaskRequest(BaseModel):
    enabled: bool

@router.post("/tasks/{task_id}/toggle")
async def toggle_task(task_id: str, payload: ToggleTaskRequest) -> dict:
    try:
        TASK_SCHEDULER.toggle_task(task_id, payload.enabled)
        return {"success": True, "task_id": task_id, "enabled": payload.enabled}
    except KeyError:
        raise HTTPException(status_code=404)

@router.get("/tasks/scheduler/status")
async def scheduler_status() -> dict:
    running = bool(TASK_SCHEDULER.scheduler and getattr(TASK_SCHEDULER.scheduler, "running", False))
    return {"success": True, "running": running, "available": _aps_available}

@router.post("/tasks/scheduler/start")
async def scheduler_start() -> dict:
    return TASK_SCHEDULER.start_scheduler()

@router.post("/tasks/scheduler/stop")
async def scheduler_stop() -> dict:
    return TASK_SCHEDULER.stop_scheduler()

@router.get("/health")
async def get_health_status() -> dict:
    return health_payload()
