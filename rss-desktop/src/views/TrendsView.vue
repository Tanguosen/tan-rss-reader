<template>
  <div class="trends-view">
    <div class="tabs">
      <button :class="{ active: viewMode === 'trends' }" @click="viewMode = 'trends'">话题趋势</button>
      <button :class="{ active: viewMode === 'search' }" @click="viewMode = 'search'">语义搜索</button>
    </div>

    <div v-if="viewMode === 'trends'" class="view-content">
      <div class="trends-header">
        <h1>话题趋势</h1>
        <div class="controls">
          <select v-model="days" @change="loadClusters">
            <option :value="1">最近 24 小时</option>
            <option :value="3">最近 3 天</option>
            <option :value="7">最近一周</option>
            <option :value="30">最近 1 个月</option>
            <option :value="90">最近 3 个月</option>
            <option :value="180">最近半年</option>
            <option :value="365">最近 1 年</option>
          </select>
          <button @click="loadClusters" :disabled="store.loading">刷新</button>
        </div>
      </div>
      
      <div v-if="store.loading && !store.clusters.length" class="loading">正在加载趋势...</div>
      <div v-else-if="store.error" class="error">{{ store.error }}</div>
      <div v-else-if="!store.clusters.length" class="empty">该时间段内未发现趋势话题。</div>
      
      <div v-else class="clusters-grid">
        <div v-for="cluster in store.clusters" :key="cluster.cluster_id" class="cluster-card" @click="viewDetail(cluster.cluster_id)">
          <div class="cluster-header">
            <h3>{{ cluster.topic }}</h3>
            <span class="badge">{{ cluster.size }} 篇文章</span>
          </div>
          <ul class="cluster-items">
            <li v-for="item in cluster.items.slice(0, 3)" :key="item.entry_id">
              <span class="item-title">{{ item.title }}</span>
            </li>
            <li v-if="cluster.items.length > 3" class="more">
              + {{ cluster.items.length - 3 }} 篇更多
            </li>
          </ul>
        </div>
      </div>
    </div>

    <div v-if="viewMode === 'search'" class="view-content">
      <div class="search-header">
        <h1>语义搜索</h1>
        <div class="search-bar">
          <input 
            v-model="searchQuery" 
            @keyup.enter="handleSearch" 
            placeholder="输入问题或描述你想要查找的内容..." 
            type="text"
          />
          <button @click="handleSearch" :disabled="store.loading">搜索</button>
        </div>
      </div>

      <div v-if="store.loading" class="loading">搜索中...</div>
      <div v-else-if="store.searchResults.length === 0 && hasSearched" class="empty">未找到相关结果。</div>
      
      <div v-else class="search-results">
        <div v-for="result in store.searchResults" :key="result.id" class="search-result-card">
          <div class="result-score">相似度: {{ (result.score * 100).toFixed(1) }}%</div>
          <h3>{{ result.title }}</h3>
          <div class="result-meta">
            <span>{{ new Date(result.published_at * 1000).toLocaleString() }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useClusteringStore } from '../stores/clusteringStore'

const router = useRouter()
const store = useClusteringStore()
const days = ref(3)
const viewMode = ref<'trends' | 'search'>('trends')
const searchQuery = ref('')
const hasSearched = ref(false)

function loadClusters() {
  store.fetchClusters(days.value)
}

function viewDetail(id: number) {
  router.push({ name: 'topic-detail', params: { id } })
}

function handleSearch() {
  if (!searchQuery.value.trim()) return
  hasSearched.value = true
  store.search(searchQuery.value)
}

onMounted(() => {
  loadClusters()
})
</script>

<style scoped>
.trends-view {
  display: flex;
  flex-direction: column;
  height: 100%;
  background: var(--bg-base);
  color: var(--text-primary);
  overflow: hidden;
}

.tabs {
  display: flex;
  gap: 1px;
  background: var(--border-color);
  padding-bottom: 1px;
}

.tabs button {
  padding: 12px 24px;
  background: var(--bg-surface);
  border: none;
  cursor: pointer;
  font-weight: 500;
  color: var(--text-secondary);
  border-bottom: 2px solid transparent;
}

.tabs button.active {
  color: var(--accent);
  border-bottom-color: var(--accent);
  background: var(--bg-base);
}

.view-content {
  flex: 1;
  padding: 24px;
  overflow-y: auto;
}

.trends-header, .search-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
}

.search-bar {
  display: flex;
  gap: 12px;
  flex: 1;
  max-width: 600px;
  margin-left: 24px;
}

.search-bar input {
  flex: 1;
  padding: 8px 12px;
  border-radius: 6px;
  border: 1px solid var(--border-color);
  background: var(--bg-surface);
  color: var(--text-primary);
}

.trends-header h1, .search-header h1 {
  font-size: 24px;
  font-weight: 600;
  margin: 0;
}

.controls {
  display: flex;
  gap: 12px;
}

select, button {
  padding: 8px 12px;
  border-radius: 6px;
  border: 1px solid var(--border-color);
  background: var(--bg-surface);
  color: var(--text-primary);
  font-size: 14px;
  cursor: pointer;
}

button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.clusters-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 20px;
}

.cluster-card {
  border: 1px solid var(--border-color);
  border-radius: 12px;
  padding: 20px;
  background: var(--bg-surface);
  box-shadow: 0 2px 8px rgba(0,0,0,0.05);
  transition: transform 0.2s, box-shadow 0.2s;
  cursor: pointer;
}

.cluster-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 16px rgba(0,0,0,0.1);
}

.cluster-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 16px;
  gap: 12px;
}

.cluster-header h3 {
  margin: 0;
  font-size: 16px;
  line-height: 1.4;
  font-weight: 600;
  flex: 1;
}

.badge {
  background: var(--accent);
  color: white;
  padding: 4px 8px;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 500;
  white-space: nowrap;
}

.cluster-items {
  list-style: none;
  padding: 0;
  margin: 0;
}

.cluster-items li {
  margin-bottom: 8px;
  font-size: 14px;
  line-height: 1.4;
  color: var(--text-secondary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.more {
  color: var(--text-tertiary);
  font-size: 12px;
  margin-top: 12px;
  font-style: italic;
}

.loading, .error, .empty {
  text-align: center;
  padding: 40px;
  color: var(--text-secondary);
}

.error {
  color: #ff4d4f;
}

.search-results {
  display: flex;
  flex-direction: column;
  gap: 16px;
  max-width: 800px;
}

.search-result-card {
  padding: 16px;
  border: 1px solid var(--border-color);
  border-radius: 8px;
  background: var(--bg-surface);
}

.result-score {
  font-size: 12px;
  color: var(--accent);
  margin-bottom: 4px;
  font-weight: 500;
}

.search-result-card h3 {
  margin: 0 0 8px 0;
  font-size: 16px;
}

.result-meta {
  font-size: 12px;
  color: var(--text-tertiary);
}
</style>
