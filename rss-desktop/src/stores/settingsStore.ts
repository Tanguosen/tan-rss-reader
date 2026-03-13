import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import api from '../api/client'
import { clampAutoTitleTranslationLimit, getDefaultAutoTitleTranslationLimit } from '../constants/translation'

export interface AppSettings {
  fetch_interval_minutes: number
  items_per_page: number
  // 时间过滤相关设置
  enable_date_filter: boolean
  default_date_range: string
  time_field: string
  show_entry_summary: boolean
  max_auto_title_translations: number
  // 翻译显示模式
  translation_display_mode: string
  // 品牌描述切换
  branding_toggle: boolean
  // 夜间模式
  theme: 'light' | 'dark'
  // RSSHub URL (Admin only)
  rsshub_url?: string
}

export const useSettingsStore = defineStore('settings', () => {
  const settings = ref<AppSettings>({
    fetch_interval_minutes: 15,
    items_per_page: 50,
    enable_date_filter: true,
    default_date_range: '30d',
    time_field: 'inserted_at',
    show_entry_summary: true,
    max_auto_title_translations: getDefaultAutoTitleTranslationLimit(),
    translation_display_mode: localStorage.getItem('translation_display_mode') || 'replace',
    branding_toggle: ((): boolean => {
      const v = localStorage.getItem('branding_toggle')
      if (v === null) return false
      if (v === '1' || v === 'true') return true
      return false
    })(),
    theme: (localStorage.getItem('theme') as 'light' | 'dark') || 'light'
  })

  const loading = ref(false)
  const error = ref<string | null>(null)

  const isDarkMode = computed(() => settings.value.theme === 'dark')

  function toggleTheme() {
    settings.value.theme = settings.value.theme === 'dark' ? 'light' : 'dark'
    localStorage.setItem('theme', settings.value.theme)
    if (settings.value.theme === 'dark') {
      document.documentElement.classList.add('dark')
    } else {
      document.documentElement.classList.remove('dark')
    }
  }

  // 获取应用设置
  async function fetchSettings() {
    loading.value = true
    error.value = null

    try {
      // 优先加载本地存储的设置
      const localMode = localStorage.getItem('translation_display_mode')
      const localBranding = localStorage.getItem('branding_toggle')
      const localShowSummary = localStorage.getItem('show_entry_summary')
      const localEnableDateFilter = localStorage.getItem('enable_date_filter')
      const localDefaultDateRange = localStorage.getItem('default_date_range')
      
      const merged = { ...settings.value }
      
      if (localMode) merged.translation_display_mode = localMode
      if (localBranding) merged.branding_toggle = localBranding === '1' || localBranding === 'true'
      if (localShowSummary) merged.show_entry_summary = localShowSummary === '1' || localShowSummary === 'true'
      if (localEnableDateFilter) merged.enable_date_filter = localEnableDateFilter === '1' || localEnableDateFilter === 'true'
      if (localDefaultDateRange) merged.default_date_range = localDefaultDateRange

      // 尝试获取远程系统设置（不强制依赖，因为非管理员可能无权访问或只需要读取部分）
      // 注意：目前后端 GET /settings 是公开的，所以可以读取。
      // 但为了健壮性，如果失败我们仍然可以使用默认值 + 本地值
      try {
        const { data } = await api.get<Partial<AppSettings>>('/settings')
        // 只合并系统级设置，保留本地偏好
        // 系统设置包括: fetch_interval_minutes, items_per_page, rsshub_url, max_auto_title_translations
        if (data.fetch_interval_minutes !== undefined) merged.fetch_interval_minutes = data.fetch_interval_minutes
        if (data.items_per_page !== undefined) merged.items_per_page = data.items_per_page
        if (data.rsshub_url !== undefined) merged.rsshub_url = data.rsshub_url
        if (data.max_auto_title_translations !== undefined) merged.max_auto_title_translations = data.max_auto_title_translations
      } catch (e) {
        // 忽略获取远程设置失败，继续使用本地/默认
        console.warn('Could not fetch system settings, using defaults/local')
      }

      merged.max_auto_title_translations = clampAutoTitleTranslationLimit(
        merged.max_auto_title_translations
      )
      settings.value = merged
      return settings.value
    } catch (err) {
      console.error('Failed to fetch settings:', err)
      error.value = '获取设置失败'
      throw err
    } finally {
      loading.value = false
    }
  }

  // 更新应用设置
  async function updateSettings(newSettings: Partial<AppSettings>) {
    loading.value = true
    error.value = null

    // 1. 处理本地偏好设置 (User Preferences)
    if (newSettings.translation_display_mode) {
      localStorage.setItem('translation_display_mode', newSettings.translation_display_mode)
    }
    if (typeof newSettings.branding_toggle === 'boolean') {
      localStorage.setItem('branding_toggle', newSettings.branding_toggle ? '1' : '0')
    }
    if (typeof newSettings.show_entry_summary === 'boolean') {
      localStorage.setItem('show_entry_summary', newSettings.show_entry_summary ? '1' : '0')
    }
    if (typeof newSettings.enable_date_filter === 'boolean') {
      localStorage.setItem('enable_date_filter', newSettings.enable_date_filter ? '1' : '0')
    }
    if (newSettings.default_date_range) {
      localStorage.setItem('default_date_range', newSettings.default_date_range)
    }

    // 乐观更新：先更新本地状态
    const previousSettings = { ...settings.value }
    settings.value = {
      ...settings.value,
      ...newSettings
    }
    
    // 2. 只有当包含系统设置时，才调用后端 API
    // 系统设置字段：fetch_interval_minutes, items_per_page, max_auto_title_translations
    const systemFields = ['fetch_interval_minutes', 'items_per_page', 'max_auto_title_translations']
    const hasSystemUpdates = Object.keys(newSettings).some(k => systemFields.includes(k))

    if (!hasSystemUpdates) {
       loading.value = false
       return settings.value
    }

    try {
      const { data } = await api.patch<Partial<AppSettings>>('/settings', newSettings)
      
      // 合并后端返回的系统设置
      const merged = { ...settings.value }
      if (data.fetch_interval_minutes !== undefined) merged.fetch_interval_minutes = data.fetch_interval_minutes
      if (data.items_per_page !== undefined) merged.items_per_page = data.items_per_page
      if (data.max_auto_title_translations !== undefined) merged.max_auto_title_translations = data.max_auto_title_translations
      
      merged.max_auto_title_translations = clampAutoTitleTranslationLimit(
        merged.max_auto_title_translations
      )
      settings.value = merged

      return data
    } catch (err: any) {
      console.error('Failed to update settings:', err)
      // 如果是权限错误 (403)，说明用户试图修改系统设置但不是管理员
      if (err.response && err.response.status === 403) {
         error.value = '无权修改系统设置'
      } else {
         error.value = '更新设置失败'
      }
      // 回滚状态 (只回滚系统设置部分，本地设置保持修改)
      // 简化起见，这里回滚全部，用户体验可能稍差但安全
      settings.value = previousSettings
      throw err
    } finally {
      loading.value = false
    }
  }

  // 清除错误
  function clearError() {
    error.value = null
  }

  return {
    // 状态
    settings,
    loading,
    error,

    // 方法
    fetchSettings,
    updateSettings,
    clearError,
    toggleTheme,

    // 计算属性
    isDarkMode
  }
})
