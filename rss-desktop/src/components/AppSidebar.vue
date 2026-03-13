<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useFeedStore } from '../stores/feedStore'
import { useChannelsStore, type Channel } from '../stores/channelsStore'
import { useSettingsStore } from '../stores/settingsStore'
import { useUserStore } from '../stores/userStore'
import LogoMark from './LogoMark.vue'
import type { Feed } from '../types'

const props = defineProps<{
  totalUnreadCount: number
  width: number
  isDragging?: boolean
}>()

const emit = defineEmits<{
  (e: 'reset-filters'): void
  (e: 'mark-all-read'): void
  (e: 'open-settings'): void
  (e: 'open-create-channel'): void
  (e: 'open-auth-modal'): void
  (e: 'logout'): void
  (e: 'open-channel-square'): void
  (e: 'open-edit-channel', channel: Channel): void
}>()

const router = useRouter()
const route = useRoute()
const { t } = useI18n()
const store = useFeedStore()
const channelsStore = useChannelsStore()
const settingsStore = useSettingsStore()
const userStore = useUserStore()

const loadedIconUrls = ref<Record<string, boolean>>({})
const feedListEl = ref<HTMLElement | null>(null)
const openMenuChannelId = ref<string | null>(null)
const showUserMenu = ref(false)

// Icon Helpers
const API_BASE = import.meta.env.VITE_API_BASE_URL ?? 'http://127.0.0.1:27496/api'

function iconSrcFor(url?: string | null) {
  if (!url) return undefined
  return `${API_BASE}/icons/proxy?url=${encodeURIComponent(url)}`
}

function handleFeedIconLoad(_feedId: string, url?: string | null) {
  if (!url) return
  loadedIconUrls.value = { ...loadedIconUrls.value, [url]: true }
}

function handleFeedIconError(_feedId: string, url?: string | null) {
  if (!url) return
  loadedIconUrls.value = { ...loadedIconUrls.value, [url]: false }
}

function isFeedIconLoaded(url?: string | null) {
  if (!url) return false
  return !!loadedIconUrls.value[url]
}

function isFeedIconBroken(_feed: Feed) {
  // Simple check if we want to track broken state persistently
  return false
}

function getFeedInitial(title: string) {
  return title ? title.charAt(0).toUpperCase() : '?'
}

onMounted(() => {
  if (userStore.token) {
    channelsStore.fetchMySubscriptions()
  }
  const handler = () => { 
    openMenuChannelId.value = null
    showUserMenu.value = false
  }
  document.addEventListener('click', handler)
  ;(onUnmounted as any)(() => { document.removeEventListener('click', handler) })
})

function toggleUserMenu() {
  showUserMenu.value = !showUserMenu.value
}

function handleMenuAction(action: () => void) {
  action()
  showUserMenu.value = false
}

watch(() => store.activeChannelId, async (id) => {
  if (!id) return
  await nextTick()
  const root = feedListEl.value
  if (!root) return
  const el = root.querySelector(`[data-channel-id="${id}"]`) as HTMLElement | null
  if (!el) return
  el.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
})
function toggleChannelMenu(id: string) {
  openMenuChannelId.value = openMenuChannelId.value === id ? null : id
}
async function doUnsubscribe(id: string) {
  await channelsStore.unsubscribe(id)
  openMenuChannelId.value = null
}

function handleEditChannel(channel: Channel) {
  emit('open-edit-channel', channel)
  openMenuChannelId.value = null
}

function handleChannelClick(id: string) {
  store.selectChannel(id)
  if (route.name === 'my-channel-detail' && route.params.id === id) {
    store.fetchEntries({ channelId: id })
  } else {
    router.push({ name: 'my-channel-detail', params: { id } })
  }
}

const visibleMyChannels = computed(() => channelsStore.myChannels)
const isAdmin = computed(() => userStore.profile?.role === 'admin')

// Context Menu Logic
const contextMenu = ref({
  visible: false,
  x: 0,
  y: 0,
  feed: null as Feed | null
})

function showContextMenu(event: MouseEvent, feed: Feed) {
  event.preventDefault()
  contextMenu.value = {
    visible: true,
    x: event.clientX,
    y: event.clientY,
    feed: feed
  }
  // Close menu when clicking elsewhere
  document.addEventListener('click', closeContextMenu)
}

function closeContextMenu() {
  contextMenu.value.visible = false
  document.removeEventListener('click', closeContextMenu)
}

async function handleEditFeed() {
  const feed = contextMenu.value.feed
  if (!feed) return
  
  const newTitle = prompt(t('common.rename') || '重命名', feed.title || feed.url)
  if (newTitle && newTitle !== feed.title) {
    await store.updateFeed(feed.id, { title: newTitle })
  }
  closeContextMenu()
}

async function handleUnsubscribe() {
  const feed = contextMenu.value.feed
  if (!feed) return
  
  if (confirm((t('common.confirmUnsubscribe') || '确认取消订阅？') + `\n${feed.title || feed.url}`)) {
    await store.deleteFeed(feed.id)
  }
  closeContextMenu()
}
</script>

<template>
  <aside class="sidebar" :class="{ 'no-transition': isDragging }" :style="{ width: width + 'px' }">
    <header class="sidebar__header">
      <div class="brand">
        <div class="brand__icon">
          <LogoMark :size="24" />
        </div>
        <div class="brand__text">
          <h1 class="brand-title">TAN</h1>
          <p class="brand-subtitle">
            {{ settingsStore.settings.branding_toggle ? 'Tech · AI · Nexus' : 'Trend · Awareness · Network' }}
          </p>
        </div>
      </div>
    </header>

    <div class="sidebar-nav-fixed" v-if="userStore.token">
      <!-- 全部订阅 -->
      <div class="nav-section">
        <button 
          class="nav-item main-nav-item" 
          :class="{ active: !store.activeFeedId && !store.activeChannelId && !store.activeGroupName && route.name !== 'my-channels' }"
          @click="emit('reset-filters')"
        >
          <span class="icon">
            <svg class="icon icon-18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M4 11a9 9 0 0 1 9 9" />
              <path d="M4 4a16 16 0 0 1 16 16" />
              <circle cx="5" cy="19" r="1" />
            </svg>
          </span>
          <span class="label">全部订阅</span>
          <span class="count" v-if="totalUnreadCount > 0">{{ totalUnreadCount }}</span>
        </button>
      </div>

      <!-- 我的专题 (Channels) -->
      <div class="nav-section">
        <button 
          class="nav-item main-nav-item" 
          :class="{ active: route.name === 'my-channels' }"
          @click="router.push('/my-channels')"
        >
          <span class="icon">
            <svg class="icon icon-14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
            </svg>
          </span>
          <span class="label">我的专题</span>
        </button>

        <!-- 趋势分析 (Trends) -->
        <button 
          class="nav-item main-nav-item" 
          :class="{ active: route.name === 'trends' }"
          @click="router.push('/trends')"
        >
          <span class="icon">
            <svg class="icon icon-14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="23 6 13.5 15.5 8.5 10.5 1 18"></polyline>
              <polyline points="17 6 23 6 23 12"></polyline>
            </svg>
          </span>
          <span class="label">趋势分析</span>
        </button>
      </div>
    </div>

    <div class="sidebar-feed-list" v-if="userStore.token">
      <!-- 订阅频道 (My Channels) -->
      <div class="nav-section">
        <div class="section-header">
          <span class="icon">
            <svg class="icon icon-14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M4 11a9 9 0 0 1 9 9" />
              <path d="M4 4a16 16 0 0 1 16 16" />
              <circle cx="5" cy="19" r="1" />
            </svg>
          </span>
          <span>订阅频道</span>
        </div>
        <div class="feed-list-simple" ref="feedListEl">
          <div v-for="c in visibleMyChannels" :key="c.id" class="feed-item-row">
            <button 
              class="nav-item sub-item feed-item"
              :class="{ active: store.activeChannelId === c.id }"
              :data-channel-id="c.id"
              @click="handleChannelClick(c.id)"
            >
              <div class="feed-favicon">
                <span class="feed-initial">{{ c.name?.charAt(0).toUpperCase() }}</span>
              </div>
              <span class="label">{{ c.name }}</span>
              <div class="item-actions">
                <span class="more-icon" @click.stop="toggleChannelMenu(c.id)">⋯</span>
                <div v-if="openMenuChannelId === c.id" class="item-menu" @click.stop>
                  <button class="menu-item" @click="handleEditChannel(c)">编辑频道</button>
                  <button class="menu-item" @click="doUnsubscribe(c.id)">取消订阅</button>
                </div>
              </div>
            </button>
          </div>
          <div v-if="channelsStore.loading" class="empty-state small" role="status" aria-live="polite">
            <div class="empty-title">正在加载订阅…</div>
          </div>
          <div v-else-if="channelsStore.error && visibleMyChannels.length === 0" class="empty-state small" role="alert">
            <div class="empty-title">订阅列表加载失败</div>
            <div class="empty-desc">{{ channelsStore.error }}</div>
            <div class="empty-actions">
              <button class="empty-action secondary" type="button" @click="channelsStore.fetchMySubscriptions()">重试</button>
            </div>
          </div>
          <div v-else-if="visibleMyChannels.length === 0" class="empty-state small">
            <div class="empty-emoji" aria-hidden="true">📭</div>
            <div class="empty-title">还没有订阅频道</div>
            <div class="empty-desc">从频道广场订阅，或创建自己的频道开始使用</div>
            <div class="empty-actions">
              <button class="empty-action primary" type="button" @click="emit('open-channel-square')">去频道广场</button>
              <button class="empty-action secondary" type="button" @click="emit('open-create-channel')">创建频道</button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Bottom Actions -->
    <div class="sidebar-footer">
      <!-- User Profile / Login -->
      <div v-if="userStore.token" class="user-footer-item" @click.stop="toggleUserMenu">
        <div class="user-info-row">
          <div class="user-avatar-small">
            {{ userStore.profile?.username?.charAt(0).toUpperCase() || 'U' }}
          </div>
          <span class="username-text">{{ userStore.profile?.username }}</span>
          <span class="expand-icon">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" :class="{ rotated: showUserMenu }">
              <polyline points="18 15 12 9 6 15"></polyline>
            </svg>
          </span>
        </div>

        <!-- User Menu Popover -->
        <div v-if="showUserMenu" class="user-menu-popover" @click.stop>
          <div class="menu-group">
            <button class="menu-item" @click="handleMenuAction(() => emit('open-channel-square'))">
              <span class="icon">
                <svg class="icon icon-18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <rect x="3" y="3" width="7" height="7"></rect>
                  <rect x="14" y="3" width="7" height="7"></rect>
                  <rect x="14" y="14" width="7" height="7"></rect>
                  <rect x="3" y="14" width="7" height="7"></rect>
                </svg>
              </span>
              <span>频道广场</span>
            </button>
            <button class="menu-item" @click="handleMenuAction(() => emit('open-create-channel'))">
              <span class="icon">+</span>
              <span>创建频道</span>
            </button>
          </div>

          <div v-if="isAdmin" class="menu-group">
            <button class="menu-item" @click="handleMenuAction(() => router.push('/admin/channels'))">
              <span class="icon">🛡️</span>
              <span>频道管理</span>
            </button>
            <button class="menu-item" @click="handleMenuAction(() => router.push('/admin/users'))">
              <span class="icon">👥</span>
              <span>用户管理</span>
            </button>
            <button class="menu-item" @click="handleMenuAction(() => router.push('/admin/settings'))">
              <span class="icon">⚙️</span>
              <span>系统设置</span>
            </button>
          </div>

          <div class="menu-group">
            <button class="menu-item" @click="handleMenuAction(() => emit('open-settings'))">
              <span class="icon">⚙</span>
              <span>设置</span>
            </button>
            <button class="menu-item logout" @click="handleMenuAction(() => emit('logout'))">
              <span class="icon">✕</span>
              <span>退出登录</span>
            </button>
          </div>
        </div>
      </div>
      
      <button v-else class="footer-action-btn login-btn" @click="emit('open-auth-modal')">
        <span class="icon">➔</span>
        <span>立即登录</span>
      </button>
    </div>
    
    <!-- Context Menu -->
    <div 
      v-if="contextMenu.visible"
      class="context-menu"
      :style="{ top: contextMenu.y + 'px', left: contextMenu.x + 'px' }"
      @click.stop
    >
      <div class="context-menu-item" @click="handleEditFeed">
        <span class="icon">✎</span>
        <span>编辑订阅频道</span>
      </div>
      <div class="context-menu-item danger" @click="handleUnsubscribe">
        <span class="icon">🗑</span>
        <span>取消订阅</span>
      </div>
    </div>
  </aside>
</template>

<style scoped>
/* Context Menu Styles */
.context-menu {
  position: fixed;
  z-index: 1000;
  background: var(--bg-surface);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  padding: 4px;
  min-width: 140px;
  backdrop-filter: blur(10px);
}

.context-menu-item {
  display: flex;
  align-items: center;
  padding: 8px 12px;
  font-size: 13px;
  cursor: pointer;
  border-radius: 6px;
  color: var(--text-primary);
  transition: background-color 0.2s;
}

.context-menu-item:hover {
  background: var(--sidebar-bg-hover);
}

.context-menu-item.danger {
  color: #ff4d4d;
}

.context-menu-item.danger:hover {
  background: rgba(255, 77, 77, 0.1);
}

.context-menu-item .icon {
  margin-right: 8px;
  font-size: 14px;
  width: 16px;
  text-align: center;
}

/* Local variables mapping to global design system */
.sidebar {
  --sidebar-accent: var(--accent);
  --sidebar-accent-dim: rgba(255, 122, 24, 0.15);
  --sidebar-text-tertiary: hsl(var(--au-text-tertiary));
  --sidebar-bg-hover: hsl(var(--au-item-hover));
  --sidebar-bg-tertiary: hsl(var(--au-bg-tertiary));
  --sidebar-border-dim: hsl(var(--au-border-medium));
  
  display: flex;
  flex-direction: column;
  border-right: 1px solid var(--border-color);
  padding: 16px 10px;
  /* Use translucent background for backdrop blur */
  background: linear-gradient(180deg, 
    hsl(var(--au-bg-surface) / 0.95) 0%, 
    hsl(var(--au-bg-surface) / 0.85) 100%);
  flex-shrink: 0;
  box-sizing: border-box;
  max-height: 100vh;
  overflow: hidden;
  min-height: 0;
  transition: width 160ms ease;
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
}

.sidebar.no-transition {
  transition: none !important;
}

/* Custom Scrollbar */
.sidebar-feed-list::-webkit-scrollbar { width: 4px; }
.sidebar-feed-list::-webkit-scrollbar-thumb { background: transparent; border-radius: 3px; transition: background 0.3s; }
.sidebar:hover .sidebar-feed-list::-webkit-scrollbar-thumb { background: rgba(15, 17, 21, 0.15); }
:global(.dark) .sidebar:hover .sidebar-feed-list::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.15); }

.sidebar__header {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-bottom: 16px;
  padding-bottom: 12px;
  border-bottom: 1px solid var(--sidebar-border-dim);
}

.brand {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 0 4px;
}

.brand__icon {
  flex-shrink: 0;
  filter: drop-shadow(0 4px 12px rgba(255, 122, 24, 0.2));
  transition: transform 0.4s cubic-bezier(0.34, 1.56, 0.64, 1);
}

.brand:hover .brand__icon {
  transform: rotate(15deg) scale(1.1);
}

.brand__text {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.brand-title {
  font-size: 22px;
  font-weight: 800;
  margin: 0;
  line-height: 1.1;
  background: linear-gradient(135deg, #ff7a18 0%, #ff4d4d 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
  letter-spacing: -0.5px;
}

.brand-subtitle {
  font-size: 10px;
  color: var(--text-secondary);
  margin: 0;
  font-weight: 600;
  opacity: 0.7;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.sidebar-nav-fixed {
  display: flex;
  flex-direction: column;
  gap: 16px;
  margin-bottom: 16px;
  flex-shrink: 0;
}

.sidebar-feed-list {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 16px;
  overflow-y: auto;
  min-height: 0;
  padding-bottom: 12px;
}

.nav-section {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.section-header {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 8px;
  margin-bottom: 4px;
  font-size: 11px;
  font-weight: 700;
  color: var(--sidebar-text-tertiary);
  text-transform: uppercase;
  letter-spacing: 0.08em;
  
  /* Sticky Header */
  position: sticky;
  top: 0;
  z-index: 5;
  background: linear-gradient(180deg, 
    hsl(var(--au-bg-surface) / 0.95) 0%, 
    hsl(var(--au-bg-surface) / 0.85) 100%);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border-bottom: 1px solid var(--sidebar-border-dim);
}

.nav-item {
  display: flex;
  align-items: center;
  width: 100%;
  padding: 6px 10px;
  border: none;
  background: transparent;
  color: var(--text-secondary);
  cursor: pointer;
  border-radius: 8px;
  transition: all 0.2s cubic-bezier(0.2, 0, 0, 1);
  text-align: left;
  font-size: 13.5px;
  position: relative;
  overflow: hidden;
  font-weight: 500;
}

.nav-item:hover {
  background: var(--sidebar-bg-hover);
  color: var(--text-primary);
}

.nav-item.active {
  background: linear-gradient(90deg, var(--sidebar-accent-dim), rgba(255, 122, 24, 0.05));
  color: var(--sidebar-accent);
  font-weight: 600;
}

.nav-item.active::before {
  content: '';
  position: absolute;
  left: 0;
  top: 50%;
  transform: translateY(-50%);
  width: 3px;
  height: 16px;
  background: var(--sidebar-accent);
  border-radius: 0 2px 2px 0;
}

.nav-item .icon {
  margin-right: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 20px;
  height: 20px;
  color: inherit;
  opacity: 0.7;
  transition: opacity 0.2s;
}

.nav-item:hover .icon,
.nav-item.active .icon {
  opacity: 1;
}

.nav-item .label {
  flex: 1;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.nav-item .count {
  font-size: 11px;
  background: rgba(0, 0, 0, 0.05);
  padding: 2px 8px;
  border-radius: 12px;
  color: var(--text-secondary);
  font-weight: 600;
  min-width: 18px;
  text-align: center;
  transition: all 0.2s;
}

:global(.dark) .nav-item .count {
  background: rgba(255, 255, 255, 0.1);
}

.nav-item.active .count {
  background: var(--sidebar-accent);
  color: white;
  box-shadow: 0 2px 8px rgba(255, 122, 24, 0.4);
}

/* Feed List Styles */
.feed-list-simple {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.empty-state {
  padding: 10px 10px;
  border-radius: 10px;
  border: 1px dashed var(--sidebar-border-dim);
  background: hsl(var(--au-bg-surface) / 0.4);
  color: var(--text-secondary);
}

.empty-state.small {
  margin-top: 6px;
}

.empty-emoji {
  font-size: 18px;
  line-height: 1;
  margin-bottom: 8px;
  opacity: 0.9;
}

.empty-title {
  font-size: 13px;
  font-weight: 700;
  color: var(--text-primary);
  margin-bottom: 6px;
}

.empty-desc {
  font-size: 12px;
  line-height: 1.4;
  color: var(--text-secondary);
  margin-bottom: 10px;
}

.empty-actions {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.empty-action {
  border-radius: 8px;
  padding: 7px 10px;
  border: 1px solid var(--border-color);
  background: var(--bg-surface);
  color: var(--text-primary);
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
  transition: transform 0.12s ease, filter 0.2s ease, background-color 0.2s ease, border-color 0.2s ease;
}

.empty-action:hover {
  filter: brightness(1.05);
}

.empty-action:active {
  transform: scale(0.98);
}

.empty-action.primary {
  background: var(--sidebar-accent);
  color: #fff;
  border-color: transparent;
  box-shadow: 0 4px 12px rgba(255, 122, 24, 0.25);
}

.empty-action.primary:hover {
  filter: brightness(1.1);
}

.empty-action.secondary {
  background: transparent;
  color: var(--text-primary);
  border-color: var(--sidebar-border-dim);
}

.feed-item {
  padding: 5px 10px;
  font-size: 13px;
  overflow: visible;
}

.item-actions {
  display: flex;
  align-items: center;
  gap: 6px;
  position: relative;
}

.more-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 24px;
  height: 24px;
  border-radius: 6px;
  opacity: 0.7;
}

.more-icon:hover {
  background: var(--sidebar-bg-hover);
  opacity: 1;
}

.item-menu {
  position: absolute;
  right: 0;
  top: 28px;
  background: var(--bg-surface);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  box-shadow: 0 6px 20px rgba(0,0,0,0.08);
  padding: 6px;
  min-width: 120px;
  z-index: 10;
}

.menu-item {
  display: block;
  width: 100%;
  background: transparent;
  border: none;
  text-align: left;
  padding: 8px 10px;
  border-radius: 6px;
  color: var(--text-secondary);
  font-size: 13px;
  cursor: pointer;
}

.menu-item:hover {
  background: var(--sidebar-bg-hover);
  color: var(--text-primary);
}

.feed-favicon {
  width: 16px;
  height: 16px;
  margin-right: 8px;
  border-radius: 3px;
  overflow: hidden;
  flex-shrink: 0;
  background: var(--sidebar-bg-tertiary);
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 1px 3px rgba(0,0,0,0.1);
}

.feed-favicon img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.feed-initial {
  font-size: 9px;
  font-weight: 700;
  color: var(--text-secondary);
}

/* Footer Actions */
.sidebar-footer {
  margin-top: auto;
  padding-top: 12px;
  border-top: 1px solid var(--sidebar-border-dim);
  display: flex;
  flex-direction: column;
  gap: 4px;
  flex-shrink: 0;
  background: var(--sidebar-bg-surface);
}

.footer-action-btn {
  display: flex;
  align-items: center;
  width: 100%;
  padding: 6px 10px;
  border: 1px solid transparent;
  background: transparent;
  color: var(--text-secondary);
  cursor: pointer;
  border-radius: 8px;
  transition: all 0.2s;
  font-size: 13px;
  font-weight: 500;
}

.footer-action-btn:hover {
  background: var(--sidebar-bg-hover);
  color: var(--text-primary);
}

.footer-action-btn .icon {
  margin-right: 10px;
  width: 18px;
  text-align: center;
  font-size: 15px;
  opacity: 0.8;
}

.footer-action-btn:hover .icon {
  opacity: 1;
}

.login-btn {
  background: linear-gradient(135deg, var(--sidebar-accent) 0%, #ff4d4d 100%);
  color: white;
  margin-top: 12px;
  justify-content: center;
  box-shadow: 0 4px 12px rgba(255, 122, 24, 0.3);
  font-weight: 600;
}

.login-btn:hover {
  background: linear-gradient(135deg, var(--sidebar-accent) 0%, #ff4d4d 100%);
  transform: translateY(-2px);
  box-shadow: 0 8px 20px rgba(255, 122, 24, 0.4);
  color: white;
}

.login-btn .icon {
  color: white;
}

/* User Profile */
.user-footer-item {
  margin-top: 4px;
  position: relative;
  cursor: pointer;
}

.user-info-row {
  display: flex;
  align-items: center;
  padding: 8px 10px;
  background: var(--bg-surface);
  border-radius: 10px;
  border: 1px solid var(--border-color);
  transition: all 0.2s;
}

.user-info-row:hover {
  border-color: var(--sidebar-accent-dim);
  box-shadow: 0 4px 12px rgba(0,0,0,0.05);
}

.expand-icon {
  margin-left: auto;
  color: var(--text-tertiary);
  display: flex;
  align-items: center;
  opacity: 0.7;
}

.expand-icon svg {
  transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.expand-icon svg.rotated {
  transform: rotate(180deg);
}

.user-menu-popover {
  position: absolute;
  bottom: calc(100% + 8px);
  left: 0;
  width: 100%;
  background: var(--bg-surface);
  border: 1px solid var(--border-color);
  border-radius: 12px;
  box-shadow: 0 -4px 20px rgba(0, 0, 0, 0.15);
  padding: 6px;
  z-index: 100;
  display: flex;
  flex-direction: column;
  gap: 2px;
  transform-origin: bottom center;
  animation: popoverSlideUp 0.2s cubic-bezier(0.16, 1, 0.3, 1);
}

@keyframes popoverSlideUp {
  from { opacity: 0; transform: translateY(8px) scale(0.96); }
  to { opacity: 1; transform: translateY(0) scale(1); }
}

.menu-group {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding-bottom: 6px;
  margin-bottom: 6px;
  border-bottom: 1px solid var(--sidebar-border-dim);
}

.menu-group:last-child {
  border-bottom: none;
  padding-bottom: 0;
  margin-bottom: 0;
}

.user-menu-popover .menu-item {
  display: flex;
  align-items: center;
  padding: 8px 10px;
  font-weight: 500;
}

.user-menu-popover .menu-item .icon {
  margin-right: 10px;
  width: 18px;
  height: 18px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 15px;
  opacity: 0.8;
  color: inherit;
}

.user-menu-popover .menu-item:hover .icon {
  opacity: 1;
}

.menu-item.logout {
  color: #ef4444;
}

.menu-item.logout:hover {
  background: rgba(239, 68, 68, 0.08);
  color: #ef4444;
}

.user-avatar-small {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  background: linear-gradient(135deg, var(--sidebar-accent), #ff4d4d);
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 14px;
  margin-right: 10px;
  box-shadow: 0 2px 8px rgba(255, 122, 24, 0.3);
}

.username-text {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-primary);
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>
