from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import String, Integer, DateTime, Text, Boolean, ForeignKey
from datetime import datetime
from typing import Optional
from .db import Base

class Feed(Base):
    __tablename__ = "feeds"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    title: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    url: Mapped[str] = mapped_column(String, nullable=False, unique=True)
    category: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    favicon: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    update_interval: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    last_updated: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    last_status: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    error_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class Entry(Base):
    __tablename__ = "entries"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    feed_id: Mapped[str] = mapped_column(String, ForeignKey("feeds.id"), index=True)
    title: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    url: Mapped[str] = mapped_column(String, nullable=False)
    author: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    content: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    summary: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    published_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False)
    is_starred: Mapped[bool] = mapped_column(Boolean, default=False)
    reading_time: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    word_count: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

class SiteIcon(Base):
    __tablename__ = "site_icons"
    domain: Mapped[str] = mapped_column(String, primary_key=True)
    mime: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    data_base64: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    source_url: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    last_fetched: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    error_count: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class EntryAI(Base):
    __tablename__ = "entry_ai"
    entry_id: Mapped[str] = mapped_column(String, ForeignKey("entries.id"), primary_key=True)
    summary: Mapped[Optional[str]] = mapped_column(Text, nullable=True)  # JSON
    translation: Mapped[Optional[str]] = mapped_column(Text, nullable=True)  # JSON
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class RSSHubConfig(Base):
    __tablename__ = "rsshub_configs"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    url: Mapped[str] = mapped_column(String, unique=True)
    priority: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=False)
    last_tested: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    response_time: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    error_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class AppSettingsRow(Base):
    __tablename__ = "app_settings"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    fetch_interval_minutes: Mapped[int] = mapped_column(Integer, default=15)
    items_per_page: Mapped[int] = mapped_column(Integer, default=50)
    enable_date_filter: Mapped[bool] = mapped_column(Boolean, default=True)
    default_date_range: Mapped[str] = mapped_column(String, default="30d")
    time_field: Mapped[str] = mapped_column(String, default="inserted_at")
    show_entry_summary: Mapped[bool] = mapped_column(Boolean, default=True)
    max_auto_title_translations: Mapped[int] = mapped_column(Integer, default=30)
    translation_display_mode: Mapped[str] = mapped_column(String, default="replace")
    branding_toggle: Mapped[bool] = mapped_column(Boolean, default=False)
    rsshub_url: Mapped[str] = mapped_column(String, default="https://rsshub.app")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class AIConfigRow(Base):
    __tablename__ = "ai_configs"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    summary_api_key: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    summary_base_url: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    summary_model_name: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    summary_has_api_key: Mapped[bool] = mapped_column(Boolean, default=False)
    translation_api_key: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    translation_base_url: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    translation_model_name: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    translation_has_api_key: Mapped[bool] = mapped_column(Boolean, default=False)
    embedding_api_key: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    embedding_base_url: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    embedding_model_name: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    embedding_has_api_key: Mapped[bool] = mapped_column(Boolean, default=False)
    
    milvus_host: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    milvus_port: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    milvus_collection_name: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    
    auto_summary: Mapped[bool] = mapped_column(Boolean, default=False)
    auto_translation: Mapped[bool] = mapped_column(Boolean, default=False)
    auto_title_translation: Mapped[bool] = mapped_column(Boolean, default=False)
    translation_language: Mapped[str] = mapped_column(String, default="zh")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class Channel(Base):
    __tablename__ = "channels"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[str] = mapped_column(String, unique=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    cover_url: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    is_public: Mapped[bool] = mapped_column(Boolean, default=True)
    owner_id: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    kind: Mapped[str] = mapped_column(String, default="topic")
    category_id: Mapped[Optional[str]] = mapped_column(String, ForeignKey("categories.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class Category(Base):
    __tablename__ = "categories"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[str] = mapped_column(String, unique=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class Tag(Base):
    __tablename__ = "tags"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[str] = mapped_column(String, unique=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class ChannelTag(Base):
    __tablename__ = "channel_tags"
    channel_id: Mapped[str] = mapped_column(String, ForeignKey("channels.id"), primary_key=True)
    tag_id: Mapped[str] = mapped_column(String, ForeignKey("tags.id"), primary_key=True)

class ChannelSource(Base):
    __tablename__ = "channel_sources"
    channel_id: Mapped[str] = mapped_column(String, ForeignKey("channels.id"), primary_key=True)
    feed_id: Mapped[str] = mapped_column(String, ForeignKey("feeds.id"), primary_key=True)
    order_index: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    weight: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class User(Base):
    __tablename__ = "users"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    username: Mapped[str] = mapped_column(String, unique=True)
    email: Mapped[Optional[str]] = mapped_column(String, nullable=True, unique=True)
    password_hash: Mapped[str] = mapped_column(String)
    role: Mapped[str] = mapped_column(String, default="user")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class Subscription(Base):
    __tablename__ = "subscriptions"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(String, ForeignKey("users.id"), index=True)
    channel_id: Mapped[str] = mapped_column(String, ForeignKey("channels.id"), index=True)
    notify: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
