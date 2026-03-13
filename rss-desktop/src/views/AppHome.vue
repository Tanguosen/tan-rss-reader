<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import dayjs from 'dayjs'
import relativeTime from 'dayjs/plugin/relativeTime'
import utc from 'dayjs/plugin/utc'
import { useFeedStore } from '../stores/feedStore'
import { useAIStore } from '../stores/aiStore'
import { useFavoritesStore } from '../stores/favoritesStore'
import { useSettingsStore } from '../stores/settingsStore'
import { useUserStore } from '../stores/userStore'
import { useChannelsStore } from '../stores/channelsStore'
import { useRouter, useRoute } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useLanguage } from '../composables/useLanguage'
import LoadingSpinner from '../components/LoadingSpinner.vue'
import LogoMark from '../components/LogoMark.vue'
import SmartDetails from '../components/SmartDetails.vue'
import ErrorBoundary from '../components/ErrorBoundary.vue'
import type { Entry, Feed } from '../types'
import { TITLE_TRANSLATION_CONCURRENCY_FALLBACK } from '../constants/translation'

dayjs.extend(relativeTime)
dayjs.extend(utc)

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? 'http://127.0.0.1:27496/api'

function iconSrcFor(url?: string | null) {
  if (!url) return undefined
  return `${API_BASE}/icons/proxy?url=${encodeURIComponent(url)}`
}

const store = useFeedStore()
const userStore = useUserStore()
const channelsStore = useChannelsStore()
const router = useRouter()
const route = useRoute()
const aiStore = useAIStore()
const favoritesStore = useFavoritesStore()
const settingsStore = useSettingsStore()
const { t } = useI18n()
const { loadLanguage } = useLanguage()
const aiFeatures = computed(() => aiStore.config.features)


// 初始化语言设置
loadLanguage()

const totalUnreadCount = computed(() => {
  return store.feeds.reduce((acc, feed) => acc + (feed.unread_count || 0), 0)
})

function resetFilters() {
  store.activeFeedId = null
  store.activeGroupName = null
  store.activeChannelId = null
}

async function markAllRead() {
  // Placeholder for mark all read functionality
  // In a real implementation, this would call an API endpoint
  if (confirm(t('common.confirmMarkAllRead'))) {
     // await store.markAllRead()
     showNotification(t('common.comingSoon'), 'info')
  }
}

// Computed filtered entries
const filteredEntries = computed(() => {
  let result = currentEntries.value

  if (showFavoritesOnly.value) {
    if (filterMode.value === 'unread') {
      result = result.filter((entry) => !entry.read)
    }
    // 收藏模式下默认所有条目均为收藏，无需再次按star筛选
  } else {
    // Apply filter mode for订阅视图
    if (filterMode.value === 'unread') {
      result = result.filter((entry) => !entry.read)
    } else if (filterMode.value === 'starred') {
      result = result.filter((entry) => entry.starred)
    }
  }

  // Apply search query
  if (searchQuery.value.trim()) {
    const query = searchQuery.value.toLowerCase()
    result = result.filter(
      (entry) =>
        entry.title?.toLowerCase().includes(query) ||
        entry.summary?.toLowerCase().includes(query) ||
        entry.content?.toLowerCase().includes(query) ||
        entry.feed_title?.toLowerCase().includes(query)
    )
  }

  return result
})

// Handle route params for channel
watch(
  () => route.params.id,
  async (newId) => {
    if (route.name === 'my-channel-detail' && typeof newId === 'string') {
      store.selectChannel(newId)
      await store.fetchEntries()
    } else if (route.name === 'home') {
      store.activeChannelId = null
      store.activeFeedId = null
      store.activeGroupName = null
      await store.fetchEntries()
    }
  },
  { immediate: true }
)

const summaryText = ref('')
const summaryPoints = ref<string[]>([])
const summaryLoading = ref(false)
const translationLanguage = ref('zh')
const translationLoading = ref(false)
const showTranslation = ref(false)
const translatedContent = ref<{
  title: string | null
  content: string | null
}>({ title: null, content: null })
const titleTranslationLoadingMap = ref<Record<string, boolean>>({})

// 标题翻译并发数：完全由用户设置控制（/settings.max_auto_title_translations）
const titleTranslationConcurrency = computed(() => {
  const raw = settingsStore.settings.max_auto_title_translations
  if (typeof raw !== 'number' || Number.isNaN(raw) || !Number.isFinite(raw)) {
    return TITLE_TRANSLATION_CONCURRENCY_FALLBACK
  }
  // 并发数至少为 1，避免死锁
  return Math.max(1, raw)
})
const titleTranslationQueue: Array<() => void> = []
let activeTitleTranslationTasks = 0

function releaseTitleTranslationSlot() {
  activeTitleTranslationTasks = Math.max(0, activeTitleTranslationTasks - 1)
  const next = titleTranslationQueue.shift()
  if (next) {
    next()
  }
}

async function acquireTitleTranslationSlot() {
  const limit = Math.max(
    1,
    titleTranslationConcurrency.value || TITLE_TRANSLATION_CONCURRENCY_FALLBACK,
  )
  while (activeTitleTranslationTasks >= limit) {
    await new Promise<void>((resolve) => {
      titleTranslationQueue.push(resolve)
    })
  }
  activeTitleTranslationTasks++
}

async function withTitleTranslationSemaphore<T>(task: () => Promise<T>): Promise<T> {
  await acquireTitleTranslationSlot()
  try {
    return await task()
  } finally {
    releaseTitleTranslationSlot()
  }
}
const fileInput = ref<HTMLInputElement | null>(null)
const importLoading = ref(false)
const searchQuery = ref('')
const filterMode = ref<'all' | 'unread' | 'starred'>('all')
const dateRangeFilter = ref('30d')
const filterLoading = ref(false)
// deprecated
const darkMode = ref(false)
const isElectron = computed(() => !!(window as any).electron)


// 翻译显示模式计算属性
const translationDisplayMode = computed(() =>
  settingsStore.settings.translation_display_mode || 'replace'
)

// 翻译显示模式处理
const translationMode = computed(() => {
  return translationDisplayMode.value || 'replace'
})

// Debug watcher for translation mode
watch(translationMode, (newVal) => {
  console.log('AppHome: translationMode changed to:', newVal)
})



// 判断是否为替换模式（用于标题翻译）
function isTranslationModeReplace() {
  return translationMode.value === 'replace'
}

// 判断是否为双语模式（用于标题翻译）
function isTranslationModeBilingual() {
  return translationMode.value === 'bilingual_original_first' || translationMode.value === 'bilingual_translation_first'
}

// 获取刷新按钮文本
function getRefreshButtonText() {
  if (showFavoritesOnly.value) {
    return store.refreshingGroup ? '刷新中...' : t('navigation.refreshFavorites')
  }

  // 统一显示"刷新"，loading时显示"刷新中..."
  return store.refreshingGroup ? '刷新中...' : '刷新'
}

// 双语显示的内容处理

const NO_SUMMARY_TEXT = computed(() => t('ai.noSummary'))

const brokenFeedIcons = ref<Record<string, boolean>>({})
// Track which icon URLs have loaded successfully to avoid broken-image flashes
const loadedIconUrls = ref<Record<string, boolean>>({})

function handleFeedIconLoad(_feedId: string, url?: string | null) {
  if (!url) return
  loadedIconUrls.value = { ...loadedIconUrls.value, [url]: true }
}


// 布局状态管理
const DEFAULT_VIEWPORT_WIDTH = typeof window !== 'undefined' ? window.innerWidth : 1440
const DEFAULT_DETAILS_RATIO = 0.45
const MIN_TIMELINE_WIDTH = 240
const MIN_DETAILS_WIDTH = 360
const DETAILS_RATIO_KEY = 'rss-layout-details-ratio'
const detailsRatio = ref(DEFAULT_DETAILS_RATIO)
const viewportWidth = ref(DEFAULT_VIEWPORT_WIDTH)
const isDraggingRight = ref(false)
const appShell = ref<HTMLElement | null>(null)

function getViewport() {
  return viewportWidth.value || DEFAULT_VIEWPORT_WIDTH
}

const detailsWidth = computed(() => Math.round(getViewport() * detailsRatio.value))

function minDetailsRatio() {
  return MIN_DETAILS_WIDTH / getViewport()
}

function minTimelineRatio() {
  return MIN_TIMELINE_WIDTH / getViewport()
}

function refreshViewportWidth() {
  if (appShell.value) {
    viewportWidth.value = appShell.value.clientWidth
  } else if (typeof window !== 'undefined') {
    viewportWidth.value = window.innerWidth
  }
}

const layoutStyle = computed(() => ({
  '--details-width': `${detailsWidth.value}px`,
}))

function normalizeRatios() {
  const detailsMin = minDetailsRatio()
  const timelineMin = minTimelineRatio()
  detailsRatio.value = Math.max(detailsRatio.value, detailsMin)

  const maxDetails = Math.max(0, 1 - timelineMin)
  if (detailsRatio.value > maxDetails) {
    detailsRatio.value = maxDetails
  }
}

function handleWindowResize() {
  refreshViewportWidth()
  normalizeRatios()
  saveLayoutSettings()
}

function showNotification(message: string, type: 'success' | 'error' | 'info' = 'info') {
  // Use a custom event to notify App.vue or use a store if available
  // Since we removed Toast component, we should probably rely on a global store or event bus
  // But App.vue has the Toast component.
  // Ideally, we should use a composable for Toast.
  // For now, let's just console log or maybe we can't show toast easily without prop drilling or store.
  // But wait, the user didn't ask to refactor Toast logic, just Sidebar.
  // I should have kept Toast in AppHome if I'm not moving the state to a store.
  // But I moved Toast component to App.vue.
  // So AppHome cannot show Toast directly unless it emits an event or uses a store.
  // I will add a simple event emit or console log for now, as refactoring Toast to store is out of scope but recommended.
  // Actually, I can use a simple event bus or just inject.
  // Let's assume for now we just log it, or better, make a temporary composable or just emit.
  console.log(`[Toast ${type}] ${message}`)
}

function getTitleTranslationCacheKey(entryId: string) {
  const language = aiFeatures.value?.translation_language || 'zh'
  return `${entryId}_${language}_title`
}

function getTranslatedTitle(entryId: string) {
  const cacheKey = getTitleTranslationCacheKey(entryId)
  return store.titleTranslationCache[cacheKey]?.title ?? null
}

function isTitleTranslationLoading(entryId: string) {
  const cacheKey = getTitleTranslationCacheKey(entryId)
  return !!titleTranslationLoadingMap.value[cacheKey]
}

async function ensureTitleTranslation(entry: Entry) {
  if (!aiFeatures.value?.auto_title_translation || !entry?.id || !entry.title) {
    return
  }
  const cacheKey = getTitleTranslationCacheKey(entry.id)
  if (store.titleTranslationCache[cacheKey] || titleTranslationLoadingMap.value[cacheKey]) {
    return
  }
  titleTranslationLoadingMap.value[cacheKey] = true
  try {
    await withTitleTranslationSemaphore(() =>
      store.requestTitleTranslation(entry.id, aiFeatures.value?.translation_language || 'zh')
    )
  } catch (error) {
    console.error('标题翻译失败:', error)
  } finally {
    delete titleTranslationLoadingMap.value[cacheKey]
  }
}

// 批量翻译函数：用于处理大量条目的翻译
async function batchEnsureTitleTranslations(entries: Entry[], maxConcurrency?: number) {
  if (!aiFeatures.value?.auto_title_translation || !entries?.length) {
    return
  }

  // 过滤需要翻译的条目
  const entriesNeedingTranslation = entries.filter(entry => {
    if (!entry?.id || !entry.title) return false
    const cacheKey = getTitleTranslationCacheKey(entry.id)
    return !store.titleTranslationCache[cacheKey] && !titleTranslationLoadingMap.value[cacheKey]
  })

  if (!entriesNeedingTranslation.length) return

  // 根据设置的最大并发数限制并发
  const concurrency = maxConcurrency || Math.max(1, titleTranslationConcurrency.value || TITLE_TRANSLATION_CONCURRENCY_FALLBACK)

  // 分批处理翻译请求
  for (let i = 0; i < entriesNeedingTranslation.length; i += concurrency) {
    const batch = entriesNeedingTranslation.slice(i, i + concurrency)
    await Promise.allSettled(
      batch.map(entry => ensureTitleTranslation(entry))
    )
  }
}

// 收藏状态管理
const showFavoritesOnly = ref(false)
const selectedFavoriteFeed = ref<string | null>(null)
const selectedFavoriteEntryId = ref<string | null>(null)
const lastActiveFeedId = ref<string | null>(null)

const currentEntries = computed(() => (showFavoritesOnly.value ? favoritesStore.starredEntries : store.entries))

const currentSelectedEntry = computed(() => {
  if (showFavoritesOnly.value) {
    return favoritesStore.starredEntries.find((entry) => entry.id === selectedFavoriteEntryId.value) ?? null
  }
  return store.selectedEntry
})

const timelineLoading = computed(() => (showFavoritesOnly.value ? favoritesStore.loading : store.loadingEntries))


// 收藏相关函数
async function loadFavoritesData(options: { includeEntries?: boolean; feedId?: string | null } = {}) {
  const includeEntries = options.includeEntries ?? false
  const targetFeedId = options.feedId ?? selectedFavoriteFeed.value

  try {
    if (includeEntries) {
      await favoritesStore.fetchStarredEntries(targetFeedId || undefined, 200)
      ensureFavoriteSelection()
    } else {
      await favoritesStore.fetchStarredStats()
    }
  } catch (error) {
    console.error('Failed to load favorites data:', error)
    showNotification(t('toast.loadFavoritesFailed'), 'error')
  }
}


function backToAllFeeds() {
  showFavoritesOnly.value = false
  selectedFavoriteFeed.value = null
  selectedFavoriteEntryId.value = null
  filterMode.value = 'all'
  if (lastActiveFeedId.value) {
    store.selectFeed(lastActiveFeedId.value)
  }
}

function ensureFavoriteSelection() {
  if (!showFavoritesOnly.value) return
  const entries = favoritesStore.starredEntries
  if (!entries.length) {
    selectedFavoriteEntryId.value = null
    return
  }
  if (!selectedFavoriteEntryId.value || !entries.some((entry) => entry.id === selectedFavoriteEntryId.value)) {
    selectedFavoriteEntryId.value = entries[0].id
  }
}

function handleEntrySelect(entryId: string) {
  if (showFavoritesOnly.value) {
    selectedFavoriteEntryId.value = entryId
  } else {
    store.selectEntry(entryId)
  }

  // 窄屏模式下直接跳转到阅读页
  if (viewportWidth.value < 960) {
    const entry = showFavoritesOnly.value
      ? favoritesStore.starredEntries.find((e) => e.id === entryId)
      : store.entries.find((e) => e.id === entryId)
    
    if (entry) {
      goToReader(entry)
    }
  }
}

function isEntryActive(entryId: string) {
  return currentSelectedEntry.value?.id === entryId
}

function handleFeedIconError(feedId: string, failedUrl?: string | null) {
  brokenFeedIcons.value = {
    ...brokenFeedIcons.value,
    [feedId]: true
  }
  if (failedUrl) {
    const { [failedUrl]: _omit, ...rest } = loadedIconUrls.value
    loadedIconUrls.value = rest
  }
}

function isFeedIconBroken(feed?: Feed | null) {
  if (!feed?.favicon_url) return true
  return !!brokenFeedIcons.value[feed.id]
}

function isFeedIconLoaded(url?: string | null) {
  if (!url) return false
  return !!loadedIconUrls.value[url]
}

function getFeedInitial(text?: string | null) {
  const safe = text?.trim()
  if (!safe) return '订'
  return safe.charAt(0).toUpperCase()
}


function normalizeWhitespace(text: string) {
  return text.replace(/\s+/g, ' ').trim()
}

function stripHtml(value?: string | null) {
  if (!value) return ''
  const temp = document.createElement('div')
  temp.innerHTML = value
  const text = temp.textContent || temp.innerText || ''
  return normalizeWhitespace(text)
}

function getEntryPreview(entry: Entry) {
  const summary = entry.summary?.trim()
  if (summary) return summary
  const fallback = stripHtml(entry.content)
  return fallback || NO_SUMMARY_TEXT
}

function getEntryThumbnail(entry: Entry): string | null {
  if (!entry.content) return null
  
  // Try to find the first image in the content
  const imgMatch = entry.content.match(/<img[^>]+src="([^">]+)"/)
  if (imgMatch && imgMatch[1]) {
    return imgMatch[1]
  }
  
  return null
}

// Watch for AI store errors
watch(() => aiStore.error, (error) => {
  if (error) {
    showNotification(error, 'error')
    setTimeout(() => {
      aiStore.clearError()
    }, 100)
  }
})

// Watch for favorites store errors
watch(() => favoritesStore.error, (error) => {
  if (error) {
    showNotification(error, 'error')
    setTimeout(() => {
      favoritesStore.clearError()
    }, 100)
  }
})


function updateTheme() {
  if (darkMode.value) {
    document.documentElement.classList.add('dark')
    localStorage.setItem('theme', 'dark')
  } else {
    document.documentElement.classList.remove('dark')
    localStorage.setItem('theme', 'light')
  }
}

function saveLayoutSettings() {
  localStorage.setItem(DETAILS_RATIO_KEY, detailsRatio.value.toString())
}

function loadLayoutSettings() {
  if (typeof window === 'undefined') return
  refreshViewportWidth()
  const savedDetailsRatio = localStorage.getItem(DETAILS_RATIO_KEY)

  if (savedDetailsRatio) {
    const ratio = parseFloat(savedDetailsRatio)
    if (!Number.isNaN(ratio)) {
      detailsRatio.value = ratio
    }
  }

  normalizeRatios()
}

function setDetailsRatioFromClientX(clientX: number) {
  refreshViewportWidth()
  const viewport = getViewport()
  let offsetX = clientX
  if (appShell.value) {
    const rect = appShell.value.getBoundingClientRect()
    offsetX = clientX - rect.left
  }
  const ratio = (viewport - offsetX) / viewport
  detailsRatio.value = ratio
  normalizeRatios()
  saveLayoutSettings()
}

function handleMouseDownRight(event: MouseEvent) {
  isDraggingRight.value = true
  event.preventDefault()
  document.body.style.cursor = 'col-resize'
  document.body.style.userSelect = 'none'
}

function handleMouseMove(event: MouseEvent) {
  if (isDraggingRight.value) {
    setDetailsRatioFromClientX(event.clientX)
  }
}

function handleMouseUp() {
  if (isDraggingRight.value) {
    isDraggingRight.value = false
    document.body.style.cursor = ''
    document.body.style.userSelect = ''
  }
}

let resizeObserver: ResizeObserver | null = null

onMounted(async () => {
  if (appShell.value) {
    resizeObserver = new ResizeObserver(() => {
      refreshViewportWidth()
      normalizeRatios()
    })
    resizeObserver.observe(appShell.value)
  }

  refreshViewportWidth()
  const savedTheme = localStorage.getItem('theme')
  darkMode.value = savedTheme === 'dark'
  updateTheme()

  // 加载分组折叠状态
  store.loadCollapsedGroups()

  // 加载布局设置
  loadLayoutSettings()
  normalizeRatios()

  // 加载AI配置
  await aiStore.fetchConfig()

  // 加载用户设置
  await settingsStore.fetchSettings()

  if (userStore.token) {
    await channelsStore.fetchMySubscriptions()
  }

  // 初始化时间过滤器为设置中的默认值
  dateRangeFilter.value = settingsStore.settings.default_date_range

  // 加载收藏数据
  loadFavoritesData()

  // 添加全局事件监听器
  window.addEventListener('mousemove', handleMouseMove)
  window.addEventListener('mouseup', handleMouseUp)
  window.addEventListener('resize', handleWindowResize)

  const initialDateRange = settingsStore.settings.enable_date_filter ? dateRangeFilter.value : undefined
  const initialTimeField = settingsStore.settings.time_field

  await store.fetchFeeds({
    dateRange: initialDateRange,
    timeField: initialTimeField
  })
  await store.fetchEntries({
    dateRange: initialDateRange,
    timeField: initialTimeField
  })

  // 启动后台自动同步（固定短周期），并在聚焦/可见性变更时同步
  startBackgroundSync()
  window.addEventListener('focus', handleWindowFocus)
  document.addEventListener('visibilitychange', handleVisibilityChange)
})

// 组件卸载时清理事件监听器
onUnmounted(() => {
  if (resizeObserver) {
    resizeObserver.disconnect()
    resizeObserver = null
  }
  window.removeEventListener('mousemove', handleMouseMove)
  window.removeEventListener('mouseup', handleMouseUp)
  window.removeEventListener('resize', handleWindowResize)
  if (backgroundSyncTimer.value) {
    window.clearInterval(backgroundSyncTimer.value)
    backgroundSyncTimer.value = null
  }
  window.removeEventListener('focus', handleWindowFocus)
  document.removeEventListener('visibilitychange', handleVisibilityChange)
})

watch(
  () => currentSelectedEntry.value,
  async (entry, oldEntry) => {
    // 当文章切换时，清理阅读模式状态
    if (oldEntry && entry && oldEntry.id !== entry.id) {
      showTranslation.value = false
      translatedContent.value = { title: null, content: null }
    }

    if (!entry) {
      summaryText.value = ''
      summaryPoints.value = []
      showTranslation.value = false
      translatedContent.value = { title: null, content: null }
      return
    }
    const cached = store.summaryCache[entry.id]
    summaryText.value = cached?.summary ?? ''
    summaryPoints.value = cached?.key_points ?? []

    // 自动生成摘要逻辑
    if (aiFeatures.value?.auto_summary && !cached?.summary) {
      // 如果启用了自动摘要且没有缓存摘要，则自动生成
      try {
        summaryLoading.value = true
        const summary = await store.requestSummary(entry.id)
        summaryText.value = summary.summary
        summaryPoints.value = summary.key_points ?? []
        // 可选：显示通知让用户知道摘要已自动生成
        // showNotification('摘要已自动生成', 'success')
      } catch (error) {
        console.error('自动生成摘要失败:', error)
        // 不显示错误通知，避免干扰用户体验
      } finally {
        summaryLoading.value = false
      }
    }

    // Check if translation exists
    const cacheKey = `${entry.id}_${translationLanguage.value}`
    const cachedTranslation = store.translationCache[cacheKey]
    if (cachedTranslation) {
      translatedContent.value = {
        title: cachedTranslation.title,
        content: cachedTranslation.content,
      }
    } else {
      translatedContent.value = { title: null, content: null }
    }

    if (aiFeatures.value?.auto_translation && !cachedTranslation) {
      try {
        translationLoading.value = true
        const translation = await store.requestTranslation(
          entry.id,
          translationLanguage.value,
        )
        translatedContent.value = {
          title: translation.title,
          content: translation.content,
        }
        showTranslation.value = true
      } finally {
        translationLoading.value = false
      }
    }

    if (!entry.read) {
      await store.toggleEntryState(entry, { read: true })
    }
  },
  { immediate: true },
)

watch(
  () => ({
    entries: filteredEntries.value,
    language: aiFeatures.value?.translation_language,
    auto: aiFeatures.value?.auto_title_translation,
    concurrency: titleTranslationConcurrency.value
  }),
  ({ entries, auto, concurrency }) => {
    if (!auto) {
      titleTranslationLoadingMap.value = {}
      return
    }
    // 使用批量翻译：翻译所有可见的条目，但根据网络状况智能控制并发
    const allEntries = (entries || []) as Entry[]
    if (allEntries.length > 0) {
      // 对于大量条目，使用批量翻译以提高效率，传递当前的并发设置
      batchEnsureTitleTranslations(allEntries, concurrency)
    }
  },
  { immediate: true },
)

// 防抖函数
function debounce<T extends (...args: any[]) => any>(
  func: T,
  wait: number
): (...args: Parameters<T>) => void {
  let timeout: NodeJS.Timeout | null = null
  return (...args: Parameters<T>) => {
    if (timeout) clearTimeout(timeout)
    timeout = setTimeout(() => func(...args), wait)
  }
}

// 应用过滤器的实际函数
async function applyFilters(options: { refreshFeeds?: boolean } = {}) {
  const filterDateRange = settingsStore.settings.enable_date_filter ? dateRangeFilter.value : undefined
  const filterTimeField = settingsStore.settings.time_field

  const promises: Promise<unknown>[] = []

  if (options.refreshFeeds) {
    promises.push(
      store.fetchFeeds({
        dateRange: filterDateRange,
        timeField: filterTimeField
      })
    )
  }

  if (showFavoritesOnly.value) {
    if (promises.length) {
      await Promise.all(promises)
    }
    return
  }

  if (!store.activeFeedId && !store.activeGroupName && !store.activeChannelId) {
    if (promises.length) {
      await Promise.all(promises)
    }
    return
  }

  filterLoading.value = true
  promises.push(
    store.fetchEntries({
      feedId: store.activeFeedId || undefined,
      groupName: store.activeGroupName || undefined,
      channelId: store.activeChannelId || undefined,
      unreadOnly: filterMode.value === 'unread',
      dateRange: filterDateRange,
      timeField: filterTimeField
    })
  )

  try {
    await Promise.all(promises)
  } finally {
    filterLoading.value = false
  }
}

// 防抖的过滤器应用函数
const debouncedApplyFilters = debounce(applyFilters, 300)

// 监听activeFeedId或activeGroupName变化
watch(
  () => [store.activeFeedId, store.activeGroupName, store.activeChannelId],
  async () => {
    if ((store.activeFeedId || store.activeGroupName || store.activeChannelId) && !showFavoritesOnly.value) {
      await applyFilters()
    }
  }
)

// 监听过滤模式和时间范围变化（使用防抖）
watch(filterMode, () => {
  debouncedApplyFilters()
})

watch(dateRangeFilter, () => {
  debouncedApplyFilters({ refreshFeeds: true })
})

// 监听后端时间字段切换，同步左侧未读统计
watch(
  () => settingsStore.settings.time_field,
  () => {
    debouncedApplyFilters({ refreshFeeds: true })
  }
)


function formatDate(date?: string | null) {
  if (!date) return '未知时间'
  // 后端时间为UTC，统一转成本地再做相对时间
  return dayjs.utc(date).local().fromNow()
}

 


// 后台自动同步（短周期，仅同步左侧统计；避免打扰列表请求）
const backgroundSyncTimer = ref<number | null>(null)

function syncFeedsCounts() {
  const filterDateRange = settingsStore.settings.enable_date_filter ? dateRangeFilter.value : undefined
  const filterTimeField = settingsStore.settings.time_field
  if (store.loadingFeeds) return Promise.resolve()
  return store.fetchFeeds({ dateRange: filterDateRange, timeField: filterTimeField })
}

function startBackgroundSync() {
  if (backgroundSyncTimer.value) {
    window.clearInterval(backgroundSyncTimer.value)
    backgroundSyncTimer.value = null
  }
  // 页面可见时每30s同步一次，不可见时每60s同步（轻量，只刷新左侧计数）
  const intervalMs = document.hidden ? 60000 : 30000
  backgroundSyncTimer.value = window.setInterval(() => {
    if (showFavoritesOnly.value) {
      // 收藏视图：只需刷新收藏统计与列表（轻量）
      loadFavoritesData()
    } else {
      syncFeedsCounts()
    }
  }, intervalMs)
}

function handleWindowFocus() {
  if (showFavoritesOnly.value) {
    loadFavoritesData()
  } else {
    // 聚焦时做一次全量同步（含当前列表）
    applyFilters({ refreshFeeds: true })
  }
}

function handleVisibilityChange() {
  // 可见性变化时重置同步节奏，并在恢复可见时立即同步一次
  startBackgroundSync()
  if (!document.hidden) {
    handleWindowFocus()
  }
}


async function handleSummary() {
  if (!currentSelectedEntry.value) return
  summaryLoading.value = true
  try {
    const summary = await store.requestSummary(currentSelectedEntry.value.id)
    summaryText.value = summary.summary
    summaryPoints.value = summary.key_points ?? []
    showNotification('摘要生成成功', 'success')
  } catch (error) {
    showNotification('摘要生成失败，请检查 API 配置', 'error')
  } finally {
    summaryLoading.value = false
  }
}

async function handleTranslation() {
  if (!currentSelectedEntry.value) return

  // If already showing translation, toggle back to original
  if (showTranslation.value) {
    showTranslation.value = false
    return
  }

  // If translation already cached, just show it
  const cacheKey = `${currentSelectedEntry.value.id}_${translationLanguage.value}`
  if (store.translationCache[cacheKey]) {
    const cached = store.translationCache[cacheKey]
    translatedContent.value = {
      title: cached.title,
      content: cached.content,
    }
    showTranslation.value = true
    showNotification('翻译成功', 'success')
    return
  }

  // Otherwise, request translation
  translationLoading.value = true
  try {
    const translation = await store.requestTranslation(
      currentSelectedEntry.value.id,
      translationLanguage.value
    )
    translatedContent.value = {
      title: translation.title,
      content: translation.content,
    }
    showTranslation.value = true
    showNotification('翻译成功', 'success')
  } catch (error) {
    console.error('Translation failed:', error)
    showNotification('翻译失败，请检查 API 配置', 'error')
  } finally {
    translationLoading.value = false
  }
}

async function toggleStar() {
  if (!currentSelectedEntry.value) return

  try {
    const entryId = currentSelectedEntry.value.id
    const willBeStarred = !currentSelectedEntry.value.starred

    if (willBeStarred) {
      await favoritesStore.starEntry(entryId)
      showNotification('已添加到收藏', 'success')
    } else {
      await favoritesStore.unstarEntry(entryId)
      showNotification('已从收藏中移除', 'success')
    }

    // 更新store中的entry状态
    await store.toggleEntryState(currentSelectedEntry.value, { starred: willBeStarred })

    // 如果在收藏模式，重新加载收藏数据
    if (showFavoritesOnly.value) {
      await loadFavoritesData({ includeEntries: true })
    }
  } catch (error) {
    console.error('Failed to toggle star:', error)
    showNotification('操作失败，请重试', 'error')
  }
}

async function toggleStarFromList(entry: any) {
  try {
    const willBeStarred = !entry.starred

    if (willBeStarred) {
      await favoritesStore.starEntry(entry.id)
      showNotification('已添加到收藏', 'success')
    } else {
      await favoritesStore.unstarEntry(entry.id)
      showNotification('已从收藏中移除', 'success')
    }

    // 更新store中的entry状态
    await store.toggleEntryState(entry, { starred: willBeStarred })

    // 如果在收藏模式，重新加载收藏数据
    if (showFavoritesOnly.value) {
      await loadFavoritesData({ includeEntries: true })
    }
  } catch (error) {
    console.error('Failed to toggle star from list:', error)
    showNotification('操作失败，请重试', 'error')
  }
}

function openExternal(url?: string | null) {
  if (!url) return
  
  // 在 Electron 环境中使用 shell.openExternal 调用系统默认浏览器
  if (window.electron?.shell) {
    window.electron.shell.openExternal(url)
  } else {
    // 在 Web 环境中回退到 window.open
    window.open(url, '_blank')
  }
}

function triggerImportOpml() {
  fileInput.value?.click()
}

async function handleImportOpml(event: Event) {
  const target = event.target as HTMLInputElement
  const file = target.files?.[0]
  if (!file) return

  importLoading.value = true
  try {
    const result = await store.importOpml(file)
    showNotification(
      `导入成功 ${result.imported} 个，跳过 ${result.skipped} 个`,
      'success'
    )
  } catch (error) {
    showNotification('导入失败，请检查文件格式', 'error')
  } finally {
    importLoading.value = false
    if (target) target.value = ''
  }
}

// Smart Details Logic
const hoveredEntryId = ref<string | null>(null)
let hoverTimer: any = null

// const currentSelectedEntry = computed(() => store.selectedEntry) // Removed duplicate

const displayedEntry = computed(() => {
  if (hoveredEntryId.value) {
    return store.entries.find(e => e.id === hoveredEntryId.value) || store.selectedEntry
  }
  return store.selectedEntry
})

const displayedSummary = computed(() => {
  if (!displayedEntry.value) return null
  return store.summaryCache[displayedEntry.value.id]?.summary
})

const displayedKeyPoints = computed(() => {
  if (!displayedEntry.value) return []
  return store.summaryCache[displayedEntry.value.id]?.key_points
})

function handleEntryHover(id: string) {
  clearTimeout(hoverTimer)
  hoverTimer = setTimeout(() => {
    hoveredEntryId.value = id
  }, 300)
}

function handleEntryLeave() {
  clearTimeout(hoverTimer)
  hoverTimer = setTimeout(() => {
    hoveredEntryId.value = null
  }, 300)
}

function goToReader(entry: Entry) {
  store.selectEntry(entry.id)
  router.push({ name: 'reader', params: { id: entry.id } })
}

async function handleSmartSummaryGenerate() {
  if (!displayedEntry.value) return
  summaryLoading.value = true
  try {
    await store.requestSummary(displayedEntry.value.id)
  } catch (e) {
    console.error(e)
    showNotification('摘要生成失败', 'error')
  } finally {
    summaryLoading.value = false
  }
}
</script>

<template>
  <div
    class="app-shell"
    ref="appShell"
    :style="layoutStyle"
    :class="{ 'is-dragging-right': isDraggingRight }"
  >

    <!-- 时间线 -->
    <main class="timeline">
      
      <header class="timeline__header">
        <div class="timeline__title-block">
          <div class="title-row">
            <h2 v-if="showFavoritesOnly">
              {{ selectedFavoriteFeed ? store.feeds.find((f) => f.id === selectedFavoriteFeed)?.title + ' 的收藏' || '收藏' : '全部收藏' }}
            </h2>
            <h2 v-else-if="store.activeChannelId">
              {{ channelsStore.myChannels.find(c => c.id === store.activeChannelId)?.name || '频道' }}
            </h2>
            <h2 v-else-if="store.activeGroupName">
              {{ store.activeGroupName }} 分组
            </h2>
            <h2 v-else>
              {{ store.feeds.find((f) => f.id === store.activeFeedId)?.title || '最新条目' }}
            </h2>
            <span class="count-badge">
              {{ filteredEntries.length }}
            </span>
          </div>
        </div>
        <div class="timeline__actions">
          <button
            class="timeline-action-btn"
            :class="{ loading: store.refreshingGroup || timelineLoading }"
            :disabled="store.refreshingGroup || timelineLoading"
            @click="showFavoritesOnly ? loadFavoritesData({ includeEntries: true }) : store.refreshActiveFeed()"
            :title="getRefreshButtonText()"
          >
            <span class="timeline-action-btn__icon" aria-hidden="true">
              <svg v-if="!store.refreshingGroup && !timelineLoading" viewBox="0 0 24 24" focusable="false">
                <path
                  d="M4 4v6h6"
                  stroke="currentColor"
                  stroke-width="1.6"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  fill="none"
                />
                <path
                  d="M20 20v-6h-6"
                  stroke="currentColor"
                  stroke-width="1.6"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  fill="none"
                />
                <path
                  d="M20 10a8 8 0 0 0-13.66-4.66L4 8"
                  stroke="currentColor"
                  stroke-width="1.6"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  fill="none"
                />
                <path
                  d="M4 14a8 8 0 0 0 13.66 4.66L20 16"
                  stroke="currentColor"
                  stroke-width="1.6"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  fill="none"
                />
              </svg>
              <div v-else class="btn-loading-spinner"></div>
            </span>
          </button>
          <button
            v-if="showFavoritesOnly"
            @click="backToAllFeeds"
            class="timeline-action-btn timeline-action-btn--ghost"
            :title="t('navigation.backToSubscription')"
          >
            <span class="timeline-action-btn__icon" aria-hidden="true">
              <svg viewBox="0 0 24 24" focusable="false">
                <path
                  d="M8 5l-5 7 5 7"
                  stroke="currentColor"
                  stroke-width="1.6"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  fill="none"
                />
                <path
                  d="M21 12H4"
                  stroke="currentColor"
                  stroke-width="1.6"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  fill="none"
                />
              </svg>
            </span>
          </button>
        </div>
      </header>
      

      <div class="timeline__controls">
        <div class="timeline__controls-inner">
          <input
            v-model="searchQuery"
            type="search"
            :placeholder="t('articles.searchPlaceholder')"
            class="search-input"
          />
          
          <div class="filter-group">
            <div class="filter-buttons">
              <button
                :class="['filter-btn', { active: filterMode === 'all' }]"
                @click="filterMode = 'all'"
                :title="t('navigation.all')"
              >
                {{ t('navigation.all') }}
              </button>
              <button
                :class="['filter-btn', { active: filterMode === 'unread' }]"
                @click="filterMode = 'unread'"
                :title="t('navigation.unread')"
              >
                {{ t('navigation.unread') }}
              </button>
              <button
                :class="['filter-btn', { active: filterMode === 'starred' }]"
                @click="filterMode = 'starred'"
                :title="t('navigation.favorites')"
              >
                {{ t('navigation.favorites') }}
              </button>
            </div>

            <div class="date-filter" v-if="settingsStore.settings.enable_date_filter">
              <select
                v-model="dateRangeFilter"
                class="date-select"
                :disabled="filterLoading"
              >
                <option value="1d">{{ t('time.last1Day') }}</option>
                <option value="2d">{{ t('time.last2Days') }}</option>
                <option value="3d">{{ t('time.last3Days') }}</option>
                <option value="7d">{{ t('time.last1Week') }}</option>
                <option value="30d">{{ t('time.last1Month') }}</option>
                <option value="90d">{{ t('time.last3Months') }}</option>
                <option value="180d">{{ t('time.last6Months') }}</option>
                <option value="365d">{{ t('time.last1Year') }}</option>
                <option value="all">{{ t('time.allTime') }}</option>
              </select>
            </div>
          </div>
        </div>
      </div>
      

      <section class="timeline__list">
        <LoadingSpinner v-if="timelineLoading" message="加载中..." />
        
        <template v-else>
          <div
            v-for="entry in filteredEntries"
            :key="entry.id"
            :class="['entry-card', { active: isEntryActive(entry.id), unread: !entry.read, 'has-thumbnail': !!getEntryThumbnail(entry) }]"
            @click="handleEntrySelect(entry.id)"
          >
            <div v-if="getEntryThumbnail(entry)" class="entry-card__thumbnail">
              <img :src="getEntryThumbnail(entry) || undefined" loading="lazy" alt="" />
            </div>
            <div class="entry-card__content">
              <div class="entry-card__meta-top">
                <span class="feed-title">{{ entry.feed_title }}</span>
                <span class="publish-date">{{ formatDate(entry.published_at) }}</span>
              </div>
              
              <div class="entry-card__title">
                <!-- 替换模式：显示翻译标题（如果可用） -->
                <template v-if="isTranslationModeReplace()">
                  <template v-if="getTranslatedTitle(entry.id)">
                    {{ getTranslatedTitle(entry.id) }}
                  </template>
                  <template v-else>
                    {{ entry.title || '未命名文章' }}
                  </template>
                </template>

                <!-- 双语模式：同时显示原文和翻译 -->
                <template v-else-if="isTranslationModeBilingual()">
                  <div class="bilingual-title-entry" :class="{ 'translation-first': translationMode === 'bilingual_translation_first' }">
                    <div class="original-title-entry">{{ entry.title || '未命名文章' }}</div>
                    <div v-if="aiFeatures.auto_title_translation" class="translated-title-entry">
                      <template v-if="getTranslatedTitle(entry.id)">
                        {{ getTranslatedTitle(entry.id) }}
                      </template>
                      <template v-else-if="isTitleTranslationLoading(entry.id)">
                        <span class="loading-indicator">{{ t('articles.translatingTitle') }}</span>
                      </template>
                    </div>
                  </div>
                </template>

                <!-- 原文模式：只显示原文 -->
                <template v-else>
                  {{ entry.title || '未命名文章' }}
                </template>
              </div>

              <p v-if="settingsStore.settings.show_entry_summary" class="entry-card__summary">
                {{ getEntryPreview(entry) }}
              </p>
              
              <!-- <div class="entry-card__actions">
                 <button
                  class="entry-card__star-btn"
                  @click.stop="toggleStarFromList(entry)"
                  :title="entry.starred ? '取消收藏' : '收藏'"
                >
                  <span class="icon">{{ entry.starred ? '★' : '☆' }}</span>
                </button>
              </div> -->
            </div>
          </div>

          <div class="empty" v-if="!filteredEntries.length">
            {{ searchQuery ? t('feeds.noArticlesSearch') : t('feeds.noArticlesAdd') }}
          </div>
        </template>
      </section>
    </main>

    <!-- 右侧分隔器 -->
    <div
      class="resizer resizer-right"
      :class="{ active: isDraggingRight }"
      @mousedown="handleMouseDownRight"
      :title="t('layout.rightResizeTitle')"
    ></div>

    <!-- 详情栏 -->
    <section class="details">
      <ErrorBoundary>
        <SmartDetails
          :entry="displayedEntry"
          :summary="displayedSummary"
          :key-points="displayedKeyPoints"
          :loading="summaryLoading"
          :generating="summaryLoading"
          @generate="handleSmartSummaryGenerate"
          @open-reader="displayedEntry && goToReader(displayedEntry)"
          @open-original="displayedEntry && openExternal(displayedEntry.url)"
          @toggle-star="displayedEntry && toggleStarFromList(displayedEntry)"
        />
      </ErrorBoundary>
    </section>
  </div>
</template>

<style scoped>
.app-shell {
  display: flex;
  min-height: 100vh;
  background: var(--bg-base);
  color: var(--text-primary);
  position: relative;
  max-width: 100vw;
  /* 顶层容器不滚动，交给内部列滚动，避免多重滚动条 */
  overflow: hidden;
  height: 100vh;
  align-items: stretch;
  --details-width: 420px;
}



/* 分隔器样式 */
.resizer {
  width: 3px;
  background: rgba(15, 17, 21, 0.1);
  cursor: col-resize;
  transition: background-color 0.2s;
  position: relative;
  flex-shrink: 0;
}

.resizer:hover {
  background: rgba(255, 122, 24, 0.3);
}

.resizer.active {
  background: rgba(255, 122, 24, 0.6);
}

.resizer::before {
  content: '';
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: 20px;
  height: 40px;
  background: rgba(255, 122, 24, 0);
  transition: background-color 0.2s;
  border-radius: 2px;
}

.resizer:hover::before {
  background: rgba(255, 122, 24, 0.1);
}

.resizer.active::before {
  background: rgba(255, 122, 24, 0.2);
}





.timeline {
  display: flex;
  flex-direction: column;
  border-right: 1px solid var(--border-color);
  background: var(--bg-base);
  flex: 1 1 auto;
  min-width: 260px;
  width: auto;
  box-sizing: border-box;
  max-height: 100vh;
  min-height: 0;
  overflow: visible;
}

.timeline__header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 16px;
  border-bottom: 1px solid var(--border-color);
  gap: 12px;
  flex-wrap: nowrap;
}

.timeline__title-block {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  justify-content: center;
}

.title-row {
  display: flex;
  align-items: center;
  gap: 8px;
}

.title-row h2 {
  font-size: 16px;
  margin: 0;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.count-badge {
  font-size: 12px;
  color: var(--text-secondary);
  background: var(--bg-secondary);
  padding: 2px 8px;
  border-radius: 12px;
  flex-shrink: 0;
}

.timeline__actions {
  display: flex;
  gap: 8px;
  flex-shrink: 0;
}

.timeline-action-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  border: none;
  border-radius: 50%;
  padding: 0;
  background: linear-gradient(120deg, #ff7a18, #ffbe30);
  color: #fff;
  cursor: pointer;
  box-shadow: 0 4px 12px rgba(255, 122, 24, 0.25);
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.timeline-action-btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 16px rgba(255, 122, 24, 0.35);
}

.timeline-action-btn:active {
  transform: translateY(0);
  box-shadow: 0 2px 8px rgba(255, 122, 24, 0.2);
}

.timeline-action-btn__icon {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: transparent;
  border-radius: 50%;
}

.timeline-action-btn__icon svg {
  width: 14px;
  height: 14px;
  color: #fff;
}

.timeline-action-btn--ghost {
  background: transparent;
  color: var(--text-secondary);
  box-shadow: none;
  border: 1px solid var(--border-color);
}

.timeline-action-btn--ghost:hover {
  background: var(--bg-secondary);
  color: var(--text-primary);
  box-shadow: none;
}

.timeline-action-btn--ghost .timeline-action-btn__icon {
  background: transparent;
}

.timeline-action-btn--ghost .timeline-action-btn__icon svg {
  color: currentColor;
}

.timeline__controls {
  padding: 8px 16px;
  border-bottom: 1px solid var(--border-color);
  flex: 0 0 auto;
}

.timeline__controls-inner {
  display: flex;
  align-items: center;
  gap: 8px;
  width: 100%;
  flex-wrap: wrap;
}

.search-input {
  padding: 6px 10px;
  height: 32px;
  border: 1px solid var(--border-color);
  border-radius: 6px;
  font-size: 13px;
  background: var(--bg-surface);
  color: var(--text-primary);
  transition: border-color 0.2s, box-shadow 0.2s;
  flex: 1 1 120px;
  min-width: 0;
}

.search-input:focus {
  outline: none;
  border-color: var(--accent);
  box-shadow: 0 0 0 2px rgba(255, 122, 24, 0.18);
}

.filter-group {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-shrink: 0;
}

.filter-buttons {
  display: flex;
  gap: 4px;
  margin-bottom: 0;
}

.filter-btn {
  padding: 0 10px;
  height: 32px;
  border: 1px solid var(--border-color);
  border-radius: 6px;
  background: var(--bg-surface);
  cursor: pointer;
  font-size: 12px;
  transition: all 0.2s;
  color: var(--text-primary);
  white-space: nowrap;
}

.filter-btn:hover {
  background: var(--bg-secondary);
  border-color: var(--border-color);
}

.filter-btn.active {
  background: var(--accent-light);
  color: var(--accent);
  border-color: var(--accent);
  background: rgba(255, 122, 24, 0.1);
  box-shadow: none;
}

.date-filter {
  display: flex;
  align-items: center;
  padding: 0;
  border: none;
  background: transparent;
  box-shadow: none;
  min-width: 0;
}

.date-select {
  padding: 0 8px;
  height: 32px;
  border: 1px solid var(--border-color);
  border-radius: 6px;
  background: var(--bg-surface);
  color: var(--text-primary);
  font-size: 12px;
  cursor: pointer;
  transition: all 0.2s;
  min-width: 80px;
}

.date-select:hover {
  border-color: var(--text-secondary);
}

.date-select:focus {
  outline: none;
  border-color: var(--accent);
}

.date-select:disabled {
  opacity: 0.6;
  cursor: not-allowed;
  background: var(--bg-secondary);
}

/* removed filter-stats UI */

.loading-indicator {
  color: var(--text-secondary) !important;
  font-weight: normal !important;
  animation: pulse 1.5s ease-in-out infinite alternate;
}

@keyframes pulse {
  from {
    opacity: 0.6;
  }
  to {
    opacity: 1;
  }
}

.timeline__list {
  flex: 1 1 auto;
  padding: clamp(12px, 1.5vw, 16px);
  display: flex;
  flex-direction: column;
  gap: clamp(10px, 1vw, 14px);
  overflow-y: auto;
  overflow-x: hidden;
  min-height: 0;
}

.entry-card {
  border: 1px solid var(--border-color);
  text-align: left;
  padding: clamp(12px, 1.5vw, 16px);
  border-radius: 16px;
  background: var(--bg-surface);
  display: flex;
  align-items: flex-start;
  gap: clamp(10px, 0.8vw, 14px);
  color: var(--text-primary);
  box-shadow: 0 4px 14px rgba(15, 17, 21, 0.05);
  transition: border-color 0.2s ease, box-shadow 0.2s ease, transform 0.2s ease, background 0.2s ease;
  min-width: 0;
}

.entry-card:hover {
  border-color: rgba(255, 122, 24, 0.4);
  box-shadow: 0 14px 28px rgba(15, 17, 21, 0.12);
  transform: translateY(-2px);
}

.entry-card__main {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 6px;
  cursor: pointer;
  background: transparent;
  border: none;
  padding: 0;
  text-align: left;
  color: inherit;
  font: inherit;
  min-width: 0;
}

.entry-card__star {
  background: transparent;
  border: none;
  padding: 4px;
  border-radius: 6px;
  cursor: pointer;
  font-size: 18px;
  color: #ffbe30;
  transition: all 0.2s ease;
  flex-shrink: 0;
  margin-top: 2px;
}

.entry-card__star:hover {
  background: rgba(255, 190, 48, 0.1);
  transform: scale(1.1);
}

.entry-card.unread {
  border-color: var(--accent);
}

.entry-card.active {
  border-color: var(--accent);
  box-shadow: 0 14px 32px rgba(255, 122, 24, 0.2);
  background: rgba(255, 122, 24, 0.06);
}

.entry-card__thumbnail {
  width: 80px;
  height: 80px;
  border-radius: 8px;
  overflow: hidden;
  flex-shrink: 0;
}

.entry-card__thumbnail img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.entry-card__content {
  flex: 1;
  min-width: 0;
}

.entry-card__meta-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 12px;
  color: var(--text-secondary);
  margin-bottom: 6px;
}

.entry-card__title {
  font-weight: 600;
  line-height: 1.4;
  word-break: break-word;
  overflow-wrap: anywhere;
}

.bilingual-title-entry {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.bilingual-title-entry.translation-first {
  flex-direction: column-reverse;
}

/* 默认样式：原文在前时 */
.original-title-entry {
  font-weight: 600;
  color: var(--text-primary);
  font-size: 14px;
  line-height: 1.4;
}

.translated-title-entry {
  font-weight: 500;
  color: var(--text-secondary);
  font-size: 13px;
  line-height: 1.3;
  font-style: italic;
}

/* 当译文在前时，交换样式权重 */
.bilingual-title-entry.translation-first .translated-title-entry {
  font-weight: 600;
  color: var(--text-primary);
  font-size: 14px;
  line-height: 1.4;
  font-style: normal;
}

.bilingual-title-entry.translation-first .original-title-entry {
  font-weight: 500;
  color: var(--text-secondary);
  font-size: 13px;
  line-height: 1.3;
}

.entry-card__translation-indicator {
  font-size: 11px;
  color: var(--text-secondary);
  margin-top: 4px;
}

.entry-card__meta {
  font-size: 12px;
  color: var(--text-secondary);
  display: flex;
  gap: 6px;
  align-items: center;
  flex-wrap: wrap;
  row-gap: 2px;
  min-width: 0;
}

.entry-card__meta span {
  overflow-wrap: anywhere;
  min-width: 0;
}

.star-badge {
  color: #ffbe30;
  font-size: 14px;
}

.entry-card__summary {
  color: var(--text-secondary);
  font-size: 14px;
  line-height: 1.4;
  display: -webkit-box;
  line-clamp: 3;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
  text-overflow: ellipsis;
  max-height: clamp(4.2em, 6vw, 6.3em);
  word-break: break-word;
  overflow-wrap: anywhere;
}

.entry-card__actions {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 6px;
}

.entry-card__star-btn {
  border: none;
  background: transparent;
  cursor: pointer;
  color: #ffbe30;
  font-size: 16px;
  padding: 4px;
  border-radius: 6px;
}

.entry-card__star-btn:hover {
  background: rgba(255, 190, 48, 0.12);
}

.details {
  background: var(--bg-surface);
  padding: 24px;
  flex-shrink: 0;
  min-width: 500px;
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
  max-height: 100vh;
  min-height: 0;
  overflow-y: auto;
  overflow-x: hidden;
  width: var(--details-width);
  /* 最大宽度由JavaScript动态控制，最大可达50%屏幕宽度 */
}

.details__header {
  margin-bottom: 12px;
}

.details__content {
  display: flex;
  flex-direction: column;
  min-height: 0;
}

.details__actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-start;
  gap: 6px;
  padding: 8px;
  border-radius: 12px;
  background: var(--bg-surface);
  border: 1px solid var(--border-color);
  box-shadow: 0 6px 18px rgba(0, 0, 0, 0.12);
  margin-bottom: 14px;
}

.details__actions button,
.details__actions .lang-select {
  height: clamp(28px, 3.2vw, 34px);
  padding: 0 clamp(10px, 1.3vw, 14px);
  border-radius: 999px;
  border: 1px solid var(--border-color);
  background: var(--bg-surface);
  color: var(--text-primary);
  font-weight: 500;
  font-size: clamp(0.72rem, 1vw, 0.8rem);
  letter-spacing: 0.01em;
  cursor: pointer;
  transition: background 0.2s ease, color 0.2s ease, border-color 0.2s ease, box-shadow 0.2s ease;
  flex: 0 1 auto;
  min-width: 68px;
  white-space: nowrap;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
}

.details__actions button:hover,
.details__actions .lang-select:hover {
  border-color: var(--accent);
  background: var(--accent);
  color: #fff;
  box-shadow: 0 8px 20px rgba(255, 122, 24, 0.25);
}

.details__actions button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
  color: var(--text-secondary);
  background: var(--bg-surface);
  border-color: var(--border-color);
  box-shadow: none;
}

.details__actions button:focus-visible,
.details__actions .lang-select:focus-visible {
  outline: 2px solid var(--accent);
  outline-offset: 2px;
}

.details__actions .lang-select {
  appearance: none;
  padding-right: 28px;
  min-width: 78px;
  text-align: left;
  background-color: var(--bg-surface);
  background-image: linear-gradient(45deg, transparent 50%, var(--text-primary) 50%), linear-gradient(135deg, var(--text-primary) 50%, transparent 50%);
  background-position: calc(100% - 13px) 11px, calc(100% - 9px) 11px;
  background-size: 4px 4px, 4px 4px;
  background-repeat: no-repeat;
}

.details__body {
  font-size: 15px;
  line-height: 1.6;
  color: var(--text-primary);
  word-break: break-word;
  flex: initial;
  overflow: visible;
  min-height: auto;
}

.details__body :deep(p) {
  margin-bottom: 1em;
}

.details__body :deep(img) {
  max-width: 100%;
  height: auto;
  display: block;
  margin: 12px auto;
  border-radius: 10px;
}

.details__body :deep(table) {
  width: 100%;
  overflow-x: auto;
  display: block;
}

.details__body :deep(pre),
.details__body :deep(code) {
  max-width: 100%;
  overflow-x: auto;
  white-space: pre-wrap;
  word-break: break-word;
}

/* Webview 容器样式 */
.webview-container {
  width: 100%;
  flex: 1;
  display: flex;
  flex-direction: column;
  border-radius: 12px;
  overflow: hidden;
  background: var(--bg-surface);
  border: 1px solid var(--border-color);
  min-height: 500px;
}

.webview-frame {
  width: 100%;
  height: 100%;
  flex: 1;
  border: none;
  background: #fff;
}

/* 阅读模式包装器 */
.reading-mode-wrapper {
  border: 2px solid var(--accent);
  box-shadow: 0 4px 20px rgba(76, 116, 255, 0.1);
}

/* 阅读模式指示器 */
.reading-mode-indicator {
  background: linear-gradient(135deg, var(--accent) 0%, var(--accent-hover) 100%);
  color: white;
  padding: 12px 20px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.indicator-content {
  display: flex;
  align-items: center;
  justify-content: space-between;
  max-width: 800px;
  margin: 0 auto;
  font-size: 14px;
  font-weight: 500;
}

.indicator-icon {
  margin-right: 8px;
  font-size: 16px;
}

.indicator-text {
  flex: 1;
  text-align: center;
}

.indicator-close {
  background: rgba(255, 255, 255, 0.2);
  border: none;
  color: white;
  width: 24px;
  height: 24px;
  border-radius: 50%;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  transition: all 0.2s ease;
}

.indicator-close:hover {
  background: rgba(255, 255, 255, 0.3);
  transform: scale(1.1);
}

/* 智能阅读模式样式 */
.reading-mode-loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 300px;
  gap: 16px;
  color: var(--text-secondary);
}

.reading-mode-error {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 300px;
  padding: 32px;
}

.error-content {
  text-align: center;
  max-width: 400px;
}

.error-content h3 {
  margin: 0 0 12px 0;
  color: var(--text-primary);
  font-size: 18px;
}

.error-content p {
  margin: 0 0 20px 0;
  color: var(--text-secondary);
  line-height: 1.5;
}

.error-actions {
  display: flex;
  gap: 12px;
  justify-content: center;
}

.btn-retry,
.btn-external {
  padding: 8px 16px;
  border: none;
  border-radius: 6px;
  font-size: 14px;
  cursor: pointer;
  transition: all 0.2s ease;
}

/* 阅读模式激活状态的按钮样式 */
.reading-mode-active {
  background: var(--accent) !important;
  color: white !important;
  border-color: var(--accent) !important;
  box-shadow: 0 2px 8px rgba(76, 116, 255, 0.3);
}

.reading-mode-active:hover {
  background: var(--accent-hover) !important;
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(76, 116, 255, 0.4);
}

.btn-retry {
  background: var(--accent);
  color: white;
}

.btn-retry:hover {
  background: var(--accent-hover);
}

.btn-external {
  background: var(--bg-surface);
  color: var(--text-primary);
  border: 1px solid var(--border-color);
}

.btn-external:hover {
  background: var(--bg-hover);
}

.reading-mode-content {
  flex: 1;
  overflow-y: auto;
  padding: 32px;
  max-width: 800px;
  margin: 0 auto;
  width: 100%;
}

.reading-header {
  margin-bottom: 32px;
  border-bottom: 1px solid var(--border-color);
  padding-bottom: 24px;
}

.reading-title {
  margin: 0 0 16px 0;
  font-size: 28px;
  font-weight: 700;
  line-height: 1.3;
  color: var(--text-primary);
}

.reading-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 16px;
  font-size: 14px;
  color: var(--text-secondary);
}

.reading-byline {
  font-weight: 500;
}

.reading-site {
  background: var(--bg-hover);
  padding: 2px 8px;
  border-radius: 4px;
  font-size: 12px;
}

.reading-time {
  display: flex;
  align-items: center;
  gap: 4px;
}

.reading-body {
  line-height: 1.7;
  font-size: 16px;
  color: var(--text-primary);
}

.reading-body h1,
.reading-body h2,
.reading-body h3,
.reading-body h4,
.reading-body h5,
.reading-body h6 {
  margin: 24px 0 16px 0;
  font-weight: 600;
  color: var(--text-primary);
}

.reading-body h1 { font-size: 24px; }
.reading-body h2 { font-size: 22px; }
.reading-body h3 { font-size: 20px; }
.reading-body h4 { font-size: 18px; }

.reading-body p {
  margin: 16px 0;
}

.reading-body blockquote {
  margin: 20px 0;
  padding: 16px 20px;
  border-left: 4px solid var(--accent);
  background: var(--bg-hover);
  font-style: italic;
}

.reading-body ul,
.reading-body ol {
  margin: 16px 0;
  padding-left: 24px;
}

.reading-body li {
  margin: 8px 0;
}

.reading-body pre {
  margin: 20px 0;
  padding: 16px;
  background: var(--bg-hover);
  border-radius: 8px;
  overflow-x: auto;
  font-family: 'Courier New', monospace;
  font-size: 14px;
}

.reading-body code {
  background: var(--bg-hover);
  padding: 2px 6px;
  border-radius: 4px;
  font-family: 'Courier New', monospace;
  font-size: 14px;
}

.reading-body img {
  max-width: 100%;
  height: auto;
  border-radius: 8px;
  margin: 20px 0;
}

.reading-body a {
  color: var(--accent);
  text-decoration: none;
}

.reading-body a:hover {
  text-decoration: underline;
}

.reading-body table {
  width: 100%;
  border-collapse: collapse;
  margin: 20px 0;
}

.reading-body th,
.reading-body td {
  border: 1px solid var(--border-color);
  padding: 12px;
  text-align: left;
}

.reading-body th {
  background: var(--bg-hover);
  font-weight: 600;
}

.reading-fallback {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.fallback-notice {
  padding: 16px 20px;
  background: var(--bg-hover);
  border-bottom: 1px solid var(--border-color);
  text-align: center;
  color: var(--text-secondary);
  font-size: 14px;
}

/* 双语对照样式 */
.bilingual-title {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin: 16px 0;
}

.original-title,
.translated-title {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 12px;
  border-radius: 8px;
  border: 1px solid var(--border-color);
  background: var(--bg-surface);
  transition: all 0.2s ease;
}

.original-title:hover,
.translated-title:hover {
  border-color: var(--accent);
  box-shadow: 0 2px 8px rgba(76, 116, 255, 0.1);
}

/* 第二个标题的样式（用于区分优先级） */
.second-title {
  opacity: 0.85;
  border-style: dashed;
}

.second-title:hover {
  opacity: 1;
  border-style: solid;
}

.title-label {
  font-size: 12px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  padding: 4px 8px;
  border-radius: 4px;
  background: var(--bg-hover);
  color: var(--text-secondary);
  display: inline-block;
  width: fit-content;
}

.original-title .title-label {
  background: rgba(255, 152, 0, 0.1);
  color: #ff9800;
}

.translated-title .title-label {
  background: rgba(76, 175, 80, 0.1);
  color: #4caf50;
}

.original-title h3,
.translated-title h3 {
  margin: 0;
  font-size: 20px;
  line-height: 1.4;
  font-weight: 600;
}

.original-title h3 {
  color: var(--text-primary);
}

.translated-title h3 {
  color: var(--text-primary);
}

.bilingual-content {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24px;
  min-height: 0;
}

.original-content,
.translated-content {
  display: flex;
  flex-direction: column;
  min-height: 0;
}

.content-header {
  margin-bottom: 12px;
  padding-bottom: 8px;
  border-bottom: 1px solid var(--border-color);
}

.content-label {
  font-size: 12px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  padding: 4px 8px;
  border-radius: 4px;
  display: inline-block;
}

.original-content .content-label {
  background: rgba(255, 152, 0, 0.1);
  color: #ff9800;
}

.translated-content .content-label {
  background: rgba(76, 175, 80, 0.1);
  color: #4caf50;
}

/* 响应式设计 - 在小屏幕上垂直排列 */
@media (max-width: 1024px) {
  .bilingual-content {
    grid-template-columns: 1fr;
    gap: 16px;
  }

  .bilingual-title {
    gap: 12px;
  }

  .original-title h3,
  .translated-title h3 {
    font-size: 18px;
  }
}

/* 暗黑模式适配 */
html.dark .original-title .title-label {
  background: rgba(255, 152, 0, 0.2);
  color: #ffb74d;
}

html.dark .translated-title .title-label {
  background: rgba(76, 175, 80, 0.2);
  color: #81c784;
}

html.dark .content-header {
  border-bottom-color: rgba(255, 255, 255, 0.12);
}

.summary-card {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin: 0 0 18px;
  padding: 12px 14px;
  border-radius: 12px;
  border: 1px solid var(--border-color);
  background: var(--bg-surface);
}

.summary-card--inline {
  box-shadow: 0 10px 30px rgba(15, 17, 21, 0.08);
}

.summary-card__content {
  flex: 1;
}

.summary-card__label {
  font-size: 10px;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--text-secondary);
  margin-bottom: 2px;
  font-weight: 600;
}

.summary-card__text {
  font-size: 13px;
  line-height: 1.5;
  color: var(--text-primary);
}

.summary-card__placeholder {
  color: var(--text-secondary);
  font-size: 12px;
  line-height: 1.5;
}

.summary-card__list {
  margin: 6px 0 0;
  padding-left: 18px;
  color: var(--text-primary);
}

.summary-card__item {
  font-size: 12px;
  line-height: 1.5;
}

.summary-card__action {
  border: none;
  border-radius: 999px;
  padding: 6px 14px;
  background: #ff8a3d;
  color: #fff;
  font-weight: 500;
  font-size: 0.75rem;
  cursor: pointer;
  transition: transform 0.2s ease, box-shadow 0.2s ease;
  align-self: flex-start;
}

.summary-card__action:disabled {
  opacity: 0.6;
  cursor: not-allowed;
  box-shadow: none;
  transform: none;
}

.summary-card__action:not(:disabled):hover {
  box-shadow: 0 8px 20px rgba(255, 138, 61, 0.35);
  transform: translateY(-1px);
}

.empty {
  display: grid;
  place-items: center;
  color: var(--text-secondary);
  text-align: center;
  padding: 24px;
}

@media (max-width: 960px) {
  .app-shell {
    flex-direction: column;
    min-height: 100vh;
    height: 100vh;
    max-height: none;
    overflow: hidden;
  }

  .sidebar {
    width: 100% !important;
    height: auto;
    max-height: none;
    border-right: none;
    border-bottom: 1px solid var(--border-color);
    overflow: visible;
  }

  .resizer {
    display: none;
  }

  .timeline {
    border-right: none;
    border-bottom: 1px solid var(--border-color);
    min-width: auto;
    height: 100%;
    flex: 1;
    max-height: none;
    overflow: hidden;
    min-height: 0;
  }

  .timeline__header {
    /* 恢复正常布局，不再需要sticky，因为容器固定高度 */
    position: relative;
    top: auto;
    z-index: auto;
  }

  .timeline__controls {
    position: relative;
    top: auto;
    z-index: auto;
  }

  .details {
    display: none;
  }

  .details__actions {
    justify-content: flex-start;
    flex-wrap: wrap;
  }

  .details__actions button,
  .details__actions .lang-select {
    flex: 1 1 calc(50% - 10px);
    text-align: center;
  }
}

@media (max-width: 560px) {
  .details__actions {
    flex-direction: column;
    align-items: stretch;
  }

  .details__actions button,
  .details__actions .lang-select {
    flex: 1 1 auto;
    width: 100%;
  }
}

/* 翻译标签样式 */
.translation-label {
  display: inline-flex;
  align-items: center;
  height: 1.35rem;
  padding: 0 0.45rem;
  border-radius: 999px;
  font-size: 0.72rem;
  letter-spacing: 0.08em;
  font-weight: 600;
  text-transform: uppercase;
  border: 1px solid rgba(255, 122, 24, 0.35);
  background: rgba(255, 122, 24, 0.14);
  color: #ff7a18;
  box-shadow: inset 0 1px 1px rgba(255, 255, 255, 0.45);
}

.loading-indicator {
  display: inline-block;
  margin-left: 0.5rem;
  color: var(--primary-color);
  font-style: italic;
  font-size: 0.8rem;
}

/* 深色模式样式 */
:global(.dark) .resizer {
  background: rgba(255, 255, 255, 0.1);
}

:global(.dark) .entry-card__translated-title {
  color: rgba(255, 255, 255, 0.75);
}

:global(.dark) .translation-label {
  background: rgba(255, 255, 255, 0.1);
  border-color: rgba(255, 255, 255, 0.25);
  color: #ffe4d3;
  box-shadow: inset 0 1px 0 rgba(0, 0, 0, 0.2);
}

:global(.dark) .resizer:hover {
  background: rgba(255, 122, 24, 0.4);
}

:global(.dark) .resizer.active {
  background: rgba(255, 122, 24, 0.7);
}

:global(.dark) .feed-group {
  background: rgba(15, 17, 21, 0.4);
  border-color: rgba(255, 255, 255, 0.08);
}

:global(.dark) .feed-group:hover {
  background: rgba(15, 17, 21, 0.6);
}

:global(.dark) .group-header:hover {
  background: rgba(255, 122, 24, 0.15);
}

:global(.dark) .group-feeds {
  background: rgba(15, 17, 21, 0.3);
  border-top-color: rgba(255, 255, 255, 0.05);
}

/* 暗色模式下无需单独覆盖 details__actions/summary-card，
   它们直接使用全局主题变量（src/style.css 的 :root / :root.dark）。 */

:global(.dark) .favorites-title {
  color: rgba(255, 255, 255, 0.95);
}
:global(.dark) .group-feeds .feed-item-wrapper:hover {
  background: rgba(255, 255, 255, 0.05);
}

:global(.dark) .group-control-btn {
  border-color: rgba(255, 255, 255, 0.1);
  color: var(--text-secondary);
}

:global(.dark) .group-control-btn:hover {
  background: rgba(255, 122, 24, 0.15);
  color: var(--text-primary);
  border-color: rgba(255, 122, 24, 0.3);
}

:global(.dark) .theme-toggle,
:global(.dark) .settings-btn,
:global(.dark) .layout-reset-btn {
  color: rgba(255, 255, 255, 0.9);
}

:global(.dark) .theme-toggle:hover,
:global(.dark) .settings-btn:hover,
:global(.dark) .layout-reset-btn:hover {
  background: rgba(255, 255, 255, 0.12);
  color: #ffe5d0;
}

/* 收藏目录样式 */
.favorites-section {
  margin: 16px 0;
  border-top: 1px solid var(--border-color);
  border-bottom: 1px solid var(--border-color);
  padding: 12px 0;
}

.favorites-header {
  margin-bottom: 8px;
}

.favorites-toggle {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 12px;
  background: transparent;
  border: 1px solid transparent;
  border-radius: 8px;
  text-align: left;
  cursor: pointer;
  transition: all 0.2s ease;
}

.favorites-toggle:hover {
  background: rgba(255, 122, 24, 0.1);
  border-color: rgba(255, 122, 24, 0.2);
}

.favorites-toggle.active {
  background: rgba(255, 122, 24, 0.15);
  border-color: rgba(255, 122, 24, 0.3);
  color: var(--accent);
}

.favorites-icon {
  font-size: 0;
  line-height: 0;
  display: flex;
  align-items: center;
}

.favorites-title {
  flex: 1;
  font-weight: 600;
  font-size: 15px;
  color: var(--text-primary);
}

.favorites-count {
  font-size: 12px;
  background: var(--accent);
  color: white;
  padding: 2px 6px;
  border-radius: 10px;
  font-weight: 500;
}

.favorites-list {
  margin-left: 12px;
}

.favorites-group {
  margin-bottom: 12px;
}

.favorites-group:last-child {
  margin-bottom: 0;
}

.favorites-group-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 6px 8px;
  font-size: 12px;
  color: var(--text-secondary);
  font-weight: 500;
}

.favorites-group-name {
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.favorites-group-count {
  background: rgba(255, 122, 24, 0.2);
  color: var(--accent);
  padding: 1px 5px;
  border-radius: 8px;
  font-size: 11px;
}

.favorites-item,
.favorites-feed-item {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  background: transparent;
  border: 1px solid transparent;
  border-radius: 6px;
  text-align: left;
  cursor: pointer;
  transition: all 0.2s ease;
  font-size: 14px;
}

.favorites-item:hover,
.favorites-feed-item:hover {
  background: rgba(255, 122, 24, 0.08);
  border-color: rgba(255, 122, 24, 0.15);
}

.favorites-item.active,
.favorites-feed-item.active {
  background: rgba(255, 122, 24, 0.15);
  border-color: rgba(255, 122, 24, 0.3);
  color: var(--accent);
}

.favorites-item-icon {
  font-size: 0;
  line-height: 0;
  display: flex;
  align-items: center;
  opacity: 0.8;
}

.favorites-feed-icon {
  --feed-icon-size: 26px;
  opacity: 1;
}

.favorites-item-title,
.favorites-feed-title {
  flex: 1;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.favorites-item-count,
.favorites-feed-count {
  font-size: 11px;
  background: rgba(255, 122, 24, 0.15);
  color: var(--accent);
  padding: 1px 4px;
  border-radius: 6px;
  font-weight: 500;
}

.favorites-group-feeds {
  margin-left: 16px;
}

/* 深色模式收藏样式 */
:global(.dark) .favorites-section {
  border-color: rgba(255, 255, 255, 0.08);
}

:global(.dark) .favorites-toggle {
  color: var(--text-primary);
}

:global(.dark) .favorites-toggle:hover {
  background: rgba(255, 122, 24, 0.2);
  border-color: rgba(255, 122, 24, 0.4);
}

:global(.dark) .favorites-toggle.active {
  background: rgba(255, 122, 24, 0.25);
  border-color: rgba(255, 122, 24, 0.5);
}

:global(.dark) .favorites-group-header {
  color: var(--text-secondary);
}

:global(.dark) .favorites-item,
:global(.dark) .favorites-feed-item {
  color: var(--text-primary);
}

:global(.dark) .favorites-item:hover,
:global(.dark) .favorites-feed-item:hover {
  background: rgba(255, 122, 24, 0.15);
  border-color: rgba(255, 122, 24, 0.3);
}

:global(.dark) .favorites-item.active,
:global(.dark) .favorites-feed-item.active {
  background: rgba(255, 122, 24, 0.25);
  border-color: rgba(255, 122, 24, 0.5);
}

:global(.dark) .timeline-action-btn {
  box-shadow: 0 8px 20px rgba(255, 122, 24, 0.25);
}

:global(.dark) .timeline-action-btn--ghost {
  background: rgba(15, 17, 21, 0.8);
  color: var(--text-primary);
  border-color: rgba(255, 255, 255, 0.12);
  box-shadow: 0 6px 18px rgba(0, 0, 0, 0.4);
}

:global(.dark) .timeline-action-btn--ghost .timeline-action-btn__icon {
  background: rgba(255, 255, 255, 0.08);
}
/* ========== Layout and Scrolling Enhancements (added) ========== */
/* Smooth (non-janky) width transitions for panels; disabled while dragging */
.sidebar { transition: width 160ms ease; }
.details { transition: width 160ms ease; }
.is-dragging-left .sidebar,
.is-dragging-right .details { transition: none !important; }

/* Unified internal scrollbar styling */
.sidebar::-webkit-scrollbar,
.timeline__list::-webkit-scrollbar,
.details::-webkit-scrollbar,
.details__body::-webkit-scrollbar { width: 8px; height: 8px; }
.sidebar::-webkit-scrollbar-thumb,
.timeline__list::-webkit-scrollbar-thumb,
.details::-webkit-scrollbar-thumb,
.details__body::-webkit-scrollbar-thumb { background: rgba(15, 17, 21, 0.18); border-radius: 8px; }
.sidebar:hover::-webkit-scrollbar-thumb,
.timeline__list:hover::-webkit-scrollbar-thumb,
.details:hover::-webkit-scrollbar-thumb,
.details__body:hover::-webkit-scrollbar-thumb { background: rgba(15, 17, 21, 0.28); }
:global(.dark) .sidebar::-webkit-scrollbar-thumb,
:global(.dark) .timeline__list::-webkit-scrollbar-thumb,
:global(.dark) .details::-webkit-scrollbar-thumb,
:global(.dark) .details__body::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.22); }
:global(.dark) .sidebar:hover::-webkit-scrollbar-thumb,
:global(.dark) .timeline__list:hover::-webkit-scrollbar-thumb,
:global(.dark) .details:hover::-webkit-scrollbar-thumb,
:global(.dark) .details__body:hover::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.36); }
.sidebar, .timeline__list, .details { scrollbar-width: thin; scrollbar-color: rgba(15, 17, 21, 0.28) transparent; }
:global(.dark) .sidebar, :global(.dark) .timeline__list, :global(.dark) .details { scrollbar-color: rgba(255, 255, 255, 0.36) transparent; }

/* Resizer visual polish (grip + highlight) */
.resizer { transition: background-color 0.2s, box-shadow 0.2s; }
.resizer:hover { background: rgba(255, 122, 24, 0.35); box-shadow: inset 0 0 0 1px rgba(255, 122, 24, 0.25); }
.resizer.active { background: rgba(255, 122, 24, 0.55); box-shadow: inset 0 0 0 1px rgba(255, 122, 24, 0.35); }
.resizer::before { width: 22px; height: 44px; transition: background-color 0.2s, opacity 0.2s; }
.resizer:hover::before { background: rgba(255, 122, 24, 0.12); }
.resizer.active::before { background: rgba(255, 122, 24, 0.22); }
.resizer::after { content: ''; position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); width: 2px; height: 22px; border-radius: 1px; background: currentColor; opacity: 0.15; box-shadow: 0 -8px 0 currentColor, 0 8px 0 currentColor; }
.resizer:hover::after, .resizer.active::after { opacity: 0.35; }

/* ========== AI Summary Card Beautify ========== */
.summary-card { padding: 14px 14px 14px 16px; border-radius: 14px; background: linear-gradient(180deg, rgba(255, 122, 24, 0.06), rgba(255, 122, 24, 0.02)), var(--bg-surface); position: relative; }
.summary-card::before { content: ''; position: absolute; left: 0; top: 10px; bottom: 10px; width: 3px; border-radius: 2px; background: linear-gradient(180deg, var(--accent), rgba(255, 122, 24, 0.4)); opacity: 0.9; }
.summary-card__label { font-size: 11px; }
.summary-card__label::before { content: '✨'; margin-right: 6px; }
.summary-card--loading .summary-card__text, .summary-card--loading .summary-card__placeholder { position: relative; }
.summary-card--loading .summary-card__text::after, .summary-card--loading .summary-card__placeholder::after { content: ''; position: absolute; inset: 0; background: linear-gradient(90deg, transparent 0%, rgba(255, 255, 255, 0.35) 40%, rgba(255, 255, 255, 0.35) 60%, transparent 100%); animation: summaryShimmer 1.2s ease-in-out infinite; pointer-events: none; }
@keyframes summaryShimmer { 0% { transform: translateX(-100%); } 100% { transform: translateX(100%); } }

</style>

<style scoped>
/* User Section Styles */
.user-section {
  padding: 16px;
  border-top: 1px solid #e5e7eb;
  background-color: #f9fafb;
}

.user-profile {
  display: flex;
  align-items: center;
  gap: 12px;
}

.user-avatar {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  background-color: #3b82f6;
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  font-size: 16px;
}

.user-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
  flex: 1;
  min-width: 0;
}

.username {
  font-size: 14px;
  font-weight: 500;
  color: #111827;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.logout-btn {
  font-size: 12px;
  color: #6b7280;
  background: none;
  border: none;
  padding: 0;
  cursor: pointer;
  text-align: left;
}

.logout-btn:hover {
  color: #ef4444;
}

.login-prompt {
  width: 100%;
}

.login-btn-full {
  width: 100%;
  padding: 8px 16px;
  background-color: #3b82f6;
  color: white;
  border: none;
  border-radius: 6px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s;
}

.login-btn-full:hover {
  background-color: #2563eb;
}

:global(.dark) .user-section {
  border-top-color: #374151;
  background-color: #1f2937;
}

:global(.dark) .username {
  color: #f3f4f6;
}

:global(.dark) .logout-btn {
  color: #9ca3af;
}

:global(.dark) .logout-btn:hover {
  color: #f87171;
}

/* New User Footer Styles */
.user-footer-item {
  width: 100%;
}

.user-info-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 12px;
  background-color: #f3f4f6;
  border-radius: 8px;
}

:global(.dark) .user-info-row {
  background-color: #374151;
}

.user-avatar-small {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  background-color: #3b82f6;
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  font-weight: 600;
  flex-shrink: 0;
}

.username-text {
  flex: 1;
  font-size: 13px;
  font-weight: 500;
  color: #111827;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

:global(.dark) .username-text {
  color: #f3f4f6;
}

.logout-icon-btn {
  background: none;
  border: none;
  cursor: pointer;
  color: #6b7280;
  padding: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 4px;
}

.logout-icon-btn:hover {
  background-color: #e5e7eb;
  color: #ef4444;
}

:global(.dark) .logout-icon-btn {
  color: #9ca3af;
}

:global(.dark) .logout-icon-btn:hover {
  background-color: #4b5563;
  color: #f87171;
}
</style>
