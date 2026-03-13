<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useUserStore } from '../stores/userStore'
import LoadingSpinner from '../components/LoadingSpinner.vue'

const store = useUserStore()
const currentUser = store.profile

onMounted(() => {
  store.fetchUsers()
})

async function onToggleRole(user: any) {
  const newRole = user.role === 'admin' ? 'user' : 'admin'
  if (user.id === currentUser?.id) {
    if (!confirm('确定要变更自己的权限吗？如果降级为普通用户，您将无法访问管理端。')) return
  }
  await store.updateUser(user.id, { role: newRole })
}

async function onToggleActive(user: any) {
  const newActive = !user.is_active
  if (user.id === currentUser?.id) return // Should be blocked by backend anyway
  await store.updateUser(user.id, { is_active: newActive })
}

async function onDelete(user: any) {
  if (user.id === currentUser?.id) return
  if (confirm(`确定要删除用户 "${user.username}" 吗？此操作不可恢复。`)) {
    await store.deleteUser(user.id)
  }
}
</script>

<template>
  <div class="page-container">
    <header class="page-header">
      <h1 class="page-title">用户管理</h1>
      <button class="refresh-btn" @click="store.fetchUsers()">
        <span class="icon">🔄</span>
        刷新
      </button>
    </header>

    <div v-if="store.loading" class="loading-state">
      <LoadingSpinner />
    </div>

    <div v-else class="table-container">
      <table class="user-table">
        <thead>
          <tr>
            <th>用户</th>
            <th>角色</th>
            <th>状态</th>
            <th>注册时间</th>
            <th class="text-right">操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="user in store.users" :key="user.id">
            <td>
              <div class="user-info">
                <div class="user-avatar">{{ user.username.charAt(0).toUpperCase() }}</div>
                <div class="user-details">
                  <span class="username">{{ user.username }}</span>
                  <span class="email">{{ user.email || '无邮箱' }}</span>
                </div>
              </div>
            </td>
            <td>
              <span class="badge" :class="user.role">
                {{ user.role === 'admin' ? '管理员' : '普通用户' }}
              </span>
            </td>
            <td>
              <span class="status-dot" :class="{ active: user.is_active }"></span>
              {{ user.is_active ? '正常' : '禁用' }}
            </td>
            <td class="text-muted">
              {{ new Date(user.created_at || Date.now()).toLocaleDateString() }}
            </td>
            <td class="text-right actions-cell">
              <button 
                class="action-btn" 
                :class="{ 'btn-promote': user.role !== 'admin', 'btn-demote': user.role === 'admin' }"
                @click="onToggleRole(user)"
                :disabled="user.id === currentUser?.id"
                :title="user.role === 'admin' ? '降级为普通用户' : '提升为管理员'"
              >
                {{ user.role === 'admin' ? '降级' : '提权' }}
              </button>
              
              <button 
                class="action-btn" 
                :class="user.is_active ? 'btn-disable' : 'btn-enable'"
                @click="onToggleActive(user)"
                :disabled="user.id === currentUser?.id"
              >
                {{ user.is_active ? '禁用' : '启用' }}
              </button>
              
              <button 
                class="action-btn btn-delete" 
                @click="onDelete(user)"
                :disabled="user.id === currentUser?.id"
              >
                删除
              </button>
            </td>
          </tr>
        </tbody>
      </table>
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

.refresh-btn {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 16px;
  border: 1px solid var(--border-color);
  background: var(--bg-surface);
  border-radius: 6px;
  cursor: pointer;
  color: var(--text-secondary);
  transition: all 0.2s;
}

.refresh-btn:hover {
  background: var(--bg-hover);
  color: var(--text-primary);
}

.table-container {
  background: var(--bg-surface);
  border: 1px solid var(--border-color);
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 1px 3px rgba(0,0,0,0.05);
}

.user-table {
  width: 100%;
  border-collapse: collapse;
  text-align: left;
}

.user-table th {
  padding: 16px;
  font-weight: 600;
  color: var(--text-secondary);
  border-bottom: 1px solid var(--border-color);
  background: var(--bg-tertiary);
  font-size: 13px;
}

.user-table td {
  padding: 16px;
  border-bottom: 1px solid var(--border-color);
  color: var(--text-primary);
  font-size: 14px;
}

.user-table tr:last-child td {
  border-bottom: none;
}

.user-table tr:hover {
  background: var(--bg-hover);
}

.user-info {
  display: flex;
  align-items: center;
  gap: 12px;
}

.user-avatar {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  background: linear-gradient(135deg, var(--accent), #ff4d4d);
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 16px;
}

.user-details {
  display: flex;
  flex-direction: column;
}

.username {
  font-weight: 600;
}

.email {
  font-size: 12px;
  color: var(--text-tertiary);
}

.badge {
  display: inline-block;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
  font-weight: 500;
}

.badge.admin {
  background: rgba(255, 122, 24, 0.1);
  color: var(--accent);
  border: 1px solid rgba(255, 122, 24, 0.2);
}

.badge.user {
  background: var(--bg-tertiary);
  color: var(--text-secondary);
  border: 1px solid var(--border-color);
}

.status-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #ccc;
  margin-right: 6px;
}

.status-dot.active {
  background: #10b981;
}

.text-right {
  text-align: right;
}

.text-muted {
  color: var(--text-tertiary);
  font-size: 13px;
}

.actions-cell {
  white-space: nowrap;
}

.action-btn {
  padding: 6px 12px;
  border: none;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 500;
  cursor: pointer;
  margin-left: 8px;
  transition: all 0.2s;
  opacity: 0.8;
}

.action-btn:hover {
  opacity: 1;
  transform: translateY(-1px);
}

.action-btn:disabled {
  opacity: 0.3;
  cursor: not-allowed;
  transform: none;
}

.btn-promote {
  background: rgba(255, 122, 24, 0.1);
  color: var(--accent);
}

.btn-demote {
  background: var(--bg-tertiary);
  color: var(--text-secondary);
}

.btn-disable {
  background: rgba(255, 200, 0, 0.1);
  color: #d97706;
}

.btn-enable {
  background: rgba(16, 185, 129, 0.1);
  color: #059669;
}

.btn-delete {
  background: rgba(239, 68, 68, 0.1);
  color: #ef4444;
}

.loading-state {
  display: flex;
  justify-content: center;
  padding: 40px;
}
</style>
