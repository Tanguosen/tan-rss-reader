<script setup lang="ts">
import { watch } from 'vue'

const props = defineProps<{
  show: boolean
  message: string
  type: 'success' | 'error' | 'info'
}>()

const emit = defineEmits<{
  close: []
}>()

watch(
  () => props.show,
  (visible) => {
    if (!visible) return
    setTimeout(() => emit('close'), 2500)
  }
)
</script>

<template>
  <Transition name="toast">
    <div v-if="show" class="toast" :data-type="type" role="status">
      <div class="toast__message">{{ message }}</div>
      <button class="toast__close" type="button" @click="emit('close')">✕</button>
    </div>
  </Transition>
</template>

<style scoped>
.toast {
  position: fixed;
  top: 16px;
  right: 16px;
  z-index: 9999;
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border-radius: 10px;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.12);
  background: #111827;
  color: #fff;
  max-width: min(420px, calc(100vw - 32px));
}

.toast[data-type='success'] {
  background: #065f46;
}

.toast[data-type='error'] {
  background: #7f1d1d;
}

.toast[data-type='info'] {
  background: #1f2937;
}

.toast__message {
  flex: 1;
  font-size: 14px;
  line-height: 1.35;
  word-break: break-word;
}

.toast__close {
  border: none;
  background: transparent;
  color: rgba(255, 255, 255, 0.85);
  cursor: pointer;
  font-size: 14px;
  padding: 4px 6px;
}

.toast__close:hover {
  color: #fff;
}

.toast-enter-active,
.toast-leave-active {
  transition: all 0.16s ease;
}

.toast-enter-from,
.toast-leave-to {
  opacity: 0;
  transform: translateY(-6px);
}
</style>
