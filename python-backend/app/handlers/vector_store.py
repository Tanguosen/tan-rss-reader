import logging
import asyncio
from typing import List, Optional, Dict, Any
from pymilvus import (
    connections,
    Collection,
    FieldSchema,
    CollectionSchema,
    DataType,
    utility,
    MilvusException
)
from app.handlers.ai import AI_CFG, _call_embedding

logger = logging.getLogger(__name__)

class VectorStore:
    def __init__(self):
        self.connected = False
        self._collection: Optional[Collection] = None

    async def connect(self):
        if self.connected:
            return

        host = AI_CFG["vector"].get("milvus_host", "localhost")
        port = AI_CFG["vector"].get("milvus_port", "19530")
        
        try:
            # Connect in a thread to avoid blocking
            # If host is "local" or a file path, use it as uri for milvus-lite
            if host == "local" or host.endswith(".db"):
                uri = host if host.endswith(".db") else "./rss_vector.db"
                logger.info(f"Connecting to local Milvus Lite: {uri}")
                await asyncio.to_thread(
                    connections.connect, 
                    alias="default", 
                    uri=uri
                )
            else:
                await asyncio.to_thread(
                    connections.connect, 
                    alias="default", 
                    host=host, 
                    port=port
                )
            self.connected = True
            logger.info(f"Connected to Milvus")
            await self._ensure_collection()
        except Exception as e:
            logger.error(f"Failed to connect to Milvus: {e}")
            self.connected = False

    async def _ensure_collection(self):
        collection_name = AI_CFG["vector"].get("milvus_collection_name", "rss_entries")
        
        def _setup():
            if utility.has_collection(collection_name):
                col = Collection(collection_name)
                col.load()
                return col
            
            # Schema definition
            fields = [
                FieldSchema(name="id", dtype=DataType.INT64, is_primary=True, auto_id=True),
                FieldSchema(name="entry_id", dtype=DataType.VARCHAR, max_length=255),
                FieldSchema(name="embedding", dtype=DataType.FLOAT_VECTOR, dim=1024),
                FieldSchema(name="feed_id", dtype=DataType.VARCHAR, max_length=255),
                FieldSchema(name="published_at", dtype=DataType.INT64),
                FieldSchema(name="title", dtype=DataType.VARCHAR, max_length=512),
            ]
            schema = CollectionSchema(fields, "RSS Entry Embeddings")
            col = Collection(collection_name, schema)
            
            # Index
            index_params = {
                "metric_type": "COSINE",
                "index_type": "IVF_FLAT",
                "params": {"nlist": 128}
            }
            col.create_index(field_name="embedding", index_params=index_params)
            col.load()
            return col

        try:
            self._collection = await asyncio.to_thread(_setup)
            logger.info(f"Collection {collection_name} ready.")
        except Exception as e:
            logger.error(f"Error setting up collection: {e}")

    async def add_entry(self, entry_id: str, text: str, feed_id: str, published_at: int, title: str):
        if not self.connected:
            await self.connect()
        
        if not self.connected or not self._collection:
            return False

        # Generate embedding (async)
        embedding = await _call_embedding(text)
        if not embedding or len(embedding) != 1024:
            return False

        # Prepare data
        data = [
            [entry_id],
            [embedding],
            [feed_id],
            [published_at],
            [title[:512]]
        ]

        def _insert():
            # Check existing by entry_id (VARCHAR)
            # Since entry_id is not PK, we use query
            res = self._collection.query(f'entry_id == "{entry_id}"', output_fields=["id"])
            if res:
                ids = [r["id"] for r in res]
                self._collection.delete(f"id in {ids}")
            
            self._collection.insert(data)
            return True

        try:
            return await asyncio.to_thread(_insert)
        except Exception as e:
            logger.error(f"Insert error: {e}")
            return False

    async def search(self, query_text: str, limit: int = 10, feed_id: Optional[str] = None):
        if not self.connected:
            await self.connect()
        if not self.connected or not self._collection:
            return []
            
        embedding = await _call_embedding(query_text)
        if not embedding:
            return []
            
        search_params = {
            "metric_type": "COSINE",
            "params": {"nprobe": 10},
        }
        
        expr = f'feed_id == "{feed_id}"' if feed_id else ""
        
        def _search():
            results = self._collection.search(
                data=[embedding],
                anns_field="embedding",
                param=search_params,
                limit=limit,
                expr=expr,
                output_fields=["title", "published_at", "feed_id", "entry_id"]
            )
            return results

        try:
            res = await asyncio.to_thread(_search)
            if not res:
                return []
            
            # Format results
            hits = res[0]
            return [
                {
                    "id": hit.id,
                    "score": hit.score,
                    "title": hit.entity.get("title"),
                    "published_at": hit.entity.get("published_at"),
                    "feed_id": hit.entity.get("feed_id"),
                    "entry_id": hit.entity.get("entry_id")
                }
                for hit in hits
            ]
        except Exception as e:
            logger.error(f"Search error: {e}")
            return []

    async def query_vectors(self, expr: str, output_fields: List[str]):
        if not self.connected:
            await self.connect()
        if not self.connected or not self._collection:
            return []
            
        def _query():
            return self._collection.query(expr=expr, output_fields=output_fields)
            
        try:
            return await asyncio.to_thread(_query)
        except Exception as e:
            logger.error(f"Query error: {e}")
            return []

# Singleton instance
vector_store = VectorStore()
