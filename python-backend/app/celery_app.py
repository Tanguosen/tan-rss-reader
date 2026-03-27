import os
from celery import Celery
from .config import env_settings

REDIS_URL = env_settings.redis_url or os.getenv("REDIS_URL", "redis://localhost:6379/0")

celery_app = Celery(
    "tan_rss_tasks",
    broker=REDIS_URL,
    backend=REDIS_URL,
    include=['app.tasks.ai_tasks']
)

celery_app.conf.update(
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    timezone='UTC',
    enable_utc=True,
    task_track_started=True,
    task_time_limit=3600,
)
