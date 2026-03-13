<template>
  <div class="topic-detail">
    <div class="header">
      <button @click="goBack" class="back-btn">← 返回</button>
      <h1>{{ topicTitle }}</h1>
    </div>

    <div v-if="loading" class="loading-state">
      <div class="spinner"></div>
      <p>正在生成智能分析报告...</p>
    </div>
    
    <div v-else-if="error" class="error-state">
      <p>{{ error }}</p>
      <button @click="retryAnalysis">重试</button>
    </div>
    
    <div v-else-if="result" class="content">
      <div class="analysis-section">
        <div class="card summary-card">
          <h2>智能趋势分析</h2>
          <div class="prediction">
            <strong>趋势预测：</strong> {{ result.analysis.trend_prediction }}
          </div>
          <div class="keywords">
            <span v-for="kw in result.analysis.keywords" :key="kw" class="tag">{{ kw }}</span>
          </div>
          <div class="sentiment">
            <span>情感倾向：</span>
            <div class="progress-bar">
              <div class="progress" :style="{ width: ((result.analysis.sentiment_score + 1) / 2 * 100) + '%', background: sentimentColor }"></div>
            </div>
            <span :style="{ color: sentimentColor }">{{ sentimentLabel }}</span>
          </div>
          <div class="summary-text">
             <strong>摘要：</strong> {{ result.analysis.summary }}
          </div>
        </div>
        
        <div class="card chart-card">
            <h3>热度趋势</h3>
            <div class="chart-container">
              <Bar :data="chartData" :options="chartOptions" />
            </div>
        </div>
      </div>

      <div class="timeline-section">
        <h2>事件脉络</h2>
        <div class="timeline">
          <div v-for="item in result.timeline" :key="item.id" class="timeline-item">
            <div class="time-marker">
              {{ formatDate(item.published_at) }}
            </div>
            <div class="item-content">
              <h3>{{ item.title }}</h3>
              <p>{{ item.summary }}</p>
              <span class="source">{{ item.source }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useClusteringStore } from '../stores/clusteringStore'
import { Bar } from 'vue-chartjs'
import { Chart as ChartJS, Title, Tooltip, Legend, BarElement, CategoryScale, LinearScale } from 'chart.js'

ChartJS.register(Title, Tooltip, Legend, BarElement, CategoryScale, LinearScale)

const route = useRoute()
const router = useRouter()
const store = useClusteringStore()

const topicTitle = ref('')

onMounted(async () => {
  await loadData()
})

async function loadData() {
  const clusterId = Number(route.params.id)
  // Find cluster in store (must have come from TrendsView)
  const cluster = store.clusters.find(c => c.cluster_id === clusterId)
  
  if (!cluster) {
    // If not found (e.g. direct access or refresh), redirect to trends
    router.push('/trends')
    return
  }
  
  topicTitle.value = cluster.topic
  
  // Call analysis
  const entryIds = cluster.items.map(i => i.entry_id)
  await store.analyzeCluster(entryIds)
}

function retryAnalysis() {
    loadData()
}

const loading = computed(() => store.loading)
const error = computed(() => store.error)
const result = computed(() => store.analysisResult)

const sentimentColor = computed(() => {
    const score = result.value?.analysis.sentiment_score || 0
    if (score > 0.2) return '#52c41a'
    if (score < -0.2) return '#ff4d4f'
    return '#faad14'
})

const sentimentLabel = computed(() => {
    const score = result.value?.analysis.sentiment_score || 0
    if (score > 0.2) return '正面'
    if (score < -0.2) return '负面'
    return '中性'
})

const chartData = computed(() => {
    if (!result.value) return { labels: [], datasets: [] }
    
    return {
        labels: result.value.stats.time_distribution.map(d => d.date),
        datasets: [{
            label: '文章数量',
            data: result.value.stats.time_distribution.map(d => d.count),
            backgroundColor: '#1890ff',
            borderRadius: 4
        }]
    }
})

const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
        legend: {
            display: false
        }
    },
    scales: {
        y: {
            beginAtZero: true,
            ticks: {
                stepSize: 1
            },
            grid: {
                color: 'rgba(0,0,0,0.05)'
            }
        },
        x: {
            grid: {
                display: false
            }
        }
    }
}

function goBack() {
  router.back()
}

function formatDate(ts: number) {
  return new Date(ts * 1000).toLocaleString()
}
</script>

<style scoped>
.topic-detail {
  padding: 24px;
  height: 100%;
  overflow-y: auto;
  background: var(--bg-primary);
  color: var(--text-primary);
  box-sizing: border-box;
}

.header {
  display: flex;
  align-items: center;
  gap: 16px;
  margin-bottom: 24px;
}

.header h1 {
  margin: 0;
  font-size: 24px;
  font-weight: 600;
}

.back-btn {
  background: none;
  border: none;
  font-size: 16px;
  cursor: pointer;
  color: var(--text-secondary);
  padding: 8px 0;
}

.back-btn:hover {
  color: var(--text-primary);
}

.loading-state, .error-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 400px;
  color: var(--text-secondary);
}

.spinner {
  width: 40px;
  height: 40px;
  border: 3px solid var(--bg-secondary);
  border-top-color: var(--accent);
  border-radius: 50%;
  animation: spin 1s linear infinite;
  margin-bottom: 16px;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.analysis-section {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 20px;
  margin-bottom: 30px;
}

@media (max-width: 900px) {
  .analysis-section {
    grid-template-columns: 1fr;
  }
}

.card {
  background: var(--bg-surface);
  border: 1px solid var(--border-color);
  border-radius: 12px;
  padding: 20px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.02);
}

.card h2, .card h3 {
  margin-top: 0;
  margin-bottom: 16px;
  font-size: 18px;
  border-bottom: 1px solid var(--border-color);
  padding-bottom: 12px;
}

.prediction {
  margin-bottom: 16px;
  line-height: 1.6;
  font-size: 15px;
}

.keywords {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-bottom: 20px;
}

.tag {
  background: var(--bg-secondary);
  padding: 4px 10px;
  border-radius: 6px;
  font-size: 12px;
  color: var(--text-secondary);
}

.sentiment {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 16px;
}

.progress-bar {
  flex: 1;
  height: 8px;
  background: var(--bg-secondary);
  border-radius: 4px;
  overflow: hidden;
}

.progress {
  height: 100%;
  transition: width 0.5s ease-out;
}

.summary-text {
  font-size: 14px;
  color: var(--text-secondary);
  line-height: 1.6;
  background: var(--bg-secondary);
  padding: 12px;
  border-radius: 8px;
}

.chart-card {
    min-height: 350px;
    display: flex;
    flex-direction: column;
}

.chart-container {
    flex: 1;
    position: relative;
    width: 100%;
}

.timeline-section h2 {
    font-size: 20px;
    margin-bottom: 24px;
}

.timeline {
  border-left: 2px solid var(--border-color);
  padding-left: 24px;
  margin-left: 12px;
}

.timeline-item {
  position: relative;
  margin-bottom: 32px;
}

.timeline-item::before {
  content: '';
  position: absolute;
  left: -31px;
  top: 6px;
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: var(--bg-surface);
  border: 2px solid var(--accent);
}

.time-marker {
  font-size: 13px;
  color: var(--text-tertiary);
  margin-bottom: 8px;
  font-weight: 500;
}

.item-content {
  background: var(--bg-surface);
  padding: 20px;
  border-radius: 12px;
  border: 1px solid var(--border-color);
  transition: transform 0.2s, box-shadow 0.2s;
}

.item-content:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.05);
}

.item-content h3 {
  margin: 0 0 8px 0;
  font-size: 16px;
  font-weight: 600;
  line-height: 1.4;
}

.item-content p {
  font-size: 14px;
  color: var(--text-secondary);
  margin: 0 0 12px 0;
  line-height: 1.6;
}

.source {
  font-size: 12px;
  color: var(--text-tertiary);
  background: var(--bg-secondary);
  padding: 2px 8px;
  border-radius: 4px;
}
</style>
