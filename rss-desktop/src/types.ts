export interface Feed {
  id: string
  url: string
  title: string | null
  group_name: string
  favicon_url: string | null
  unread_count: number
  last_checked_at: string | null
  last_error: string | null
  channel_id?: string
  update_interval?: number
}

export interface Entry {
  id: string
  feed_id: string
  feed_title: string | null
  title: string | null
  url: string | null
  author: string | null
  summary: string | null
  content: string | null
  published_at: string | null
  inserted_at: string | null
  read: boolean
  starred: boolean
}

export interface SummaryResult {
  entry_id: string
  language: string
  summary: string
  key_points?: string[]
}

export interface TranslationResult {
  entry_id: string
  language: string
  title: string | null
  summary: string | null
  content: string | null
}

export interface ChannelSourceItem {
  feed_id: string
  url: string
  title: string | null
  group_name: string
  favicon_url: string | null
  order_index?: number | null
  weight?: number | null
  created_at: string | null
}
