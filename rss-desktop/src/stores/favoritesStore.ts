import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import api from '../api/client'
import type { Entry } from '../types'

export const useFavoritesStore = defineStore('favorites', () => {
  const starredEntries = ref<Entry[]>([])
  const starredCount = ref(0)
  const loading = ref(false)
  const error = ref<string | null>(null)

  const hasFavorites = computed(() => starredCount.value > 0)

  async function fetchStarredEntries(feedId?: string, limit = 200) {
    loading.value = true
    error.value = null
    try {
      const { data } = await api.get<Entry[]>('/entries/starred', {
        params: { limit: Math.min(limit, 1000), offset: 0 }
      })
      starredEntries.value = feedId ? data.filter((e) => e.feed_id === feedId) : data
      starredCount.value = starredEntries.value.length
    } catch (e: any) {
      error.value = e?.message ?? 'Failed to fetch favorites'
      throw e
    } finally {
      loading.value = false
    }
  }

  async function fetchStarredStats() {
    loading.value = true
    error.value = null
    try {
      const { data } = await api.get<{ count: number }>('/entries/starred/stats')
      starredCount.value = data.count ?? 0
    } catch (e: any) {
      error.value = e?.message ?? 'Failed to fetch favorites stats'
      throw e
    } finally {
      loading.value = false
    }
  }

  async function starEntry(entryId: string) {
    await api.post(`/entries/${encodeURIComponent(entryId)}/star`)
  }

  async function unstarEntry(entryId: string) {
    await api.post(`/entries/${encodeURIComponent(entryId)}/unstar`)
  }

  function clearError() {
    error.value = null
  }

  return {
    starredEntries,
    starredCount,
    hasFavorites,
    loading,
    error,
    fetchStarredEntries,
    fetchStarredStats,
    starEntry,
    unstarEntry,
    clearError
  }
})
