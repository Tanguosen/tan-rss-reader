<script setup lang="ts">
import { RouterView, useRouter, useRoute } from 'vue-router'
import { watch, onMounted, ref, computed, onUnmounted } from 'vue'
import { useUserStore } from './stores/userStore'
import { useChannelsStore, type Channel } from './stores/channelsStore'
import { useFeedStore } from './stores/feedStore'
import { useSettingsStore } from './stores/settingsStore'
import { useAIStore } from './stores/aiStore'
import { useI18n } from 'vue-i18n'
import AppSidebar from './components/AppSidebar.vue'
import Toast from './components/Toast.vue'
import AuthModal from './components/AuthModal.vue'
import SettingsModal from './components/SettingsModal.vue'
import ChannelSquare from './components/ChannelSquare.vue'
import ChannelEditModal from './components/ChannelEditModal.vue'

const userStore = useUserStore()
const channelsStore = useChannelsStore()
const feedStore = useFeedStore()
const settingsStore = useSettingsStore()
const aiStore = useAIStore()
const router = useRouter()
const route = useRoute()
const { t } = useI18n()

// Route checks
const isReader = computed(() => route.name === 'reader')
const hideSidebar = computed(() => ['login', 'reader'].includes(route.name as string))

// Global UI State
const showToast = ref(false)
const toastMessage = ref('')
const toastType = ref<'success' | 'error' | 'info'>('info')
const showSettings = ref(false)
const showCreateChannelModal = ref(false) // If needed, or remove if not implemented globally yet
const showEditChannelModal = ref(false)
const editingChannel = ref<Channel | null>(null)

function openEditChannel(channel: Channel) {
  editingChannel.value = channel
  showEditChannelModal.value = true
}

function handleEditChannelUpdated() {
  showNotification('频道更新成功', 'success')
}

// Sidebar Layout State
const DEFAULT_VIEWPORT_WIDTH = typeof window !== 'undefined' ? window.innerWidth : 1440
const DEFAULT_SIDEBAR_RATIO = 0.26
const MIN_SIDEBAR_WIDTH = 180
const SIDEBAR_RATIO_KEY = 'rss-layout-sidebar-ratio'

const sidebarRatio = ref(DEFAULT_SIDEBAR_RATIO)
const viewportWidth = ref(DEFAULT_VIEWPORT_WIDTH)
const isDraggingLeft = ref(false)

function getViewport() {
  return viewportWidth.value || DEFAULT_VIEWPORT_WIDTH
}

const sidebarWidth = computed(() => Math.round(getViewport() * sidebarRatio.value))

function minSidebarRatio() {
  return MIN_SIDEBAR_WIDTH / getViewport()
}

function refreshViewportWidth() {
  if (typeof window === 'undefined') return
  viewportWidth.value = window.innerWidth
}

function normalizeRatios() {
  const sidebarMin = minSidebarRatio()
  sidebarRatio.value = Math.max(sidebarRatio.value, sidebarMin)
  // Max width constraint could be added here (e.g. max 40%)
  if (sidebarRatio.value > 0.4) sidebarRatio.value = 0.4
}

function loadLayoutSettings() {
  if (typeof window === 'undefined') return
  refreshViewportWidth()
  const savedSidebarRatio = localStorage.getItem(SIDEBAR_RATIO_KEY)
  if (savedSidebarRatio) {
    const ratio = parseFloat(savedSidebarRatio)
    if (!Number.isNaN(ratio)) {
      sidebarRatio.value = ratio
    }
  }
  normalizeRatios()
}

function saveLayoutSettings() {
  localStorage.setItem(SIDEBAR_RATIO_KEY, sidebarRatio.value.toString())
}

function handleMouseDownLeft(event: MouseEvent) {
  isDraggingLeft.value = true
  event.preventDefault()
  document.body.style.cursor = 'col-resize'
  document.body.style.userSelect = 'none'
}

function handleMouseMove(event: MouseEvent) {
  if (isDraggingLeft.value) {
    const viewport = getViewport()
    const ratio = event.clientX / viewport
    sidebarRatio.value = ratio
    normalizeRatios()
  }
}

function handleMouseUp() {
  if (isDraggingLeft.value) {
    isDraggingLeft.value = false
    document.body.style.cursor = ''
    document.body.style.userSelect = ''
    saveLayoutSettings()
  }
}

function handleWindowResize() {
  refreshViewportWidth()
  normalizeRatios()
  saveLayoutSettings()
}

// Logic Actions
const totalUnreadCount = computed(() => {
  return feedStore.feeds.reduce((acc, feed) => acc + (feed.unread_count || 0), 0)
})

function resetFilters() {
  feedStore.activeFeedId = null
  feedStore.activeGroupName = null
  feedStore.activeChannelId = null
  // Also navigate home if needed
  if (route.name !== 'home') {
    router.push('/')
  } else {
    feedStore.fetchEntries()
  }
}

async function markAllRead() {
  if (confirm(t('common.confirmMarkAllRead') || 'Mark all as read?')) {
     showNotification(t('common.comingSoon') || 'Coming Soon', 'info')
  }
}


function showNotification(message: string, type: 'success' | 'error' | 'info' = 'info') {
  toastMessage.value = message
  toastType.value = type
  showToast.value = true
}

function handleUnauthorized() {
  userStore.logout()
  userStore.openAuthModal('login')
  showNotification('登录已过期，请重新登录', 'error')
}

// Watch for store errors
watch(() => feedStore.errorMessage, (error) => {
  if (error) {
    showNotification(error, 'error')
    setTimeout(() => {
      feedStore.errorMessage = null
    }, 100)
  }
})

watch(() => aiStore.error, (error) => {
  if (error) {
    showNotification(error, 'error')
    setTimeout(() => {
      aiStore.clearError()
    }, 100)
  }
})

watch(() => channelsStore.error, (error) => {
  if (error) {
    showNotification(error, 'error')
    setTimeout(() => {
      channelsStore.error = null
    }, 100)
  }
})

watch(() => channelsStore.message, (msg) => {
  if (msg) {
    showNotification(msg, 'success')
    setTimeout(() => {
      channelsStore.message = null
    }, 100)
  }
})

// Fetch channels when logged in
watch(() => userStore.token, async (newToken) => {
  if (newToken) {
    await channelsStore.fetchMySubscriptions()
  } else {
    channelsStore.myChannels = []
  }
})

onMounted(async () => {
  loadLayoutSettings()
  window.addEventListener('mousemove', handleMouseMove)
  window.addEventListener('mouseup', handleMouseUp)
  window.addEventListener('resize', handleWindowResize)
  window.addEventListener('auth:unauthorized', handleUnauthorized as EventListener)

  if (userStore.token) {
    await channelsStore.fetchMySubscriptions()
  }
})

onUnmounted(() => {
  window.removeEventListener('mousemove', handleMouseMove)
  window.removeEventListener('mouseup', handleMouseUp)
  window.removeEventListener('resize', handleWindowResize)
  window.removeEventListener('auth:unauthorized', handleUnauthorized as EventListener)
})
</script>

<template>
  <div class="app-layout" :class="{ 'reader-mode': isReader }" :style="{ '--sidebar-width': sidebarWidth + 'px' }">
    <Toast 
      :show="showToast" 
      :message="toastMessage" 
      :type="toastType" 
      @close="showToast = false" 
    />
    <SettingsModal 
      :show="showSettings" 
      @close="showSettings = false" 
    />
    <AuthModal
      :show="userStore.authModalVisible"
      :initial-mode="userStore.authMode"
      @close="userStore.closeAuthModal"
    />
    <ChannelSquare :show="channelsStore.showChannelSquareModal" @close="channelsStore.showChannelSquareModal = false" />
    <ChannelEditModal 
      :show="showEditChannelModal" 
      :channel="editingChannel"
      @close="showEditChannelModal = false"
      @updated="handleEditChannelUpdated"
    />

    <div v-if="!hideSidebar" class="sidebar-wrapper">
      <AppSidebar
        :width="sidebarWidth"
        :is-dragging="isDraggingLeft"
        :total-unread-count="totalUnreadCount"
        @reset-filters="resetFilters"
        @mark-all-read="markAllRead"
        @open-settings="showSettings = true"
        @open-channel-square="channelsStore.showChannelSquareModal = true"
        @open-create-channel="showCreateChannelModal = true"
        @open-auth-modal="userStore.openAuthModal('login')"
        @open-edit-channel="openEditChannel"
        @logout="userStore.logout()"
      />
      <div
        class="resizer resizer-left"
        :class="{ active: isDraggingLeft }"
        @mousedown="handleMouseDownLeft"
        title="Drag to resize sidebar"
      ></div>
    </div>

    <main class="main-content" :style="!hideSidebar ? { width: `calc(100% - ${sidebarWidth}px)` } : {}">
      <RouterView />
    </main>
  </div>
</template>

<style scoped>
.app-layout {
  display: flex;
  min-height: 100vh;
  width: 100vw;
  overflow: hidden;
  background-color: #f9fafb;
}

.sidebar-wrapper {
  display: flex;
  flex-shrink: 0;
  height: 100vh;
}

.resizer {
  width: 3px;
  background: rgba(15, 17, 21, 0.1);
  cursor: col-resize;
  transition: background-color 0.2s;
  position: relative;
  z-index: 10;
}

.resizer:hover, .resizer.active {
  background: rgba(255, 122, 24, 0.3);
}

.main-content {
  flex: 1;
  height: 100vh;
  overflow: hidden;
  position: relative;
}

/* Reader Mode overrides */
.app-layout.reader-mode {
  height: auto;
  min-height: 100vh;
  overflow: visible;
  display: block;
}

.app-layout.reader-mode .main-content {
  height: auto;
  min-height: 100vh;
  overflow: visible;
  width: 100% !important;
}
</style>
