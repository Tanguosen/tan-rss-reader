<script setup lang="ts">
import { onMounted, ref, reactive } from 'vue'
import { useFeedStore } from '../stores/feedStore'
import LoadingSpinner from '../components/LoadingSpinner.vue'
import type { Feed } from '../types'

const store = useFeedStore()
const showModal = ref(false)
const isEditing = ref(false)
const editingId = ref<string | null>(null)
const searchQuery = ref('')
let searchTimeout: any = null

const form = reactive({
  url: '',
  title: '',
  group_name: '',
  update_interval: 60
})

async function init() {
  await store.fetchAdminFeeds()
}

function onSearch() {
  if (searchTimeout) clearTimeout(searchTimeout)
  searchTimeout = setTimeout(() => {
    store.fetchAdminFeeds(searchQuery.value)
  }, 300)
}

function openCreateModal() {
  isEditing.value = false
  editingId.value = null
  form.url = ''
  form.title = ''
  form.group_name = ''
  form.update_interval = 60
  showModal.value = true
}

function openEditModal(feed: Feed) {
  isEditing.value = true
  editingId.value = feed.id
  form.url = feed.url
  form.title = feed.title || ''
  form.group_name = feed.group_name || ''
  form.update_interval = feed.update_interval || 60
  showModal.value = true
}

function closeModal() {
  showModal.value = false
}

async function submitForm() {
  if (!form.url && !isEditing.value) return
  
  const payload = {
    url: form.url,
    title: form.title,
    group_name: form.group_name,
    update_interval: form.update_interval
  }

  let success = false
  if (isEditing.value && editingId.value) {
    success = await store.updateAdminFeed(editingId.value, payload)
  } else {
    success = await store.createAdminFeed(payload)
  }

  if (success) {
    closeModal()
  }
}

async function onDelete(id: string) {
  if (confirm('确定要删除这个订阅源吗？这将影响所有使用此源的频道。')) {
    await store.deleteAdminFeed(id)
  }
}

onMounted(() => {
  init()
})
</script>

<template>
  <div class="admin-feeds p-6 h-full overflow-y-auto">
    <div class="header flex justify-between items-center mb-6 sticky top-0 bg-base-100 z-10 py-2">
      <h1 class="text-2xl font-bold">信息源管理</h1>
      <button class="primary-btn" @click="openCreateModal">添加订阅源</button>
    </div>

    <div v-if="store.loadingFeeds" class="flex justify-center py-12">
      <LoadingSpinner />
    </div>

    <div v-else class="feeds-list grid gap-4 pb-20">
      <div v-for="feed in store.adminFeeds" :key="feed.id" class="feed-card bg-base-200 p-4 rounded-lg flex justify-between items-center hover:bg-base-300 transition-colors">
        <div class="info flex-1 min-w-0 mr-4">
          <div class="flex items-center gap-2 mb-1">
            <img v-if="feed.favicon_url" :src="feed.favicon_url" class="w-4 h-4 object-contain" />
            <h3 class="font-bold truncate">{{ feed.title || feed.url }}</h3>
            <span v-if="feed.group_name" class="badge badge-sm badge-outline">{{ feed.group_name }}</span>
          </div>
          <div class="text-sm opacity-70 truncate" :title="feed.url">{{ feed.url }}</div>
          <div class="text-xs opacity-50 mt-1 flex flex-wrap gap-x-4 gap-y-1">
             <span class="flex items-center gap-1">
               <div class="w-2 h-2 rounded-full" :class="feed.last_error ? 'bg-error' : 'bg-success'"></div>
               {{ feed.last_error ? '错误' : '正常' }}
             </span>
             <span>更新: {{ feed.update_interval || 60 }}分钟</span>
             <span>上次检查: {{ feed.last_checked_at ? new Date(feed.last_checked_at).toLocaleString() : '从未' }}</span>
          </div>
          <div v-if="feed.last_error" class="text-xs text-error mt-1 truncate" :title="feed.last_error">
            {{ feed.last_error }}
          </div>
        </div>
        <div class="actions flex gap-2 shrink-0">
          <button class="btn btn-sm btn-ghost" @click="openEditModal(feed)">编辑</button>
          <button class="btn btn-sm btn-ghost text-error" @click="onDelete(feed.id)">删除</button>
        </div>
      </div>
      
      <div v-if="store.adminFeeds.length === 0" class="text-center opacity-50 py-12">
        暂无订阅源，请点击右上角添加
      </div>
    </div>

    <!-- Modal -->
    <div v-if="showModal" class="modal modal-open">
      <div class="modal-box">
        <h3 class="font-bold text-lg mb-4">{{ isEditing ? '编辑订阅源' : '添加订阅源' }}</h3>
        
        <div class="form-control w-full mb-4">
          <label class="label"><span class="label-text">RSS 链接</span></label>
          <input v-model="form.url" type="url" placeholder="https://example.com/rss.xml" class="input input-bordered w-full" :disabled="isEditing" />
          <label v-if="isEditing" class="label"><span class="label-text-alt text-warning">链接不可修改</span></label>
        </div>

        <div class="form-control w-full mb-4">
          <label class="label"><span class="label-text">标题 (可选)</span></label>
          <input v-model="form.title" type="text" placeholder="自定义标题" class="input input-bordered w-full" />
        </div>

        <div class="form-control w-full mb-4">
          <label class="label"><span class="label-text">分组 (可选)</span></label>
          <input v-model="form.group_name" type="text" placeholder="例如: 科技, 新闻" class="input input-bordered w-full" />
        </div>

        <div class="form-control w-full mb-6">
          <label class="label"><span class="label-text">更新间隔 (分钟)</span></label>
          <input v-model="form.update_interval" type="number" min="15" class="input input-bordered w-full" />
        </div>

        <div class="modal-action">
          <button class="btn" @click="closeModal">取消</button>
          <button class="btn btn-primary" @click="submitForm" :disabled="!form.url && !isEditing">
            {{ isEditing ? '保存' : '添加' }}
          </button>
        </div>
      </div>
      <div class="modal-backdrop" @click="closeModal"></div>
    </div>
  </div>
</template>

<style scoped>
.admin-feeds {
  padding: 24px;
  max-width: 1200px;
  margin: 0 auto;
  height: 100%;
  overflow-y: auto;
}

.header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 24px;
  position: sticky;
  top: 0;
  background-color: #f9fafb; /* Match page background */
  z-index: 10;
  padding: 12px 0;
}

.header h1 {
  font-size: 24px;
  font-weight: 600;
  color: #111827;
  margin: 0;
}

.primary-btn {
  padding: 8px 16px;
  border: none;
  border-radius: 6px;
  background: #3b82f6;
  color: white;
  font-weight: 500;
  cursor: pointer;
  transition: background 0.2s;
}

.primary-btn:hover {
  background: #2563eb;
}

.feeds-list {
  display: grid;
  gap: 16px;
  padding-bottom: 80px;
}

.feed-card {
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 12px;
  padding: 16px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  transition: all 0.2s;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
}

.feed-card:hover {
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
  border-color: #d1d5db;
}

.info {
  flex: 1;
  min-width: 0;
  margin-right: 16px;
}

.feed-header {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 4px;
}

.favicon {
  width: 16px;
  height: 16px;
  object-fit: contain;
}

.feed-title {
  font-weight: 600;
  color: #111827;
  font-size: 16px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.badge {
  display: inline-flex;
  align-items: center;
  padding: 2px 8px;
  border-radius: 9999px;
  font-size: 12px;
  font-weight: 500;
  background-color: #f3f4f6;
  color: #4b5563;
  border: 1px solid #e5e7eb;
}

.feed-url {
  font-size: 14px;
  color: #6b7280;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  margin-bottom: 8px;
}

.meta-info {
  display: flex;
  flex-wrap: wrap;
  gap: 16px;
  font-size: 12px;
  color: #6b7280;
}

.status-badge {
  display: flex;
  align-items: center;
  gap: 6px;
}

.status-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
}

.bg-success { background-color: #10b981; }
.bg-error { background-color: #ef4444; }

.error-msg {
  color: #ef4444;
  font-size: 12px;
  margin-top: 4px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.actions {
  display: flex;
  gap: 8px;
  flex-shrink: 0;
}

.action-btn {
  padding: 6px 12px;
  border-radius: 6px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  background: transparent;
  border: 1px solid transparent;
}

.action-btn.edit {
  color: #4b5563;
}

.action-btn.edit:hover {
  background: #f3f4f6;
  color: #111827;
}

.action-btn.delete {
  color: #ef4444;
}

.action-btn.delete:hover {
  background: #fee2e2;
  border-color: #fca5a5;
}

/* Modal Styles */
.modal {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 50;
  opacity: 0;
  pointer-events: none;
  transition: opacity 0.2s;
}

.modal.modal-open {
  opacity: 1;
  pointer-events: auto;
}

.modal-box {
  background: white;
  border-radius: 12px;
  padding: 24px;
  width: 100%;
  max-width: 500px;
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
  position: relative;
  z-index: 51;
}

.modal-title {
  font-size: 18px;
  font-weight: 600;
  color: #111827;
  margin-bottom: 20px;
}

.form-group {
  margin-bottom: 16px;
}

.form-label {
  display: block;
  font-size: 14px;
  font-weight: 500;
  color: #374151;
  margin-bottom: 6px;
}

.form-input {
  width: 100%;
  padding: 8px 12px;
  border: 1px solid #d1d5db;
  border-radius: 6px;
  font-size: 14px;
  transition: border-color 0.2s;
}

.form-input:focus {
  outline: none;
  border-color: #3b82f6;
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
}

.form-input:disabled {
  background-color: #f3f4f6;
  cursor: not-allowed;
}

.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  margin-top: 24px;
}

.btn {
  padding: 8px 16px;
  border-radius: 6px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  border: 1px solid transparent;
}

.btn-secondary {
  background: white;
  border-color: #d1d5db;
  color: #374151;
}

.btn-secondary:hover {
  background: #f9fafb;
  border-color: #9ca3af;
}

.btn-primary {
  background: #3b82f6;
  color: white;
  border: none;
}

.btn-primary:hover {
  background: #2563eb;
}

.btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.modal-backdrop {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 49;
}
</style>
