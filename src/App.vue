<script setup lang="ts">
import { ref, computed } from "vue";
import { invoke } from "@tauri-apps/api/core";
import { ask } from "@tauri-apps/plugin-dialog";
import { open } from "@tauri-apps/plugin-shell";
import FormCard from "./components/FormCard.vue";
import LogPanel from "./components/LogPanel.vue";
import StatusButton from "./components/StatusButton.vue";
import InstallNodeModal from "./components/InstallNodeModal.vue";
import type { ConfigForm, EnvironmentStatus, LogItem } from "./types";

const form = ref<ConfigForm>({
  apiKey: "",
  baseUrl: "",
  modelName: "kimi-k2.6",
  npmMirror: "npmmirror",
  proxy: "",
});

const logs = ref<LogItem[]>([
  { status: "info", message: "填写信息后，可先测试连接，再执行完整配置" },
]);

const testing = ref(false);
const configuring = ref(false);
const showInstallNodeModal = ref(false);

// 三个输入框都有内容时才启用按钮
const canAction = computed(() => {
  return (
    form.value.apiKey.trim().length > 0 &&
    form.value.baseUrl.trim().length > 0 &&
    form.value.modelName.trim().length > 0
  );
});

function addLog(status: LogItem["status"], message: string) {
  logs.value.push({ status, message });
}

async function handleTest() {
  if (!canAction.value) return;
  testing.value = true;
  const loadingIndex = logs.value.length;
  addLog("loading", "正在测试连接...");

  try {
    const result = await invoke<string>("test_connection", {
      baseUrl: form.value.baseUrl.trim(),
      apiKey: form.value.apiKey.trim(),
      modelName: form.value.modelName.trim(),
    });
    logs.value[loadingIndex] = { status: "success", message: result };
  } catch (err) {
    logs.value[loadingIndex] = { status: "error", message: String(err) };
  } finally {
    testing.value = false;
  }
}

async function handleConfigure() {
  if (!canAction.value) return;

  configuring.value = true;
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
      configuring.value = false;
      showInstallNodeModal.value = true;
      return;
    }

    await proceedConfigure(status);
  } catch (err) {
    addLog("error", String(err));
  } finally {
    configuring.value = false;
  }
}

async function handleInstallNode(mirror: string, proxy: string) {
  showInstallNodeModal.value = false;
  configuring.value = true;
  addLog("loading", `正在一键安装 Node.js（${mirror === "official" ? "官方" : mirror === "npmmirror" ? "淘宝镜像" : mirror === "tencent" ? "腾讯镜像" : mirror}）...`);

  try {
    const result = await invoke<string>("install_node", { mirror, proxy });
    addLog("success", result);

    // 重新检测环境
    const status = await invoke<EnvironmentStatus>("check_environment");
    if (!status.node_installed || !status.npm_installed) {
      addLog("error", "Node.js 安装后仍未检测到，请检查日志或手动安装");
      configuring.value = false;
      return;
    }

    addLog("success", `Node.js 安装完成：${status.node_version}`);
    await proceedConfigure(status);
  } catch (err) {
    addLog("error", String(err));
  } finally {
    configuring.value = false;
  }
}

async function handleOpenOfficialNode() {
  showInstallNodeModal.value = false;
  configuring.value = false;
  await open("https://nodejs.org/");
}

async function proceedConfigure(status: EnvironmentStatus) {
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

  // 3. 环境变量已配置：询问是否重新配置，并提示备份
  if (status.env_configured) {
    const vars = status.env_vars_status;
    const missing = [
      !vars.auth_token_set && "ANTHROPIC_AUTH_TOKEN",
      !vars.base_url_set && "ANTHROPIC_BASE_URL",
      !vars.model_set && "ANTHROPIC_MODEL",
    ].filter(Boolean);

    let message = "检测到已存在 AIEnvKit 生成的环境变量配置。\n";
    if (missing.length > 0) {
      message += `注意：部分变量未完整配置（${missing.join(", ")}）。\n`;
    }
    message += "重新配置前会自动备份原配置。\n是否继续重新配置？";

    const reconfigure = await ask(message, {
      title: "环境变量已配置",
      kind: "info",
      okLabel: "重新配置（自动备份）",
      cancelLabel: "取消",
    });
    if (!reconfigure) {
      addLog("info", "已取消配置");
      configuring.value = false;
      return;
    }
  }

  // 开始执行配置
  const startIndex = logs.value.length;
  const steps = [
    "环境检测通过",
    "检查/安装 Claude Code CLI...",
    "备份原配置...",
    "写入 Claude Code 配置...",
    "设置环境变量...",
    "最终验证...",
  ];

  steps.forEach((message) => addLog("loading", message));

  const result = await invoke<string>("execute_configure", {
    apiKey: form.value.apiKey.trim(),
    baseUrl: form.value.baseUrl.trim(),
    modelName: form.value.modelName.trim(),
    npmMirror: form.value.npmMirror.trim(),
    proxy: form.value.proxy.trim(),
  });

  steps.forEach((message, index) => {
    const successMessage = message
      .replace("通过", "✓")
      .replace("检查/安装 Claude Code CLI...", "Claude Code CLI 已就绪")
      .replace("备份原配置...", "原配置已备份")
      .replace("写入 Claude Code 配置...", "Claude Code 配置已写入")
      .replace("设置环境变量...", "环境变量已设置")
      .replace("最终验证...", "最终验证通过");
    logs.value[startIndex + index] = { status: "success", message: successMessage };
  });
  addLog("success", result);
  addLog("success", "配置完成！现在可以打开终端输入 claude 使用");
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
  <div class="h-screen bg-slate-50 flex flex-row overflow-hidden">
    <!-- 左侧：标题 + 日志面板 -->
    <section class="w-[45%] min-w-[360px] max-w-[520px] bg-white border-r border-slate-200 flex flex-col">
      <div class="px-5 py-5 border-b border-slate-100">
        <div class="flex items-center gap-2.5 mb-3">
          <div class="w-9 h-9 rounded-xl bg-gradient-to-br from-blue-500 to-emerald-400 flex items-center justify-center shadow-sm">
            <span class="text-white text-sm font-bold">AI</span>
          </div>
          <div>
            <h1 class="text-lg font-bold text-slate-900 leading-tight">AIEnvKit</h1>
            <p class="text-xs text-slate-500">Claude 一键配置</p>
          </div>
        </div>
        <p class="text-sm text-slate-600 leading-relaxed">
          填写右侧信息后，可先测试连接，再执行完整配置。执行日志将显示在这里。
        </p>
      </div>
      <div class="px-5 py-2 border-b border-slate-100 bg-slate-50/50">
        <span class="text-xs font-medium text-slate-500">执行日志</span>
      </div>
      <div class="flex-1 min-h-0 overflow-hidden">
        <LogPanel :logs="logs" class="h-full" />
      </div>
    </section>

    <!-- 右侧：配置表单 -->
    <main class="flex-1 flex flex-col items-center justify-center px-8 py-6 overflow-y-auto">
      <div class="w-full max-w-md">
        <!-- 表单卡片 -->
        <FormCard v-model="form" class="mb-5" />

        <!-- 按钮区 -->
        <div class="flex gap-3 mb-4">
          <StatusButton
            variant="secondary"
            :loading="testing"
            :disabled="!canAction || configuring"
            class="flex-1"
            @click="handleTest"
          >
            测试连接
          </StatusButton>
          <StatusButton
            variant="primary"
            :loading="configuring"
            :disabled="!canAction || testing"
            class="flex-[1.3]"
            @click="handleConfigure"
          >
            一键执行配置
          </StatusButton>
        </div>

        <!-- 底部 -->
        <footer class="flex justify-center items-center gap-6 text-sm text-slate-500 py-3 border-t border-slate-200">
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
    </main>

    <InstallNodeModal
      :show="showInstallNodeModal"
      :mirror="form.npmMirror"
      :proxy="form.proxy"
      @close="showInstallNodeModal = false"
      @install="handleInstallNode"
      @open-official="handleOpenOfficialNode"
    />
  </div>
</template>
