import { defineStore } from 'pinia'
import { ref } from 'vue'
import api from '../api/client'

export interface ClusterItem {
  entry_id: string
  title: string
  published_at: number
  feed_id: string
}

export interface Cluster {
  cluster_id: number
  items: ClusterItem[]
  size: number
  topic: string
}

export interface SearchResult {
  id: number
  score: number
  title: string
  published_at: number
  feed_id: string
  entry_id: string
}

export interface TimelineItem {
  id: string
  title: string
  published_at: number
  source: string
  summary: string
}

export interface AnalysisResult {
  timeline: TimelineItem[]
  analysis: {
    trend_prediction: string
    sentiment_score: number
    keywords: string[]
    summary: string
  }
  stats: {
    time_distribution: {date: string, count: number}[]
  }
}

export const useClusteringStore = defineStore('clustering', () => {
  const clusters = ref<Cluster[]>([])
  const searchResults = ref<SearchResult[]>([])
  const analysisResult = ref<AnalysisResult | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)

  async function fetchClusters(days: number = 3) {
    loading.value = true
    error.value = null
    try {
      const { data } = await api.post('/vector/cluster', { days })
      clusters.value = data.clusters
    } catch (err) {
      console.error('Failed to fetch clusters:', err)
      error.value = 'Failed to fetch clusters'
    } finally {
      loading.value = false
    }
  }

  async function search(query: string) {
    loading.value = true
    error.value = null
    try {
      const { data } = await api.post('/vector/search', { query, limit: 20 })
      searchResults.value = data.results
    } catch (err) {
      console.error('Failed to search vectors:', err)
      error.value = 'Failed to search'
    } finally {
      loading.value = false
    }
  }

  async function analyzeCluster(entryIds: string[]) {
    loading.value = true
    error.value = null
    try {
      const { data } = await api.post('/vector/cluster/analyze', { entry_ids: entryIds })
      analysisResult.value = data
    } catch (err) {
      console.error('Failed to analyze cluster:', err)
      error.value = 'Failed to analyze cluster'
    } finally {
      loading.value = false
    }
  }

  return {
    clusters,
    searchResults,
    analysisResult,
    loading,
    error,
    fetchClusters,
    search,
    analyzeCluster
  }
})
