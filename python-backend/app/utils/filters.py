from datetime import datetime, timedelta
from typing import Optional
from sqlalchemy import Column

def apply_date_filter_to_entries_query(q, date_range: Optional[str], time_field: Optional[str], created_col: Column, published_col: Column):
    if not date_range or date_range == "all":
        return q
    now = datetime.utcnow()
    mapping = {
        "1d": 1,
        "2d": 2,
        "3d": 3,
        "7d": 7,
        "30d": 30,
        "90d": 90,
        "180d": 180,
        "365d": 365,
    }
    days = mapping.get(date_range)
    if not days:
        return q
    cutoff = now - timedelta(days=days)
    field = created_col if (time_field or "inserted_at") == "inserted_at" else published_col
    return q.where(field >= cutoff)
