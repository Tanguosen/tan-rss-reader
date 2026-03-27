import { createI18n } from 'vue-i18n'
import enUS from './locales/en-US.json'
import jaJP from './locales/ja-JP.json'
import koKR from './locales/ko-KR.json'
import zhCN from './locales/zh-CN.json'

export const messages = {
  'en-US': enUS,
  'ja-JP': jaJP,
  'ko-KR': koKR,
  'zh-CN': zhCN
} as const

export type LocaleCode = keyof typeof messages

const STORAGE_KEY = 'tan-locale'

function resolveInitialLocale(): LocaleCode {
  const saved = localStorage.getItem(STORAGE_KEY) as LocaleCode | null
  if (saved && saved in messages) return saved
  return 'zh-CN'
}

export const i18n = createI18n({
  legacy: false,
  globalInjection: true,
  locale: resolveInitialLocale(),
  fallbackLocale: 'en-US',
  messages
})

export function persistLocale(locale: LocaleCode) {
  localStorage.setItem(STORAGE_KEY, locale)
}
