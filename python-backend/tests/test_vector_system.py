import asyncio
import logging
import sys
import os

# Add parent directory to path to import app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.handlers.vector_store import vector_store
from app.handlers.clustering import clustering_service
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def test_vector_system():
    logger.info("Starting Vector System Test...")

    # 1. Connect to Milvus
    logger.info("1. Connecting to Milvus...")
    await vector_store.connect()
    if not vector_store.connected:
        logger.error("Failed to connect to Milvus.")
        return

    # 2. Add Dummy Data
    logger.info("2. Adding Dummy Data...")
    entries = [
        {"id": "test_1", "title": "AI Revolution in 2024", "text": "Artificial Intelligence is changing the world rapidly with LLMs.", "feed_id": "feed_a"},
        {"id": "test_2", "title": "Machine Learning Basics", "text": "Learn the fundamentals of ML and neural networks.", "feed_id": "feed_a"},
        {"id": "test_3", "title": "Deep Learning Advances", "text": "New architectures in deep learning are emerging.", "feed_id": "feed_b"},
        {"id": "test_4", "title": "Cooking Pasta", "text": "How to cook the perfect pasta al dente.", "feed_id": "feed_c"},
        {"id": "test_5", "title": "Italian Cuisine", "text": "Exploring the best dishes from Italy.", "feed_id": "feed_c"},
    ]

    for e in entries:
        success = await vector_store.add_entry(
            entry_id=e["id"],
            text=e["text"],
            feed_id=e["feed_id"],
            published_at=int(datetime.now().timestamp()),
            title=e["title"]
        )
        if success:
            logger.info(f"  Added entry: {e['title']}")
        else:
            logger.error(f"  Failed to add entry: {e['title']}")

    # Wait for indexing (Milvus is near real-time but slight delay possible)
    await asyncio.sleep(2)

    # 3. Test Search
    logger.info("3. Testing Vector Search...")
    query = "AI and LLMs"
    results = await vector_store.search(query, limit=3)
    logger.info(f"  Query: '{query}'")
    for r in results:
        logger.info(f"  Result: {r['title']} (Score: {r['score']:.4f})")
    
    if results and "AI" in results[0]['title']:
        logger.info("  Search Test PASSED")
    else:
        logger.warning("  Search Test FAILED or unexpected results")

    # 4. Test Clustering
    logger.info("4. Testing Clustering...")
    clusters = await clustering_service.cluster_entries(days=1, min_samples=2, eps=0.5)
    logger.info(f"  Found {len(clusters)} clusters")
    
    for c in clusters:
        logger.info(f"  Cluster {c['cluster_id']} (Topic: {c['topic']}, Size: {c['size']}):")
        for item in c['items']:
            logger.info(f"    - {item['title']}")

    if len(clusters) >= 1:
        logger.info("  Clustering Test PASSED")
    else:
        logger.warning("  Clustering Test FAILED (might be due to insufficient data or high epsilon)")

    logger.info("Vector System Test Completed.")

if __name__ == "__main__":
    asyncio.run(test_vector_system())
