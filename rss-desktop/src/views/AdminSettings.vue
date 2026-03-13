<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useSettingsStore } from '../stores/settingsStore'
import { useAIStore, type AIServiceKey } from '../stores/aiStore'
import { useFeedStore } from '../stores/feedStore'
import { useChannelsStore } from '../stores/channelsStore'
import api from '../api/client'
import {
  clampAutoTitleTranslationLimit,
  MAX_AUTO_TITLE_TRANSLATIONS,
  MIN_AUTO_TITLE_TRANSLATIONS,
  TITLE_TRANSLATION_CONCURRENCY_FALLBACK
} from '../constants/translation'

const { t } = useI18n()
const settingsStore = useSettingsStore()
const aiStore = useAIStore()
const feedStore = useFeedStore()
const channelsStore = useChannelsStore()

// Types
type TestResult = { success: boolean; message: string }
type ServiceKey = AIServiceKey

// RSSHub URL
const rsshubUrl = ref('https://rsshub.app')
const isTestingRSSHub = ref(false)
const rsshubTestResult = ref<{ success: boolean; message: string } | null>(null)

// Fetch Interval
const FETCH_INTERVAL_MIN = 5
const FETCH_INTERVAL_MAX = 1440
const fetchIntervalInput = ref<number | null>(15)
const fetchIntervalError = ref('')

// AI Config
const createLocalServiceConfig = () => ({
  api_key: '',
  base_url: 'https://open.bigmodel.cn/api/paas/v4/',
  model_name: 'glm-4-flash'
})

const localConfig = ref({
  summary: createLocalServiceConfig(),
  translation: createLocalServiceConfig(),
  features: {
    auto_summary: false,
    auto_translation: false,
    auto_title_translation: false,
    translation_language: 'zh'
  }
})

const serviceTesting = ref<Record<ServiceKey, boolean>>({
  summary: false,
  translation: false
})
const serviceTestResult = ref<Record<ServiceKey, TestResult | null>>({
  summary: null,
  translation: null
})

// Subscription Management
const opmlFileInput = ref<HTMLInputElement | null>(null)
const isImporting = ref(false)
const isExporting = ref(false)
const rssUrl = ref('')
const addingRss = ref(false)

// AI Features Logic
const autoTitleTranslationLimitBounds = {
  min: MIN_AUTO_TITLE_TRANSLATIONS,
  max: MAX_AUTO_TITLE_TRANSLATIONS
}
const titleTranslationConcurrencyHint = Math.max(1, TITLE_TRANSLATION_CONCURRENCY_FALLBACK)

const autoTitleTranslationLimit = computed({
  get: () => settingsStore.settings.max_auto_title_translations,
  set: (value: number) => {
    const clamped = clampAutoTitleTranslationLimit(value)
    settingsStore.updateSettings({ max_auto_title_translations: clamped })
  }
})

const translationDisplayMode = ref(settingsStore.settings.translation_display_mode || 'replace')

// Branding
const brandingToggle = computed({
  get: () => settingsStore.settings.branding_toggle,
  set: (value: boolean) => {
    settingsStore.updateSettings({ branding_toggle: value })
  }
})

// Computed properties for v-model binding if needed
// const fetchIntervalComputed = computed({
//   get: () => settingsStore.settings.fetch_interval_minutes,
//   set: (val: number) => {
//     settingsStore.updateSettings({ fetch_interval_minutes: val })
//   }
// })

// Initialize
onMounted(async () => {
  await Promise.all([
    settingsStore.fetchSettings(),
    aiStore.fetchConfig()
  ])
  
  // Sync settings
  fetchIntervalInput.value = settingsStore.settings.fetch_interval_minutes
  translationDisplayMode.value = settingsStore.settings.translation_display_mode || 'replace'
  
  // Sync AI config
  syncFromStore()
  
  await fetchRSSHubUrl()
})

// Watchers
watch(() => aiStore.config, () => {
  syncFromStore()
}, { deep: true })

watch(translationDisplayMode, (newValue) => {
  settingsStore.updateSettings({ translation_display_mode: newValue })
})

// Helper Functions
function syncFromStore() {
  const summary = aiStore.config.summary || {}
  const translation = aiStore.config.translation || {}
  const features = aiStore.config.features || {}
  localConfig.value.summary = {
    ...localConfig.value.summary,
    api_key: summary.api_key ?? localConfig.value.summary.api_key,
    base_url: summary.base_url ?? localConfig.value.summary.base_url,
    model_name: summary.model_name ?? localConfig.value.summary.model_name
  }
  localConfig.value.translation = {
    ...localConfig.value.translation,
    api_key: translation.api_key ?? localConfig.value.translation.api_key,
    base_url: translation.base_url ?? localConfig.value.translation.base_url,
    model_name: translation.model_name ?? localConfig.value.translation.model_name
  }
  localConfig.value.features = {
    ...localConfig.value.features,
    auto_summary: features.auto_summary ?? localConfig.value.features.auto_summary,
    auto_translation: features.auto_translation ?? localConfig.value.features.auto_translation,
    auto_title_translation: features.auto_title_translation ?? localConfig.value.features.auto_title_translation,
    translation_language: features.translation_language ?? localConfig.value.features.translation_language
  }
}

// RSSHub Logic
async function fetchRSSHubUrl() {
  try {
    const { data } = await api.get('/settings/rsshub-url')
    rsshubUrl.value = data.rsshub_url
  } catch (error) {
    console.error('获取RSSHub URL失败:', error)
  }
}

async function testRSSHubConnection() {
  if (!rsshubUrl.value) {
    rsshubTestResult.value = { success: false, message: '请先输入RSSHub URL' }
    return
  }

  isTestingRSSHub.value = true
  rsshubTestResult.value = null

  try {
    await saveRSSHubUrl()
    const { data: result } = await api.post('/settings/test-rsshub-quick')
    if (result.success) {
      rsshubTestResult.value = {
        success: true,
        message: `✅ RSSHub连接测试成功！<br>
                 响应时间: ${result.response_time?.toFixed(2)}秒<br>
                 RSS条目数: ${result.entries_count}<br>
                 Feed标题: ${result.feed_title}<br>
                 测试路由: ${result.test_url.split('/').pop()}`
      }
    } else {
      rsshubTestResult.value = {
        success: false,
        message: `❌ RSSHub连接测试失败<br>
                 错误信息: ${result.message}<br>
                 测试地址: ${result.rsshub_url}<br>
                 测试时间: ${new Date(result.tested_at).toLocaleString()}`
      }
    }
  } catch (error) {
    rsshubTestResult.value = {
      success: false,
      message: `❌ RSSHub测试失败<br>
               错误: ${error instanceof Error ? error.message : '未知错误'}<br><br>
               请确保：<br>
               • 后端服务正在运行<br>
               • RSSHub URL配置正确<br>
               • 网络连接正常`
    }
  } finally {
    isTestingRSSHub.value = false
  }
}

async function saveRSSHubUrl() {
  if (!rsshubUrl.value) {
    rsshubTestResult.value = { success: false, message: 'RSSHub URL不能为空' }
    return
  }

  try {
    await api.post('/settings/rsshub-url', {
      rsshub_url: rsshubUrl.value
    })
    settingsStore.updateSettings({ rsshub_url: rsshubUrl.value })
    
    rsshubTestResult.value = {
      success: true,
      message: 'RSSHub URL保存成功！'
    }
  } catch (error) {
    rsshubTestResult.value = {
      success: false,
      message: `保存失败: ${error instanceof Error ? error.message : '网络错误'}`
    }
  }
}

// Fetch Interval Logic
function validateFetchInterval(value: number | null) {
  if (value === null || Number.isNaN(value)) {
    fetchIntervalError.value = t('settings.refreshIntervalErrorRequired')
    return null
  }

  if (value < FETCH_INTERVAL_MIN || value > FETCH_INTERVAL_MAX) {
    fetchIntervalError.value = t('settings.refreshIntervalErrorRange', {
      min: FETCH_INTERVAL_MIN,
      max: FETCH_INTERVAL_MAX
    })
    return null
  }

  fetchIntervalError.value = ''
  return value
}

async function commitFetchInterval() {
  const validValue = validateFetchInterval(fetchIntervalInput.value)
  if (validValue === null) {
    return false
  }

  if (validValue === settingsStore.settings.fetch_interval_minutes) {
    return true
  }

  try {
    await settingsStore.updateSettings({ fetch_interval_minutes: validValue })
    return true
  } catch (error) {
    console.error('刷新间隔保存失败', error)
    fetchIntervalError.value = t('settings.refreshIntervalErrorSubmit')
    return false
  }
}

async function handleFetchIntervalChange() {
  await commitFetchInterval()
}

// AI Config Logic
async function testConnection(service: ServiceKey) {
  const serviceConfig = localConfig.value[service]
  if (!serviceConfig.api_key || !serviceConfig.base_url || !serviceConfig.model_name) {
    serviceTestResult.value[service] = { success: false, message: '请先完善API配置' }
    return
  }

  serviceTesting.value[service] = true
  serviceTestResult.value[service] = null

  try {
    const success = await aiStore.testConnection(service, serviceConfig)
    serviceTestResult.value[service] = {
      success,
      message: success ? '连接测试成功！' : aiStore.error || '连接测试失败'
    }
  } catch (error) {
    serviceTestResult.value[service] = { success: false, message: '连接测试失败' }
  } finally {
    serviceTesting.value[service] = false
  }
}

function copySummaryToTranslation() {
  localConfig.value.translation = { ...localConfig.value.summary }
  serviceTestResult.value.translation = null
}

async function saveAIConfig() {
  try {
    const aiSuccess = await aiStore.updateConfig({
      summary: { ...localConfig.value.summary },
      translation: { ...localConfig.value.translation },
      features: { ...localConfig.value.features }
    })
    if (aiSuccess) {
      alert(t('settings.saveSuccess') || '保存成功')
    } else {
      alert(t('settings.saveFailed') || '保存失败')
    }
  } catch (error) {
    console.error('AI配置保存失败', error)
    alert(t('settings.saveFailed') || '保存失败')
  }
}

// Subscription Management Logic
function triggerImportOpml() {
  opmlFileInput.value?.click()
}

async function handleImportOpml(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return
  isImporting.value = true
  try {
    const result = await feedStore.importOpml(file)
    const imported = (result as any)?.imported ?? 0
    const skipped = (result as any)?.skipped ?? 0
    channelsStore.message = `导入完成：新增 ${imported}，跳过 ${skipped}`
    alert(`导入完成：新增 ${imported}，跳过 ${skipped}`)
  } catch {
    channelsStore.error = '导入 OPML 失败'
    alert('导入 OPML 失败')
  } finally {
    input.value = ''
    isImporting.value = false
  }
}

async function handleExportOpml() {
  isExporting.value = true
  try {
    await feedStore.exportOpml()
    channelsStore.message = '导出 OPML 成功'
  } catch {
    channelsStore.error = '导出 OPML 失败'
    alert('导出 OPML 失败')
  } finally {
    isExporting.value = false
  }
}

async function handleAddRss() {
  const url = rssUrl.value.trim()
  if (!url) return
  addingRss.value = true
  try {
    await feedStore.addFeed(url)
    channelsStore.message = '已添加订阅'
    rssUrl.value = ''
    alert('已添加订阅')
  } catch {
    feedStore.errorMessage = '添加订阅失败，请检查链接'
    alert('添加订阅失败，请检查链接')
  } finally {
    addingRss.value = false
  }
}
</script>

<template>
  <div class="admin-settings-wrapper">
    <div class="admin-settings-page">
      <header class="page-header">
        <h1>{{ t('settings.adminSettings') || '管理员设置' }}</h1>
      </header>
      
      <div class="settings-content">
      <!-- RSSHub Config -->
      <section class="settings-section">
        <h3 class="section-title admin-title">
          <span class="icon">🛡️</span>
          {{ t('settings.rssHubConfig') }}
        </h3>
        <div class="form-group">
          <label>RSSHub URL</label>
          <input
            v-model="rsshubUrl"
            type="text"
            :placeholder="t('settings.rssHubPlaceholder')"
            class="form-input"
          />
          <p class="form-hint">
            {{ t('settings.rssHubDescription') }}
          </p>
          <p class="form-hint">
            {{ t('settings.rssHubDeployGuide') }}: <a href="https://docs.rsshub.app/zh/deploy/" target="_blank">RSSHub部署指南</a>
          </p>
        </div>

        <div class="form-group">
          <button
            @click="testRSSHubConnection"
            :disabled="isTestingRSSHub || !rsshubUrl"
            class="test-btn"
            :class="{
              loading: isTestingRSSHub,
              success: rsshubTestResult?.success,
              error: rsshubTestResult?.success === false
            }"
          >
            {{ isTestingRSSHub ? t('settings.testingRssHub') : t('settings.testRssHub') }}
          </button>
          <div v-if="rsshubTestResult" class="test-result" :class="{
            success: rsshubTestResult.success,
            error: !rsshubTestResult.success
          }">
            <span v-html="rsshubTestResult.message"></span>
          </div>
        </div>
      </section>

      <!-- AI Config -->
      <section class="settings-section">
        <h3 class="section-title admin-title">
          <span class="icon">🤖</span>
          {{ t('settings.aiConfig') }}
        </h3>
        <div class="ai-config-grid">
          <!-- Summary Config -->
          <div class="ai-config-card">
            <div class="ai-config-card__header">
              <div>
                <p class="ai-config-card__title">{{ t('settings.summaryGeneration') }}</p>
                <p class="ai-config-card__subtitle">{{ t('settings.summarySubtitle') }}</p>
              </div>
              <button
                @click="testConnection('summary')"
                :disabled="serviceTesting.summary || !localConfig.summary.api_key || !localConfig.summary.base_url || !localConfig.summary.model_name"
                class="test-btn"
                :class="{
                  loading: serviceTesting.summary,
                  success: serviceTestResult.summary?.success,
                  error: serviceTestResult.summary?.success === false
                }"
              >
                {{ serviceTesting.summary ? t('common.testing') : t('settings.testConnection') }}
              </button>
            </div>

            <div class="form-group">
              <label>{{ t('settings.apiKey') }}</label>
              <input
                v-model="localConfig.summary.api_key"
                type="password"
                :placeholder="t('settings.apiKeyPlaceholder')"
                class="form-input"
              />
              <p class="form-hint">
                {{ t('settings.getApiKey') }}
                <a href="https://open.bigmodel.cn" target="_blank">https://open.bigmodel.cn</a>
              </p>
            </div>

            <div class="form-group">
              <label>{{ t('settings.apiUrl') }}</label>
              <input
                v-model="localConfig.summary.base_url"
                type="text"
                :placeholder="t('settings.apiUrlPlaceholder')"
                class="form-input"
              />
            </div>

            <div class="form-group">
              <label>{{ t('settings.modelName') }}</label>
              <input
                v-model="localConfig.summary.model_name"
                type="text"
                :placeholder="t('settings.modelPlaceholder')"
                class="form-input"
              />
              <p class="form-hint">
                {{ t('settings.supportedModels') }}
              </p>
            </div>

            <div
              v-if="serviceTestResult.summary"
              class="test-result"
              :class="{ success: serviceTestResult.summary.success, error: !serviceTestResult.summary.success }"
            >
              {{ serviceTestResult.summary.message }}
            </div>
          </div>

          <!-- Translation Config -->
          <div class="ai-config-card">
            <div class="ai-config-card__header">
              <div>
                <p class="ai-config-card__title">{{ t('settings.contentTranslation') }}</p>
                <p class="ai-config-card__subtitle">{{ t('settings.translationSubtitle') }}</p>
              </div>
              <div class="ai-config-card__actions">
                <button class="ghost-btn" type="button" @click="copySummaryToTranslation">
                  {{ t('settings.useSummaryConfig') }}
                </button>
                <button
                  @click="testConnection('translation')"
                  :disabled="serviceTesting.translation || !localConfig.translation.api_key || !localConfig.translation.base_url || !localConfig.translation.model_name"
                  class="test-btn"
                  :class="{
                    loading: serviceTesting.translation,
                    success: serviceTestResult.translation?.success,
                    error: serviceTestResult.translation?.success === false
                  }"
                >
                  {{ serviceTesting.translation ? t('common.testing') : t('settings.testConnection') }}
                </button>
              </div>
            </div>

            <div class="form-group">
              <label>{{ t('settings.apiKey') }}</label>
              <input
                v-model="localConfig.translation.api_key"
                type="password"
                :placeholder="t('settings.translationApiKeyPlaceholder')"
                class="form-input"
              />
            </div>

            <div class="form-group">
              <label>{{ t('settings.apiUrl') }}</label>
              <input
                v-model="localConfig.translation.base_url"
                type="text"
                :placeholder="t('settings.apiUrlPlaceholder')"
                class="form-input"
              />
            </div>

            <div class="form-group">
              <label>{{ t('settings.modelName') }}</label>
              <input
                v-model="localConfig.translation.model_name"
                type="text"
                :placeholder="t('settings.translationModelPlaceholder')"
                class="form-input"
              />
            </div>

            <div
              v-if="serviceTestResult.translation"
              class="test-result"
              :class="{ success: serviceTestResult.translation.success, error: !serviceTestResult.translation.success }"
            >
              {{ serviceTestResult.translation.message }}
            </div>
          </div>
        </div>
        
        <div class="form-group" style="margin-top: 20px; text-align: right;">
          <button @click="saveAIConfig" class="btn btn-primary">{{ t('settings.save') }}</button>
        </div>
      </section>

      <!-- AI Features -->
      <section class="settings-section">
        <h3 class="section-title admin-title">
          <span class="icon">✨</span>
          {{ t('settings.aiFeatures') }}
        </h3>
        <div class="form-group">
          <label class="checkbox-label">
            <input
              v-model="localConfig.features.auto_summary"
              type="checkbox"
              class="form-checkbox"
            />
            {{ t('settings.autoSummary') }}
            <span class="checkbox-hint">{{ t('settings.autoSummaryHint') }}</span>
          </label>
        </div>

        <div class="form-group">
          <label class="checkbox-label">
            <input
              v-model="localConfig.features.auto_translation"
              type="checkbox"
              class="form-checkbox"
            />
            {{ t('settings.autoTranslation') }}
            <span class="checkbox-hint">{{ t('settings.autoTranslationHint') }}</span>
          </label>
        </div>

        <div class="form-group">
          <label class="checkbox-label">
            <input
              v-model="localConfig.features.auto_title_translation"
              type="checkbox"
              class="form-checkbox"
            />
            {{ t('settings.autoTitleTranslation') }}
            <span class="checkbox-hint">{{ t('settings.autoTitleTranslationHint') }}</span>
          </label>
        </div>

        <div
          class="form-group"
          v-if="localConfig.features.auto_translation || localConfig.features.auto_title_translation"
        >
          <label>{{ t('settings.translationTargetLanguage') }}</label>
          <select v-model="localConfig.features.translation_language" class="form-select">
            <option value="zh">{{ t('languages.zh') }}</option>
            <option value="en">{{ t('languages.en') }}</option>
            <option value="ja">{{ t('languages.ja') }}</option>
            <option value="ko">{{ t('languages.ko') }}</option>
            <option value="fr">{{ t('languages.fr') }}</option>
            <option value="de">{{ t('languages.de') }}</option>
            <option value="es">{{ t('languages.es') }}</option>
          </select>
        </div>

        <div class="form-group title-translation-limit">
          <div class="title-translation-limit__label">
            <label>
              {{ t('settings.autoTitleTranslationLimitLabel', { count: autoTitleTranslationLimit }) }}
            </label>
            <span class="limit-value">{{ autoTitleTranslationLimit }}</span>
          </div>
          <input
            type="range"
            class="form-range"
            v-model.number="autoTitleTranslationLimit"
            :min="autoTitleTranslationLimitBounds.min"
            :max="autoTitleTranslationLimitBounds.max"
            :disabled="!localConfig.features.auto_title_translation"
          />
          <div class="range-scale">
            <span>{{ autoTitleTranslationLimitBounds.min }} (慢速省流)</span>
            <span>{{ autoTitleTranslationLimitBounds.max }} (快速耗流)</span>
          </div>
          <p class="form-hint">
            {{ t('settings.autoTitleTranslationLimitHint', { concurrency: titleTranslationConcurrencyHint }) }}
          </p>
        </div>

        <div class="form-group">
          <label>{{ t('settings.translationDisplayMode') }}</label>
          <select v-model="translationDisplayMode" class="form-select">
            <option value="replace">{{ t('settings.translationModeReplace') }}</option>
            <option value="bilingual_original_first">{{ t('settings.translationModeBilingualOriginalFirst') }}</option>
            <option value="bilingual_translation_first">{{ t('settings.translationModeBilingualTranslationFirst') }}</option>
          </select>
          <p class="form-hint">
            {{ t('settings.translationDisplayModeHint') }}
          </p>
        </div>
        
        <div class="form-group" style="margin-top: 20px; text-align: right;">
          <button @click="saveAIConfig" class="btn btn-primary">{{ t('settings.save') }}</button>
        </div>
      </section>

      <!-- Subscription Update Config -->
      <section class="settings-section">
        <h3 class="section-title admin-title">
          <span class="icon">🔄</span>
          {{ t('settings.subscriptionUpdate') }}
        </h3>
        <div class="form-group">
          <label>{{ t('settings.refreshInterval') }}</label>
          <input
            v-model.number="fetchIntervalInput"
            type="number"
            class="form-input"
            :min="5"
            @change="handleFetchIntervalChange"
          />
          <p class="form-hint">{{ t('settings.refreshIntervalDescription') }}</p>
          <p v-if="fetchIntervalError" class="error-message">{{ fetchIntervalError }}</p>
        </div>
      </section>
      
      <!-- Subscription Management -->
      <section class="settings-section">
        <h3 class="section-title admin-title">
          <span class="icon">📁</span>
          订阅管理
        </h3>
        <div class="form-group">
          <label>OPML 导入/导出</label>
          <div style="display: flex; gap: 10px; margin-top: 8px;">
            <button class="btn btn-secondary" @click="triggerImportOpml" :disabled="isImporting">导入 OPML</button>
            <input
              ref="opmlFileInput"
              type="file"
              accept=".opml,.xml"
              @change="handleImportOpml"
              style="display: none"
            />
            <button class="btn btn-secondary" @click="handleExportOpml" :disabled="isExporting">导出 OPML</button>
          </div>
        </div>
        <div class="form-group">
          <label>添加 RSS 订阅链接</label>
          <div style="display: flex; gap: 10px; margin-top: 8px;">
            <input v-model="rssUrl" type="url" placeholder="https://example.com/feed.xml" class="form-input" style="flex: 1;" />
            <button class="btn btn-primary" @click="handleAddRss" :disabled="addingRss || !rssUrl">添加</button>
          </div>
        </div>
      </section>

      <!-- About -->
      <section class="settings-section">
        <h3 class="section-title admin-title">
          <span class="icon">ℹ️</span>
          {{ t('settings.about') }}
        </h3>
        <div class="about-content">
          <div class="about-header">
            <h4 class="app-title">TAN</h4>
          </div>
          <div class="form-group">
            <label>品牌描述</label>
            <div class="radio-group">
              <label class="radio-label">
                <input v-model="brandingToggle" type="radio" :value="false" class="form-radio" />
                Trend · Awareness · Network（趋势 · 认知 · 网络）
              </label>
              <label class="radio-label">
                <input v-model="brandingToggle" type="radio" :value="true" class="form-radio" />
                Tech · AI · Nexus（技术 · 人工智能 · 枢纽）
              </label>
            </div>
          </div>

          <p class="app-name-note" v-if="!brandingToggle">
            TAN = Trend · Awareness · Network（趋势 · 认知 · 网络）
          </p>
          <p class="app-name-note" v-else>
            TAN = Tech · AI · Nexus（技术 · 人工智能 · 枢纽）
          </p>
          <div class="app-description" v-if="!brandingToggle">
            <p>Trend：前沿趋势、最新研究、技术动向</p>
            <p>Awareness：认知觉察、理解、判断</p>
            <p>Network：信息网络、知识网络、专家网络</p>
            <p>整体含义：面向未来的趋势感知与认知网络</p>
          </div>
          <div class="app-description" v-else>
            <p>Tech：前沿技术（AI、数字人、多模态、知识图谱、系统工程）</p>
            <p>AI：智能中枢（推理、生成、决策、协同）</p>
            <p>Nexus：连接点 / 枢纽 / 中枢（数据 ↔ 知识 ↔ 决策 ↔ 行动）</p>
            <p>整体含义：面向未来的信息与智能连接枢纽</p>
          </div>
          <div class="about-features">
            <span class="feature-badge">📰 {{ t('settings.features.rss') }}</span>
            <span class="feature-badge">🤖 {{ t('settings.features.ai') }}</span>
            <span class="feature-badge">🌐 {{ t('settings.features.translation') }}</span>
            <span class="feature-badge">⭐ {{ t('settings.features.favorites') }}</span>
          </div>
          
          <p class="about-footer">
            Made with ❤️ using Vue 3 + FastAPI
          </p>
        </div>
      </section>
    </div>
  </div>
  </div>
</template>

<style scoped>
.admin-settings-wrapper {
  height: 100%;
  overflow-y: auto;
  width: 100%;
}

.admin-settings-page {
  padding: 32px;
  max-width: 800px;
  margin: 0 auto;
}

.page-header {
  margin-bottom: 32px;
}

.page-header h1 {
  font-size: 24px;
  font-weight: 600;
  color: var(--text-primary);
  margin: 0;
}

.settings-content {
  display: flex;
  flex-direction: column;
  gap: 32px;
}

.settings-section {
  padding: 24px;
  border-radius: 12px;
  background: var(--bg-surface, #ffffff);
  border: 1px solid var(--border-color);
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
}

.section-title {
  display: flex;
  align-items: center;
  gap: 8px;
  margin: 0 0 24px 0;
  font-size: 18px;
  font-weight: 600;
  color: var(--text-primary);
}

.admin-title {
  color: #d97706; /* Amber-600 */
}

.form-group {
  margin-bottom: 20px;
}

.form-group:last-child {
  margin-bottom: 0;
}

.form-group label {
  display: block;
  margin-bottom: 8px;
  font-weight: 500;
  color: var(--text-primary);
}

.form-input,
.form-select {
  width: 100%;
  padding: 10px 12px;
  border-radius: 8px;
  border: 1px solid var(--border-color);
  background: var(--bg-surface-2, #f9fafb);
  color: var(--text-primary);
  font-size: 14px;
  transition: all 0.2s;
}

.form-input:focus,
.form-select:focus {
  outline: none;
  border-color: var(--primary-color, #4c74ff);
  box-shadow: 0 0 0 3px rgba(76, 116, 255, 0.1);
}

.form-hint {
  margin-top: 8px;
  font-size: 13px;
  color: var(--text-secondary);
  line-height: 1.5;
}

.form-hint a {
  color: var(--primary-color, #4c74ff);
  text-decoration: none;
}

.form-hint a:hover {
  text-decoration: underline;
}

/* AI Config Grid */
.ai-config-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
  gap: 16px;
}

.ai-config-card {
  border: 1px solid var(--border-color);
  border-radius: 12px;
  padding: 16px;
  background: var(--bg-surface-2, #f9fafb);
}

.ai-config-card__header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  margin-bottom: 12px;
  flex-wrap: wrap;
}

.ai-config-card__title {
  margin: 0;
  font-size: 15px;
  font-weight: 600;
  color: var(--text-primary);
}

.ai-config-card__subtitle {
  margin: 4px 0 0 0;
  font-size: 13px;
  color: var(--text-secondary);
}

.ai-config-card__actions {
  display: flex;
  gap: 8px;
  align-items: center;
  flex-wrap: wrap;
  justify-content: flex-end;
}

/* Buttons */
.btn {
  padding: 8px 16px;
  border: none;
  border-radius: 6px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-secondary {
  background: var(--bg-surface-hover, #f3f4f6);
  color: var(--text-secondary);
  border: 1px solid var(--border-color);
}

.btn-secondary:hover {
  background: var(--bg-surface-active, #e5e7eb);
}

.btn-primary {
  background: var(--primary-color, #4c74ff);
  color: white;
}

.btn-primary:hover {
  opacity: 0.9;
}

.test-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 6px 12px;
  border-radius: 6px;
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  background: white;
  border: 1px solid var(--border-color);
  color: var(--text-primary);
}

.test-btn:hover:not(:disabled) {
  background: var(--bg-surface-hover);
}

.test-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.test-btn.loading {
  cursor: wait;
}

.test-btn.success {
  background: #d1fae5;
  color: #065f46;
  border-color: #a7f3d0;
}

.test-btn.error {
  background: #fee2e2;
  color: #991b1b;
  border-color: #fecaca;
}

.ghost-btn {
  border: 1px dashed rgba(76, 116, 255, 0.4);
  background: rgba(76, 116, 255, 0.08);
  color: var(--primary-color, #4c74ff);
  padding: 6px 12px;
  border-radius: 6px;
  font-size: 13px;
  cursor: pointer;
  transition: all 0.2s;
}

.ghost-btn:hover {
  background: rgba(76, 116, 255, 0.15);
}

.test-result {
  margin-top: 12px;
  padding: 12px;
  border-radius: 8px;
  font-size: 13px;
  line-height: 1.5;
}

.test-result.success {
  background: #f0fdf4;
  color: #166534;
  border: 1px solid #bbf7d0;
}

.test-result.error {
  background: #fef2f2;
  color: #991b1b;
  border: 1px solid #fecaca;
}

.error-message {
  margin-top: 8px;
  color: #dc2626;
  font-size: 13px;
}

/* Form Controls */
.checkbox-label {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  cursor: pointer;
  padding: 4px 0;
}

.form-checkbox {
  margin-top: 3px;
}

.checkbox-hint {
  font-size: 12px;
  color: var(--text-secondary);
  display: block;
  margin-top: 2px;
  line-height: 1.3;
}

.form-range {
  width: 100%;
  margin-top: 4px;
  accent-color: var(--primary-color, #4c74ff);
}

.range-scale {
  display: flex;
  justify-content: space-between;
  font-size: 11px;
  color: var(--text-secondary);
  margin-top: 4px;
}

.title-translation-limit__label {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.limit-value {
  font-weight: 600;
  color: var(--primary-color, #4c74ff);
}

/* About Section */
.about-content {
  background: linear-gradient(135deg, rgba(255, 122, 24, 0.05) 0%, rgba(88, 86, 214, 0.05) 100%);
  border-radius: 12px;
  padding: 20px;
  border: 1px solid var(--border-color);
}

.about-header {
  margin-bottom: 16px;
}

.app-title {
  margin: 0;
  font-size: 20px;
  font-weight: 700;
  background: linear-gradient(120deg, #ff7a18, #5856d6);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.radio-group {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.radio-label {
  display: flex;
  align-items: center;
  gap: 8px;
  font-weight: normal;
  margin-bottom: 0;
}

.app-name-note {
  margin: 12px 0 0;
  font-size: 13px;
  color: var(--text-secondary);
}

.app-description {
  font-size: 14px;
  color: var(--text-primary);
  line-height: 1.6;
  margin: 12px 0 16px 0;
}

.about-features {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-bottom: 16px;
}

.feature-badge {
  display: inline-flex;
  align-items: center;
  padding: 4px 10px;
  background: white;
  border: 1px solid var(--border-color);
  border-radius: 20px;
  font-size: 12px;
  color: var(--text-secondary);
  font-weight: 500;
}

.about-footer {
  margin: 0;
  padding-top: 16px;
  border-top: 1px solid var(--border-color);
  font-size: 13px;
  color: var(--text-secondary);
  text-align: center;
  font-style: italic;
}
</style>
