<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useChannelsStore, type Channel } from '../stores/channelsStore'
import { useUserStore } from '../stores/userStore'

const channels = useChannelsStore()
const user = useUserStore()
const query = ref('')

async function init() {
  await Promise.all([
    channels.fetchPublicCategories(),
    channels.fetchSquare('', 500)
  ])
  if (user.token) {
    await channels.fetchMySubscriptions()
  }
  if (user.token && !user.profile) {
    await user.fetchMe()
  }
}

async function onSearch() {
  await channels.fetchSquare(query.value, 500)
}

async function onSubscribe(id: string) {
  if (!user.token) {
    user.openAuthModal('login')
    return
  }
  const ok = await channels.subscribe(id)
  if (ok) {
    await channels.fetchMySubscriptions()
  }
}

function isSubscribed(id: string) {
  return channels.myChannels.some(c => c.id === id)
}

function getCoverStyle(c: Channel) {
  let url = c.cover_url
  if (!url && c.preview_entries && c.preview_entries.length > 0) {
    const entryWithImage = c.preview_entries.find(e => e.cover_image)
    if (entryWithImage) {
      url = entryWithImage.cover_image
    }
  }
  
  if (url) {
    return { backgroundImage: `url(${url})` }
  }
  // Fallback gradient based on name length to give some variety
  const colors = ['#ff7a18', '#3b82f6', '#10b981', '#8b5cf6', '#ec4899']
  const index = c.name.length % colors.length
  return { background: `linear-gradient(135deg, ${colors[index]} 0%, ${colors[(index + 1) % colors.length]} 100%)` }
}

const groupedChannels = computed(() => {
  const groups: Record<string, typeof channels.square> = {}
  const othersKey = '未分类'

  // Initialize known categories
  channels.categories.forEach(cat => {
    groups[cat.id] = []
  })

  // Group channels
  channels.square.forEach(c => {
    if (c.category_id && groups[c.category_id]) {
      groups[c.category_id].push(c)
    } else {
      if (!groups['others']) groups['others'] = []
      groups['others'].push(c)
    }
  })

  const result: { id: string; name: string; channels: typeof channels.square }[] = []

  // Add sorted categories
  channels.categories.forEach(cat => {
    if (groups[cat.id] && groups[cat.id].length > 0) {
      result.push({ id: cat.id, name: cat.name, channels: groups[cat.id] })
    }
  })

  // Add others if any
  if (groups['others'] && groups['others'].length > 0) {
    result.push({ id: 'others', name: othersKey, channels: groups['others'] })
  }

  // If no categories loaded but we have channels, show all as one group or just show them
  if (channels.categories.length === 0 && channels.square.length > 0 && result.length === 0) {
     // Fallback if categories failed to load or none exist
     if (groups['others']) {
        return [{ id: 'others', name: '所有频道', channels: groups['others'] }]
     }
  }

  return result
})

onMounted(() => {
  init()
})
</script>

<template>
  <div class="page">
    <header class="page__header">
      <h1>频道广场</h1>
      <div class="actions">
        <input v-model="query" type="search" placeholder="搜索频道" class="search-input" @keyup.enter="onSearch" />
        <button class="primary-btn" @click="onSearch">搜索</button>
        <button class="secondary-btn" @click="channels.fetchSquare('', 500)">刷新</button>
        <button class="secondary-btn" @click="channels.fetchMySubscriptions()">我的订阅</button>
      </div>
    </header>

    <div v-if="channels.loading" class="loading-state">
      加载中...
    </div>

    <template v-else>
      <div v-if="groupedChannels.length === 0" class="empty-state">
        没有找到频道
      </div>

      <div v-for="group in groupedChannels" :key="group.id" class="category-section">
        <h2 class="category-title">{{ group.name }}</h2>
        <section class="grid">
          <div v-for="c in group.channels" :key="c.id" class="card">
            <div class="card__cover" :style="getCoverStyle(c)"></div>
            
            <div class="card__content">
              <h3 class="card__title">{{ c.name }}</h3>
              <p class="card__desc">{{ c.description || '暂无描述' }}</p>
              
              <div class="card__tags" v-if="c.tags && c.tags.length">
                 <span v-for="tag in c.tags" :key="tag.id" class="tag">{{ tag.name }}</span>
              </div>
              
              <div v-if="c.preview_entries && c.preview_entries.length" class="card__previews">
                <div class="previews-title">最新更新</div>
                <ul>
                  <li v-for="entry in c.preview_entries.slice(0, 3)" :key="entry.id" :title="entry.title">
                    {{ entry.title }}
                  </li>
                </ul>
              </div>

              <div class="card__actions">
                <button class="primary-btn" :disabled="isSubscribed(c.id)" @click="onSubscribe(c.id)">
                  {{ isSubscribed(c.id) ? '已订阅' : '订阅' }}
                </button>
                <button class="secondary-btn" :disabled="!isSubscribed(c.id)" @click="isSubscribed(c.id) && channels.fetchChannelEntries(c.id)">查看条目</button>
              </div>
            </div>
          </div>
        </section>
      </div>
    </template>

    <section v-if="channels.channelEntries.length" class="entries">
      <h2>频道条目预览</h2>
      <ul>
        <li v-for="e in channels.channelEntries" :key="e.id">
          <a :href="e.url || '#'" target="_blank">{{ e.title }}</a>
        </li>
      </ul>
    </section>
  </div>
</template>

<style scoped>
.page { 
  padding: 24px; 
  height: 100%;
  overflow-y: auto;
  background-color: var(--bg-base, #f9fafb);
  color: var(--text-primary, #111);
}

.page__header { 
  display: flex; 
  align-items: center; 
  justify-content: space-between; 
  margin-bottom: 24px;
}

.page__header h1 {
  font-size: 24px;
  font-weight: 600;
  margin: 0;
}

.actions { display: flex; gap: 12px; }
.search-input { 
  padding: 8px 12px; 
  border: 1px solid var(--border-color, #ddd); 
  border-radius: 8px; 
  min-width: 240px;
}

.category-section {
  margin-bottom: 32px;
}

.category-title {
  font-size: 18px;
  font-weight: 600;
  margin-bottom: 16px;
  padding-left: 8px;
  border-left: 4px solid var(--primary-color, #ff7a18);
}

.grid { 
  display: grid; 
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); 
  gap: 20px; 
}

.card { 
  background: var(--bg-surface, #fff);
  border: 1px solid var(--border-color, #eee); 
  border-radius: 12px; 
  display: flex;
  flex-direction: column;
  transition: transform 0.2s, box-shadow 0.2s;
  overflow: hidden;
  height: 100%;
}

.card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 24px rgba(0,0,0,0.08);
}

.card__cover {
  height: 120px;
  background-size: cover;
  background-position: center;
  position: relative;
}

.card__content {
  padding: 16px;
  display: flex;
  flex-direction: column;
  flex: 1;
}

.card__title { 
  font-size: 16px; 
  font-weight: 600;
  margin: 0 0 8px; 
  line-height: 1.4;
}

.card__desc { 
  font-size: 14px; 
  color: var(--text-secondary, #666); 
  margin-bottom: 12px;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.5;
}

.card__tags {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-bottom: 12px;
}

.tag {
  font-size: 12px;
  background: var(--bg-base-secondary, #f0f0f0);
  padding: 2px 8px;
  border-radius: 4px;
  color: var(--text-secondary, #666);
}

.card__previews {
  margin-top: 8px;
  margin-bottom: 16px;
  background: var(--bg-base, #f9fafb);
  border-radius: 8px;
  padding: 8px;
  flex: 1;
}

.previews-title {
  font-size: 12px;
  font-weight: 600;
  color: var(--text-secondary, #888);
  margin-bottom: 4px;
}

.card__previews ul {
  list-style: none;
  padding: 0;
  margin: 0;
}

.card__previews li {
  font-size: 13px;
  color: var(--text-primary, #333);
  margin-bottom: 4px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  padding-left: 8px;
  position: relative;
}

.card__previews li::before {
  content: "";
  position: absolute;
  left: 0;
  top: 6px;
  width: 4px;
  height: 4px;
  border-radius: 50%;
  background: var(--primary-color, #ff7a18);
  opacity: 0.6;
}

.card__actions { 
  display: flex; 
  gap: 8px; 
  margin-top: auto;
}

.primary-btn { 
  padding: 8px 16px; 
  border: none; 
  border-radius: 6px; 
  background: var(--primary-color, #ff7a18); 
  color: #fff; 
  cursor: pointer;
  font-weight: 500;
  transition: opacity 0.2s;
  flex: 1;
}

.primary-btn:hover:not(:disabled) {
  opacity: 0.9;
}

.primary-btn:disabled {
  background: #ccc;
  cursor: not-allowed;
}

.secondary-btn { 
  padding: 8px 16px; 
  border: 1px solid var(--border-color, #ddd); 
  border-radius: 6px; 
  background: transparent; 
  cursor: pointer;
  color: var(--text-primary, #333);
  transition: background 0.2s;
}

.secondary-btn:hover:not(:disabled) {
  background: rgba(0,0,0,0.05);
}

.loading-state, .empty-state {
  text-align: center;
  padding: 40px;
  color: var(--text-secondary, #888);
}

.entries { 
  margin-top: 32px; 
  padding-top: 24px;
  border-top: 1px solid var(--border-color, #eee);
}

.entries ul { 
  list-style: none; 
  padding: 0; 
  margin: 0; 
  display: grid; 
  gap: 8px; 
}

.entries a { 
  color: var(--text-primary, #111); 
  text-decoration: none; 
  display: block;
  padding: 8px;
  border-radius: 4px;
}

.entries a:hover {
  background: var(--bg-base-secondary, #f5f5f5);
}
</style>