<script setup lang="ts">
import { ref, onErrorCaptured } from 'vue'

const error = ref<Error | null>(null)

onErrorCaptured((err) => {
  error.value = err instanceof Error ? err : new Error(String(err))
  console.error('ErrorBoundary captured error:', err)
  return false // Stop propagation
})

function retry() {
  error.value = null
}
</script>

<template>
  <div v-if="error" class="error-boundary">
    <div class="error-content">
      <span class="error-icon">⚠️</span>
      <h3>Something went wrong</h3>
      <p class="error-message">{{ error.message }}</p>
      <button @click="retry" class="retry-btn">Try Again</button>
    </div>
  </div>
  <slot v-else></slot>
</template>

<style scoped>
.error-boundary {
  padding: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
  background: var(--bg-surface, #fff);
  color: var(--text-primary, #333);
  border-radius: 8px;
}

.error-content {
  text-align: center;
  max-width: 400px;
}

.error-icon {
  font-size: 48px;
  margin-bottom: 16px;
  display: block;
}

h3 {
  margin: 0 0 8px 0;
  font-size: 18px;
  font-weight: 600;
}

.error-message {
  margin: 0 0 24px 0;
  color: var(--text-secondary, #666);
  font-size: 14px;
  line-height: 1.5;
}

.retry-btn {
  padding: 8px 24px;
  background: var(--primary-color, #ff7a18);
  color: white;
  border: none;
  border-radius: 20px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: opacity 0.2s;
}

.retry-btn:hover {
  opacity: 0.9;
}
</style>
