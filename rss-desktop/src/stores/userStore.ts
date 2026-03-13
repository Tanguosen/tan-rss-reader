import { defineStore } from 'pinia'
import { ref } from 'vue'
import api from '../api/client'

interface UserProfile {
  id: string
  username: string
  email?: string | null
  role: string
  is_active: boolean
  created_at?: string
}

export const useUserStore = defineStore('user', () => {
  const token = ref<string | null>(localStorage.getItem('rss-auth-token'))
  const profile = ref<UserProfile | null>(null)
  const users = ref<UserProfile[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  const authModalVisible = ref(false)
  const authMode = ref<'login' | 'register'>('login')

  function openAuthModal(mode: 'login' | 'register' = 'login') {
    authMode.value = mode
    authModalVisible.value = true
  }

  function closeAuthModal() {
    authModalVisible.value = false
  }

  async function login(username: string, password: string) {
    loading.value = true
    error.value = null
    try {
      const { data } = await api.post<{ access_token: string }>('/auth/login', { username, password })
      token.value = data.access_token
      localStorage.setItem('rss-auth-token', data.access_token)
      await fetchMe()
      closeAuthModal()
      return true
    } catch (err) {
      error.value = '登录失败'
      return false
    } finally {
      loading.value = false
    }
  }

  async function register(username: string, password: string, email?: string, phone?: string) {
    loading.value = true
    error.value = null
    try {
      await api.post('/auth/register', { username, password, email, phone })
      // Auto login after register? Or just switch to login mode?
      // Let's switch to login mode for now or just notify success
      authMode.value = 'login'
      return true
    } catch (err) {
      error.value = '注册失败'
      return false
    } finally {
      loading.value = false
    }
  }

  async function fetchMe() {
    loading.value = true
    error.value = null
    try {
      const { data } = await api.get<UserProfile>('/me')
      profile.value = data
    } catch (err) {
      error.value = '获取用户信息失败'
      // If fetchMe fails (e.g. 401), we might want to logout locally
      // But let the caller handle it or use interceptors
    } finally {
      loading.value = false
    }
  }

  function logout() {
    token.value = null
    profile.value = null
    localStorage.removeItem('rss-auth-token')
  }

  // Admin Actions
  async function fetchUsers() {
    loading.value = true
    try {
      const { data } = await api.get<UserProfile[]>('/admin/users')
      users.value = data
    } catch (err) {
      error.value = '加载用户列表失败'
    } finally {
      loading.value = false
    }
  }

  async function updateUser(id: string, payload: { role?: string; is_active?: boolean }) {
    try {
      await api.patch(`/admin/users/${id}`, payload)
      await fetchUsers()
      return true
    } catch (err) {
      error.value = '更新用户失败'
      return false
    }
  }

  async function deleteUser(id: string) {
    try {
      await api.delete(`/admin/users/${id}`)
      await fetchUsers()
      return true
    } catch (err) {
      error.value = '删除用户失败'
      return false
    }
  }

  return {
    token,
    profile,
    users,
    loading,
    error,
    authModalVisible,
    authMode,
    openAuthModal,
    closeAuthModal,
    login,
    register,
    fetchMe,
    logout,
    fetchUsers,
    updateUser,
    deleteUser,
  }
})
