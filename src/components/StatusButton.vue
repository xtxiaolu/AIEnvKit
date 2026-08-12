<script setup lang="ts">
defineProps<{
  variant: "primary" | "secondary";
  icon?: string;
  loading?: boolean;
  disabled?: boolean;
}>();

defineEmits<{
  (e: "click"): void;
}>();
</script>

<template>
  <button
    type="button"
    :disabled="disabled || loading"
    class="relative inline-flex items-center justify-center gap-2 rounded-xl px-5 py-3.5 text-sm font-semibold transition-all disabled:opacity-50 disabled:cursor-not-allowed"
    :class="{
      'bg-gradient-to-r from-blue-500 to-emerald-400 text-white shadow-md hover:shadow-lg hover:from-blue-600 hover:to-emerald-500': variant === 'primary',
      'bg-white text-blue-600 border border-slate-300 shadow-sm hover:bg-slate-50 hover:border-blue-400': variant === 'secondary',
    }"
    @click="$emit('click')"
  >
    <span v-if="loading" class="w-4 h-4 border-2 border-current border-t-transparent rounded-full animate-spin" />
    <span v-else-if="icon" class="text-base">{{ icon }}</span>
    <span><slot /></span>
  </button>
</template>
