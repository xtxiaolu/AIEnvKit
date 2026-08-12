<script setup lang="ts">
import { ref } from "vue";
import type { ConfigForm } from "../types";

const props = defineProps<{
  modelValue: ConfigForm;
}>();

const emit = defineEmits<{
  (e: "update:modelValue", value: ConfigForm): void;
}>();

const showKey = ref(false);

function updateField<K extends keyof ConfigForm>(key: K, value: ConfigForm[K]) {
  emit("update:modelValue", { ...props.modelValue, [key]: value });
}
</script>

<template>
  <div class="bg-white rounded-2xl shadow-sm border border-slate-200 p-5">
    <!-- API Key -->
    <div class="mb-4">
      <label class="block text-sm font-semibold text-slate-800 mb-2">API Key</label>
      <div class="relative flex items-center">
        <input
          :type="showKey ? 'text' : 'password'"
          :value="modelValue.apiKey"
          placeholder="sk-你的密钥"
          class="w-full px-4 py-3 pr-12 rounded-xl border border-slate-300 bg-white text-sm text-slate-800 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
          @input="updateField('apiKey', ($event.target as HTMLInputElement).value)"
        />
        <button
          type="button"
          class="absolute right-3 text-slate-400 hover:text-slate-600 transition-colors p-1"
          @click="showKey = !showKey"
        >
          <svg v-if="!showKey" xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg>
          <svg v-else xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9.88 9.88a3 3 0 1 0 4.24 4.24"/><path d="M10.73 5.08A10.43 10.43 0 0 1 12 5c7 0 10 7 10 7a13.16 13.16 0 0 1-1.67 2.68"/><path d="M6.61 6.61A13.526 13.526 0 0 0 2 12s3 7 10 7a9.74 9.74 0 0 0 5.39-1.61"/><line x1="2" x2="22" y1="2" y2="22"/></svg>
        </button>
      </div>
    </div>

    <!-- API 地址 -->
    <div class="mb-4">
      <label class="block text-sm font-semibold text-slate-800 mb-2">API 地址 (Base URL)</label>
      <input
        type="text"
        :value="modelValue.baseUrl"
        placeholder="https://api.xxx.com"
        class="w-full px-4 py-3 rounded-xl border border-slate-300 bg-white text-sm text-slate-800 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
        @input="updateField('baseUrl', ($event.target as HTMLInputElement).value)"
      />
    </div>

    <!-- 模型名称 -->
    <div class="mb-4">
      <label class="block text-sm font-semibold text-slate-800 mb-2">模型名称</label>
      <input
        type="text"
        :value="modelValue.modelName"
        placeholder="kimi-k2.6"
        class="w-full px-4 py-3 rounded-xl border border-slate-300 bg-white text-sm text-slate-800 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
        @input="updateField('modelName', ($event.target as HTMLInputElement).value)"
      />
    </div>

    <!-- 高级选项：npm 镜像与代理 -->
    <div class="pt-3 border-t border-slate-100">
      <div class="grid grid-cols-2 gap-3">
        <div>
          <label class="block text-xs font-medium text-slate-500 mb-1.5">npm 镜像</label>
          <select
            :value="modelValue.npmMirror"
            class="w-full px-3 py-2.5 rounded-lg border border-slate-300 bg-white text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all appearance-none"
            @change="updateField('npmMirror', ($event.target as HTMLSelectElement).value)"
          >
            <option value="official">官方</option>
            <option value="npmmirror">淘宝镜像</option>
            <option value="tencent">腾讯镜像</option>
          </select>
        </div>
        <div>
          <label class="block text-xs font-medium text-slate-500 mb-1.5">代理 (可选)</label>
          <input
            type="text"
            :value="modelValue.proxy"
            placeholder="http://127.0.0.1:7890"
            class="w-full px-3 py-2.5 rounded-lg border border-slate-300 bg-white text-sm text-slate-800 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
            @input="updateField('proxy', ($event.target as HTMLInputElement).value)"
          />
        </div>
      </div>
    </div>
  </div>
</template>
