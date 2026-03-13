import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import api from '../api/client'
import type { Entry, Feed, SummaryResult, TranslationResult, ChannelSourceItem } from '../types'
import { useUserStore } from './userStore'

export const useFeedStore = defineStore('feed', () => {
  const feeds = ref<Feed[]>([])
  const adminFeeds = ref<Feed[]>([])
  const entries = ref<Entry[]>([])
  const activeFeedId = ref<string | null>(null)
  const activeGroupName = ref<string | null>(null)
  const activeChannelId = ref<string | null>(null)
  const selectedEntryId = ref<string | null>(null)
  const loadingFeeds = ref(false)
  const loadingEntries = ref(false)
  const addingFeed = ref(false)
  const refreshingGroup = ref(false)
  const summaryCache = ref<Record<string, SummaryResult>>({})
  const translationCache = ref<Record<string, TranslationResult>>({})
  const titleTranslationCache = ref<Record<string, { title: string; language: string }>>({})
  const errorMessage = ref<string | null>(null)
  const collapsedGroups = ref<Set<string>>(new Set())
  const lastFeedFilters = ref<{ dateRange?: string; timeField?: string } | null>(null)
  const lastEntryFilters = ref<{ unreadOnly?: boolean; dateRange?: string; timeField?: string } | null>(null)
  const userStore = useUserStore()

  const selectedEntry = computed(() =>
    entries.value.find((entry) => entry.id === selectedEntryId.value) ?? null
  )

  // 分组相关的计算属性
  const groupedFeeds = computed(() => {
    const groups: Record<string, Feed[]> = {}

    // 将feeds按分组归类
    feeds.value.forEach(feed => {
      const groupName = feed.group_name || '未分组'
      if (!groups[groupName]) {
        groups[groupName] = []
      }
      groups[groupName].push(feed)
    })

    // 对每个分组内的feeds按名称排序
    Object.keys(groups).forEach(groupName => {
      groups[groupName].sort((a, b) => (a.title || a.url).localeCompare(b.title || b.url))
    })

    return groups
  })

  const groupStats = computed(() => {
    const stats: Record<string, { feedCount: number; unreadCount: number }> = {}

    Object.entries(groupedFeeds.value).forEach(([groupName, groupFeeds]) => {
      const feedCount = groupFeeds.length
      const unreadCount = groupFeeds.reduce((sum, feed) => sum + (feed.unread_count || 0), 0)
      stats[groupName] = { feedCount, unreadCount }
    })

    return stats
  })

  const sortedGroupNames = computed(() => {
    const groups = Object.keys(groupedFeeds.value)
    return groups.sort((a, b) => {
      // 未分组放在最后
      if (a === '未分组') return 1
      if (b === '未分组') return -1
      return a.localeCompare(b)
    })
  })

  async function fetchFeeds(options?: { dateRange?: string; timeField?: string }) {
    loadingFeeds.value = true
    try {
      const hasDateRange = options && Object.prototype.hasOwnProperty.call(options, 'dateRange')
      const hasTimeField = options && Object.prototype.hasOwnProperty.call(options, 'timeField')
      const mergedFilters = {
        dateRange: hasDateRange ? options?.dateRange : lastFeedFilters.value?.dateRange,
        timeField: hasTimeField ? options?.timeField : lastFeedFilters.value?.timeField,
      }
      lastFeedFilters.value = mergedFilters

      const params: Record<string, string | number> = { limit: 1000 }
      if (mergedFilters.dateRange && mergedFilters.dateRange !== 'all') {
        params.date_range = mergedFilters.dateRange
      }
      if (mergedFilters.timeField) {
        params.time_field = mergedFilters.timeField
      }
      // 排序字段与过滤时间字段保持一致，默认倒序
      params.order_by = mergedFilters.timeField === 'published_at' ? 'published_at' : 'created_at'
      params.order = 'desc'

      const { data } = await api.get<Feed[]>('/feeds', { params })
      feeds.value = data
      // 移除自动选中第一个订阅的逻辑，以便默认显示"全部订阅"
    } catch (error) {
      console.error(error)
      errorMessage.value = '加载订阅列表失败'
    } finally {
      loadingFeeds.value = false
    }
  }

  async function addFeed(url: string) {
    if (!url) return
    addingFeed.value = true
    try {
      const { data } = await api.post<Feed>('/feeds', { url })
      feeds.value = [data, ...feeds.value]
      try {
        const channelsStore = (await import('./channelsStore')).useChannelsStore()
        const before = new Set(channelsStore.myChannels.map(c => c.id))
        const createdId = data.channel_id
        if (createdId && userStore.token) {
          const ok = await channelsStore.subscribe(createdId)
          if (!ok) {
            userStore.openAuthModal('login')
            await channelsStore.fetchMySubscriptions()
          }
        } else {
          userStore.openAuthModal('login')
          await channelsStore.fetchMySubscriptions()
        }
        if (createdId) {
          activeChannelId.value = createdId
          await fetchEntries({ channelId: createdId, unreadOnly: lastEntryFilters.value?.unreadOnly, dateRange: lastEntryFilters.value?.dateRange, timeField: lastEntryFilters.value?.timeField })
        } else {
          const added = channelsStore.myChannels.find(c => !before.has(c.id) && c.kind !== 'feed')
          if (added) {
            activeChannelId.value = added.id
            await fetchEntries({ channelId: added.id, unreadOnly: lastEntryFilters.value?.unreadOnly, dateRange: lastEntryFilters.value?.dateRange, timeField: lastEntryFilters.value?.timeField })
          } else {
            await fetchEntries({ unreadOnly: lastEntryFilters.value?.unreadOnly, dateRange: lastEntryFilters.value?.dateRange, timeField: lastEntryFilters.value?.timeField })
          }
        }
      } catch (e) {
        await fetchEntries({ unreadOnly: lastEntryFilters.value?.unreadOnly, dateRange: lastEntryFilters.value?.dateRange, timeField: lastEntryFilters.value?.timeField })
      }
    } catch (error) {
      console.error(error)
      errorMessage.value = '添加订阅失败，请检查链接'
    } finally {
      addingFeed.value = false
    }
  }

  async function fetchAdminFeeds(search?: string) {
    loadingFeeds.value = true
    try {
      const params: any = { limit: 1000 }
      if (search) params.search = search
      const { data } = await api.get<Feed[]>('/admin/feeds', { params })
      adminFeeds.value = data
    } catch (error) {
      console.error(error)
      errorMessage.value = '加载管理源列表失败'
    } finally {
      loadingFeeds.value = false
    }
  }

  async function createAdminFeed(payload: { url: string; title?: string; group_name?: string; update_interval?: number }) {
    if (!payload.url) return false
    addingFeed.value = true
    try {
      const { data } = await api.post<Feed>('/admin/feeds', payload)
      adminFeeds.value = [data, ...adminFeeds.value]
      return true
    } catch (error) {
      console.error(error)
      errorMessage.value = '添加源失败，请检查链接'
      return false
    } finally {
      addingFeed.value = false
    }
  }

  async function updateAdminFeed(id: string, updates: { title?: string; group_name?: string; update_interval?: number }) {
    try {
      const { data } = await api.put<Feed>(`/admin/feeds/${id}`, updates)
      const index = adminFeeds.value.findIndex(f => f.id === id)
      if (index !== -1) {
        adminFeeds.value[index] = data
      }
      return true
    } catch (error) {
      console.error(error)
      errorMessage.value = '更新源失败'
      return false
    }
  }

  async function deleteAdminFeed(id: string) {
    try {
      await api.delete(`/admin/feeds/${id}`)
      adminFeeds.value = adminFeeds.value.filter(f => f.id !== id)
      return true
    } catch (error) {
      console.error(error)
      errorMessage.value = '删除源失败'
      return false
    }
  }


  async function refreshActiveFeed() {
    // 如果是分组模式，刷新该分组下的所有订阅源
    if (activeGroupName.value) {
      const groupFeeds = groupedFeeds.value[activeGroupName.value] || []
      if (groupFeeds.length === 0) {
        console.log(`分组 "${activeGroupName.value}" 没有订阅源`)
        return
      }

      refreshingGroup.value = true
      console.log(`开始刷新分组 "${activeGroupName.value}" 中的 ${groupFeeds.length} 个订阅源...`)

      // 并行刷新所有订阅源，提高效率
      const refreshPromises = groupFeeds.map(feed =>
        api.post(`/feeds/${feed.id}/refresh`).catch(error => {
          console.error(`Failed to refresh feed ${feed.title}:`, error)
          return { feedId: feed.id, success: false, error }
        })
      )

      try {
        const results = await Promise.allSettled(refreshPromises)
        const successCount = results.filter(result =>
          result.status === 'fulfilled'
        ).length

        console.log(`分组 "${activeGroupName.value}" 刷新完成: ${successCount}/${groupFeeds.length} 个订阅源成功`)

        // 保留当前的过滤器状态
        await fetchEntries({
          groupName: activeGroupName.value,
          unreadOnly: lastEntryFilters.value?.unreadOnly,
          dateRange: lastEntryFilters.value?.dateRange,
          timeField: lastEntryFilters.value?.timeField,
        })
        await fetchFeeds()

      } catch (error) {
        console.error('分组刷新失败:', error)
        errorMessage.value = `分组 "${activeGroupName.value}" 刷新失败`
      } finally {
        refreshingGroup.value = false
      }
      return
    }

    // 频道视图模式：刷新该频道下的所有订阅源
    if (activeChannelId.value) {
      try {
        refreshingGroup.value = true
        const { data } = await api.get<ChannelSourceItem[]>(`/admin/channels/${activeChannelId.value}/sources`)
        const feedIds = data.map((item) => item.feed_id)
        const refreshPromises = feedIds.map((fid) =>
          api.post(`/feeds/${fid}/refresh`).catch((error) => ({ feedId: fid, success: false, error }))
        )
        await Promise.allSettled(refreshPromises)
        await fetchEntries({
          channelId: activeChannelId.value,
          unreadOnly: lastEntryFilters.value?.unreadOnly,
          dateRange: lastEntryFilters.value?.dateRange,
          timeField: lastEntryFilters.value?.timeField,
        })
        await fetchFeeds()
      } catch (error) {
        console.error('频道刷新失败:', error)
        errorMessage.value = '频道刷新失败'
      } finally {
        refreshingGroup.value = false
      }
      return
    }

    // 单个订阅源模式
    if (!activeFeedId.value) return
    await api.post(`/feeds/${activeFeedId.value}/refresh`)
    // 保留当前的过滤器状态
    await fetchEntries({
      unreadOnly: lastEntryFilters.value?.unreadOnly,
      dateRange: lastEntryFilters.value?.dateRange,
      timeField: lastEntryFilters.value?.timeField,
    })
    await fetchFeeds()
  }

  async function deleteFeed(feedId: string) {
    try {
      await api.delete(`/feeds/${feedId}`)
      feeds.value = feeds.value.filter((f) => f.id !== feedId)
      if (activeFeedId.value === feedId) {
        activeFeedId.value = feeds.value.length > 0 ? feeds.value[0].id : null
        if (activeFeedId.value) {
          // 保留当前的过滤器状态
          await fetchEntries({
            unreadOnly: lastEntryFilters.value?.unreadOnly,
            dateRange: lastEntryFilters.value?.dateRange,
            timeField: lastEntryFilters.value?.timeField,
          })
        } else {
          entries.value = []
        }
      }
    } catch (error) {
      console.error(error)
      errorMessage.value = '删除订阅失败'
    }
  }

  async function updateFeed(feedId: string, updates: { group_name?: string; title?: string }) {
    try {
      const { data } = await api.patch<Feed>(`/feeds/${feedId}`, updates)
      const index = feeds.value.findIndex((f) => f.id === feedId)
      if (index !== -1) {
        feeds.value[index] = data
      }
      // 统一刷新订阅列表，确保未读统计与当前筛选条件一致
      await fetchFeeds()
    } catch (error) {
      console.error(error)
      errorMessage.value = '更新订阅失败'
    }
  }

  async function fetchEntries(options?: {
    feedId?: string
    groupName?: string
    channelId?: string
    unreadOnly?: boolean
    dateRange?: string
    timeField?: string
  }) {
    const targetFeed = options?.feedId ?? activeFeedId.value
    const targetGroup = options?.groupName ?? activeGroupName.value
    const targetChannel = options?.channelId ?? activeChannelId.value
    
    loadingEntries.value = true
    try {
      const { useSettingsStore } = await import('./settingsStore')
      const settingsStore = useSettingsStore()
      const hasUnreadOnly = options && Object.prototype.hasOwnProperty.call(options, 'unreadOnly')
      const hasDateRange = options && Object.prototype.hasOwnProperty.call(options, 'dateRange')
      const hasTimeField = options && Object.prototype.hasOwnProperty.call(options, 'timeField')
      const mergedFilters = {
        unreadOnly: hasUnreadOnly ? (options?.unreadOnly as boolean) : (lastEntryFilters.value?.unreadOnly ?? false),
        dateRange: hasDateRange ? options?.dateRange : (lastEntryFilters.value?.dateRange ?? undefined),
        timeField: hasTimeField ? options?.timeField : (lastEntryFilters.value?.timeField ?? settingsStore.settings.time_field),
      }
      lastEntryFilters.value = mergedFilters

      const params: Record<string, string | number | boolean> = { limit: 100 }

      if (mergedFilters.unreadOnly) {
        params.unread_only = true
      }

      if (mergedFilters.dateRange && mergedFilters.dateRange !== 'all') {
        params.date_range = mergedFilters.dateRange
      }

      if (mergedFilters.timeField) {
        params.time_field = mergedFilters.timeField
      }

      const orderBy = mergedFilters.timeField === 'published_at' ? 'published_at' : 'created_at'
      params.order_by = orderBy
      params.order = 'desc'

      let endpoint = '/entries'

      // 优先使用 channelId，其次 feedId，最后 groupName
      if (targetChannel) {
        endpoint = `/channels/${targetChannel}/entries`
      } else if (targetFeed) {
        params.feed_id = targetFeed
      } else if (targetGroup) {
        params.group_name = targetGroup
      } else if (userStore.token) {
        endpoint = '/me/subscriptions/entries'
      }

      const { data } = await api.get<Entry[]>(endpoint, { params })
      entries.value = data
      if (data.length > 0) {
        const defaultEntry = data.find((entry) => entry.id === selectedEntryId.value) ?? data[0]
        selectedEntryId.value = defaultEntry.id
      } else {
        selectedEntryId.value = null
      }
    } catch (error) {
      console.error(error)
      errorMessage.value = '加载文章失败'
    } finally {
      loadingEntries.value = false
    }
  }

  function selectFeed(id: string) {
    if (activeFeedId.value === id) return
    activeFeedId.value = id
    activeGroupName.value = null
    activeChannelId.value = null
  }

  function selectGroup(groupName: string) {
    activeGroupName.value = groupName
    activeFeedId.value = null
    activeChannelId.value = null
  }

  function selectChannel(id: string) {
    if (activeChannelId.value === id) return
    activeChannelId.value = id
    activeFeedId.value = null
    activeGroupName.value = null
  }

  function selectEntry(entryId: string) {
    selectedEntryId.value = entryId
  }

  function adjustFeedUnreadCount(feedId: string, delta: number) {
    const feed = feeds.value.find((f) => f.id === feedId)
    if (feed) {
      const next = Math.max(0, (feed.unread_count || 0) + delta)
      feed.unread_count = next
    }
  }

  async function toggleEntryState(entry: Entry, state: Partial<Pick<Entry, 'read' | 'starred'>>) {
    const previousRead = entry.read
    await api.patch<Entry>(`/entries/${entry.id}`, state)
    entry.read = state.read ?? entry.read
    entry.starred = state.starred ?? entry.starred

    if (state.read !== undefined && previousRead !== entry.read) {
      adjustFeedUnreadCount(entry.feed_id, entry.read ? -1 : 1)
    }
  }

  async function requestSummary(entryId: string, language = 'zh') {
    if (summaryCache.value[entryId]) {
      return summaryCache.value[entryId]
    }
    const { data } = await api.post<SummaryResult>('/ai/summary', {
      entry_id: entryId,
      language,
    }, {
      timeout: 90000, // 90 seconds for summary generation
    })
    summaryCache.value[entryId] = data
    return data
  }

  async function requestTranslation(entryId: string, language = 'zh') {
    const cacheKey = `${entryId}_${language}`
    if (translationCache.value[cacheKey]) {
      return translationCache.value[cacheKey]
    }
    const { data } = await api.post<{ entry_id: string; field_type: string; target_language: string; translated_text: string }>(
      '/ai/translate',
      {
        entry_id: entryId,
        field_type: 'content',
        target_language: language,
      },
      {
        timeout: 120000,
      },
    )
    const result: TranslationResult = {
      entry_id: data.entry_id,
      language: data.target_language,
      title: null,
      summary: null,
      content: data.translated_text,
    }
    translationCache.value[cacheKey] = result
    return result
  }

  async function requestTitleTranslation(entryId: string, language = 'zh') {
    const cacheKey = `${entryId}_${language}_title`
    if (titleTranslationCache.value[cacheKey]) {
      return titleTranslationCache.value[cacheKey]
    }
    const { data } = await api.post<{ entry_id: string; title: string; language: string }>('/ai/translate-title', {
      entry_id: entryId,
      language,
    }, {
      timeout: 30000, // 30 seconds for title translation
    })
    titleTranslationCache.value[cacheKey] = {
      title: data.title,
      language: data.language
    }
    return titleTranslationCache.value[cacheKey]
  }

  async function exportOpml() {
    try {
      const response = await api.get('/opml/export', { responseType: 'blob' })
      const url = window.URL.createObjectURL(new Blob([response.data]))
      const link = document.createElement('a')
      link.href = url
      link.setAttribute('download', 'rss_subscriptions.opml')
      document.body.appendChild(link)
      link.click()
      link.remove()
      window.URL.revokeObjectURL(url)
    } catch (error) {
      console.error(error)
      errorMessage.value = '导出 OPML 失败'
      throw error
    }
  }

  async function importOpml(file: File) {
    try {
      const formData = new FormData()
      formData.append('file', file)
      const { data } = await api.post<{ imported: number; skipped: number; errors: string[] }>(
        '/opml/import',
        formData
      )
      try {
        const channelsStore = (await import('./channelsStore')).useChannelsStore()
        const before = new Set(channelsStore.myChannels.map(c => c.id))
        await channelsStore.fetchMySubscriptions()
        const added = channelsStore.myChannels.find(c => !before.has(c.id) && c.kind !== 'feed')
        if (added) {
          activeChannelId.value = added.id
          await fetchEntries({ channelId: added.id, unreadOnly: lastEntryFilters.value?.unreadOnly, dateRange: lastEntryFilters.value?.dateRange, timeField: lastEntryFilters.value?.timeField })
        }
      } catch (e) {
      }
      try {
        await fetchFeeds()
      }
      catch (_e) {}
      return data
    } catch (error) {
      console.error(error)
      errorMessage.value = '导入 OPML 失败'
      throw error
    }
  }

  // 分组管理方法
  function toggleGroupCollapse(groupName: string) {
    if (collapsedGroups.value.has(groupName)) {
      collapsedGroups.value.delete(groupName)
    } else {
      collapsedGroups.value.add(groupName)
    }
    // 保存到localStorage
    localStorage.setItem('collapsedGroups', JSON.stringify([...collapsedGroups.value]))
  }

  function isGroupCollapsed(groupName: string) {
    return collapsedGroups.value.has(groupName)
  }

  function expandAllGroups() {
    collapsedGroups.value.clear()
    localStorage.removeItem('collapsedGroups')
  }

  function collapseAllGroups() {
    collapsedGroups.value = new Set(sortedGroupNames.value)
    localStorage.setItem('collapsedGroups', JSON.stringify([...collapsedGroups.value]))
  }

  function loadCollapsedGroups() {
    const saved = localStorage.getItem('collapsedGroups')
    if (saved) {
      try {
        collapsedGroups.value = new Set(JSON.parse(saved))
      } catch (e) {
        console.error('Failed to load collapsed groups:', e)
      }
    }
  }

  return {
    feeds,
    adminFeeds,
    entries,
    selectedEntry,
    activeFeedId,
    activeGroupName,
    loadingFeeds,
    loadingEntries,
    addingFeed,
    refreshingGroup,
    activeChannelId,
    selectChannel,
    errorMessage,
    summaryCache,
    translationCache,
    titleTranslationCache,
    // 分组相关属性
    groupedFeeds,
    groupStats,
    sortedGroupNames,
    collapsedGroups,
    // 方法
    fetchFeeds,
    fetchAdminFeeds,
    fetchEntries,
    addFeed,
    createAdminFeed,
    updateAdminFeed,
    deleteAdminFeed,
    selectFeed,
    selectGroup,
    selectEntry,
    refreshActiveFeed,
    deleteFeed,
    updateFeed,
    toggleEntryState,
    requestSummary,
    requestTranslation,
    requestTitleTranslation,
    exportOpml,
    importOpml,
    // 分组管理方法
    toggleGroupCollapse,
    isGroupCollapsed,
    expandAllGroups,
    collapseAllGroups,
    loadCollapsedGroups,
  }
})
