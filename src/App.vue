<script setup lang="ts">
import { ref, computed, reactive } from "vue";
import { invoke } from "@tauri-apps/api/core";
import { ask } from "@tauri-apps/plugin-dialog";
import { open } from "@tauri-apps/plugin-shell";
import FormCard from "./components/FormCard.vue";
import LogPanel from "./components/LogPanel.vue";
import StatusButton from "./components/StatusButton.vue";
import type { ConfigForm, EnvironmentStatus, LogItem } from "./types";

const form = reactive<ConfigForm>({
  apiKey: "",
  baseUrl: "",
  modelName: "kimi-k2.6",
});

const logs = ref<LogItem[]>([
  { status: "info", message: "填写信息后，可先测试连接，再执行完整配置" },
]);

const testing = ref(false);
const configuring = ref(false);

const canAction = computed(() => {
  return form.apiKey.trim() && form.baseUrl.trim() && form.modelName.trim();
});

function addLog(status: LogItem["status"], message: string) {
  logs.value.push({ status, message });
}

async function handleTest() {
  if (!canAction.value) return;
  testing.value = true;
  addLog("loading", "正在测试连接...");

  try {
    const result = await invoke<string>("test_connection", {
      baseUrl: form.baseUrl,
      apiKey: form.apiKey,
      modelName: form.modelName,
    });
    addLog("success", result);
  } catch (err) {
    addLog("error", String(err));
  } finally {
    testing.value = false;
  }
}

async function handleConfigure() {
  if (!canAction.value) return;

  configuring.value = true;
  logs.value = [];
  addLog("info", "正在检查环境...");

  try {
    const status = await invoke<EnvironmentStatus>("check_environment");
    addLog(
      status.node_installed ? "success" : "error",
      `Node.js: ${status.node_version}`
    );
    addLog(
      status.npm_installed ? "success" : "error",
      `npm: ${status.npm_version}`
    );
    addLog(
      status.claude_installed ? "success" : "info",
      `Claude Code CLI: ${status.claude_version}`
    );
    addLog(
      status.env_configured ? "success" : "info",
      status.env_configured ? "已检测到环境变量配置" : "未检测到环境变量配置"
    );

    // 1. Node.js 检查
    if (!status.node_installed || !status.npm_installed) {
      const openDownload = await ask(
        "需要 Node.js 才能安装 Claude Code CLI。\n是否打开 Node.js 官方下载页面？",
        {
          title: "缺少 Node.js",
          kind: "warning",
          okLabel: "打开下载页",
          cancelLabel: "取消",
        }
      );
      if (openDownload) {
        await open("https://nodejs.org/");
      }
      configuring.value = false;
      return;
    }

    // 2. Claude 已安装：询问是否重新安装
    if (status.claude_installed) {
      const reinstall = await ask(
        `Claude Code CLI 已安装（${status.claude_version}）。\n是否重新安装并重新配置？`,
        {
          title: "Claude 已安装",
          kind: "info",
          okLabel: "重新安装",
          cancelLabel: "取消",
        }
      );
      if (!reinstall) {
        addLog("info", "已取消配置");
        configuring.value = false;
        return;
      }
    }

    // 3. 环境变量已配置：询问是否重新配置
    if (status.env_configured) {
      const reconfigure = await ask(
        "检测到已存在 AIEnvKit 生成的环境变量配置。\n是否重新配置？",
        {
          title: "环境变量已配置",
          kind: "info",
          okLabel: "重新配置",
          cancelLabel: "取消",
        }
      );
      if (!reconfigure) {
        addLog("info", "已取消配置");
        configuring.value = false;
        return;
      }
    }

    // 开始执行配置
    logs.value = [];
    const steps = [
      { status: "loading" as const, message: "环境检测通过" },
      { status: "loading" as const, message: "检查/安装 Claude Code CLI..." },
      { status: "loading" as const, message: "备份原配置..." },
      { status: "loading" as const, message: "写入 Claude Code 配置..." },
      { status: "loading" as const, message: "设置环境变量..." },
      { status: "loading" as const, message: "最终验证..." },
    ];

    steps.forEach((step) => addLog(step.status, step.message));

    const result = await invoke<string>("execute_configure", {
      apiKey: form.apiKey,
      baseUrl: form.baseUrl,
      modelName: form.modelName,
    });

    logs.value = steps.map((s) => ({
      status: "success" as const,
      message: s.message
        .replace("通过", "✓")
        .replace("检查/安装 Claude Code CLI...", "Claude Code CLI 已就绪")
        .replace("备份原配置...", "原配置已备份")
        .replace("写入 Claude Code 配置...", "Claude Code 配置已写入")
        .replace("设置环境变量...", "环境变量已设置")
        .replace("最终验证...", "最终验证通过"),
    }));
    addLog("success", result);
    addLog("success", "配置完成！现在可以打开终端输入 claude 使用");
  } catch (err) {
    addLog("error", String(err));
  } finally {
    configuring.value = false;
  }
}

async function handleRestore() {
  try {
    const result = await invoke<string>("restore_backup");
    addLog("success", result);
  } catch (err) {
    addLog("error", String(err));
  }
}

function handleHelp() {
  addLog(
    "info",
    "使用说明：填写 API Key、API 地址和模型名称，点击测试连接确认可用后，再点一键执行配置。"
  );
}
</script>

<template>
  <div class="min-h-screen bg-slate-50 flex flex-col items-center p-6">
    <!-- 头部 -->
    <header class="text-center mb-6 mt-2">
      <div class="flex items-center justify-center gap-3 mb-2">
        <div
          class="w-10 h-10 rounded-full bg-gradient-to-br from-blue-400 to-cyan-400 flex items-center justify-center text-white text-xl"
        >
          🤖
        </div>
        <h1 class="text-3xl font-bold text-slate-900 tracking-tight">AIEnvKit</h1>
      </div>
      <h2 class="text-xl font-semibold text-blue-600 mb-1">Claude 一键配置</h2>
      <p class="text-sm text-slate-500">
        填写以下信息，可先测试连接，再执行完整配置
      </p>
    </header>

    <!-- 表单卡片 -->
    <FormCard v-model="form" class="w-full max-w-md mb-5" />

    <!-- 按钮区 -->
    <div class="w-full max-w-md flex gap-3 mb-5">
      <StatusButton
        variant="secondary"
        icon="🔌"
        :loading="testing"
        :disabled="!canAction || configuring"
        class="flex-1"
        @click="handleTest"
      >
        测试连接
      </StatusButton>
      <StatusButton
        variant="primary"
        icon="→"
        :loading="configuring"
        :disabled="!canAction || testing"
        class="flex-[1.3]"
        @click="handleConfigure"
      >
        一键执行配置
      </StatusButton>
    </div>

    <!-- 日志区 -->
    <LogPanel :logs="logs" class="w-full max-w-md flex-1 min-h-[180px] mb-4" />

    <!-- 底部 -->
    <footer
      class="w-full max-w-md flex justify-center items-center gap-6 text-sm text-slate-500 py-3 border-t border-slate-200"
    >
      <button
        class="flex items-center gap-1 hover:text-blue-600 transition-colors"
        @click="handleRestore"
      >
        <span>↩</span>
        <span>恢复备份</span>
      </button>
      <button
        class="flex items-center gap-1 hover:text-blue-600 transition-colors"
        @click="handleHelp"
      >
        <span>?</span>
        <span>查看帮助</span>
      </button>
    </footer>
  </div>
</template>
