<script setup lang="ts">
import { ref, watch } from "vue";

const props = defineProps<{
  show: boolean;
  mirror: string;
  proxy: string;
}>();

const emit = defineEmits<{
  (e: "close"): void;
  (e: "install", mirror: string, proxy: string): void;
  (e: "openOfficial"): void;
}>();

const localMirror = ref(props.mirror);
const localProxy = ref(props.proxy);

watch(() => props.show, (newVal) => {
  if (newVal) {
    localMirror.value = props.mirror;
    localProxy.value = props.proxy;
  }
});

function onClose() {
  emit("close");
}
</script>

<template>
  <Teleport to="body">
    <Transition name="fade">
      <div
        v-if="show"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm px-6"
        @click.self="onClose"
      >
        <div class="bg-white rounded-2xl shadow-xl w-full max-w-sm p-5">
          <h3 class="text-lg font-bold text-slate-900 mb-2">缺少 Node.js</h3>
          <p class="text-sm text-slate-600 mb-4 leading-relaxed">
            未检测到 Node.js。Claude Code CLI 依赖 Node.js 环境，请选择以下操作：
          </p>

          <div class="space-y-3 mb-5">
            <div>
              <label class="block text-xs font-medium text-slate-500 mb-1.5">Node.js 下载源</label>
              <select
                v-model="localMirror"
                class="w-full px-3 py-2.5 rounded-lg border border-slate-300 bg-white text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="npmmirror">淘宝镜像（国内推荐）</option>
                <option value="official">Node.js 官方</option>
                <option value="tencent">腾讯镜像</option>
              </select>
            </div>
            <div>
              <label class="block text-xs font-medium text-slate-500 mb-1.5">代理地址（可选）</label>
              <input
                v-model="localProxy"
                type="text"
                placeholder="http://127.0.0.1:7890"
                class="w-full px-3 py-2.5 rounded-lg border border-slate-300 bg-white text-sm text-slate-800 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>

          <div class="flex flex-col gap-2">
            <button
              type="button"
              class="w-full py-2.5 rounded-xl bg-gradient-to-r from-blue-500 to-emerald-400 text-white text-sm font-semibold shadow-sm hover:shadow-md transition-all"
              @click="$emit('install', localMirror, localProxy)"
            >
              一键安装 Node.js
            </button>
            <button
              type="button"
              class="w-full py-2.5 rounded-xl bg-white text-blue-600 text-sm font-semibold border border-slate-300 hover:bg-slate-50 transition-all"
              @click="$emit('openOfficial')"
            >
              打开官方下载页面
            </button>
            <button
              type="button"
              class="w-full py-2.5 rounded-xl text-slate-500 text-sm font-medium hover:text-slate-700 transition-colors"
              @click="onClose"
            >
              取消
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
