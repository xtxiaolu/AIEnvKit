<script setup lang="ts">
import { ref, watch, nextTick } from "vue";
import type { LogItem } from "../types";

const props = defineProps<{
  logs: LogItem[];
}>();

const logContainer = ref<HTMLDivElement | null>(null);

watch(
  () => props.logs.length,
  async () => {
    await nextTick();
    if (logContainer.value) {
      logContainer.value.scrollTop = logContainer.value.scrollHeight;
    }
  },
  { flush: "post" }
);
</script>

<template>
  <div class="bg-white h-full flex flex-col p-4">
    <div ref="logContainer" class="flex-1 space-y-2.5 overflow-y-auto pr-1 min-h-0">
      <div
        v-for="(log, index) in logs"
        :key="index"
        class="flex items-center gap-2.5 text-sm"
      >
        <span class="flex-shrink-0 w-5 h-5 flex items-center justify-center">
          <span
            v-if="log.status === 'success'"
            class="text-green-500"
          >✔</span>
          <span
            v-else-if="log.status === 'error'"
            class="text-red-500"
          >✖</span>
          <span
            v-else-if="log.status === 'loading'"
            class="text-blue-500 animate-spin"
          >↻</span>
          <span
            v-else
            class="text-slate-400"
          >ℹ</span>
        </span>
        <span
          class="transition-all"
          :class="{
            'text-slate-700': log.status === 'info' || log.status === 'loading',
            'text-green-600': log.status === 'success',
            'text-red-600': log.status === 'error',
          }"
        >{{ log.message }}</span>
      </div>
    </div>
  </div>
</template>
