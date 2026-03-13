import asyncio
import httpx
import sys
import os

# Add parent dir to path to import app modules if needed, but we are testing via HTTP
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.db import SessionLocal
from sqlalchemy import select
from app.models import Entry

async def test_analysis():
    # 1. Get some entry IDs
    print("Fetching entries from DB...")
    async with SessionLocal() as session:
        result = await session.execute(select(Entry.id).limit(5))
        entry_ids = result.scalars().all()
        entry_ids = [str(eid) for eid in entry_ids]
        
    if not entry_ids:
        print("No entries to test")
        return

    print(f"Testing with entries: {entry_ids}")
    
    # 2. Call endpoint
    # Note: Port might be 27496 (Python backend default)
    url = "http://127.0.0.1:27496/api/vector/cluster/analyze"
    print(f"Calling {url}...")
    
    try:
        async with httpx.AsyncClient(timeout=60) as client:
            resp = await client.post(url, json={"entry_ids": entry_ids})
            
        if resp.status_code == 200:
            data = resp.json()
            print("\n✅ Analysis Success!")
            print("-" * 30)
            analysis = data.get("analysis", {})
            print(f"Trend Prediction: {analysis.get('trend_prediction')}")
            print(f"Sentiment: {analysis.get('sentiment_score')}")
            print(f"Keywords: {analysis.get('keywords')}")
            print(f"Summary: {analysis.get('summary')}")
            print("-" * 30)
            print(f"Timeline items: {len(data.get('timeline', []))}")
            print(f"Stats: {data.get('stats')}")
        else:
            print(f"❌ Failed: {resp.status_code} {resp.text}")
    except Exception as e:
        print(f"❌ Connection error: {e}")
        print("Make sure the backend server is running.")

if __name__ == "__main__":
    asyncio.run(test_analysis())
