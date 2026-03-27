from pydantic import BaseModel
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional

class AppSettings(BaseModel):
    fetch_interval_minutes: int = 15
    items_per_page: int = 50
    enable_date_filter: bool = True
    default_date_range: str = "30d"
    time_field: str = "inserted_at"
    show_entry_summary: bool = True
    max_auto_title_translations: int = 30
    translation_display_mode: str = "replace"
    rsshub_url: str = "https://rsshub.app"
    branding_toggle: bool = False

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

class VectorConfig(BaseModel):
    milvus_host: str = "localhost"
    milvus_port: str = "19530"
    milvus_collection_name: str = "rss_entries"

class AIConfig(BaseModel):
    summary: AIServiceConfig
    translation: AIServiceConfig
    embedding: AIServiceConfig
    features: AIFeatureConfig
    vector: VectorConfig

class EnvSettings(BaseSettings):
    """
    环境配置管理，自动从 .env 文件或环境变量加载
    用于统一管理外部依赖服务的地址和凭证
    """
    # Database
    db_url: Optional[str] = None
    
    # Redis / Celery
    redis_url: str = "redis://localhost:6379/0"
    
    # Vector Database (Milvus)
    milvus_host: str = "10.110.3.25"
    milvus_port: str = "19530"
    milvus_collection: str = "rss_entries"
    
    # Default AI Services (Aurora AI)
    aurora_ai_api_key: str = ""
    aurora_ai_base_url: str = "http://10.110.3.61:9997/v1"
    aurora_ai_model: str = "qwen3"
    aurora_ai_embedding_model: str = "Qwen3-Embedding-0.6B"
    
    # Backend Server
    host: str = "0.0.0.0"
    port: int = 27496

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

env_settings = EnvSettings()
SETTINGS = AppSettings()
