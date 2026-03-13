<script setup lang="ts">
import { ref, onMounted, watch, computed } from 'vue'
import { useChannelsStore } from '../stores/channelsStore'
import { useUserStore } from '../stores/userStore'
import LoadingSpinner from './LoadingSpinner.vue'

const props = defineProps<{
  show: boolean
}>()

const emit = defineEmits<{
  (e: 'close'): void
}>()

const channels = useChannelsStore()
const user = useUserStore()
const query = ref('')
const activeCategory = ref('')
const expandedDescIds = ref<Set<string>>(new Set())
const subscribingIds = ref<Set<string>>(new Set())
const abVariant = ref<'A' | 'B'>('B')

const filteredChannels = computed(() => {
  if (!activeCategory.value) {
    return channels.square
  }
  return channels.square.filter(c => c.category_id === activeCategory.value)
})

function getDescText(desc?: string | null) {
  const v = (desc || '').trim()
  return v || '暂无简介'
}

function canToggleDesc(desc?: string | null) {
  return getDescText(desc).length > 60
}

function isDescExpanded(id: string) {
  return expandedDescIds.value.has(id)
}

function toggleDesc(id: string) {
  const next = new Set(expandedDescIds.value)
  if (next.has(id)) next.delete(id)
  else next.add(id)
  expandedDescIds.value = next
}

function resolveAbVariant() {
  const qs = new URLSearchParams(window.location.search)
  const forced = qs.get('ab_channel_square')?.toUpperCase()
  if (forced === 'A' || forced === 'B') {
    abVariant.value = forced
    localStorage.setItem('ab_channel_square_variant', forced)
    return
  }
  const saved = localStorage.getItem('ab_channel_square_variant')?.toUpperCase()
  if (saved === 'A' || saved === 'B') {
    abVariant.value = saved as 'A' | 'B'
    return
  }
  abVariant.value = 'B'
  localStorage.setItem('ab_channel_square_variant', 'B')
}

function track(event: string, payload?: Record<string, unknown>) {
  const entry = {
    event,
    payload: payload || {},
    ts: Date.now(),
    variant: abVariant.value
  }
  try {
    const key = 'ab_channel_square_events'
    const raw = localStorage.getItem(key)
    const list = raw ? (JSON.parse(raw) as any[]) : []
    list.push(entry)
    const capped = list.length > 200 ? list.slice(list.length - 200) : list
    localStorage.setItem(key, JSON.stringify(capped))
  } catch (_e) {
  }
}

async function init() {
  // Always fetch square data when opened to get latest
  await Promise.all([
    channels.fetchSquare(),
    channels.fetchPublicCategories()
  ])
  if (user.token) {
    await channels.fetchMySubscriptions()
  }
}

watch(() => props.show, (val) => {
  if (val) {
    resolveAbVariant()
    expandedDescIds.value = new Set()
    init()
    track('impression', { total: filteredChannels.value.length })
  }
})

async function onSubscribe(id: string) {
  if (!user.token) {
    user.openAuthModal('login')
    return
  }
  if (subscribingIds.value.has(id)) return
  subscribingIds.value = new Set(subscribingIds.value).add(id)
  const success = await channels.subscribe(id)
  if (success) {
    await channels.fetchMySubscriptions()
    track('subscribe_success', { channelId: id })
  } else {
    track('subscribe_failed', { channelId: id })
  }
  const next = new Set(subscribingIds.value)
  next.delete(id)
  subscribingIds.value = next
}

function getAvatarColor(name: string) {
  const colors = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#ec4899']
  let hash = 0
  for (let i = 0; i < name.length; i++) {
    hash = name.charCodeAt(i) + ((hash << 5) - hash)
  }
  return colors[Math.abs(hash) % colors.length]
}

function getInitial(name: string) {
  return name ? name.charAt(0).toUpperCase() : '?'
}

function isSubscribed(id: string) {
  return channels.myChannels.some(c => c.id === id)
}
</script>

<template>
  <Transition name="slide">
    <div v-if="show" class="channel-square-overlay">
      <div class="header-container">
        <button class="close-btn" type="button" @click="emit('close')" aria-label="关闭频道广场" title="关闭">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <line x1="18" y1="6" x2="6" y2="18"></line>
            <line x1="6" y1="6" x2="18" y2="18"></line>
          </svg>
        </button>
        
        <div class="header-content fixed-container">
          <h1 class="title">频道广场</h1>
          <p class="subtitle">探索并订阅你感兴趣的频道</p>
          
          <div class="search-bar">
            <input 
              v-model="query" 
              type="search" 
              placeholder="搜索频道" 
              @keyup.enter="channels.fetchSquare(query)"
              aria-label="搜索频道"
            />
            <button class="search-btn" type="button" @click="channels.fetchSquare(query)" aria-label="搜索">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <circle cx="11" cy="11" r="8"></circle>
                <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
              </svg>
            </button>
          </div>
          
          <div class="categories-nav">
             <button
               class="cat-btn"
               :class="{ active: activeCategory === '' }"
               @click="activeCategory = ''"
               type="button"
             >
               全部
             </button>
             <button 
               v-for="cat in channels.categories" 
               :key="cat.id"
               class="cat-btn"
               :class="{ active: activeCategory === cat.id }"
               @click="activeCategory = cat.id"
               type="button"
             >
               {{ cat.name }}
             </button>
          </div>
        </div>
      </div>

      <div class="content-body">
        <div class="fixed-container">
          <div v-if="channels.loading" class="loading-state">
             <LoadingSpinner />
          </div>
          <div v-else-if="channels.error" class="error-state">
             {{ channels.error }}
             <button class="retry-btn" type="button" @click="init">重试</button>
          </div>
          <div v-else class="grid" :class="{ compact: abVariant === 'B' }">
            <div v-for="c in filteredChannels" :key="c.id" class="card" :class="{ 'card--compact': abVariant === 'B' }">
              <template v-if="abVariant === 'A'">
                <div class="card-top">
                  <div class="article-preview" v-for="i in 2" :key="i">
                    <span class="article-title">这里是预览文章标题...</span>
                    <div class="article-thumb"></div>
                  </div>
                </div>
                
                <div class="card-bottom">
                  <div class="channel-info">
                    <h3 class="channel-name">{{ c.name }}</h3>
                    <div class="channel-meta">
                      <div class="avatar" :style="{ backgroundColor: getAvatarColor(c.name) }">
                        <img v-if="c.cover_url" :src="c.cover_url" />
                        <span v-else>{{ getInitial(c.name) }}</span>
                      </div>
                      <p class="desc">{{ getDescText(c.description) }}</p>
                    </div>
                  </div>
                  <div class="actions-row">
                    <button class="subscribe-btn" type="button" :disabled="isSubscribed(c.id)" @click="onSubscribe(c.id)">
                      {{ isSubscribed(c.id) ? '已订阅' : '订阅' }}
                    </button>
                  </div>
                </div>
              </template>

              <template v-else>
                <div class="card__top">
                  <h3 class="card__name" :title="c.name">{{ c.name }}</h3>
                  <button
                    class="subscribe-btn subscribe-btn--primary"
                    type="button"
                    :disabled="isSubscribed(c.id) || subscribingIds.has(c.id)"
                    :aria-pressed="isSubscribed(c.id)"
                    :aria-busy="subscribingIds.has(c.id)"
                    @click="onSubscribe(c.id)"
                  >
                    <span v-if="subscribingIds.has(c.id)">订阅中…</span>
                    <span v-else>{{ isSubscribed(c.id) ? '已订阅' : '订阅' }}</span>
                  </button>
                </div>

                <div class="card__desc">
                  <p class="desc" :class="{ expanded: isDescExpanded(c.id) }">
                    {{ getDescText(c.description) }}
                  </p>
                  <button
                    v-if="canToggleDesc(c.description)"
                    class="desc-toggle"
                    type="button"
                    :aria-expanded="isDescExpanded(c.id)"
                    @click="toggleDesc(c.id)"
                  >
                    {{ isDescExpanded(c.id) ? '收起' : '展开' }}
                  </button>
                </div>
              </template>
            </div>
          </div>
        </div>
      </div>
    </div>
  </Transition>
</template>

<style scoped>
.channel-square-overlay {
  position: absolute;
  top: 0;
  right: 0;
  bottom: 0;
  left: var(--sidebar-width);
  background: var(--bg-base, #fcfcfc);
  z-index: 100;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  box-shadow: -4px 0 20px rgba(0,0,0,0.05);
}

.slide-enter-active,
.slide-leave-active {
  transition: transform 0.3s cubic-bezier(0.16, 1, 0.3, 1);
}

.slide-enter-from,
.slide-leave-to {
  transform: translateX(100%);
}

.header-container {
  padding: 20px 24px 12px;
  background: var(--bg-surface, #fff);
  position: relative;
}

.fixed-container {
  max-width: 1200px;
  margin: 0 auto;
  width: 100%;
}

.close-btn {
  position: absolute;
  top: 12px;
  right: 12px;
  background: transparent;
  border: none;
  cursor: pointer;
  color: var(--text-tertiary, #999);
  padding: 8px;
  border-radius: 50%;
  transition: all 0.2s;
}

.close-btn:hover {
  background: #f5f5f5;
  color: #333;
}

.title {
  font-size: 20px;
  font-weight: 800;
  margin: 0 0 6px;
  color: var(--text-primary, #111);
}

.subtitle {
  color: var(--text-secondary, #666);
  font-size: 13px;
  margin-bottom: 12px;
}

.search-bar {
  position: relative;
  max-width: 100%;
  margin-bottom: 12px;
}

.search-bar input {
  width: 100%;
  padding: 10px 12px;
  padding-right: 44px;
  border: 1px solid var(--border-color, #e5e5e5);
  border-radius: 10px;
  font-size: 14px;
  background: var(--bg-surface, #fff);
  transition: border-color 0.2s;
  box-sizing: border-box;
}

.search-bar input:focus {
  outline: none;
  border-color: var(--accent, #ff7a18);
  box-shadow: 0 0 0 3px rgba(255, 122, 24, 0.12);
}

.search-btn {
  position: absolute;
  right: 8px;
  top: 50%;
  transform: translateY(-50%);
  background: var(--text-primary, #111);
  color: var(--bg-surface, #fff);
  border: none;
  width: 36px;
  height: 36px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
}

.categories-nav {
  display: flex;
  gap: 10px;
  overflow-x: auto;
  padding-bottom: 8px;
  border-bottom: 1px solid var(--border-color, #f0f0f0);
}

.categories-nav::-webkit-scrollbar {
  display: none;
}

.cat-btn {
  background: transparent;
  border: none;
  font-size: 13px;
  color: var(--text-secondary, #666);
  cursor: pointer;
  padding: 6px 0;
  position: relative;
  white-space: nowrap;
  font-weight: 500;
}

.cat-btn.active {
  color: var(--text-primary, #111);
  font-weight: 700;
}

.cat-btn.active::after {
  content: '';
  position: absolute;
  bottom: -9px;
  left: 0;
  width: 100%;
  height: 2px;
  background: var(--text-primary, #111);
}

.content-body {
  flex: 1;
  overflow-y: auto;
  padding: 16px 24px 24px;
  background: var(--bg-base, #f9f9f9);
}

.grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
  gap: 12px;
}

.grid.compact {
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: 10px;
}

.card {
  background: var(--bg-surface, #fff);
  border-radius: 14px;
  padding: 16px;
  box-shadow: 0 1px 2px rgba(0,0,0,0.03);
  border: 1px solid var(--border-color, #f0f0f0);
  display: flex;
  flex-direction: column;
  transition: transform 0.2s, box-shadow 0.2s;
}

.card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 16px rgba(0,0,0,0.06);
}

.card--compact:hover {
  transform: translateY(-1px);
}

.card__top {
  display: flex;
  align-items: flex-start;
  gap: 10px;
}

.card__name {
  margin: 0;
  font-size: 14px;
  font-weight: 800;
  color: var(--text-primary, #111);
  line-height: 1.3;
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.card__desc {
  margin-top: 10px;
}

.card-top {
  margin-bottom: 20px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.article-preview {
  display: flex;
  justify-content: space-between;
  gap: 12px;
}

.article-title {
  font-size: 13px;
  color: #333;
  line-height: 1.5;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.article-thumb {
  width: 48px;
  height: 36px;
  background: #f0f0f0;
  border-radius: 4px;
  flex-shrink: 0;
}

.card-bottom {
  margin-top: auto;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-top: 16px;
  border-top: 1px solid #f5f5f5;
}

.channel-info {
  flex: 1;
  min-width: 0;
  margin-right: 12px;
}

.channel-name {
  font-size: 15px;
  font-weight: 700;
  margin: 0 0 4px;
  color: #111;
}

.channel-meta {
  display: flex;
  align-items: center;
  gap: 8px;
}

.avatar {
  width: 20px;
  height: 20px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  font-size: 10px;
  font-weight: bold;
  overflow: hidden;
}

.avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.desc {
  font-size: 12px;
  color: var(--text-secondary, #666);
  margin: 0;
  line-height: 1.5;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.desc.expanded {
  -webkit-line-clamp: initial;
}

.desc-toggle {
  margin-top: 6px;
  padding: 0;
  background: transparent;
  border: none;
  cursor: pointer;
  font-size: 12px;
  color: var(--accent, #ff7a18);
  font-weight: 700;
}

.subscribe-btn {
  background: #f5f5f5;
  color: #111;
  border: none;
  padding: 6px 16px;
  border-radius: 20px;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.subscribe-btn:hover {
  background: #413d3d;
}

.subscribe-btn--primary {
  background: var(--accent, #ff7a18);
  color: #fff;
  border-radius: 999px;
  padding: 6px 14px;
  font-size: 12px;
  font-weight: 800;
  box-shadow: 0 6px 16px rgba(255, 122, 24, 0.25);
}

.subscribe-btn--primary:hover {
  filter: brightness(1.05);
}

.subscribe-btn--primary:disabled {
  opacity: 0.75;
  cursor: not-allowed;
  box-shadow: none;
  filter: none;
}

.loading-state, .error-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 200px;
  color: #666;
}

.retry-btn {
  margin-top: 10px;
  padding: 6px 16px;
  background: var(--accent, #ff7a18);
  color: #fff;
  border: none;
  border-radius: 6px;
  cursor: pointer;
}

@media (max-width: 900px) {
  .fixed-container {
    max-width: 100%;
  }
}

@media (max-width: 768px) {
  .channel-square-overlay {
    left: 0;
  }
  .header-container {
    padding: 16px 14px 10px;
  }
  .content-body {
    padding: 12px 14px 18px;
  }
  .subtitle {
    display: none;
  }
  .grid,
  .grid.compact {
    grid-template-columns: 1fr;
  }
}
</style>
