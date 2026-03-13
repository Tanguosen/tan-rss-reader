from sklearn.cluster import DBSCAN
import numpy as np
from datetime import datetime, timedelta
from typing import List, Dict, Any
import logging
from .vector_store import vector_store

logger = logging.getLogger(__name__)

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
        ids = [e["entry_id"] for e in entries]
        embeddings = [e["embedding"] for e in entries]
        titles = [e["title"] for e in entries]
        
        if not embeddings:
            return []

        X = np.array(embeddings)
        
        # Normalize vectors if not already? 
        # Embedding model usually returns normalized vectors.
        # But for safety, we can normalize.
        # norm = np.linalg.norm(X, axis=1, keepdims=True)
        # X = X / (norm + 1e-10)

        # 3. Cluster
        # eps: The maximum distance between two samples for one to be considered as in the neighborhood of the other.
        # metric='cosine': cosine distance = 1 - cosine similarity.
        # If similarity is high (close to 1), distance is low (close to 0).
        # So eps=0.3 means similarity > 0.7.
        try:
            db = DBSCAN(eps=eps, min_samples=min_samples, metric='cosine')
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
            centroid = np.mean(cluster_vectors, axis=0)
            
            # Find item closest to centroid (cosine similarity)
            # Cosine similarity = dot(a, b) / (|a| * |b|)
            # We can compute dot product of centroid with all vectors in cluster
            # and pick max.
            
            # Normalize centroid
            centroid_norm = np.linalg.norm(centroid)
            if centroid_norm > 0:
                centroid = centroid / centroid_norm
                
            # Normalize cluster vectors (if not already)
            # Assuming vectors from model are normalized, but let's be safe
            vec_norms = np.linalg.norm(cluster_vectors, axis=1)
            # Avoid division by zero
            vec_norms[vec_norms == 0] = 1
            normalized_vecs = cluster_vectors / vec_norms[:, np.newaxis]
            
            similarities = np.dot(normalized_vecs, centroid)
            best_idx_in_cluster = np.argmax(similarities)
            best_global_idx = indices[best_idx_in_cluster]
            
            cluster["topic"] = titles[best_global_idx]
            
            # Clean up internal data
            del cluster["vector_indices"]


        logger.info(f"Clustered {len(entries)} entries into {len(result)} clusters. Noise: {noise_count}")
        return result

clustering_service = ClusteringService(vector_store)
