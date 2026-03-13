/**
 * 智能阅读模式处理器 - 浏览器优化版本
 * 利用浏览器原生能力，无需复杂的代理设置
 */

import { Readability } from '@mozilla/readability'
import DOMPurify from 'dompurify'
import api from '../api/client'

export interface ReadableArticle {
  title?: string
  content: string
  textContent?: string
  length?: number
  excerpt?: string
  byline?: string
  siteName?: string
  publishedTime?: string
}

export interface ReadingModeOptions {
  timeout?: number
  maxLength?: number
  enableImages?: boolean
  enableStyles?: boolean
}

export class ReadingModeHandler {
  private cache = new Map<string, ReadableArticle>()
  private readonly defaultOptions: Required<ReadingModeOptions> = {
    timeout: 30000,
    maxLength: 0,
    enableImages: true,
    enableStyles: true
  }

  constructor(private options: ReadingModeOptions = {}) {
    this.options = { ...this.defaultOptions, ...options }
  }

  /**
   * 提取文章可读内容
   */
  async extractArticle(url: string, options?: { force?: boolean }): Promise<ReadableArticle | null> {
    try {
      // 检查缓存
      if (!options?.force && this.cache.has(url)) {
        return this.cache.get(url)!
      }
      if (options?.force) {
        this.cache.delete(url)
      }

      // 获取原始HTML
      const { html, finalUrl } = await this.fetchHTML(url, options?.force)

      // 解析并提取内容
      const article = this.parseArticle(html, finalUrl)

      if (!article || !article.content) {
        throw new Error('无法提取文章内容')
      }

      // 缓存结果
      this.cache.set(url, article)

      return article
    } catch (error) {
      console.error('阅读模式提取失败:', error)
      throw error
    }
  }

  /**
   * 获取原始HTML内容 - 浏览器优化版本
   */
  private async fetchHTML(url: string, force?: boolean): Promise<{ html: string; finalUrl: string }> {
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), this.options.timeout)

    try {
      const { data } = await api.get('/proxy/fetch', {
        params: { url, force: !!force },
        timeout: this.options.timeout,
        signal: controller.signal
      })

      const html: string = data?.content || ''
      const finalUrl: string = data?.final_url || url

      if (!html) {
        throw new Error('内容为空')
      }

      if (this.options.maxLength && html.length > this.options.maxLength) {
        throw new Error(`页面内容过大 (${Math.round(html.length / 1024 / 1024)}MB)，无法处理`)
      }

      return { html, finalUrl }
    } finally {
      clearTimeout(timeoutId)
    }
  }

  /**
   * 解析文章内容
   */
  private parseArticle(html: string, baseUrl: string): ReadableArticle | null {
    try {
      // 创建DOM文档
      const parser = new DOMParser()
      const doc = parser.parseFromString(html, 'text/html')
      const base = doc.createElement('base')
      base.href = baseUrl
      doc.head?.prepend(base)

      // 使用Readability提取内容
      const reader = new Readability(doc, {
        debug: false,
        maxElemsToParse: 0, // 0 = 不限制
        nbTopCandidates: 5,
        charThreshold: 500, // 最小字符数阈值
        classesToPreserve: ['caption', 'license', 'byline', 'author', 'published'],
        keepClasses: false
      })

      const article = reader.parse()

      if (!article) {
        return null
      }

      // 使用DOMPurify清洗HTML内容，确保安全性
      const cleanContent = this.sanitizeHTML(article.content || '', baseUrl)

      return {
        title: article.title || undefined,
        content: cleanContent,
        textContent: article.textContent || undefined,
        length: article.length || 0,
        excerpt: article.excerpt || undefined,
        byline: article.byline || undefined,
        siteName: article.siteName || undefined,
        publishedTime: article.publishedTime || undefined
      }
    } catch (error) {
      console.error('文章解析失败:', error)
      return null
    }
  }

  /**
   * 清洗HTML内容，移除不安全元素
   */
  private sanitizeHTML(html: string, baseUrl: string): string {
    const config = {
      ALLOWED_TAGS: [
        // 文本结构
        'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
        'p', 'br', 'span', 'div', 'section', 'article', 'header', 'footer',

        // 文本格式
        'strong', 'em', 'u', 'i', 'b', 'mark', 'small', 'sub', 'sup', 'del', 'ins',

        // 列表
        'ul', 'ol', 'li', 'dl', 'dt', 'dd',

        // 代码和引用
        'blockquote', 'pre', 'code', 'kbd', 'samp',

        // 媒体（如果启用图片）
        ... (this.options.enableImages ? ['img', 'picture', 'figure', 'figcaption', 'source'] : []),

        // 链接和表格
        'a', 'table', 'thead', 'tbody', 'tr', 'th', 'td', 'tfoot', 'caption', 'colgroup', 'col',

        // 分隔符和其他
        'hr', 'wbr', 'abbr', 'time', 'address', 'cite', 'q', 'ruby', 'rt', 'rp'
      ].filter(Boolean),

      ALLOWED_ATTR: [
        // 通用属性
        'class', 'id', 'title', 'lang', 'dir', 'data-*',

        // 链接属性
        'href', 'target', 'rel', 'download',

        // 图片属性（如果启用图片）
        ... (this.options.enableImages ? [
          'src', 'alt', 'width', 'height', 'srcset', 'sizes', 'loading', 'decoding'
        ] : []),

        // 表格属性
        'colspan', 'rowspan', 'scope',

        // 引用属性
        'cite',

        // 时间属性
        'datetime',

        // 样式属性（如果启用样式）
        ... (this.options.enableStyles ? ['style'] : [])
      ].filter(Boolean),

      // 允许的URI协议
      ALLOWED_URI_REGEXP: /^(?:(?:(?:f|ht)tps?|mailto|tel|callto|cid|xmpp|data):|[^a-z]|[a-z+.\-]+(?:[^a-z+.\-:]|$))/i,

      // 添加target="_blank"到外部链接
      ADD_ATTR: ['target'],

      // 禁止的标签
      FORBID_TAGS: [
        'script', 'noscript', 'style', 'iframe', 'object', 'embed', 'form',
        'input', 'button', 'select', 'textarea', 'option', 'label', 'fieldset',
        'legend', 'canvas', 'svg', 'math', 'video', 'audio', 'source', 'track',
        'map', 'area', 'progress', 'meter', 'details', 'summary', 'dialog',
        'template', 'slot', 'canvas', 'svg'
      ],

      // 禁止的属性
      FORBID_ATTR: [
        'onclick', 'onload', 'onerror', 'onmouseover', 'onfocus', 'onblur',
        'onchange', 'onsubmit', 'onreset', 'onselect', 'onunload', 'onabort',
        'oncanplay', 'oncanplaythrough', 'oncuechange', 'ondurationchange',
        'onemptied', 'onended', 'onloadeddata', 'onloadedmetadata',
        'onloadstart', 'onpause', 'onplay', 'onplaying', 'onprogress',
        'onratechange', 'onseeked', 'onseeking', 'onstalled', 'onsuspend',
        'ontimeupdate', 'onvolumechange', 'onwaiting', 'onwheel',
        'oncopy', 'oncut', 'onpaste', 'ondrag', 'ondrop', 'onfocusin',
        'onfocusout', 'onhashchange', 'oninput', 'oninvalid', 'onkeydown',
        'onkeypress', 'onkeyup', 'onload', 'onloadeddata', 'onloadedmetadata',
        'onloadstart', 'onmousedown', 'onmouseenter', 'onmouseleave',
        'onmousemove', 'onmouseout', 'onmouseover', 'onmouseup', 'onmousewheel',
        'onoffline', 'ononline', 'onpagehide', 'onpageshow', 'onpopstate',
        'onresize', 'onscroll', 'onstorage', 'onsubmit', 'onunload'
      ]
    }

    // 处理HTML内容
    const cleanHTML = DOMPurify.sanitize(html, config)

    // 后处理：确保外部链接在新窗口打开并添加安全属性
    return this.processContentLinks(cleanHTML, baseUrl)
  }

  /**
   * 处理外部链接，添加安全属性
   */
  private processContentLinks(html: string, baseUrl: string): string {
    const parser = new DOMParser()
    const doc = parser.parseFromString(html, 'text/html')

    const resolveUrl = (raw: string): string | null => {
      const v = (raw || '').trim()
      if (!v) return null
      try {
        const u = new URL(v, baseUrl)
        if (u.protocol === 'http:' || u.protocol === 'https:' || u.protocol === 'mailto:' || u.protocol === 'tel:' || u.protocol === 'data:') {
          return u.toString()
        }
      } catch {
        return null
      }
      return null
    }

    const links = doc.querySelectorAll('a[href]')
    links.forEach(link => {
      const href = link.getAttribute('href')
      const resolved = href ? resolveUrl(href) : null
      if (resolved) {
        link.setAttribute('href', resolved)
        if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
          link.setAttribute('target', '_blank')
          link.setAttribute('rel', 'noopener noreferrer')
        }
      }
    })

    const images = doc.querySelectorAll('img')
    images.forEach(img => {
      const src = img.getAttribute('src')
      const resolvedSrc = src ? resolveUrl(src) : null
      if (resolvedSrc) {
        img.setAttribute('src', resolvedSrc)
      }
      img.setAttribute('loading', 'lazy')
      img.setAttribute('decoding', 'async')
      img.setAttribute('referrerpolicy', 'no-referrer')
    })

    const sources = doc.querySelectorAll('source[srcset]')
    sources.forEach(source => {
      const srcset = source.getAttribute('srcset')
      if (!srcset) return
      const next = srcset
        .split(',')
        .map(part => part.trim())
        .filter(Boolean)
        .map(token => {
          const segs = token.split(/\s+/).filter(Boolean)
          const urlPart = segs[0]
          const rest = segs.slice(1)
          const resolved = resolveUrl(urlPart) || urlPart
          return [resolved, ...rest].join(' ')
        })
        .join(', ')
      source.setAttribute('srcset', next)
    })

    return doc.body.innerHTML
  }

  /**
   * 清理缓存
   */
  clearCache(): void {
    this.cache.clear()
  }

  /**
   * 获取缓存大小
   */
  getCacheSize(): number {
    return this.cache.size
  }

  /**
   * 生成文章摘要
   */
  generateExcerpt(article: ReadableArticle, maxLength: number = 200): string {
    if (article.excerpt) {
      return article.excerpt.length > maxLength
        ? article.excerpt.substring(0, maxLength) + '...'
        : article.excerpt
    }

    if (article.textContent) {
      const text = article.textContent.replace(/\s+/g, ' ').trim()
      return text.length > maxLength
        ? text.substring(0, maxLength) + '...'
        : text
    }

    return ''
  }

  /**
   * 预加载文章（可选功能）
   */
  async preloadArticle(url: string): Promise<void> {
    try {
      await this.extractArticle(url)
    } catch (error) {
      // 静默失败，预加载不应该阻塞主要流程
      console.warn('预加载文章失败:', url, error)
    }
  }
}

// 创建全局实例
export const readingModeHandler = new ReadingModeHandler()
