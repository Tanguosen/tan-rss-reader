<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useChannelsStore } from '../stores/channelsStore'
import { useUserStore } from '../stores/userStore'

const router = useRouter()
const channelsStore = useChannelsStore()
const userStore = useUserStore()

const myTopics = computed(() => {
  return channelsStore.myChannels.filter(c => c.kind !== 'feed')
})

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? 'http://127.0.0.1:27496/api'

function getCoverUrl(url?: string | null) {
  if (!url) return undefined
  if (url.startsWith('http')) return url
  return `${API_BASE}${url}`
}

function handleRefresh() {
  channelsStore.fetchMySubscriptions()
}

function navigateToChannel(id: string) {
  router.push(`/my-channels/${id}`)
}

onMounted(() => {
  if (userStore.token) {
    channelsStore.fetchMySubscriptions()
  }
})
</script>

<template>
  <div class="my-topics-page">
    <header class="page-header">
      <div class="header-left">
        <h1 class="page-title">我的专题</h1>
        <p class="page-subtitle">基于你订阅的内容，自动生成和更新专题</p>
      </div>
      <div class="header-right">
        <button 
          class="refresh-btn" 
          @click="handleRefresh" 
          :disabled="channelsStore.loading"
        >
          <span class="icon" :class="{ spinning: channelsStore.loading }">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M23 4v6h-6"></path>
              <path d="M1 20v-6h6"></path>
              <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"></path>
            </svg>
          </span>
          {{ channelsStore.loading ? '更新中...' : '刷新推荐' }}
        </button>
      </div>
    </header>

    <div class="content-body">
      <div v-if="channelsStore.loading && myTopics.length === 0" class="loading-state">
        <div class="spinner"></div>
        <p>正在获取专题...</p>
      </div>

      <div v-else-if="myTopics.length === 0" class="empty-state">
        <div class="empty-icon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
            <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
          </svg>
        </div>
        <h3>暂无专题</h3>
        <p>订阅更多内容以生成个性化专题</p>
        <button class="explore-btn" @click="channelsStore.showChannelSquareModal = true">去广场逛逛</button>
      </div>

      <div v-else class="topics-grid">
        <div 
          v-for="topic in myTopics" 
          :key="topic.id" 
          class="topic-card"
          @click="navigateToChannel(topic.id)"
        >
          <div class="card-cover">
            <img 
              v-if="topic.cover_url" 
              :src="getCoverUrl(topic.cover_url)" 
              alt="cover"
              loading="lazy"
            />
            <div v-else class="placeholder-cover">
              <span>{{ topic.name.charAt(0) }}</span>
            </div>
          </div>
          <div class="card-content">
            <h3 class="card-title">{{ topic.name }}</h3>
            <p class="card-desc">{{ topic.description || '暂无描述' }}</p>
            <div class="card-meta">
              <!-- Placeholder for meta info like 'Updated 10 days ago', 'Update 78 articles' -->
              <!-- Since we don't have this exact data in Channel model yet, we leave it simple or mock it -->
              <!-- Or we could fetch it, but for now just display static or nothing -->
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.my-topics-page {
  padding: 32px 40px;
  height: 100%;
  overflow-y: auto;
  background-color: #fff;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  margin-bottom: 32px;
}

.page-title {
  font-size: 24px;
  font-weight: 600;
  color: #111827;
  margin: 0 0 8px 0;
  display: flex;
  align-items: center;
  gap: 8px;
}


/* Hide the actual text if we used ::before, or just style the text. 
   Actually, let's just style the H1 directly. 
*/
.page-title {
  color: #ef4444;
}
.page-title span {
  color: #9ca3af;
  font-weight: 400;
  font-size: 14px;
  margin-left: 12px;
}

.page-subtitle {
  color: #6b7280;
  font-size: 14px;
  margin: 0;
  padding-left: 12px;
  border-left: 1px solid #e5e7eb;
  display: inline-block;
}

.header-left {
  display: flex;
  align-items: baseline;
}

.refresh-btn {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 16px;
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  background: #fff;
  color: #374151;
  font-size: 14px;
  cursor: pointer;
  transition: all 0.2s;
}

.refresh-btn:hover:not(:disabled) {
  background: #f9fafb;
  border-color: #d1d5db;
}

.refresh-btn:disabled {
  opacity: 0.6;
  cursor: default;
}

.icon {
  width: 16px;
  height: 16px;
}

.spinning {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

.topics-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 24px;
}

.topic-card {
  border: 1px solid #e5e7eb;
  border-radius: 12px;
  overflow: hidden;
  cursor: pointer;
  transition: transform 0.2s, box-shadow 0.2s;
  background: #fff;
  display: flex;
  flex-direction: column;
}

.topic-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
}

.card-cover {
  height: 140px;
  background-color: #f3f4f6;
  position: relative;
  overflow: hidden;
}

.card-cover img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.placeholder-cover {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 48px;
  color: #9ca3af;
  background: linear-gradient(135deg, #f3f4f6 0%, #e5e7eb 100%);
}

.card-content {
  padding: 16px;
  flex: 1;
  display: flex;
  flex-direction: column;
}

.card-title {
  font-size: 16px;
  font-weight: 600;
  color: #111827;
  margin: 0 0 8px 0;
  line-height: 1.4;
}

.card-desc {
  font-size: 14px;
  color: #6b7280;
  margin: 0;
  line-height: 1.5;
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
  flex: 1;
}

.loading-state, .empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 64px 0;
  color: #6b7280;
}

.spinner {
  width: 32px;
  height: 32px;
  border: 3px solid #e5e7eb;
  border-top-color: #ef4444;
  border-radius: 50%;
  animation: spin 1s linear infinite;
  margin-bottom: 16px;
}

.empty-icon {
  width: 64px;
  height: 64px;
  color: #d1d5db;
  margin-bottom: 16px;
}

.explore-btn {
  margin-top: 24px;
  padding: 10px 24px;
  background-color: #ef4444;
  color: white;
  border: none;
  border-radius: 6px;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s;
}

.explore-btn:hover {
  background-color: #dc2626;
}
</style>