<script setup lang="ts">
import { ref, watch } from 'vue'
import { useChannelsStore, type Channel } from '../stores/channelsStore'

const props = defineProps<{
  show: boolean
  channel: Channel | null
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'updated'): void
}>()

const channelsStore = useChannelsStore()

const name = ref('')
const description = ref('')
const loading = ref(false)

watch(() => props.channel, (newChannel) => {
  if (newChannel) {
    name.value = newChannel.name || ''
    description.value = newChannel.description || ''
  }
}, { immediate: true })

async function handleSave() {
  if (!props.channel) return
  loading.value = true
  try {
    const success = await channelsStore.updateChannel(props.channel.id, {
      name: name.value,
      description: description.value
    })
    if (success) {
      // Refresh my subscriptions to reflect changes in sidebar
      await channelsStore.fetchMySubscriptions()
      emit('updated')
      emit('close')
    }
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <Transition name="modal">
    <div v-if="show" class="modal-backdrop" @click.self="emit('close')">
      <div class="modal-content">
        <div class="modal-header">
          <h2>编辑频道</h2>
          <button class="close-btn" @click="emit('close')">&times;</button>
        </div>
        <div class="modal-body">
          <div class="form-group">
            <label>频道名称</label>
            <input v-model="name" type="text" class="form-input" placeholder="输入频道名称" />
          </div>
          <div class="form-group">
            <label>描述</label>
            <textarea v-model="description" class="form-input" placeholder="输入频道描述" rows="3"></textarea>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-secondary" @click="emit('close')">取消</button>
          <button class="btn btn-primary" @click="handleSave" :disabled="loading || !name">
            {{ loading ? '保存中...' : '保存' }}
          </button>
        </div>
      </div>
    </div>
  </Transition>
</template>

<style scoped>
.modal-backdrop {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 1000;
}

.modal-content {
  background: white;
  border-radius: 8px;
  width: 90%;
  max-width: 500px;
  max-height: 90vh;
  overflow-y: auto;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  display: flex;
  flex-direction: column;
}

.modal-header {
  padding: 16px 24px;
  border-bottom: 1px solid #e5e7eb;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.modal-header h2 {
  margin: 0;
  font-size: 1.25rem;
  font-weight: 600;
  color: #111827;
}

.close-btn {
  background: none;
  border: none;
  font-size: 1.5rem;
  color: #6b7280;
  cursor: pointer;
  padding: 4px;
  line-height: 1;
}

.modal-body {
  padding: 24px;
}

.form-group {
  margin-bottom: 16px;
}

.form-group label {
  display: block;
  margin-bottom: 8px;
  font-weight: 500;
  color: #374151;
}

.form-input {
  width: 100%;
  padding: 8px 12px;
  border: 1px solid #d1d5db;
  border-radius: 4px;
  font-size: 0.95rem;
}

.form-input:focus {
  outline: none;
  border-color: #3b82f6;
  box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.2);
}

.modal-footer {
  padding: 16px 24px;
  border-top: 1px solid #e5e7eb;
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}

.btn {
  padding: 8px 16px;
  border-radius: 4px;
  font-weight: 500;
  cursor: pointer;
  border: none;
  transition: all 0.2s;
}

.btn-secondary {
  background: #f3f4f6;
  color: #374151;
}

.btn-secondary:hover {
  background: #e5e7eb;
}

.btn-primary {
  background: #3b82f6;
  color: white;
}

.btn-primary:hover {
  background: #2563eb;
}

.btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* Transitions */
.modal-enter-active,
.modal-leave-active {
  transition: opacity 0.3s ease;
}

.modal-enter-from,
.modal-leave-to {
  opacity: 0;
}
</style>
