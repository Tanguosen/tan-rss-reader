<script setup lang="ts">
import { computed, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useLanguage } from '../composables/useLanguage'
import type { LocaleCode } from '../i18n'
import { useSettingsStore } from '../stores/settingsStore'

const props = defineProps<{
  show: boolean
}>()

const emit = defineEmits<{
  close: []
}>()

const { t } = useI18n()
const { setLanguage, currentLanguage, availableLocales } = useLanguage()
const settingsStore = useSettingsStore()

// 语言选择器的本地绑定 - 使用computed确保响应式
const selectedLanguage = computed({
  get: () => currentLanguage.value?.code || 'zh',
  set: (value: string) => handleLanguageChange(value)
})

// 显示设置 - 与settingsStore同步
const enableDateFilter = computed({
  get: () => settingsStore.settings.enable_date_filter,
  set: (value) => {
    settingsStore.updateSettings({ enable_date_filter: value })
  }
})

const defaultDateRange = computed({
  get: () => settingsStore.settings.default_date_range,
  set: (value) => {
    settingsStore.updateSettings({ default_date_range: value })
  }
})

const timeField = computed({
  get: () => settingsStore.settings.time_field,
  set: (value) => {
    settingsStore.updateSettings({ time_field: value })
  }
})

const showEntrySummary = computed({
  get: () => settingsStore.settings.show_entry_summary,
  set: (value) => {
    settingsStore.updateSettings({ show_entry_summary: value })
  }
})

// 监听模态框显示状态
watch(() => props.show, async (show) => {
  if (show) {
    await settingsStore.fetchSettings()
  }
})

async function saveSettings() {
  try {
    // 其他设置已经通过computed属性自动保存了
    // 因为enableDateFilter、defaultDateRange、timeField使用了computed的setter
    emit('close')
  } catch (error) {
    console.error('保存设置失败:', error)
  }
}

function handleClose() {
  emit('close')
}

function handleBackdropClick(event: MouseEvent) {
  if (event.target === event.currentTarget) {
    handleClose()
  }
}

// 优化语言切换体验
function handleLanguageChange(newLanguage: string) {
  // 验证语言代码有效性
  if (!newLanguage || !availableLocales.some(locale => locale.code === newLanguage)) {
    console.warn(`无效的语言代码: ${newLanguage}`)
    return
  }

  // 检查是否已经是当前语言
  if (currentLanguage.value?.code === newLanguage) {
    return
  }

  // 切换语言 (setLanguage会自动保存到localStorage)
  setLanguage(newLanguage as LocaleCode)

  // 显示成功提示
  console.log(`语言已切换到: ${newLanguage}`)
}

</script>

<template>
  <Transition name="modal">
    <div v-if="show" class="modal-backdrop" @click="handleBackdropClick">
      <div class="modal-content">
        <div class="modal-header">
          <h2>{{ t('settings.title') }}</h2>
          <button @click="handleClose" class="close-btn">✕</button>
        </div>

        <div class="modal-body">
          <!-- Language Settings -->
          <section class="settings-section">
            <h3>{{ t('settings.language') }}</h3>
            <div class="form-group">
              <select
                v-model="selectedLanguage"
                class="form-select"
              >
                <option
                  v-for="locale in availableLocales"
                  :key="locale.code"
                  :value="locale.code"
                >
                  {{ locale.flag }} {{ locale.name }}
                </option>
              </select>
            </div>
          </section>

          <section class="settings-section">
            <h3>{{ t('settings.displaySettings') }}</h3>
            <div class="form-group">
              <label>
                <input
                  v-model="showEntrySummary"
                  type="checkbox"
                  class="form-checkbox"
                />
                {{ t('settings.showEntrySummary') }}
              </label>
              <p class="form-hint">{{ t('settings.showEntrySummaryDescription') }}</p>
            </div>

            <div class="form-group">
              <label>
                <input
                  v-model="enableDateFilter"
                  type="checkbox"
                  class="form-checkbox"
                />
                {{ t('settings.enableTimeFilter') }}
              </label>
              <p class="form-hint">{{ t('settings.timeFilterDescription') }}</p>
            </div>

            <div class="form-group" v-if="enableDateFilter">
              <label>{{ t('settings.defaultTimeRange') }}</label>
              <select v-model="defaultDateRange" class="form-select">
                <option value="1d">{{ t('time.last1Day') }}</option>
                <option value="2d">{{ t('time.last2Days') }}</option>
                <option value="3d">{{ t('time.last3Days') }}</option>
                <option value="7d">{{ t('time.last1Week') }}</option>
                <option value="30d">{{ t('time.last1Month') }}</option>
                <option value="90d">{{ t('time.last3Months') }}</option>
                <option value="180d">{{ t('time.last6Months') }}</option>
                <option value="365d">{{ t('time.last1Year') }}</option>
                <option value="all">{{ t('time.allTime') }}</option>
              </select>
              <p class="form-hint">{{ t('settings.timeRangeDescription') }}</p>
            </div>

            <div class="form-group" v-if="enableDateFilter">
              <label>{{ t('settings.timeBase') }}</label>
              <div class="radio-group">
                <label class="radio-label">
                  <input
                    v-model="timeField"
                    type="radio"
                    value="inserted_at"
                    class="form-radio"
                  />
                  {{ t('settings.entryTime') }}
                </label>
                <label class="radio-label">
                  <input
                    v-model="timeField"
                    type="radio"
                    value="published_at"
                    class="form-radio"
                  />
                  {{ t('settings.publishTime') }}
                </label>
              </div>
              <p class="form-hint">
                {{ t('settings.timeBaseDescription') }}
              </p>
            </div>
          </section>
        </div>

        <div class="modal-footer">
          <button @click="handleClose" class="btn btn-secondary">{{ t('settings.cancel') }}</button>
          <button @click="saveSettings" class="btn btn-primary">{{ t('settings.save') }}</button>
        </div>
      </div>
    </div>
  </Transition>
</template>

<style scoped>
.modal-backdrop {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  backdrop-filter: blur(4px);
}

.modal-content {
  --settings-accent: #4c74ff;
  --settings-accent-strong: #2f54ff;
  --settings-muted: #5a6276;
  background: linear-gradient(180deg, #ffffff 0%, #f5f7fc 100%);
  color: var(--text-primary, #0f1419);
  border-radius: 18px;
  width: 92%;
  max-width: 640px;
  max-height: 82vh;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  border: 1px solid rgba(15, 20, 25, 0.08);
  box-shadow:
    0 20px 60px rgba(15, 20, 25, 0.25),
    0 2px 8px rgba(15, 20, 25, 0.08);
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 24px;
  border-bottom: 1px solid var(--border-color);
}

.modal-header h2 {
  margin: 0;
  font-size: 20px;
  color: var(--text-primary);
}

.close-btn {
  border: none;
  background: transparent;
  font-size: 24px;
  cursor: pointer;
  color: var(--text-secondary);
  padding: 4px;
  border-radius: 4px;
  transition: background 0.2s;
}

.close-btn:hover {
  background: rgba(0, 0, 0, 0.05);
}

.modal-body {
  flex: 1;
  overflow-y: auto;
  padding: 24px;
  background: rgba(255, 255, 255, 0.5);
}

.settings-section {
  margin-bottom: 24px;
  padding: 20px 22px;
  border-radius: 14px;
  background: #f8faff;
  border: 1px solid rgba(76, 116, 255, 0.08);
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.6);
}

.settings-section:last-child {
  margin-bottom: 0;
}

.settings-section h3 {
  margin: 0 0 18px 0;
  font-size: 16.5px;
  color: var(--text-primary);
  font-weight: 600;
  letter-spacing: -0.01em;
}

.form-group {
  margin-bottom: 16px;
}

.form-group label {
  display: block;
  margin-bottom: 8px;
  font-size: 14px;
  color: #1a1f2e;
  font-weight: 600;
}

.form-input,
.form-select {
  width: 100%;
  padding: 11px 14px;
  border: 1px solid rgba(92, 106, 138, 0.22);
  border-radius: 10px;
  font-size: 14px;
  background: #fefefe;
  color: var(--text-primary, #0f1419);
  transition: border-color 0.2s, box-shadow 0.2s;
  box-shadow: inset 0 1px 2px rgba(15, 20, 25, 0.04);
}

.form-input::placeholder {
  color: rgba(90, 98, 118, 0.8);
}

.form-input:focus,
.form-select:focus {
  outline: none;
  border-color: var(--settings-accent, #4c74ff);
  box-shadow: 0 0 0 3px rgba(76, 116, 255, 0.15);
}

.form-checkbox {
  margin-right: 8px;
}

.form-radio {
  margin-right: 8px;
}

.radio-group {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.radio-label {
  display: flex;
  align-items: center;
  font-weight: normal;
  margin-bottom: 0;
}

.form-hint {
  margin-top: 6px;
  font-size: 12px;
  color: #5a6276;
  line-height: 1.5;
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  padding: 16px 24px;
  border-top: 1px solid var(--border-color);
}

.btn {
  padding: 10px 20px;
  border: none;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-secondary {
  background: #f2f4fb;
  color: var(--settings-muted, #5a6276);
  border: 1px solid rgba(92, 106, 138, 0.2);
}

.btn-secondary:hover {
  background: #e4e8f4;
}

.btn-primary {
  background: linear-gradient(130deg, var(--settings-accent, #4c74ff), var(--settings-accent-strong, #2f54ff));
  color: white;
  box-shadow: 0 12px 24px rgba(76, 116, 255, 0.25);
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.btn-primary:hover {
  transform: translateY(-2px);
  box-shadow: 0 18px 30px rgba(76, 116, 255, 0.3);
}

.modal-enter-active,
.modal-leave-active {
  transition: opacity 0.3s ease;
}

.modal-enter-from,
.modal-leave-to {
  opacity: 0;
}

.modal-enter-active .modal-content,
.modal-leave-active .modal-content {
  transition: transform 0.3s cubic-bezier(0.16, 1, 0.3, 1);
}

.modal-enter-from .modal-content,
.modal-leave-to .modal-content {
  transform: scale(0.9);
}

/* Modal body scrollbar styling */
.modal-body::-webkit-scrollbar { width: 8px; height: 8px; }
.modal-body::-webkit-scrollbar-thumb { background: rgba(15, 17, 21, 0.18); border-radius: 8px; }
.modal-body:hover::-webkit-scrollbar-thumb { background: rgba(15, 17, 21, 0.28); }
.modal-body { scrollbar-width: thin; scrollbar-color: rgba(15, 17, 21, 0.28) transparent; }
</style>

<style>
/* =====================
   Dark mode overrides (Global)
   ===================== */
html.dark .modal-backdrop {
  background: rgba(0, 0, 0, 0.6) !important;
}

html.dark .modal-content {
  background: linear-gradient(180deg, #181b22 0%, #0f1115 100%) !important;
  color: #f5f6fa !important;
  border-color: rgba(255, 255, 255, 0.12) !important;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.6), 0 2px 8px rgba(0, 0, 0, 0.4) !important;
}

html.dark .modal-header {
  border-color: rgba(255, 255, 255, 0.15) !important;
}

html.dark .modal-header h2 {
  color: #ffffff !important;
  font-weight: 600;
}

html.dark .close-btn {
  color: #9ba1b3 !important;
}

html.dark .close-btn:hover {
  background: rgba(255, 255, 255, 0.08) !important;
  color: #ffffff !important;
}

html.dark .modal-body {
  background: #0f1115 !important;
  scrollbar-color: rgba(255, 255, 255, 0.36) transparent;
}

html.dark .modal-body::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.22); }
html.dark .modal-body:hover::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.36); }

html.dark .settings-section {
  background: #1a1e26 !important;
  border-color: rgba(255, 255, 255, 0.15) !important;
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.06) !important;
}

html.dark .settings-section h3 {
  color: #ffffff !important;
  font-weight: 600;
}

html.dark .form-input,
html.dark .form-select {
  background: #181b22 !important;
  color: #f5f6fa !important;
  border-color: rgba(255, 255, 255, 0.15) !important;
  box-shadow: none !important;
}

html.dark .form-input::placeholder {
  color: rgba(155, 161, 179, 0.7) !important;
}

html.dark .radio-label,
html.dark .checkbox-label {
  color: #f5f6fa !important;
}

html.dark .form-group label {
  color: #e8eaef !important;
  font-weight: 600;
}

html.dark .form-hint {
  color: #a0a6ba !important;
}
</style>
