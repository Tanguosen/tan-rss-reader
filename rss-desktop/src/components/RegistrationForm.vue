<script setup lang="ts">
import { ref, computed, reactive, watch, nextTick } from 'vue'
import { useUserStore } from '../stores/userStore'
import LoadingSpinner from './LoadingSpinner.vue'

const emit = defineEmits<{
  (e: 'success'): void
  (e: 'login'): void
}>()

const userStore = useUserStore()

// --- State ---
const currentStep = ref(1)
const loading = ref(false)
const generalError = ref<string | null>(null)
const showPassword = ref(false)

const form = reactive({
  username: '',
  password: '',
  email: '',
  phone: ''
})

const errors = reactive({
  username: '',
  password: '',
  email: '',
  phone: ''
})

const touched = reactive({
  username: false,
  password: false,
  email: false,
  phone: false
})

// --- Validation Logic ---
const passwordStrength = computed(() => {
  const pwd = form.password
  if (!pwd) return { score: 0, label: '', color: 'bg-gray-200' }
  
  let score = 0
  if (pwd.length >= 8) score++
  if (/[A-Z]/.test(pwd)) score++
  if (/[a-z]/.test(pwd)) score++
  if (/[0-9]/.test(pwd)) score++
  if (/[^A-Za-z0-9]/.test(pwd)) score++

  if (score <= 2) return { score, label: '弱', color: 'bg-red-500' }
  if (score <= 4) return { score, label: '中', color: 'bg-yellow-500' }
  return { score, label: '强', color: 'bg-green-500' }
})

const isPasswordValid = computed(() => form.password && form.password.length >= 6)

function validateField(field: keyof typeof form) {
  touched[field] = true
  errors[field] = ''

  switch (field) {
    case 'username':
      if (!form.username.trim()) errors.username = '请输入用户名'
      else if (form.username.length < 3) errors.username = '用户名至少3个字符'
      break
    case 'password':
      if (!form.password) errors.password = '请输入密码'
      else if (!isPasswordValid.value) errors.password = '密码至少6位'
      break
    case 'email':
      if (!form.email) errors.email = '请输入邮箱地址'
      else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email)) errors.email = '请输入有效的邮箱地址'
      break
    case 'phone':
      if (form.phone && !/^1[3-9]\d{9}$/.test(form.phone)) errors.phone = '请输入有效的手机号'
      break
  }
}

// Watchers for real-time validation after touch
watch(() => form.username, () => { if (touched.username) validateField('username') })
watch(() => form.password, () => { if (touched.password) validateField('password') })
watch(() => form.email, () => { if (touched.email) validateField('email') })
watch(() => form.phone, () => { if (touched.phone) validateField('phone') })

// --- Navigation ---
function scrollToError() {
  nextTick(() => {
    const errorEl = document.querySelector('.form-group.error')
    if (errorEl) {
      errorEl.scrollIntoView({ behavior: 'smooth', block: 'center' })
    }
  })
}

function nextStep() {
  if (currentStep.value === 1) {
    validateField('username')
    validateField('password')
    if (!errors.username && !errors.password) {
      currentStep.value = 2
    } else {
      scrollToError()
    }
  } else if (currentStep.value === 2) {
    validateField('email')
    validateField('phone')
    if (!errors.email && !errors.phone) {
      currentStep.value = 3
    } else {
      scrollToError()
    }
  }
}

function prevStep() {
  if (currentStep.value > 1) currentStep.value--
}

// --- Submit ---
async function onSubmit() {
  loading.value = true
  generalError.value = null

  // Simulate verification delay
  await new Promise(resolve => setTimeout(resolve, 800))

  const ok = await userStore.register(form.username, form.password, form.email, form.phone)
  
  loading.value = false
  if (ok) {
    emit('success')
  } else {
    generalError.value = userStore.error || '注册失败，请重试'
  }
}

// --- Helpers ---
function fillExampleData() {
  form.username = `User${Math.floor(Math.random() * 1000)}`
  form.password = 'Test@1234'
  form.email = `test${Math.floor(Math.random() * 1000)}@example.com`
  form.phone = '13800138000'
  
  // Reset errors
  Object.keys(errors).forEach(k => errors[k as keyof typeof errors] = '')
}

function togglePasswordVisibility() {
  showPassword.value = !showPassword.value
}
</script>

<template>
  <div class="registration-form">
    <!-- Progress Bar -->
    <div class="progress-container">
      <div class="progress-track">
        <div class="progress-fill" :style="{ width: `${(currentStep / 3) * 100}%` }"></div>
      </div>
      <div class="steps-label">
        <span :class="{ active: currentStep >= 1 }">账户信息</span>
        <span :class="{ active: currentStep >= 2 }">个人信息</span>
        <span :class="{ active: currentStep >= 3 }">验证完成</span>
      </div>
    </div>

    <form @submit.prevent="onSubmit" class="form-content">
      
      <!-- Step 1: Account Info -->
      <div v-show="currentStep === 1" class="step-panel">
        <div class="form-group" :class="{ error: errors.username }">
          <label>用户名</label>
          <input 
            v-model="form.username" 
            type="text" 
            placeholder="请输入用户名（3-20字符）"
            @blur="validateField('username')"
            class="form-input"
          />
          <div class="tooltip" v-if="!errors.username">用于登录和显示的唯一标识</div>
          <span v-if="errors.username" class="error-msg">{{ errors.username }}</span>
        </div>

        <div class="form-group" :class="{ error: errors.password }">
          <label>密码</label>
          <div class="input-wrapper">
            <input 
              v-model="form.password" 
              :type="showPassword ? 'text' : 'password'" 
              placeholder="请输入密码（至少6位）"
              @blur="validateField('password')"
              class="form-input"
            />
            <button type="button" class="eye-btn" @click="togglePasswordVisibility">
              {{ showPassword ? '🙈' : '👁️' }}
            </button>
          </div>
          
          <!-- Password Strength Meter -->
          <div class="strength-meter" v-if="form.password" role="status" aria-live="polite">
            <div class="strength-bars">
              <div 
                class="block" 
                :class="passwordStrength.score >= 1 ? passwordStrength.color : 'bg-empty'"
                aria-hidden="true"
              ></div>
              <div 
                class="block" 
                :class="passwordStrength.score >= 3 ? passwordStrength.color : 'bg-empty'"
                aria-hidden="true"
              ></div>
              <div 
                class="block" 
                :class="passwordStrength.score >= 5 ? passwordStrength.color : 'bg-empty'"
                aria-hidden="true"
              ></div>
            </div>
            <span class="strength-label" :class="passwordStrength.color.replace('bg-', 'text-')">
              强度: {{ passwordStrength.label }}
            </span>
          </div>

          <span v-if="errors.password" class="error-msg" role="alert">{{ errors.password }}</span>
        </div>
        
        <div class="step-actions">
           <button type="button" class="link-btn" @click="fillExampleData">一键填充示例</button>
           <button type="button" class="primary-btn brand-btn" @click="nextStep">下一步</button>
        </div>
      </div>

      <!-- Step 2: Personal Info -->
      <div v-show="currentStep === 2" class="step-panel">
        <div class="form-group" :class="{ error: errors.email }">
          <label>电子邮箱</label>
          <input 
            v-model="form.email" 
            type="email" 
            placeholder="example@domain.com"
            @blur="validateField('email')"
            class="form-input"
            aria-required="true"
          />
          <span v-if="errors.email" class="error-msg" role="alert">{{ errors.email }}</span>
        </div>

        <div class="form-group" :class="{ error: errors.phone }">
          <label>手机号码 (可选)</label>
          <input 
            v-model="form.phone" 
            type="tel" 
            placeholder="11位手机号码"
            @blur="validateField('phone')"
            class="form-input"
          />
          <span v-if="errors.phone" class="error-msg" role="alert">{{ errors.phone }}</span>
        </div>

        <div class="step-actions">
          <button type="button" class="secondary-btn" @click="prevStep">上一步</button>
          <button type="button" class="primary-btn brand-btn" @click="nextStep">下一步</button>
        </div>
      </div>

      <!-- Step 3: Verification & Submit -->
      <div v-show="currentStep === 3" class="step-panel">
        <div class="summary-box">
          <h3>请确认您的信息</h3>
          <div class="summary-item">
            <span class="label">用户名:</span>
            <span class="value">{{ form.username }}</span>
          </div>
          <div class="summary-item">
            <span class="label">邮箱:</span>
            <span class="value">{{ form.email }}</span>
          </div>
          <div class="summary-item" v-if="form.phone">
            <span class="label">手机:</span>
            <span class="value">{{ form.phone }}</span>
          </div>
        </div>

        <div class="verification-box">
          <label class="checkbox-label">
            <input type="checkbox" required aria-required="true" />
            我已阅读并同意 <a href="#">服务条款</a> 和 <a href="#">隐私政策</a>
          </label>
        </div>

        <div v-if="generalError" class="global-error" role="alert">
          {{ generalError }}
        </div>

        <div class="step-actions">
          <button type="button" class="secondary-btn" @click="prevStep" :disabled="loading">上一步</button>
          <button type="submit" class="primary-btn submit-btn brand-btn" :disabled="loading" :aria-busy="loading">
            <LoadingSpinner v-if="loading" size="small" />
            <span v-else>提交注册</span>
          </button>
        </div>
      </div>

      <div class="form-footer">
        已有账号？<a href="#" @click.prevent="emit('login')">去登录</a>
      </div>
    </form>
  </div>
</template>

<style scoped>
.registration-form {
  width: 100%;
  max-width: 400px;
  margin: 0 auto;
}

/* Progress Bar */
.progress-container {
  margin-bottom: 24px;
}

.progress-track {
  height: 4px;
  background: #eee;
  border-radius: 2px;
  overflow: hidden;
  margin-bottom: 8px;
}

.progress-fill {
  height: 100%;
  background: var(--accent, #ff7a18);
  transition: width 0.3s ease;
}

.steps-label {
  display: flex;
  justify-content: space-between;
  font-size: 12px;
  color: #999;
}

.steps-label span.active {
  color: var(--accent, #ff7a18);
  font-weight: 500;
}

/* Form Groups */
.form-group {
  margin-bottom: 16px;
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.form-group label {
  font-size: 14px;
  font-weight: 500;
  color: #333;
}

.form-input {
  padding: 10px 12px;
  border: 1px solid #ddd;
  border-radius: 6px;
  font-size: 14px;
  transition: all 0.2s;
}

.form-input:focus {
  border-color: var(--accent, #ff7a18);
  outline: none;
  box-shadow: 0 0 0 3px rgba(255, 122, 24, 0.1);
}

.form-group.error .form-input {
  border-color: #ef4444;
  background-color: #fff5f5;
}

.error-msg {
  color: #ef4444;
  font-size: 12px;
  margin-top: 2px;
  animation: slideDown 0.2s ease-out;
}

@keyframes slideDown {
  from { opacity: 0; transform: translateY(-5px); }
  to { opacity: 1; transform: translateY(0); }
}

.tooltip {
  font-size: 12px;
  color: #888;
}

/* Password Field */
.input-wrapper {
  position: relative;
  display: flex;
  align-items: center;
}

.input-wrapper .form-input {
  width: 100%;
}

.eye-btn {
  position: absolute;
  right: 10px;
  background: none;
  border: none;
  cursor: pointer;
  font-size: 14px;
  opacity: 0.6;
}

.eye-btn:hover {
  opacity: 1;
}

/* Strength Meter */
.strength-meter {
  margin-top: 6px;
  display: flex;
  align-items: center;
  gap: 10px;
}

.strength-bars {
  flex: 1;
  display: flex;
  gap: 4px;
  height: 4px;
}

.strength-bars .bar {
  flex: 1;
  background: #eee;
  border-radius: 2px;
  transition: background-color 0.3s;
}

.strength-bars .block {
  width: 20px;
  height: 8px;
  border-radius: 2px;
  transition: all 0.3s;
}

.bg-empty { background-color: #e5e7eb; opacity: 0.5; }
.bg-red-500 { background-color: #ef4444; }
.bg-yellow-500 { background-color: #eab308; }
.bg-green-500 { background-color: #22c55e; }

.text-red-500 { color: #ef4444; }
.text-yellow-500 { color: #eab308; }
.text-green-500 { color: #22c55e; }

.strength-label {
  font-size: 12px;
  font-weight: 500;
  width: 40px;
  text-align: right;
}

/* Buttons */
.step-actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-top: 24px;
}

.primary-btn {
  background: var(--accent, #ff7a18);
  color: white;
  border: none;
  padding: 10px 24px;
  border-radius: 6px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: background 0.2s, transform 0.1s;
}

.primary-btn:active {
  transform: scale(0.98);
}

.primary-btn.brand-btn {
  background-color: var(--accent, #ff7a18) !important;
  color: #fff !important;
  font-weight: 600;
}

.primary-btn:hover {
  filter: brightness(1.1);
}

.primary-btn:disabled {
  opacity: 0.7;
  cursor: not-allowed;
  filter: none;
}

.secondary-btn {
  background: #f3f4f6;
  color: #4b5563;
  border: 1px solid #d1d5db;
  padding: 10px 24px;
  border-radius: 6px;
  font-size: 14px;
  cursor: pointer;
}

.secondary-btn:hover {
  background: #e5e7eb;
}

.link-btn {
  background: none;
  border: none;
  color: var(--accent, #ff7a18);
  font-size: 12px;
  cursor: pointer;
  padding: 0;
  text-decoration: underline;
}

/* Summary & Verification */
.summary-box {
  background: #f9fafb;
  padding: 16px;
  border-radius: 8px;
  margin-bottom: 20px;
}

.summary-box h3 {
  margin: 0 0 12px;
  font-size: 15px;
  color: #333;
}

.summary-item {
  display: flex;
  justify-content: space-between;
  margin-bottom: 8px;
  font-size: 14px;
}

.summary-item .label {
  color: #666;
}

.summary-item .value {
  font-weight: 500;
  color: #111;
}

.verification-box {
  margin-bottom: 20px;
}

.checkbox-label {
  font-size: 13px;
  color: #666;
  display: flex;
  align-items: center;
  gap: 8px;
}

.checkbox-label a {
  color: var(--accent, #ff7a18);
}

.global-error {
  background: #fef2f2;
  color: #ef4444;
  padding: 10px;
  border-radius: 6px;
  font-size: 13px;
  text-align: center;
  margin-bottom: 16px;
}

.form-footer {
  text-align: center;
  margin-top: 24px;
  font-size: 13px;
  color: #666;
}

.form-footer a {
  color: var(--accent, #ff7a18);
  text-decoration: none;
  font-weight: 500;
}
</style>
