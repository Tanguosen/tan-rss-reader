<script setup lang="ts">
import { onMounted, ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { useChannelsStore } from '../stores/channelsStore'
import type { Channel, Category, Tag } from '../stores/channelsStore'
import LoadingSpinner from '../components/LoadingSpinner.vue'

const router = useRouter()
const store = useChannelsStore()
const filterPublic = ref<'all' | 'public' | 'private'>('all')
const activeTab = ref<'channels' | 'categories' | 'tags'>('channels')

// Modal State
const showModal = ref(false)
const isEditing = ref(false)
const editingId = ref<string | null>(null)

// Category Modal
const showCategoryModal = ref(false)
const isEditingCategory = ref(false)
const editingCategoryId = ref<string | null>(null)
const categoryForm = reactive({
  name: '',
  sort_order: 0
})

// Tag Modal
const showTagModal = ref(false)
const tagForm = reactive({
  name: ''
})

const form = reactive({
  name: '',
  description: '',
  is_public: true,
  cover_url: '',
  category_id: '',
  tags: [] as string[]
})

async function init() {
  await Promise.all([
    store.fetchAdminChannels(),
    store.fetchCategories(),
    store.fetchTags()
  ])
}

async function onFilterChange() {
  if (filterPublic.value === 'all') {
    await store.fetchAdminChannels()
  } else if (filterPublic.value === 'public') {
    await store.fetchAdminChannels(true)
  } else {
    await store.fetchAdminChannels(false)
  }
}

function openSources(id: string) {
  router.push(`/admin/channels/${id}/sources`)
}

function openCreateModal() {
  isEditing.value = false
  editingId.value = null
  form.name = ''
  form.description = ''
  form.is_public = true
  form.cover_url = ''
  form.category_id = ''
  form.tags = []
  showModal.value = true
}

function openEditModal(channel: Channel) {
  isEditing.value = true
  editingId.value = channel.id
  form.name = channel.name
  form.description = channel.description || ''
  form.is_public = channel.is_public
  form.cover_url = channel.cover_url || ''
  form.category_id = channel.category_id || ''
  form.tags = channel.tags ? channel.tags.map(t => t.id) : []
  showModal.value = true
}

function closeModal() {
  showModal.value = false
}

async function submitForm() {
  if (!form.name) return
  
  const payload = {
    name: form.name,
    description: form.description,
    is_public: form.is_public,
    cover_url: form.cover_url,
    category_id: form.category_id || undefined,
    tags: form.tags
  }

  let success = false
  if (isEditing.value && editingId.value) {
    success = await store.updateChannel(editingId.value, payload)
  } else {
    success = await store.createChannel(payload)
  }

  if (success) {
    closeModal()
  }
}

async function onDelete(id: string) {
  if (confirm('确定要删除这个频道吗？所有关联将被移除。')) {
    await store.deleteChannel(id)
  }
}

// Category Management
function openCreateCategoryModal() {
  isEditingCategory.value = false
  editingCategoryId.value = null
  categoryForm.name = ''
  categoryForm.sort_order = 0
  showCategoryModal.value = true
}

function openEditCategoryModal(category: Category) {
  isEditingCategory.value = true
  editingCategoryId.value = category.id
  categoryForm.name = category.name
  categoryForm.sort_order = category.sort_order
  showCategoryModal.value = true
}

function closeCategoryModal() {
  showCategoryModal.value = false
}

async function submitCategoryForm() {
  if (!categoryForm.name) return
  
  let success = false
  if (isEditingCategory.value && editingCategoryId.value) {
    success = await store.updateCategory(editingCategoryId.value, {
      name: categoryForm.name,
      sort_order: categoryForm.sort_order
    })
  } else {
    success = await store.createCategory({
      name: categoryForm.name,
      sort_order: categoryForm.sort_order
    })
  }

  if (success) {
    closeCategoryModal()
  }
}

async function onDeleteCategory(id: string) {
  if (confirm('确定要删除这个分类吗？')) {
    await store.deleteCategory(id)
  }
}

// Tag Management
function openCreateTagModal() {
  tagForm.name = ''
  showTagModal.value = true
}

function closeTagModal() {
  showTagModal.value = false
}

async function submitTagForm() {
  if (!tagForm.name) return
  
  const success = await store.createTag({ name: tagForm.name })
  if (success) {
    closeTagModal()
  }
}

async function onDeleteTag(id: string) {
  if (confirm('确定要删除这个标签吗？')) {
    await store.deleteTag(id)
  }
}

onMounted(() => {
  init()
})
</script>

<template>
  <div class="page-container">
    <header class="page-header">
      <h1 class="page-title">频道管理</h1>
      <div class="header-actions">
        <div class="tabs">
          <button 
            class="tab-btn" 
            :class="{ active: activeTab === 'channels' }"
            @click="activeTab = 'channels'"
          >频道</button>
          <button 
            class="tab-btn" 
            :class="{ active: activeTab === 'categories' }"
            @click="activeTab = 'categories'"
          >分类</button>
          <button 
            class="tab-btn" 
            :class="{ active: activeTab === 'tags' }"
            @click="activeTab = 'tags'"
          >标签</button>
        </div>

        <div v-if="activeTab === 'channels'" class="filter-group">
          <select v-model="filterPublic" class="select" @change="onFilterChange">
            <option value="all">全部类型</option>
            <option value="public">公开频道</option>
            <option value="private">私有频道</option>
          </select>
        </div>
        
        <button v-if="activeTab === 'channels'" class="action-btn primary" @click="openCreateModal">
          <span class="icon">+</span>
          创建频道
        </button>
        <button v-else-if="activeTab === 'categories'" class="action-btn primary" @click="openCreateCategoryModal">
          <span class="icon">+</span>
          创建分类
        </button>
        <button v-else-if="activeTab === 'tags'" class="action-btn primary" @click="openCreateTagModal">
          <span class="icon">+</span>
          创建标签
        </button>

        <button class="action-btn secondary" @click="router.push('/admin/feeds')">
          <span class="icon">📡</span>
          管理所有订阅源
        </button>

        <button class="action-btn secondary" @click="init">
          <span class="icon">🔄</span>
          刷新
        </button>
      </div>
    </header>
    
    <div v-if="store.loading" class="loading-state">
      <LoadingSpinner />
    </div>

    <!-- Channels View -->
    <template v-else-if="activeTab === 'channels'">
      <div v-if="store.adminChannels.length === 0" class="empty-state">
        <p>暂无频道数据</p>
        <button class="action-btn primary" @click="openCreateModal">创建第一个频道</button>
      </div>

      <div v-else class="grid">
        <div v-for="c in store.adminChannels" :key="c.id" class="channel-card">
          <div class="card-header">
            <h3 class="card-title">{{ c.name }}</h3>
            <span class="badge" :class="c.is_public ? 'public' : 'private'">
              {{ c.is_public ? '公开' : '私有' }}
            </span>
          </div>
          
          <p class="card-desc">{{ c.description || '暂无描述' }}</p>
          
          <div class="card-meta" v-if="c.category_id || (c.tags && c.tags.length)">
             <span v-if="c.category_id" class="meta-tag category">
               📁 {{ store.categories.find(cat => cat.id === c.category_id)?.name || '未知分类' }}
             </span>
             <span v-for="tag in c.tags" :key="tag.id" class="meta-tag tag">
               #{{ tag.name }}
             </span>
          </div>

          <div class="card-footer">
            <button class="card-btn" @click="openSources(c.id)">
              <span class="icon">📡</span>
              管理源
            </button>
            <div class="card-actions-right">
              <button class="icon-btn edit" @click="openEditModal(c)" title="编辑">
                ✎
              </button>
              <button class="icon-btn delete" @click="onDelete(c.id)" title="删除">
                🗑
              </button>
            </div>
          </div>
        </div>
      </div>
    </template>

    <!-- Categories View -->
    <template v-else-if="activeTab === 'categories'">
      <div v-if="store.categories.length === 0" class="empty-state">
        <p>暂无分类数据</p>
        <button class="action-btn primary" @click="openCreateCategoryModal">创建第一个分类</button>
      </div>
      <div v-else class="list-container">
        <div v-for="cat in store.categories" :key="cat.id" class="list-item">
          <div class="list-info">
            <span class="list-name">{{ cat.name }}</span>
            <span class="list-meta">排序: {{ cat.sort_order }}</span>
          </div>
          <div class="list-actions">
            <button class="icon-btn edit" @click="openEditCategoryModal(cat)" title="编辑">✎</button>
            <button class="icon-btn delete" @click="onDeleteCategory(cat.id)" title="删除">🗑</button>
          </div>
        </div>
      </div>
    </template>

    <!-- Tags View -->
    <template v-else-if="activeTab === 'tags'">
      <div v-if="store.tags.length === 0" class="empty-state">
        <p>暂无标签数据</p>
        <button class="action-btn primary" @click="openCreateTagModal">创建第一个标签</button>
      </div>
      <div v-else class="tags-grid">
        <div v-for="tag in store.tags" :key="tag.id" class="tag-card">
          <span class="tag-name"># {{ tag.name }}</span>
          <button class="icon-btn delete small" @click="onDeleteTag(tag.id)" title="删除">×</button>
        </div>
      </div>
    </template>

    <!-- Channel Modal -->
    <div v-if="showModal" class="modal-overlay" @click.self="closeModal">
      <div class="modal">
        <header class="modal-header">
          <h2 class="modal-title">{{ isEditing ? '编辑频道' : '创建频道' }}</h2>
          <button class="close-btn" @click="closeModal">×</button>
        </header>
        
        <div class="modal-body">
          <div class="form-group">
            <label>频道名称</label>
            <input v-model="form.name" type="text" placeholder="输入频道名称" class="input" autofocus />
          </div>
          
          <div class="form-group">
            <label>分类</label>
            <select v-model="form.category_id" class="input select-input">
              <option value="">无分类</option>
              <option v-for="cat in store.categories" :key="cat.id" :value="cat.id">{{ cat.name }}</option>
            </select>
          </div>

          <div class="form-group">
            <label>标签 (按住 Ctrl/Cmd 多选)</label>
            <select v-model="form.tags" multiple class="input select-input multi">
              <option v-for="tag in store.tags" :key="tag.id" :value="tag.id">{{ tag.name }}</option>
            </select>
          </div>

          <div class="form-group">
            <label>描述</label>
            <textarea v-model="form.description" rows="3" placeholder="频道描述..." class="input textarea"></textarea>
          </div>
          
          <div class="form-group checkbox-group">
            <label class="checkbox-label">
              <input v-model="form.is_public" type="checkbox" />
              <span class="checkbox-text">设为公开频道</span>
              <span class="checkbox-hint">（公开频道可以被所有用户发现和订阅）</span>
            </label>
          </div>
        </div>
        
        <footer class="modal-footer">
          <button class="modal-btn secondary" @click="closeModal">取消</button>
          <button class="modal-btn primary" @click="submitForm" :disabled="!form.name">保存</button>
        </footer>
      </div>
    </div>

    <!-- Category Modal -->
    <div v-if="showCategoryModal" class="modal-overlay" @click.self="closeCategoryModal">
      <div class="modal small-modal">
        <header class="modal-header">
          <h2 class="modal-title">{{ isEditingCategory ? '编辑分类' : '创建分类' }}</h2>
          <button class="close-btn" @click="closeCategoryModal">×</button>
        </header>
        <div class="modal-body">
          <div class="form-group">
            <label>分类名称</label>
            <input v-model="categoryForm.name" type="text" placeholder="输入分类名称" class="input" autofocus />
          </div>
          <div class="form-group">
            <label>排序权重 (越小越靠前)</label>
            <input v-model.number="categoryForm.sort_order" type="number" class="input" />
          </div>
        </div>
        <footer class="modal-footer">
          <button class="modal-btn secondary" @click="closeCategoryModal">取消</button>
          <button class="modal-btn primary" @click="submitCategoryForm" :disabled="!categoryForm.name">保存</button>
        </footer>
      </div>
    </div>

    <!-- Tag Modal -->
    <div v-if="showTagModal" class="modal-overlay" @click.self="closeTagModal">
      <div class="modal small-modal">
        <header class="modal-header">
          <h2 class="modal-title">创建标签</h2>
          <button class="close-btn" @click="closeTagModal">×</button>
        </header>
        <div class="modal-body">
          <div class="form-group">
            <label>标签名称</label>
            <input v-model="tagForm.name" type="text" placeholder="输入标签名称" class="input" autofocus />
          </div>
        </div>
        <footer class="modal-footer">
          <button class="modal-btn secondary" @click="closeTagModal">取消</button>
          <button class="modal-btn primary" @click="submitTagForm" :disabled="!tagForm.name">保存</button>
        </footer>
      </div>
    </div>
  </div>
</template>

<style scoped>
.page-container {
  padding: 24px;
  max-width: 1200px;
  margin: 0 auto;
  height: 100%;
  overflow-y: auto;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
}

.page-title {
  font-size: 24px;
  font-weight: 700;
  color: var(--text-primary);
  margin: 0;
}

.header-actions {
  display: flex;
  gap: 12px;
}

.select {
  padding: 8px 12px;
  border: 1px solid var(--border-color);
  border-radius: 6px;
  background: var(--bg-surface);
  color: var(--text-primary);
  font-size: 14px;
  outline: none;
}

.action-btn {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 16px;
  border-radius: 6px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  border: none;
}

.action-btn.primary {
  background: var(--accent);
  color: white;
}

.action-btn.primary:hover {
  filter: brightness(1.1);
}

.action-btn.secondary {
  background: var(--bg-surface);
  border: 1px solid var(--border-color);
  color: var(--text-secondary);
}

.action-btn.secondary:hover {
  background: var(--bg-hover);
  color: var(--text-primary);
}

.grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 20px;
}

.channel-card {
  background: var(--bg-surface);
  border: 1px solid var(--border-color);
  border-radius: 12px;
  padding: 20px;
  display: flex;
  flex-direction: column;
  transition: transform 0.2s, box-shadow 0.2s;
}

.channel-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.05);
  border-color: var(--accent);
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 12px;
}

.card-title {
  font-size: 18px;
  font-weight: 600;
  color: var(--text-primary);
  margin: 0;
  line-height: 1.4;
}

.badge {
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
  font-weight: 500;
  white-space: nowrap;
}

.badge.public {
  background: rgba(16, 185, 129, 0.1);
  color: #059669;
}

.badge.private {
  background: var(--bg-tertiary);
  color: var(--text-secondary);
}

.card-desc {
  font-size: 14px;
  color: var(--text-secondary);
  margin: 0 0 20px 0;
  flex-grow: 1;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.5;
}

.card-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-top: 16px;
  border-top: 1px solid var(--border-color);
}

.card-btn {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 6px 12px;
  border-radius: 6px;
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  background: var(--bg-tertiary);
  color: var(--text-secondary);
  border: none;
  transition: all 0.2s;
}

.card-btn:hover {
  background: var(--bg-hover);
  color: var(--text-primary);
}

.card-actions-right {
  display: flex;
  gap: 8px;
}

.icon-btn {
  width: 32px;
  height: 32px;
  border-radius: 6px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: none;
  background: transparent;
  cursor: pointer;
  transition: all 0.2s;
  color: var(--text-secondary);
}

.icon-btn:hover {
  background: var(--bg-hover);
  color: var(--text-primary);
}

.icon-btn.delete:hover {
  background: rgba(239, 68, 68, 0.1);
  color: #ef4444;
}

.loading-state, .empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 60px;
  color: var(--text-secondary);
  gap: 16px;
}

/* Modal Styles */
.modal-overlay {
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

.modal {
  background: var(--bg-surface);
  border-radius: 12px;
  width: 100%;
  max-width: 500px;
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
  overflow: hidden;
  animation: modal-slide-in 0.3s ease-out;
}

@keyframes modal-slide-in {
  from { opacity: 0; transform: translateY(20px); }
  to { opacity: 1; transform: translateY(0); }
}

.modal-header {
  padding: 20px 24px;
  border-bottom: 1px solid var(--border-color);
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.modal-title {
  font-size: 18px;
  font-weight: 600;
  color: var(--text-primary);
  margin: 0;
}

.close-btn {
  background: transparent;
  border: none;
  font-size: 24px;
  color: var(--text-tertiary);
  cursor: pointer;
  padding: 0;
  line-height: 1;
}

.close-btn:hover {
  color: var(--text-primary);
}

.modal-body {
  padding: 24px;
}

.form-group {
  margin-bottom: 20px;
}

.form-group label {
  display: block;
  font-size: 14px;
  font-weight: 500;
  color: var(--text-secondary);
  margin-bottom: 8px;
}

.input {
  width: 100%;
  padding: 10px 12px;
  border: 1px solid var(--border-color);
  border-radius: 6px;
  background: var(--bg-surface);
  color: var(--text-primary);
  font-size: 14px;
  transition: border-color 0.2s;
}

.input:focus {
  outline: none;
  border-color: var(--accent);
  box-shadow: 0 0 0 3px rgba(var(--accent-rgb), 0.1);
}

.input.textarea {
  resize: vertical;
  min-height: 80px;
}

.checkbox-group {
  margin-bottom: 0;
}

.checkbox-label {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
}

.checkbox-text {
  font-size: 14px;
  color: var(--text-primary);
  font-weight: 500;
}

.checkbox-hint {
  font-size: 12px;
  color: var(--text-tertiary);
}

.modal-footer {
  padding: 20px 24px;
  background: var(--bg-tertiary);
  border-top: 1px solid var(--border-color);
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}

.modal-btn {
  padding: 8px 16px;
  border-radius: 6px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  border: none;
  transition: all 0.2s;
}

.modal-btn.secondary {
  background: white;
  border: 1px solid var(--border-color);
  color: var(--text-secondary);
}

.modal-btn.secondary:hover {
  background: var(--bg-hover);
  color: var(--text-primary);
}

.modal-btn.primary {
  background: var(--accent);
  color: white;
}

.modal-btn.primary:hover {
  filter: brightness(1.1);
}

.modal-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* Tabs */
.tabs {
  display: flex;
  gap: 4px;
  background: var(--bg-surface);
  padding: 4px;
  border-radius: 8px;
  border: 1px solid var(--border-color);
}

.tab-btn {
  padding: 6px 16px;
  border-radius: 6px;
  border: none;
  background: transparent;
  color: var(--text-secondary);
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.tab-btn.active {
  background: var(--bg-tertiary);
  color: var(--text-primary);
  font-weight: 600;
}

.tab-btn:hover:not(.active) {
  background: var(--bg-hover);
  color: var(--text-primary);
}

/* List View (Categories) */
.list-container {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.list-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: var(--bg-surface);
  border: 1px solid var(--border-color);
  padding: 16px 20px;
  border-radius: 12px;
}

.list-info {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.list-name {
  font-size: 16px;
  font-weight: 600;
  color: var(--text-primary);
}

.list-meta {
  font-size: 12px;
  color: var(--text-tertiary);
}

.list-actions {
  display: flex;
  gap: 8px;
}

/* Tags View */
.tags-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
}

.tag-card {
  display: flex;
  align-items: center;
  gap: 8px;
  background: var(--bg-surface);
  border: 1px solid var(--border-color);
  padding: 8px 12px;
  border-radius: 20px;
  transition: all 0.2s;
}

.tag-card:hover {
  border-color: var(--accent);
}

.tag-name {
  font-size: 14px;
  font-weight: 500;
  color: var(--text-primary);
}

.icon-btn.small {
  width: 20px;
  height: 20px;
  font-size: 16px;
}

/* Card Meta (in Channel Card) */
.card-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-bottom: 12px;
}

.meta-tag {
  font-size: 12px;
  padding: 2px 8px;
  border-radius: 4px;
  background: var(--bg-tertiary);
  color: var(--text-secondary);
}

.meta-tag.category {
  color: var(--accent);
  background: rgba(var(--accent-rgb), 0.1);
}

/* Form Elements */
.select-input {
  appearance: none;
  background-image: url("data:image/svg+xml;charset=UTF-8,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3e%3cpolyline points='6 9 12 15 18 9'%3e%3c/polyline%3e%3c/svg%3e");
  background-repeat: no-repeat;
  background-position: right 12px center;
  background-size: 16px;
  padding-right: 40px;
}

.select-input.multi {
  background-image: none;
  padding-right: 12px;
  min-height: 100px;
}

.small-modal {
  max-width: 400px;
}
</style>
