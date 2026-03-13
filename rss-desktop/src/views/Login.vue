<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useUserStore } from '../stores/userStore'
import RegistrationForm from '../components/RegistrationForm.vue'

const router = useRouter()
const userStore = useUserStore()
const username = ref('')
const password = ref('')
const error = ref<string | null>(null)
const loading = ref(false)
const isRegister = ref(false)

const title = computed(() => isRegister.value ? '注册' : '登录')

function toggleMode() {
  isRegister.value = !isRegister.value
  error.value = null
}

function switchToLogin() {
  isRegister.value = false
  error.value = null
}

async function onLoginSubmit() {
  loading.value = true
  error.value = null
  
  const ok = await userStore.login(username.value.trim(), password.value)
  
  loading.value = false
  
  if (ok) {
    const redirect = router.currentRoute.value.query.redirect as string
    router.push(redirect || '/')
  } else {
    error.value = userStore.error || '登录失败'
  }
}

function onRegisterSuccess() {
  isRegister.value = false
  error.value = '注册成功，请登录'
  password.value = ''
}
</script>

<template>
  <div class="auth-container">
    <h1>{{ title }}</h1>
    
    <RegistrationForm 
      v-if="isRegister"
      @success="onRegisterSuccess"
      @login="switchToLogin"
    />

    <form v-else @submit.prevent="onLoginSubmit" class="auth-form">
      <label>用户名</label>
      <input v-model="username" type="text" class="form-input" placeholder="请输入用户名" />
      
      <label>密码</label>
      <input v-model="password" type="password" class="form-input" placeholder="请输入密码" />
      
      <button class="primary-btn" :disabled="loading">
        {{ loading ? '处理中…' : '登录' }}
      </button>
      
      <div class="toggle-mode">
        <a href="#" @click.prevent="toggleMode">没有账号？去注册</a>
      </div>

      <p v-if="error" class="error-text">{{ error }}</p>
    </form>
  </div>
</template>

<style scoped>
.auth-container { max-width: 400px; margin: 40px auto; padding: 16px; }
.auth-form { display: grid; gap: 10px; }
.form-input { padding: 8px; border: 1px solid #ddd; border-radius: 6px; }
.primary-btn { padding: 10px; border: none; border-radius: 6px; background: #3b82f6; color: #fff; cursor: pointer; }
.primary-btn:disabled { background: #93c5fd; cursor: not-allowed; }
.error-text { color: #b91c1c; }
.toggle-mode { text-align: center; font-size: 14px; margin-top: 10px; }
.toggle-mode a { color: #3b82f6; text-decoration: none; }
.toggle-mode a:hover { text-decoration: underline; }
</style>
