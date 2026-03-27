import { computed, ref } from 'vue'
import { i18n, persistLocale, type LocaleCode } from '../i18n'

export type LocaleInfo = {
  code: LocaleCode
  name: string
  flag: string
}

const LOCALES: LocaleInfo[] = [
  { code: 'zh-CN', name: '简体中文', flag: 'CN' },
  { code: 'en-US', name: 'English', flag: 'EN' },
  { code: 'ja-JP', name: '日本語', flag: 'JA' },
  { code: 'ko-KR', name: '한국어', flag: 'KO' }
]

const current = ref<LocaleInfo | null>(null)

function syncCurrentFromGlobal() {
  const code = i18n.global.locale.value as LocaleCode
  current.value = LOCALES.find((l) => l.code === code) ?? LOCALES[0]
}

export function useLanguage() {
  const availableLocales = LOCALES
  const currentLanguage = computed(() => current.value)

  function setLanguage(locale: LocaleCode) {
    i18n.global.locale.value = locale
    persistLocale(locale)
    syncCurrentFromGlobal()
  }

  function loadLanguage() {
    syncCurrentFromGlobal()
  }

  if (!current.value) {
    syncCurrentFromGlobal()
  }

  return {
    availableLocales,
    currentLanguage,
    setLanguage,
    loadLanguage
  }
}
