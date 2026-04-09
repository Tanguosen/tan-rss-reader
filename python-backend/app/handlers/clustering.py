from sklearn.cluster import DBSCAN
import numpy as np
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional, Tuple
import logging
from .vector_store import vector_store

logger = logging.getLogger(__name__)

EXPECTED_EMBEDDING_DIM = 1024


def _sanitize_embedding(raw_embedding: Any) -> Optional[np.ndarray]:
    try:
        vector = np.asarray(raw_embedding, dtype=np.float64).reshape(-1)
    except Exception:
        return None

    if vector.size != EXPECTED_EMBEDDING_DIM:
        return None

    if not np.all(np.isfinite(vector)):
        return None

    vector = np.clip(vector, -1e4, 1e4)
    norm = np.linalg.norm(vector)
    if not np.isfinite(norm) or norm <= 1e-12:
        return None

    vector = vector / norm
    if not np.all(np.isfinite(vector)):
        return None
    return vector


def _prepare_cluster_inputs(
    entries: List[Dict[str, Any]],
) -> Tuple[np.ndarray, List[str], List[str], List[Dict[str, Any]]]:
    cleaned_vectors: List[np.ndarray] = []
    ids: List[str] = []
    titles: List[str] = []
    cleaned_entries: List[Dict[str, Any]] = []
    invalid_count = 0

    for entry in entries:
        vector = _sanitize_embedding(entry.get("embedding"))
        if vector is None:
            invalid_count += 1
            continue
        cleaned_vectors.append(vector)
        ids.append(entry.get("entry_id") or "")
        titles.append(entry.get("title") or "未命名主题")
        cleaned_entries.append(entry)

    if invalid_count:
        logger.warning("Skipping %s invalid embedding vectors before clustering", invalid_count)

    if not cleaned_vectors:
        return np.empty((0, EXPECTED_EMBEDDING_DIM), dtype=np.float64), [], [], []

    X = np.vstack(cleaned_vectors).astype(np.float64, copy=False)
    return X, ids, titles, cleaned_entries

class ClusteringService:
    def __init__(self, vector_store):
        self.vector_store = vector_store

    async def cluster_entries(self, days: int = 1, min_samples: int = 2, eps: float = 0.3) -> List[Dict[str, Any]]:
        """
        Cluster entries published within the last `days`.
        Uses DBSCAN with cosine distance (metric='cosine').
        """
        # 1. Fetch data
        start_ts = int((datetime.now() - timedelta(days=days)).timestamp())
        
        # Query Milvus for all vectors in time range
        # Note: Milvus query limit is 16384 by default. If we have more, we need pagination.
        # For now assume < 10000.
        try:
            entries = await self.vector_store.query_vectors(
                expr=f"published_at >= {start_ts}",
                output_fields=["entry_id", "embedding", "title", "published_at", "feed_id"]
            )
        except Exception as e:
            logger.error(f"Failed to query vectors: {e}")
            return []
        
        if not entries:
            return []

        # 2. Prepare data
        X, ids, titles, entries = _prepare_cluster_inputs(entries)
        if len(X) == 0:
            return []

        # 3. Cluster
        # Use euclidean distance on normalized vectors to avoid sklearn cosine
        # distance numerical instability. For unit vectors:
        # ||u - v|| = sqrt(2 * (1 - cosine_similarity)).
        effective_eps = float(np.sqrt(max(0.0, 2.0 * eps)))
        try:
            db = DBSCAN(
                eps=effective_eps,
                min_samples=min_samples,
                metric="euclidean",
            )
            labels = db.fit_predict(X)
        except Exception as e:
            logger.error(f"Clustering failed: {e}")
            return []
        
        # 4. Group results
        clusters = {}
        noise_count = 0
        
        # Prepare to find representative items
        cluster_vectors = {}
        
        for idx, label in enumerate(labels):
            if label == -1:
                noise_count += 1
                continue # Noise
            
            label_id = int(label)
            if label_id not in clusters:
                clusters[label_id] = {
                    "cluster_id": label_id,
                    "items": [],
                    "vector_indices": []
                }
            
            clusters[label_id]["items"].append({
                "entry_id": ids[idx],
                "title": titles[idx],
                "published_at": entries[idx]["published_at"],
                "feed_id": entries[idx]["feed_id"]
            })
            clusters[label_id]["vector_indices"].append(idx)
            
        # Format output
        result = list(clusters.values())
        
        # Sort clusters by size (descending)
        result.sort(key=lambda x: len(x["items"]), reverse=True)
        
        # Add metadata and find representative topic
        for cluster in result:
            cluster["size"] = len(cluster["items"])
            
            # Calculate centroid
            indices = cluster["vector_indices"]
            if not indices:
                continue
                
            cluster_vectors = X[indices]
            centroid = np.mean(cluster_vectors, axis=0, dtype=np.float64)
            
            # Find item closest to centroid (cosine similarity)
            # Cosine similarity = dot(a, b) / (|a| * |b|)
            # We can compute dot product of centroid with all vectors in cluster
            # and pick max.
            
            # Normalize centroid
            centroid_norm = np.linalg.norm(centroid)
            if not np.isfinite(centroid_norm) or centroid_norm <= 1e-12:
                cluster["topic"] = titles[indices[0]]
                del cluster["vector_indices"]
                continue
            centroid = centroid / centroid_norm
                
            # Normalize cluster vectors (if not already)
            # Assuming vectors from model are normalized, but let's be safe
            similarities = np.clip(cluster_vectors @ centroid, -1.0, 1.0)
            best_idx_in_cluster = np.argmax(similarities)
            best_global_idx = indices[best_idx_in_cluster]
            
            cluster["topic"] = titles[best_global_idx]
            
            # Clean up internal data
            del cluster["vector_indices"]


        logger.info(f"Clustered {len(entries)} entries into {len(result)} clusters. Noise: {noise_count}")
        return result

clustering_service = ClusteringService(vector_store)
