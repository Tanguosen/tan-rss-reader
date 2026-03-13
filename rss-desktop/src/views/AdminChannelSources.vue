<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { useChannelsStore } from '../stores/channelsStore'
import { useFeedStore } from '../stores/feedStore'

const route = useRoute()
const channelsStore = useChannelsStore()
const feedStore = useFeedStore()
const selectedChannelId = ref<string | null>(null)
const selectedFeedId = ref<string | null>(null)
const feedSearchQuery = ref('')
let feedSearchTimeout: any = null

function onFeedSearch() {
  if (feedSearchTimeout) clearTimeout(feedSearchTimeout)
  feedSearchTimeout = setTimeout(() => {
    feedStore.fetchAdminFeeds(feedSearchQuery.value)
  }, 300)
}

async function init() {
  await Promise.all([channelsStore.fetchAdminChannels(), feedStore.fetchAdminFeeds()])
  const id = route.params.id as string | undefined
  if (id) {
    selectedChannelId.value = id
    await channelsStore.fetchChannelSources(id)
  } else if (channelsStore.adminChannels.length > 0) {
    selectedChannelId.value = channelsStore.adminChannels[0].id
    await channelsStore.fetchChannelSources(selectedChannelId.value)
  }
}

async function onSelectChannel(id: string) {
  selectedChannelId.value = id
  await channelsStore.fetchChannelSources(id)
}

async function onAddSource() {
  if (!selectedChannelId.value || !selectedFeedId.value) return
  const ok = await channelsStore.addChannelSource(selectedChannelId.value, selectedFeedId.value)
  if (ok) {
    selectedFeedId.value = null
  }
}

async function onRemoveSource(feedId: string) {
  if (!selectedChannelId.value) return
  await channelsStore.removeChannelSource(selectedChannelId.value, feedId)
}

watch(() => route.params.id, async (newId) => {
  if (typeof newId === 'string' && newId) {
    await onSelectChannel(newId)
  }
})

onMounted(() => {
  init()
})
</script>

<template>
  <div class="page">
    <header class="page__header">
      <h1>管理端：频道源配置</h1>
      <div class="actions">
        <select v-model="selectedChannelId" class="select" @change="onSelectChannel(selectedChannelId!)">
          <option v-for="c in channelsStore.adminChannels" :key="c.id" :value="c.id">{{ c.name }}</option>
        </select>
        <button class="secondary-btn" @click="channelsStore.fetchAdminChannels()">刷新频道</button>
        <button class="secondary-btn" @click="selectedChannelId && channelsStore.fetchChannelSources(selectedChannelId)">刷新源</button>
      </div>
    </header>

    <div class="admin-grid">
      <!-- List of sources in the channel -->
      <div class="panel sources-panel">
        <h3 class="panel-title">已关联信息源</h3>
        <ul class="list">
          <li v-for="s in channelsStore.channelSources" :key="s.feed_id">
            <div class="list-item">
              <span class="list-title">{{ s.title || s.url }}</span>
              <button class="danger-btn" @click="onRemoveSource(s.feed_id)">移除</button>
            </div>
          </li>
          <li v-if="channelsStore.channelSources.length === 0" class="empty-state">
            暂无关联源
          </li>
        </ul>
      </div>

      <!-- Add new source & List of all feeds -->
      <div class="panel main-panel">
        <h3 class="panel-title">添加信息源</h3>
        <div class="add-form">
          <input 
            v-model="feedSearchQuery" 
            type="text" 
            placeholder="搜索源..." 
            class="input-bordered mr-2"
            style="padding: 8px 12px; border: 1px solid #d1d5db; border-radius: 6px; width: 150px;"
            @input="onFeedSearch"
          />
          <select v-model="selectedFeedId" class="select grow">
            <option :value="null">选择要添加的源</option>
            <option v-for="f in feedStore.adminFeeds" :key="f.id" :value="f.id">
              {{ f.title || f.url }}（{{ f.group_name }}）
            </option>
          </select>
          <button class="primary-btn" :disabled="!selectedChannelId || !selectedFeedId" @click="onAddSource">添加到频道</button>
        </div>
        
        <div class="feeds-list-section">
          <h4 class="section-subtitle">所有订阅源参考</h4>
          <div class="feeds-scroll">
            <ul class="list">
              <li v-for="f in feedStore.adminFeeds" :key="f.id">
                <div class="list-item">
                  <span class="list-title">{{ f.title || f.url }}</span>
                  <button class="secondary-btn small" @click="selectedFeedId = f.id">选择</button>
                </div>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.page { padding: 24px; max-width: 1200px; margin: 0 auto; height: 100%; overflow-y: auto; }
.page__header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 24px; }
.page__header h1 { font-size: 24px; font-weight: 600; color: #111827; margin: 0; }

.actions { display: flex; gap: 12px; }
.select { padding: 8px 12px; border: 1px solid #d1d5db; border-radius: 6px; background-color: white; font-size: 14px; }
.select.grow { flex-grow: 1; }

.admin-grid { display: grid; grid-template-columns: 350px 1fr; gap: 24px; align-items: start; }

.panel { 
  background: white; 
  border: 1px solid #e5e7eb; 
  border-radius: 12px; 
  padding: 20px; 
  box-shadow: 0 1px 3px rgba(0,0,0,0.05); 
}

.panel-title { margin: 0 0 16px; font-size: 18px; font-weight: 600; color: #374151; }
.section-subtitle { margin: 24px 0 12px; font-size: 15px; font-weight: 500; color: #6b7280; }

.list { list-style: none; padding: 0; margin: 0; display: flex; flex-direction: column; gap: 8px; }
.list-item { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 10px; border: 1px solid #f3f4f6; border-radius: 8px; background: #f9fafb; transition: all 0.2s; }
.list-item:hover { border-color: #e5e7eb; background: #fff; box-shadow: 0 2px 4px rgba(0,0,0,0.02); }
.list-title { font-size: 14px; color: #374151; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

.empty-state { padding: 20px; text-align: center; color: #9ca3af; font-size: 14px; background: #f9fafb; border-radius: 8px; border: 1px dashed #e5e7eb; }

.add-form { display: flex; gap: 12px; align-items: center; margin-bottom: 20px; }

.feeds-scroll { max-height: 500px; overflow-y: auto; padding-right: 4px; }

.primary-btn { padding: 8px 16px; border: none; border-radius: 6px; background: #3b82f6; color: white; font-weight: 500; cursor: pointer; transition: background 0.2s; }
.primary-btn:hover { background: #2563eb; }
.primary-btn:disabled { background: #93c5fd; cursor: not-allowed; }

.secondary-btn { padding: 8px 12px; border: 1px solid #d1d5db; border-radius: 6px; background: white; color: #374151; font-weight: 500; cursor: pointer; transition: all 0.2s; }
.secondary-btn:hover { border-color: #9ca3af; background: #f9fafb; }
.secondary-btn.small { padding: 4px 10px; font-size: 12px; }

.danger-btn { padding: 6px 12px; border: none; border-radius: 6px; background: #fee2e2; color: #ef4444; font-size: 13px; font-weight: 500; cursor: pointer; transition: background 0.2s; }
.danger-btn:hover { background: #fecaca; }

/* Scrollbar styles */
.feeds-scroll::-webkit-scrollbar { width: 6px; }
.feeds-scroll::-webkit-scrollbar-track { background: transparent; }
.feeds-scroll::-webkit-scrollbar-thumb { background-color: #d1d5db; border-radius: 3px; }
.feeds-scroll::-webkit-scrollbar-thumb:hover { background-color: #9ca3af; }
</style>
