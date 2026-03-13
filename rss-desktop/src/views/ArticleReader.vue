<script setup lang="ts">
import { ref, onMounted, computed, onUnmounted, watch, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useFeedStore } from '../stores/feedStore'
import { useSettingsStore } from '../stores/settingsStore'
import { useI18n } from 'vue-i18n'
import api from '../api/client'
import type { Entry, SummaryResult } from '../types'
import LoadingSpinner from '../components/LoadingSpinner.vue'
import { readingModeHandler } from '../utils/readingMode'
import type { ReadableArticle } from '../utils/readingMode'
import dayjs from 'dayjs'
import localizedFormat from 'dayjs/plugin/localizedFormat'

dayjs.extend(localizedFormat)

const route = useRoute()
const router = useRouter()
const store = useFeedStore()
const settingsStore = useSettingsStore()
const { t } = useI18n()

const entry = ref<Entry | null>(null)
const loading = ref(true)
const error = ref<string | null>(null)
const rssRawHtml = ref<string>('')
const originalUrl = ref<string | null>(null)
const originalArticle = ref<ReadableArticle | null>(null)
const originalRawHtml = ref<string>('')
const originalLoading = ref(false)
const originalError = ref<string | null>(null)
const contentMode = ref<'rss' | 'original'>('rss')
const userSelectedMode = ref(false)
const displayHtml = ref<string>('')

// TOC State
const toc = ref<{ id: string; text: string; level: number }[]>([])
const showToc = ref(false)

// AI Summary State
const summaryLoading = ref(false)
const aiSummary = ref<string | null>(null)
const aiKeyPoints = ref<string[]>([])
const showAiPanel = ref(true)

// Reading settings
const fontSize = ref(parseInt(localStorage.getItem('reader_fontSize') || '18'))
const lineHeight = ref(parseFloat(localStorage.getItem('reader_lineHeight') || '1.8'))
const maxWidth = ref(800)
const fontFamily = ref<'serif' | 'sans' | 'mono'>((localStorage.getItem('reader_fontFamily') as any) || 'serif')
const themeMode = ref<'light' | 'dark' | 'sepia'>((localStorage.getItem('reader_themeMode') as any) || 'light')

// Persist settings
watch([fontSize, lineHeight, fontFamily, themeMode], () => {
  localStorage.setItem('reader_fontSize', fontSize.value.toString())
  localStorage.setItem('reader_lineHeight', lineHeight.value.toString())
  localStorage.setItem('reader_fontFamily', fontFamily.value)
  localStorage.setItem('reader_themeMode', themeMode.value)
})

// Sync with global dark mode initially if no local pref
onMounted(() => {
  if (!localStorage.getItem('reader_themeMode')) {
    themeMode.value = settingsStore.isDarkMode ? 'dark' : 'light'
  }
})

// Scroll behavior for toolbar
const showToolbar = ref(true)
let lastScrollTop = 0

// Progress tracking
const scrollProgress = ref(0)
const contentRef = ref<HTMLElement | null>(null)

const formattedDate = computed(() => {
  if (!entry.value?.published_at) return ''
  return dayjs(entry.value.published_at).format('LL HH:mm')
})

function textLengthFromHtml(html: string): number {
  const div = document.createElement('div')
  div.innerHTML = html
  return (div.textContent || '').replace(/\s+/g, ' ').trim().length
}

const wordCount = computed(() => textLengthFromHtml(displayHtml.value))

const readingTime = computed(() => {
  if (!displayHtml.value) return 0
  return Math.ceil(textLengthFromHtml(displayHtml.value) / 500)
})

const contentStyle = computed(() => ({
  fontSize: `${fontSize.value}px`,
  lineHeight: lineHeight.value,
  maxWidth: `${maxWidth.value}px`,
  fontFamily: fontFamily.value === 'serif' 
    ? "'Merriweather', 'Georgia', serif" 
    : fontFamily.value === 'sans' 
      ? "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"
      : "'Menlo', 'Monaco', 'Courier New', monospace"
}))

async function loadEntry() {
  const id = route.params.id as string
  if (!id) {
    error.value = 'Invalid Article ID'
    loading.value = false
    return
  }

  // Try to find in store first
  const cached = store.entries.find(e => e.id === id)
  if (cached) {
    entry.value = cached
    const raw = cached.content || cached.summary || ''
    rssRawHtml.value = raw
    setDisplayFromRaw(raw)
    initOriginal(cached)
    loading.value = false
    checkCachedSummary(id)
    markAsRead(cached)
    return
  }

  // Fetch from API
  try {
    const { data } = await api.get<Entry>(`/entries/${id}`)
    entry.value = data
    const raw = data.content || data.summary || ''
    rssRawHtml.value = raw
    setDisplayFromRaw(raw)
    initOriginal(data)
    checkCachedSummary(id)
    markAsRead(data)
  } catch (err) {
    console.error(err)
    error.value = 'Failed to load article'
  } finally {
    loading.value = false
  }
}

function setDisplayFromRaw(rawHtml: string) {
  if (!rawHtml) {
    displayHtml.value = ''
    toc.value = []
    return
  }
  const { html, items } = generateToc(rawHtml)
  displayHtml.value = html
  toc.value = items
}

function generateToc(html: string) {
  const div = document.createElement('div')
  div.innerHTML = html
  const items: { id: string; text: string; level: number }[] = []
  
  const headers = div.querySelectorAll('h1, h2, h3, h4')
  headers.forEach((header, index) => {
    const id = `heading-${index}`
    header.id = id
    items.push({
      id,
      text: header.textContent || '',
      level: parseInt(header.tagName.substring(1))
    })
  })
  
  return { html: div.innerHTML, items }
}

function isHttpUrl(url: string): boolean {
  try {
    const u = new URL(url)
    return u.protocol === 'http:' || u.protocol === 'https:'
  } catch {
    return false
  }
}

function extractOriginalUrl(e: Entry): string | null {
  if (e.url && isHttpUrl(e.url)) return e.url

  const candidates = [e.summary, e.content].filter(Boolean) as string[]
  for (const html of candidates) {
    try {
      const doc = new DOMParser().parseFromString(html, 'text/html')
      const a = doc.querySelector('a[href]')
      const href = a?.getAttribute('href') || ''
      if (href && isHttpUrl(href)) return href
    } catch {
    }

    const m = html.match(/https?:\/\/[^\s"'<>()[\]]+/i)
    if (m?.[0] && isHttpUrl(m[0])) return m[0]
  }

  return null
}

const originalLink = computed(() => originalUrl.value || entry.value?.url || null)

async function initOriginal(e: Entry) {
  originalUrl.value = extractOriginalUrl(e)
  originalArticle.value = null
  originalRawHtml.value = ''
  originalError.value = null
  originalLoading.value = false
  contentMode.value = 'rss'
  userSelectedMode.value = false
  if (originalUrl.value) {
    await loadOriginal(false)
  }
}

async function loadOriginal(force: boolean) {
  if (!originalUrl.value) return
  if (originalLoading.value) return
  originalLoading.value = true
  originalError.value = null
  try {
    const article = await readingModeHandler.extractArticle(originalUrl.value, { force })
    if (!article?.content) {
      throw new Error('无法提取正文')
    }
    originalArticle.value = article
    originalRawHtml.value = article.content
    if (!userSelectedMode.value) {
      contentMode.value = 'original'
    }
    if (contentMode.value === 'original') {
      setDisplayFromRaw(originalRawHtml.value)
    }
  } catch (e: any) {
    const status = e?.response?.status
    if (status === 403) originalError.value = 'robots.txt 禁止抓取'
    else if (status === 415) originalError.value = '原文不是可解析的 HTML'
    else if (status === 429) originalError.value = '触发访问限制，稍后再试'
    else if (status === 502) originalError.value = '网络请求失败'
    else if (typeof status === 'number') originalError.value = `加载失败（HTTP ${status}）`
    else originalError.value = e?.message || '加载失败'
  } finally {
    originalLoading.value = false
  }
}

function selectMode(mode: 'rss' | 'original') {
  userSelectedMode.value = true
  contentMode.value = mode
  if (mode === 'rss') {
    setDisplayFromRaw(rssRawHtml.value)
    return
  }
  if (originalRawHtml.value) {
    setDisplayFromRaw(originalRawHtml.value)
    return
  }
  if (originalUrl.value && !originalLoading.value) {
    void loadOriginal(false)
  }
}

function refreshOriginal() {
  if (!originalUrl.value) return
  userSelectedMode.value = true
  contentMode.value = 'original'
  void loadOriginal(true)
}

function scrollToId(id: string) {
  const el = document.getElementById(id)
  if (el) {
    const toolbarHeight = 80
    const top = el.getBoundingClientRect().top + window.scrollY - toolbarHeight
    window.scrollTo({ top, behavior: 'smooth' })
    if (window.innerWidth < 1000) {
      showToc.value = false
    }
  }
}

function checkCachedSummary(id: string) {
  if (store.summaryCache[id]) {
    const cached = store.summaryCache[id]
    aiSummary.value = cached.summary
    aiKeyPoints.value = cached.key_points || []
  } else {
    // Optionally auto-generate? Let's just allow manual generation for now to save tokens, 
    // or maybe auto-generate if user enabled "Auto AI" (future feature).
    // For now, we will leave it empty and let user click "Generate" if they want, 
    // OR if we already have it in the store's cache from the list view.
  }
}

async function handleGenerateSummary() {
  if (!entry.value) return
  
  summaryLoading.value = true
  try {
    const result = await store.requestSummary(entry.value.id)
    aiSummary.value = result.summary
    aiKeyPoints.value = result.key_points || []
  } catch (err) {
    console.error('Failed to generate summary', err)
  } finally {
    summaryLoading.value = false
  }
}

function markAsRead(e: Entry) {
  if (!e.read) {
    store.toggleEntryState(e, { read: true })
  }
}

function toggleStar() {
  if (!entry.value) return
  store.toggleEntryState(entry.value, { starred: !entry.value.starred })
}

function handleScroll() {
  const scrollTop = window.scrollY
  const docHeight = document.body.scrollHeight - window.innerHeight
  if (docHeight > 0) {
    scrollProgress.value = Math.min(100, Math.max(0, (scrollTop / docHeight) * 100))
  }
  
  // Toolbar auto-hide
  if (scrollTop > lastScrollTop && scrollTop > 100) {
    showToolbar.value = false
  } else {
    showToolbar.value = true
  }
  lastScrollTop = Math.max(0, scrollTop)
}

function handleKeydown(e: KeyboardEvent) {
  if (e.key === 'Escape') {
    goBack()
  }
}

onMounted(() => {
  loadEntry()
  window.addEventListener('scroll', handleScroll)
  window.addEventListener('keydown', handleKeydown)
})

onUnmounted(() => {
  window.removeEventListener('scroll', handleScroll)
  window.removeEventListener('keydown', handleKeydown)
})

function goBack() {
  router.back()
}

function cycleTheme() {
  if (themeMode.value === 'light') themeMode.value = 'sepia'
  else if (themeMode.value === 'sepia') themeMode.value = 'dark'
  else themeMode.value = 'light'
}
</script>

<template>
  <div class="reader-page" :class="`${themeMode}-mode`">
    <!-- Progress Bar -->
    <div class="progress-bar" :style="{ width: `${scrollProgress}%` }"></div>

    <!-- Toolbar -->
    <header class="reader-toolbar" :class="{ 'hidden': !showToolbar }">
      <div class="toolbar-left">
        <button class="icon-btn" @click="goBack" :title="t('common.back') || '返回'">
          <svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
        </button>
      </div>
      
      <div class="toolbar-center">
        <button class="icon-btn" @click="showToc = !showToc" :class="{ active: showToc }" :title="t('article.toc') || '目录'" v-if="toc.length > 0">
          <svg viewBox="0 0 24 24" width="24" height="24" stroke="currentColor" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="8" y1="6" x2="21" y2="6"></line><line x1="8" y1="12" x2="21" y2="12"></line><line x1="8" y1="18" x2="21" y2="18"></line><line x1="3" y1="6" x2="3.01" y2="6"></line><line x1="3" y1="12" x2="3.01" y2="12"></line><line x1="3" y1="18" x2="3.01" y2="18"></line></svg>
        </button>
        <div class="divider-vertical"></div>
        <button class="font-toggle" :class="{ active: fontFamily === 'serif' }" @click="fontFamily = 'serif'">衬线</button>
        <button class="font-toggle" :class="{ active: fontFamily === 'sans' }" @click="fontFamily = 'sans'">无衬线</button>
        <button class="font-toggle" :class="{ active: fontFamily === 'mono' }" @click="fontFamily = 'mono'">等宽</button>
      </div>

      <div class="toolbar-right">
        <div class="font-controls">
          <button class="icon-btn small" @click="fontSize = Math.max(14, fontSize - 2)">A-</button>
          <span class="font-size-label">{{ fontSize }}</span>
          <button class="icon-btn small" @click="fontSize = Math.min(32, fontSize + 2)">A+</button>
        </div>
        
        <button class="icon-btn" @click="toggleStar" :class="{ active: entry?.starred }" :title="entry?.starred ? '取消收藏' : '收藏'">
           <svg v-if="entry?.starred" viewBox="0 0 24 24" width="20" height="20" fill="currentColor" stroke="none"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/></svg>
           <svg v-else viewBox="0 0 24 24" width="20" height="20" stroke="currentColor" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/></svg>
        </button>
        
        <button class="icon-btn" @click="cycleTheme" :title="themeMode === 'light' ? '切换复古' : themeMode === 'sepia' ? '切换暗色' : '切换亮色'">
          <svg v-if="themeMode === 'dark'" viewBox="0 0 24 24" width="20" height="20" stroke="currentColor" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="5"/><path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/></svg>
          <svg v-else-if="themeMode === 'sepia'" viewBox="0 0 24 24" width="20" height="20" stroke="currentColor" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2v2m0 16v2M4.93 4.93l1.41 1.41m11.32 11.32l1.41 1.41M2 12h2m16 0h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41"/></svg>
          <svg v-else viewBox="0 0 24 24" width="20" height="20" stroke="currentColor" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>
        </button>
      </div>
    </header>

    <!-- TOC Sidebar -->
    <div class="toc-backdrop" v-if="showToc" @click="showToc = false"></div>
    <aside class="toc-sidebar" :class="{ open: showToc }" v-if="toc.length > 0">
      <div class="toc-header">
        <h3>{{ t('article.toc') || '目录' }}</h3>
        <button class="icon-btn small" @click="showToc = false">
          <svg viewBox="0 0 24 24" width="18" height="18" stroke="currentColor" fill="none" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
        </button>
      </div>
      <ul class="toc-list">
        <li v-for="item in toc" :key="item.id" :class="`level-${item.level}`">
          <a :href="`#${item.id}`" @click.prevent="scrollToId(item.id)">{{ item.text }}</a>
        </li>
      </ul>
    </aside>

    <!-- Content -->
    <main v-if="loading" class="reader-loading">
      <LoadingSpinner size="medium" message="正在加载文章..." />
    </main>

    <main v-else-if="error" class="reader-error">
      <p>{{ error }}</p>
      <button @click="goBack" class="retry-btn">返回</button>
    </main>

    <article v-else-if="entry" class="reader-content" :style="contentStyle" ref="contentRef">
      <header class="article-header">
        <h1 class="article-title">{{ entry.title }}</h1>
        <div class="article-meta">
          <span v-if="entry.author" class="meta-item author">
            <svg viewBox="0 0 24 24" width="14" height="14" stroke="currentColor" fill="none" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
            {{ entry.author }}
          </span>
          <span class="meta-item date">
             <svg viewBox="0 0 24 24" width="14" height="14" stroke="currentColor" fill="none" stroke-width="2"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
            {{ formattedDate }}
          </span>
          <span class="meta-item reading-time">
             <svg viewBox="0 0 24 24" width="14" height="14" stroke="currentColor" fill="none" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
            约 {{ readingTime }} 分钟
          </span>
          <span class="meta-item word-count">
             <svg viewBox="0 0 24 24" width="14" height="14" stroke="currentColor" fill="none" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line><polyline points="10 9 9 9 8 9"></polyline></svg>
            {{ wordCount }} 字
          </span>
          <span class="meta-item feed">
             <svg viewBox="0 0 24 24" width="14" height="14" stroke="currentColor" fill="none" stroke-width="2"><path d="M4 11a9 9 0 0 1 9 9"/><path d="M4 4a16 16 0 0 1 16 16"/><circle cx="5" cy="19" r="1"/></svg>
            {{ entry.feed_title }}
          </span>
        </div>
        <div class="article-actions">
          <div class="content-mode-toggle">
            <button class="mode-btn" :class="{ active: contentMode === 'rss' }" @click="selectMode('rss')">摘要</button>
            <button class="mode-btn" :class="{ active: contentMode === 'original' }" @click="selectMode('original')" :disabled="!originalUrl">原文</button>
          </div>
          <button class="refresh-original-btn" @click="refreshOriginal" :disabled="!originalUrl || originalLoading">
            {{ originalRawHtml ? '刷新原文' : '获取原文' }}
          </button>
          <a v-if="originalLink" :href="originalLink" target="_blank" class="original-link">查看原文 &rarr;</a>
        </div>
      </header>

      <!-- AI Smart Assistant Section -->
      <section class="ai-assistant-card" :class="{ 'has-content': aiSummary || aiKeyPoints.length > 0 }">
        <div class="ai-header" @click="showAiPanel = !showAiPanel">
          <div class="ai-title">
            <span class="ai-icon">✨</span>
            <h3>AI 智能速览</h3>
          </div>
          <button v-if="!aiSummary && !aiKeyPoints.length && !summaryLoading" @click.stop="handleGenerateSummary" class="generate-btn">
            生成摘要
          </button>
          <div v-else class="ai-controls">
             <button class="toggle-btn">
               <svg :class="{ rotated: !showAiPanel }" viewBox="0 0 24 24" width="20" height="20" stroke="currentColor" fill="none" stroke-width="2"><path d="M6 9l6 6 6-6"/></svg>
             </button>
          </div>
        </div>

        <div v-if="summaryLoading" class="ai-loading">
          <LoadingSpinner size="medium" />
          <span>正在分析内容...</span>
        </div>

        <div v-if="showAiPanel && (aiSummary || aiKeyPoints.length > 0)" class="ai-content">
          <div v-if="aiSummary" class="ai-summary">
            <p>{{ aiSummary }}</p>
          </div>
          <div v-if="aiKeyPoints.length > 0" class="ai-keypoints">
            <h4>关键要点</h4>
            <ul>
              <li v-for="(point, idx) in aiKeyPoints" :key="idx">{{ point }}</li>
            </ul>
          </div>
        </div>
      </section>

      <div class="article-divider">
        <span>***</span>
      </div>

      <div v-if="originalLoading || originalError || originalRawHtml" class="original-status">
        <span v-if="originalLoading">正在加载原文…</span>
        <span v-else-if="originalError">原文加载失败：{{ originalError }}</span>
        <span v-else-if="contentMode === 'original'">已显示原文</span>
        <span v-else>原文已准备好</span>
      </div>

      <div class="article-body" v-html="displayHtml"></div>
      
      <div class="article-footer">
        <p>正文结束</p>
      </div>
    </article>
  </div>
</template>

<style scoped>
.reader-page {
  min-height: 100vh;
  background-color: var(--bg-base, #ffffff);
  color: var(--text-primary, #333);
  position: relative;
  padding-top: 60px; /* Toolbar height */
  transition: background-color 0.3s, color 0.3s;
}

.dark-mode {
  --bg-base: #1a1a1a;
  --bg-secondary: #2d2d2d;
  --text-primary: #e0e0e0;
  --text-secondary: #a0a0a0;
  --text-tertiary: #666;
  --border-color: #333;
  --hover-bg: #333;
}

.sepia-mode {
  --bg-base: #f4ecd8;
  --bg-secondary: #e9e1cc;
  --text-primary: #5b4636;
  --text-secondary: #7e6a5c;
  --text-tertiary: #a4968c;
  --border-color: #dcd3b8;
  --hover-bg: #e9e1cc;
  --primary-color: #d06d12;
}

.progress-bar {
  position: fixed;
  top: 0;
  left: 0;
  height: 3px;
  background: var(--primary-color, #ff7a18);
  z-index: 1001;
  transition: width 0.1s;
}

.reader-toolbar {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  height: 60px;
  background: var(--bg-base);
  border-bottom: 1px solid var(--border-color, #eee);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 24px;
  z-index: 1000;
  box-shadow: 0 2px 8px rgba(0,0,0,0.05);
  transition: transform 0.3s ease, background-color 0.3s, border-color 0.3s;
}

.divider-vertical {
  width: 1px;
  height: 24px;
  background-color: var(--border-color, #ddd);
  margin: 0 8px;
}

.reader-toolbar.hidden {
  transform: translateY(-100%);
  box-shadow: none;
}

.icon-btn {
  background: none;
  border: none;
  cursor: pointer;
  padding: 8px;
  border-radius: 50%;
  color: var(--text-secondary, #666);
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
}

.icon-btn:hover {
  background: var(--hover-bg, #f5f5f5);
  color: var(--primary-color, #ff7a18);
}

.icon-btn.active {
  color: var(--primary-color, #ff7a18);
}

.toolbar-center {
  display: flex;
  gap: 8px;
  background: var(--bg-secondary, #f5f5f5);
  padding: 4px;
  border-radius: 8px;
}

.font-toggle {
  background: none;
  border: none;
  padding: 4px 12px;
  border-radius: 6px;
  font-size: 13px;
  cursor: pointer;
  color: var(--text-secondary);
  transition: all 0.2s;
}

.font-toggle:hover {
  color: var(--text-primary);
}

.font-toggle.active {
  background: var(--bg-base);
  color: var(--primary-color);
  box-shadow: 0 1px 3px rgba(0,0,0,0.1);
}

.toolbar-right {
  display: flex;
  align-items: center;
  gap: 16px;
}

.font-controls {
  display: flex;
  align-items: center;
  gap: 8px;
  background: var(--bg-secondary, #f5f5f5);
  padding: 4px 8px;
  border-radius: 20px;
}

.font-size-label {
  font-size: 13px;
  color: var(--text-secondary);
  min-width: 24px;
  text-align: center;
  font-variant-numeric: tabular-nums;
}

.reader-content {
  margin: 0 auto;
  padding: 60px 24px 120px;
  max-width: 800px; /* fallback */
}

.article-header {
  margin-bottom: 40px;
  text-align: center;
}

.article-title {
  font-size: 2.5em;
  font-weight: 800;
  line-height: 1.25;
  margin-bottom: 24px;
  color: var(--text-primary);
  letter-spacing: -0.02em;
}

.article-meta {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 20px;
  color: var(--text-tertiary, #999);
  font-size: 0.95em;
  margin-bottom: 24px;
}

.meta-item {
  display: flex;
  align-items: center;
  gap: 6px;
}

.original-link {
  display: inline-block;
  color: var(--primary-color, #ff7a18);
  text-decoration: none;
  font-size: 0.9em;
  font-weight: 500;
  border-bottom: 1px solid transparent;
  transition: border-color 0.2s;
}

.original-link:hover {
  border-bottom-color: currentColor;
}

.article-actions {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  flex-wrap: wrap;
}

.content-mode-toggle {
  display: inline-flex;
  border: 1px solid var(--border-color, #eee);
  border-radius: 999px;
  overflow: hidden;
  background: var(--bg-secondary, #f9f9f9);
}

.mode-btn {
  appearance: none;
  border: none;
  background: transparent;
  color: var(--text-secondary, #666);
  font-size: 0.85em;
  padding: 6px 12px;
  cursor: pointer;
  transition: background 0.2s, color 0.2s;
}

.mode-btn:hover:not(:disabled) {
  background: rgba(255, 122, 24, 0.08);
  color: var(--primary-color, #ff7a18);
}

.mode-btn.active {
  background: rgba(255, 122, 24, 0.14);
  color: var(--primary-color, #ff7a18);
  font-weight: 600;
}

.mode-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.refresh-original-btn {
  appearance: none;
  border: 1px solid rgba(255, 122, 24, 0.35);
  background: rgba(255, 122, 24, 0.12);
  color: var(--primary-color, #ff7a18);
  border-radius: 999px;
  padding: 6px 12px;
  font-size: 0.85em;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.2s, border-color 0.2s;
}

.refresh-original-btn:hover:not(:disabled) {
  background: rgba(255, 122, 24, 0.18);
  border-color: rgba(255, 122, 24, 0.5);
}

.refresh-original-btn:disabled {
  opacity: 0.55;
  cursor: not-allowed;
}

.original-status {
  margin: 14px 0 0;
  padding: 10px 12px;
  border-radius: 10px;
  background: var(--bg-secondary, #f9f9f9);
  border: 1px solid var(--border-color, #eee);
  color: var(--text-secondary, #666);
  font-size: 0.9em;
}

/* AI Assistant Card */
.ai-assistant-card {
  background: var(--bg-secondary, #f9f9f9);
  border-radius: 12px;
  padding: 0;
  margin-bottom: 40px;
  border: 1px solid var(--border-color, #eee);
  overflow: hidden;
  transition: all 0.3s ease;
}

.ai-assistant-card.has-content {
  border-color: rgba(255, 122, 24, 0.2);
  box-shadow: 0 4px 12px rgba(0,0,0,0.03);
}

.ai-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px 20px;
  cursor: pointer;
  background: rgba(255, 255, 255, 0.5);
}

.dark-mode .ai-header {
  background: rgba(255, 255, 255, 0.05);
}

.ai-title {
  display: flex;
  align-items: center;
  gap: 10px;
}

.ai-icon {
  font-size: 1.2em;
}

.ai-title h3 {
  margin: 0;
  font-size: 1em;
  font-weight: 600;
  color: var(--text-primary);
}

.generate-btn {
  background: var(--primary-color);
  color: white;
  border: none;
  padding: 6px 16px;
  border-radius: 20px;
  font-size: 0.85em;
  font-weight: 500;
  cursor: pointer;
  transition: opacity 0.2s;
}

.generate-btn:hover {
  opacity: 0.9;
}

.toggle-btn {
  background: none;
  border: none;
  color: var(--text-secondary);
  padding: 4px;
  cursor: pointer;
}

.toggle-btn svg {
  transition: transform 0.3s;
}

.toggle-btn svg.rotated {
  transform: rotate(-90deg);
}

.ai-loading {
  padding: 20px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  color: var(--text-secondary);
  font-size: 0.9em;
}

.ai-content {
  padding: 0 20px 24px;
  border-top: 1px solid var(--border-color, #eee);
}

.ai-summary {
  margin-top: 16px;
  font-size: 1.05em;
  line-height: 1.6;
  color: var(--text-primary);
}

.ai-keypoints {
  margin-top: 20px;
}

.ai-keypoints h4 {
  margin: 0 0 12px;
  font-size: 0.9em;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-secondary);
}

.ai-keypoints ul {
  margin: 0;
  padding-left: 20px;
}

.ai-keypoints li {
  margin-bottom: 8px;
  line-height: 1.5;
  color: var(--text-primary);
}

.article-divider {
  text-align: center;
  margin: 40px 0;
  color: var(--text-tertiary);
  letter-spacing: 0.5em;
  font-size: 1.2em;
}

.article-footer {
  text-align: center;
  margin-top: 60px;
  color: var(--text-tertiary);
  font-size: 0.9em;
  font-style: italic;
}

/* Article Body Typography */
.article-body {
  color: var(--text-primary);
  word-wrap: break-word;
}

:deep(.article-body img) {
  max-width: 100%;
  height: auto;
  border-radius: 8px;
  margin: 32px 0;
  box-shadow: 0 4px 12px rgba(0,0,0,0.05);
  display: block;
  margin-left: auto;
  margin-right: auto;
}

:deep(.article-body p) {
  margin-bottom: 1.6em;
}

:deep(.article-body h1), 
:deep(.article-body h2), 
:deep(.article-body h3), 
:deep(.article-body h4) {
  margin-top: 2em;
  margin-bottom: 0.8em;
  line-height: 1.3;
  font-weight: 700;
}

:deep(.article-body a) {
  color: var(--primary-color);
  text-decoration: underline;
  text-decoration-thickness: 1px;
  text-underline-offset: 2px;
}

:deep(.article-body blockquote) {
  margin: 32px 0;
  padding-left: 24px;
  border-left: 4px solid var(--primary-color);
  color: var(--text-secondary);
  font-style: italic;
}

:deep(.article-body pre) {
  background: var(--bg-secondary, #f5f5f5);
  padding: 20px;
  border-radius: 8px;
  overflow-x: auto;
  font-family: 'Menlo', 'Monaco', 'Courier New', monospace;
  font-size: 0.9em;
  margin: 32px 0;
  border: 1px solid var(--border-color, #eee);
}

:deep(.article-body ul), 
:deep(.article-body ol) {
  margin-bottom: 1.6em;
  padding-left: 2em;
}

:deep(.article-body li) {
  margin-bottom: 0.5em;
}

.reader-loading, .reader-error {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 60vh;
  gap: 16px;
}

.retry-btn {
  padding: 8px 24px;
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 20px;
  cursor: pointer;
  font-weight: 500;
  transition: all 0.2s;
}

.retry-btn:hover {
  background: var(--hover-bg);
  color: var(--primary-color);
}

/* TOC Sidebar */
  .toc-backdrop {
    position: fixed;
    inset: 0;
    background: rgba(0,0,0,0.1);
    z-index: 899;
  }
  
  .toc-sidebar {
  position: fixed;
  top: 60px;
  right: 0;
  bottom: 0;
  width: 280px;
  background: var(--bg-base);
  border-left: 1px solid var(--border-color);
  z-index: 900;
  transform: translateX(100%);
  transition: transform 0.3s ease;
  overflow-y: auto;
  padding: 20px;
}

.toc-sidebar.open {
  transform: translateX(0);
}

.toc-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 20px;
  padding-bottom: 10px;
  border-bottom: 1px solid var(--border-color);
}

.toc-header h3 {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
}

.toc-list {
  list-style: none;
  padding: 0;
  margin: 0;
}

.toc-list li {
  margin-bottom: 10px;
}

.toc-list a {
  text-decoration: none;
  color: var(--text-secondary);
  font-size: 14px;
  display: block;
  padding: 4px 8px;
  border-radius: 4px;
  transition: all 0.2s;
  line-height: 1.4;
}

.toc-list a:hover {
  background: var(--bg-secondary);
  color: var(--primary-color);
}

.toc-list li.level-1 { font-weight: 600; }
.toc-list li.level-2 { padding-left: 12px; }
.toc-list li.level-3 { padding-left: 24px; }
.toc-list li.level-4 { padding-left: 36px; }

</style>
