<script setup lang="ts">
const props = withDefaults(defineProps<{ size?: number }>(), {
  size: 32,
})
const logoSrc = new URL('/icons/app-release.png', import.meta.url).href
</script>

<template>
  <img
    class="logo-mark"
    :src="logoSrc"
    :width="props.size"
    :height="props.size"
    alt="TAN图标"
  />
</template>

<style scoped>
.logo-mark {
  display: block;
  object-fit: contain;
}
</style>
