import { defineStore } from 'pinia'
import { ref } from 'vue'
import api from '../api/client'
import type { Entry, ChannelSourceItem } from '../types'

export interface Category {
  id: string
  name: string
  sort_order: number
}

export interface Tag {
  id: string
  name: string
}

export interface PreviewEntry {
  id: string
  title: string
  cover_image?: string | null
  published_at?: string | null
}

export interface Channel {
  id: string
  name: string
  description?: string | null
  cover_url?: string | null
  is_public: boolean
  kind?: string
  category_id?: string | null
  tags?: Tag[]
  preview_entries?: PreviewEntry[]
}

export const useChannelsStore = defineStore('channels', () => {
  const square = ref<Channel[]>([])
  const myChannels = ref<Channel[]>([])
  const channelEntries = ref<Entry[]>([])
  const activeChannelId = ref<string | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)
  const message = ref<string | null>(null)
  const adminChannels = ref<Channel[]>([])
  const channelSources = ref<ChannelSourceItem[]>([])
  const categories = ref<Category[]>([])
  const tags = ref<Tag[]>([])

  // UI State
  const showChannelSquareModal = ref(false)

  // Categories & Tags Actions
  async function fetchPublicCategories() {
    try {
      const { data } = await api.get<Category[]>('/categories')
      categories.value = data
    } catch (err) {
      console.error('Failed to fetch public categories', err)
    }
  }

  async function fetchCategories() {
    try {
      const { data } = await api.get<Category[]>('/admin/categories')
      categories.value = data
    } catch (err) {
      console.error('Failed to fetch categories', err)
    }
  }

  async function createCategory(payload: { name: string; sort_order?: number }) {
    try {
      await api.post('/admin/categories', payload)
      await fetchCategories()
      return true
    } catch (err) {
      error.value = '创建分类失败'
      return false
    }
  }

  async function updateCategory(id: string, payload: { name?: string; sort_order?: number }) {
    try {
      await api.patch(`/admin/categories/${id}`, payload)
      await fetchCategories()
      return true
    } catch (err) {
      error.value = '更新分类失败'
      return false
    }
  }

  async function deleteCategory(id: string) {
    try {
      await api.delete(`/admin/categories/${id}`)
      await fetchCategories()
      return true
    } catch (err) {
      error.value = '删除分类失败'
      return false
    }
  }

  async function fetchTags() {
    try {
      const { data } = await api.get<Tag[]>('/admin/tags')
      tags.value = data
    } catch (err) {
      console.error('Failed to fetch tags', err)
    }
  }

  async function createTag(payload: { name: string }) {
    try {
      await api.post('/admin/tags', payload)
      await fetchTags()
      return true
    } catch (err) {
      error.value = '创建标签失败'
      return false
    }
  }

  async function deleteTag(id: string) {
    try {
      await api.delete(`/admin/tags/${id}`)
      await fetchTags()
      return true
    } catch (err) {
      error.value = '删除标签失败'
      return false
    }
  }

  async function fetchSquare(query?: string, limit: number = 100) {
    loading.value = true
    error.value = null
    try {
      const params: Record<string, string | number> = { limit }
      if (query && query.trim()) params.q = query.trim()
      const { data } = await api.get<Channel[]>('/channels/square', { params })
      square.value = data
    } catch (err) {
      error.value = '加载频道广场失败'
    } finally {
      loading.value = false
    }
  }

  async function fetchMySubscriptions() {
    loading.value = true
    error.value = null
    try {
      const { data } = await api.get<Channel[]>('/me/subscriptions')
      myChannels.value = data
    } catch (err) {
      error.value = '加载我的频道失败'
    } finally {
      loading.value = false
    }
  }

  async function subscribe(channelId: string) {
    loading.value = true
    error.value = null
    try {
      await api.post(`/channels/${channelId}/subscribe`)
      await fetchMySubscriptions()
      message.value = '订阅成功'
      return true
    } catch (err) {
      error.value = '订阅失败'
      return false
    } finally {
      loading.value = false
    }
  }

  async function unsubscribe(channelId: string) {
    loading.value = true
    error.value = null
    try {
      await api.delete(`/channels/${channelId}/subscribe`)
      await fetchMySubscriptions()
      if (activeChannelId.value === channelId) {
        activeChannelId.value = null
        channelEntries.value = []
      }
      message.value = '已取消订阅'
      return true
    } catch (err) {
      error.value = '取消订阅失败'
      return false
    } finally {
      loading.value = false
    }
  }

  async function fetchChannelEntries(channelId: string, options?: { unreadOnly?: boolean; dateRange?: string; timeField?: string }) {
    loading.value = true
    error.value = null
    try {
      const params: Record<string, string | number | boolean> = { limit: 100 }
      if (options?.unreadOnly) params.unread_only = true
      if (options?.dateRange && options.dateRange !== 'all') params.date_range = options.dateRange
      if (options?.timeField) params.time_field = options.timeField
      // 排序字段与过滤时间字段保持一致，默认倒序
      const orderBy = options?.timeField === 'published_at' ? 'published_at' : 'created_at'
      params.order_by = orderBy
      params.order = 'desc'
      const { data } = await api.get<Entry[]>(`/channels/${channelId}/entries`, { params })
      channelEntries.value = data
      activeChannelId.value = channelId
    } catch (err) {
      error.value = '加载频道条目失败'
    } finally {
      loading.value = false
    }
  }

  async function fetchAdminChannels(isPublic?: boolean) {
    loading.value = true
    error.value = null
    try {
      const params: Record<string, string | number | boolean> = {}
      if (typeof isPublic === 'boolean') params.is_public = isPublic
      const { data } = await api.get<Channel[]>('/admin/channels', { params })
      adminChannels.value = data
    } catch (err) {
      error.value = '加载管理频道失败'
    } finally {
      loading.value = false
    }
  }

  async function fetchChannelSources(channelId: string) {
    loading.value = true
    error.value = null
    try {
      const { data } = await api.get<ChannelSourceItem[]>(`/admin/channels/${channelId}/sources`)
      channelSources.value = data
    } catch (err) {
      error.value = '加载频道源失败'
    } finally {
      loading.value = false
    }
  }

  async function addChannelSource(channelId: string, feedId: string, options?: { orderIndex?: number; weight?: number }) {
    loading.value = true
    error.value = null
    try {
      await api.post(`/admin/channels/${channelId}/sources`, {
        feed_id: feedId,
        order_index: options?.orderIndex,
        weight: options?.weight
      })
      await fetchChannelSources(channelId)
      return true
    } catch (err) {
      error.value = '新增频道源失败'
      return false
    } finally {
      loading.value = false
    }
  }

  async function removeChannelSource(channelId: string, feedId: string) {
    loading.value = true
    error.value = null
    try {
      await api.delete(`/admin/channels/${channelId}/sources/${feedId}`)
      await fetchChannelSources(channelId)
      return true
    } catch (err) {
      error.value = '移除频道源失败'
      return false
    } finally {
      loading.value = false
    }
  }

  async function createChannel(payload: { name: string; description?: string; is_public?: boolean; cover_url?: string; category_id?: string; tags?: string[] }) {
    loading.value = true
    error.value = null
    try {
      await api.post('/admin/channels', payload)
      await fetchAdminChannels()
      return true
    } catch (err) {
      error.value = '创建频道失败'
      return false
    } finally {
      loading.value = false
    }
  }

  async function updateChannel(id: string, payload: { name?: string; description?: string; is_public?: boolean; cover_url?: string; category_id?: string; tags?: string[] }) {
    loading.value = true
    error.value = null
    try {
      await api.patch(`/admin/channels/${id}`, payload)
      await fetchAdminChannels()
      return true
    } catch (err) {
      error.value = '更新频道失败'
      return false
    } finally {
      loading.value = false
    }
  }

  async function deleteChannel(id: string) {
    loading.value = true
    error.value = null
    try {
      await api.delete(`/admin/channels/${id}`)
      await fetchAdminChannels()
      return true
    } catch (err) {
      error.value = '删除频道失败'
      return false
    } finally {
      loading.value = false
    }
  }

  return {
    square,
    myChannels,
    channelEntries,
    activeChannelId,
    loading,
    error,
    message,
    adminChannels,
    channelSources,
    categories,
    tags,
    fetchSquare,
    fetchMySubscriptions,
    subscribe,
    unsubscribe,
    fetchChannelEntries,
    fetchAdminChannels,
    fetchChannelSources,
    addChannelSource,
    removeChannelSource,
    createChannel,
    updateChannel,
    deleteChannel,
    showChannelSquareModal,
    fetchPublicCategories,
    fetchCategories,
    createCategory,
    updateCategory,
    deleteCategory,
    fetchTags,
    createTag,
    deleteTag
  }
})
