<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { useUserStore } from '../stores/userStore'
import RegistrationForm from './RegistrationForm.vue'

defineProps<{
  show: boolean
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'success'): void
}>()

const userStore = useUserStore()
const username = ref('')
const password = ref('')
const error = ref<string | null>(null)
const loading = ref(false)

const isRegister = computed(() => userStore.authMode === 'register')
const title = computed(() => isRegister.value ? '注册' : '登录')

// Clear form when mode changes or modal opens
watch(() => userStore.authMode, () => {
  error.value = null
})

watch(() => userStore.authModalVisible, (visible) => {
  if (visible) {
    username.value = ''
    password.value = ''
    error.value = null
  }
})

function toggleMode() {
  userStore.openAuthModal(isRegister.value ? 'login' : 'register')
}

async function onLoginSubmit() {
  if (!username.value || !password.value) {
    error.value = '请输入用户名和密码'
    return
  }

  loading.value = true
  error.value = null
  
  const ok = await userStore.login(username.value.trim(), password.value)
  
  loading.value = false

  if (ok) {
    emit('success')
    emit('close')
  } else {
    error.value = userStore.error || '登录失败'
  }
}

function onRegisterSuccess() {
  // Registration successful, maybe switch to login or close
  // For now, let's switch to login mode and show a message
  userStore.openAuthModal('login')
  error.value = '注册成功，请登录'
}
</script>

<template>
  <div v-if="show" class="modal-overlay" @click.self="emit('close')">
    <div class="modal-content" :class="{ 'wide-modal': isRegister }">
      <button class="close-btn" @click="emit('close')">&times;</button>
      
      <h2 class="modal-title">{{ title }}</h2>
      
      <!-- Registration Form Component -->
      <RegistrationForm 
        v-if="isRegister" 
        @success="onRegisterSuccess"
        @login="toggleMode"
      />

      <!-- Login Form (Legacy/Simple) -->
      <form v-else @submit.prevent="onLoginSubmit" class="auth-form">
        <div class="form-group">
          <label>用户名</label>
          <input v-model="username" type="text" class="form-input" placeholder="请输入用户名" />
        </div>
        
        <div class="form-group">
          <label>密码</label>
          <input v-model="password" type="password" class="form-input" placeholder="请输入密码" />
        </div>

        <div v-if="error" class="error-text">{{ error }}</div>
        
        <button type="submit" class="primary-btn" :disabled="loading">
          {{ loading ? '处理中...' : '登录' }}
        </button>

        <div class="toggle-mode">
          没有账号？
          <a href="#" @click.prevent="toggleMode">去注册</a>
        </div>
      </form>
    </div>
  </div>
</template>

<style scoped>
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-content {
  background: #fff;
  padding: 24px;
  border-radius: 12px;
  width: 90%;
  max-width: 400px;
  position: relative;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
  transition: max-width 0.3s ease;
}

.modal-content.wide-modal {
  max-width: 480px;
}

.close-btn {
  position: absolute;
  top: 12px;
  right: 12px;
  background: none;
  border: none;
  font-size: 24px;
  color: #9ca3af;
  cursor: pointer;
  z-index: 10;
}

.modal-title {
  margin: 0 0 24px;
  font-size: 24px;
  font-weight: 600;
  text-align: center;
  color: #111827;
}

.auth-form {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.form-group label {
  font-size: 14px;
  color: #374151;
  font-weight: 500;
}

.form-input {
  padding: 10px;
  border: 1px solid #d1d5db;
  border-radius: 6px;
  font-size: 14px;
  outline: none;
  transition: border-color 0.2s;
}

.form-input:focus {
  border-color: #3b82f6;
  box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.1);
}

.error-text {
  color: #ef4444;
  font-size: 14px;
  text-align: center;
}

.primary-btn {
  padding: 12px;
  border: none;
  border-radius: 6px;
  background: #3b82f6;
  color: #fff;
  font-size: 16px;
  font-weight: 500;
  cursor: pointer;
  transition: background 0.2s;
}

.primary-btn:hover {
  background: #2563eb;
}

.primary-btn:disabled {
  background: #93c5fd;
  cursor: not-allowed;
}

.toggle-mode {
  margin-top: 16px;
  text-align: center;
  font-size: 14px;
  color: #6b7280;
}

.toggle-mode a {
  color: #3b82f6;
  text-decoration: none;
  font-weight: 500;
}

.toggle-mode a:hover {
  text-decoration: underline;
}
</style>
