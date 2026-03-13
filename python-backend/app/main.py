from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select

from .db import engine, Base as SABase, SessionLocal
from .models import AppSettingsRow as SAAppSettingsRow
from .config import SETTINGS
from .handlers.icons import router as icons_router
from .handlers.tasks import router as tasks_router, TASK_SCHEDULER
from .handlers.opml import router as opml_router
from .handlers.settings import router as settings_router
from .handlers.ai import router as ai_router, init_ai_config
from .handlers.rsshub import router as rsshub_router
from .handlers.feeds import router as feeds_router
from .handlers.entries import router as entries_router
from .handlers.proxy import router as proxy_router
from .handlers.channels import router as channels_router
from .handlers.auth import router as auth_router
from .handlers.users import router as users_router
from .handlers.subscriptions import router as subs_router
from .handlers.categories import router as categories_router
from .handlers.tags import router as tags_router
from .handlers.vector import router as vector_router

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Use shared SETTINGS from app.config

@app.get("/")
def root() -> str:
    return "RSS Backend API is running!"

app.include_router(icons_router, prefix="/api")
app.include_router(tasks_router, prefix="/api")
app.include_router(opml_router, prefix="/api")
app.include_router(settings_router, prefix="/api")
app.include_router(ai_router, prefix="/api")
app.include_router(rsshub_router, prefix="/api")
app.include_router(feeds_router, prefix="/api")
app.include_router(entries_router, prefix="/api")
app.include_router(proxy_router, prefix="/api")
app.include_router(channels_router, prefix="/api")
app.include_router(auth_router, prefix="/api")
app.include_router(users_router, prefix="/api")
app.include_router(subs_router, prefix="/api")
app.include_router(categories_router, prefix="/api")
app.include_router(tags_router, prefix="/api")
app.include_router(vector_router, prefix="/api")

@app.on_event("startup")
async def on_startup():
    async with engine.begin() as conn:
        await conn.run_sync(SABase.metadata.create_all)
        try:
            await conn.exec_driver_sql("ALTER TABLE app_settings ADD COLUMN branding_toggle BOOLEAN DEFAULT 0")
        except Exception:
            pass
    session = SessionLocal()
    try:
        q1 = await session.execute(select(SAAppSettingsRow).where(SAAppSettingsRow.id == "default"))
        srow = q1.scalar_one_or_none()
        if srow:
            SETTINGS.fetch_interval_minutes = srow.fetch_interval_minutes
            SETTINGS.items_per_page = srow.items_per_page
            SETTINGS.enable_date_filter = bool(srow.enable_date_filter)
            SETTINGS.default_date_range = srow.default_date_range
            SETTINGS.time_field = srow.time_field
            SETTINGS.show_entry_summary = bool(srow.show_entry_summary)
            SETTINGS.max_auto_title_translations = srow.max_auto_title_translations
            SETTINGS.translation_display_mode = srow.translation_display_mode
            SETTINGS.rsshub_url = srow.rsshub_url
            SETTINGS.branding_toggle = bool(getattr(srow, "branding_toggle", False))
        await init_ai_config(session)
        TASK_SCHEDULER.start_scheduler()
    finally:
        await session.close()

@app.on_event("shutdown")
async def on_shutdown():
    TASK_SCHEDULER.stop_scheduler()
