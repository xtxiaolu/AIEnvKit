<script setup lang="ts">
defineProps<{
  variant: "primary" | "secondary";
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
    <svg
      v-else-if="variant === 'secondary'"
      xmlns="http://www.w3.org/2000/svg"
      width="16"
      height="16"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2.5"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <path d="M12 22v-5" />
      <path d="M9 8V2" />
      <path d="M15 8V2" />
      <path d="M18 8v3a3 3 0 0 1-3 3H9a3 3 0 0 1-3-3V8" />
      <path d="M9 8a3 3 0 0 1 3-3h0a3 3 0 0 1 3 3" />
    </svg>
    <svg
      v-else
      xmlns="http://www.w3.org/2000/svg"
      width="16"
      height="16"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2.5"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <path d="M5 12h14" />
      <path d="m12 5 7 7-7 7" />
    </svg>
    <span><slot /></span>
  </button>
</template>
