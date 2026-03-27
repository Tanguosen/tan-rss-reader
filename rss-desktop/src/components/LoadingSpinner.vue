<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(
  defineProps<{
    label?: string
    message?: string
    size?: number | 'small' | 'medium' | 'large'
  }>(),
  {
    label: '',
    message: '',
    size: 'medium'
  }
)

const pixelSize = computed(() => {
  if (typeof props.size === 'number') return props.size
  if (props.size === 'small') return 14
  if (props.size === 'large') return 22
  return 18
})

const displayLabel = computed(() => props.message || props.label)
</script>

<template>
  <div class="spinner" role="status" aria-live="polite">
    <div class="spinner__icon" :style="{ width: pixelSize + 'px', height: pixelSize + 'px' }"></div>
    <div v-if="displayLabel" class="spinner__label">{{ displayLabel }}</div>
  </div>
</template>

<style scoped>
.spinner {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  color: rgba(15, 17, 21, 0.75);
}

.spinner__icon {
  border-radius: 999px;
  border: 2px solid rgba(15, 17, 21, 0.15);
  border-top-color: rgba(255, 122, 24, 0.9);
  animation: spin 0.9s linear infinite;
}

.spinner__label {
  font-size: 14px;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}
</style>
