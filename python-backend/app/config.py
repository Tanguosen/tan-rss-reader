from pydantic import BaseModel

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

SETTINGS = AppSettings()
