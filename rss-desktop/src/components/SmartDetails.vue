<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import type { Entry } from '../types'

const props = defineProps<{
  entry: Entry | null
  summary?: string | null
  keyPoints?: string[]
  loading?: boolean
  generating?: boolean
}>()

const emit = defineEmits<{
  (e: 'generate'): void
  (e: 'open-reader'): void
  (e: 'open-original'): void
  (e: 'toggle-star'): void
}>()

const { t } = useI18n()

const hasContent = computed(() => !!props.summary || (props.keyPoints && props.keyPoints.length > 0))

function formatReadingTime(content?: string) {
  if (!content) return 0
  return Math.ceil(content.length / 500)
}
</script>

<template>
  <div class="smart-details">
    <div v-if="entry" class="smart-details__content">
      
      <!-- Actions Header -->
      <div class="details-actions">
        <button class="action-chip primary" @click="emit('open-reader')">
          <span class="icon">📖</span>
          {{ t('readingMode.smartReading') || '沉浸阅读' }}
        </button>
        <button class="action-chip" @click="emit('open-original')">
          <span class="icon">🔗</span>
          {{ t('feeds.openOriginal') || '原网页' }}
        </button>
        <button class="action-chip" @click="emit('toggle-star')">
          <span class="icon">{{ entry.starred ? '★' : '☆' }}</span>
          {{ entry.starred ? (t('articles.cancelFavorite') || '已收藏') : (t('articles.addFavorite') || '收藏') }}
        </button>
      </div>

      <!-- 精华速览区域 -->
      <section class="detail-card essence-card">
        <div class="card-header">
          <span class="icon-box">✨</span>
          <h3>{{ t('ai.summaryLabel') || '精华速览' }}</h3>
        </div>
        
        <div class="card-body">
          <div v-if="generating" class="loading-state">
            <div class="spinner"></div>
            <span>{{ t('ai.generating') || '正在生成...' }}</span>
          </div>
          
          <div v-else-if="summary" class="summary-content">
            <p>{{ summary }}</p>
          </div>
          
          <div v-else class="empty-state">
            <p>{{ t('ai.noSummary') || '暂无摘要' }}</p>
            <button class="generate-btn" @click="emit('generate')" :disabled="loading">
              {{ t('ai.generateButton') || '生成摘要' }}
            </button>
          </div>
        </div>
      </section>

      <!-- 关键信息区域 -->
      <section class="detail-card key-info-card">
        <div class="card-header">
          <span class="icon-box">💡</span>
          <h3>{{ '关键信息' }}</h3>
        </div>
        
        <div class="card-body">
          <ul v-if="keyPoints && keyPoints.length" class="key-points-list">
            <li v-for="(point, index) in keyPoints" :key="index" class="key-point-item">
              <span class="index-badge">{{ index + 1 }}</span>
              <span class="text">{{ point }}</span>
            </li>
          </ul>
          <div v-else-if="summary" class="empty-info">
             <p class="muted-text">未提取到关键点</p>
          </div>
          <div v-else class="empty-info">
            <p class="muted-text">生成摘要后查看关键信息</p>
          </div>
        </div>
      </section>

      <!-- 全文拆解/元数据 -->
      <section class="detail-card meta-card">
         <div class="card-header">
          <span class="icon-box">📝</span>
          <h3>{{ '全文拆解' }}</h3>
        </div>
        <div class="card-body meta-grid">
           <div class="meta-item">
             <span class="label">字数</span>
             <span class="value">{{ entry.content?.length || 0 }} 字</span>
           </div>
           <div class="meta-item">
             <span class="label">阅读时长</span>
             <span class="value">约 {{ formatReadingTime(entry.content ?? undefined) }} 分钟</span>
           </div>
           <div class="meta-item">
             <span class="label">发布时间</span>
             <span class="value">{{ new Date(entry.published_at || '').toLocaleDateString() }}</span>
           </div>
           <div class="meta-item">
             <span class="label">来源</span>
             <span class="value">{{ entry.feed_title || 'Unknown' }}</span>
           </div>
        </div>
      </section>
      
    </div>
    
    <div v-else class="empty-selection">
      <div class="empty-content">
        <span class="empty-icon">👈</span>
        <p>{{ t('articles.selectArticle') || '选择一篇文章查看详情' }}</p>
      </div>
    </div>
  </div>
</template>

<style scoped>
.smart-details {
  height: 100%;
  overflow-y: auto;
  padding: 24px;
  background-color: var(--bg-surface, #fff);
  box-sizing: border-box;
}

.smart-details__content {
  display: flex;
  flex-direction: column;
  gap: 20px;
  max-width: 800px;
  margin: 0 auto;
}

/* Actions */
.details-actions {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
  margin-bottom: 8px;
}

.action-chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 8px 16px;
  border-radius: 20px;
  border: 1px solid var(--border-color);
  background: var(--bg-surface);
  color: var(--text-primary);
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
}

.action-chip:hover {
  background: var(--bg-secondary);
  transform: translateY(-1px);
  box-shadow: 0 2px 8px rgba(0,0,0,0.05);
}

.action-chip.primary {
  background: var(--primary-color, #ff7a18);
  color: white;
  border-color: transparent;
}

.action-chip.primary:hover {
  background: var(--primary-color-hover, #e66000);
  box-shadow: 0 4px 12px rgba(255, 122, 24, 0.2);
}

.detail-card {
  background: var(--bg-card, #f9f9f9);
  border-radius: 16px;
  padding: 20px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.02);
  transition: transform 0.2s, box-shadow 0.2s;
  border: 1px solid var(--border-color, rgba(0,0,0,0.05));
}

.detail-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.06);
}

.card-header {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 16px;
}

.icon-box {
  font-size: 18px;
  background: var(--bg-icon-box, rgba(0,0,0,0.03));
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 10px;
}

.card-header h3 {
  font-size: 16px;
  font-weight: 600;
  margin: 0;
  color: var(--text-primary);
}

.card-body {
  font-size: 14px;
  line-height: 1.6;
  color: var(--text-secondary);
}

/* Essence Card */
.summary-content p {
  margin: 0;
  text-align: justify;
}

.generate-btn {
  margin-top: 12px;
  padding: 8px 20px;
  background: var(--primary-color, #ff7a18);
  color: white;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-size: 14px;
  transition: opacity 0.2s;
}

.generate-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

/* Key Points Card */
.key-points-list {
  list-style: none;
  padding: 0;
  margin: 0;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.key-point-item {
  display: flex;
  gap: 12px;
  align-items: flex-start;
}

.index-badge {
  background: var(--bg-tertiary, #eee);
  color: var(--text-secondary);
  font-size: 12px;
  font-weight: 700;
  min-width: 20px;
  height: 20px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 6px;
  margin-top: 2px;
}

/* Meta Card */
.meta-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
  gap: 16px;
}

.meta-item {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.meta-item .label {
  font-size: 12px;
  color: var(--text-tertiary, #999);
}

.meta-item .value {
  font-size: 14px;
  font-weight: 500;
  color: var(--text-primary);
}

.empty-selection {
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-tertiary);
}

.empty-content {
  text-align: center;
  opacity: 0.5;
}

.empty-icon {
  font-size: 48px;
  display: block;
  margin-bottom: 16px;
}
</style>
