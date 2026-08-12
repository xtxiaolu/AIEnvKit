# AIEnvKit

AI 模型环境一键配置工具，面向普通用户。下载一个文件，双击打开，填写 3 项信息，先测试连接，再一键完成 Claude Code 环境配置。

## 界面预览

- 窗口固定尺寸：480 × 680
- 顶部：Logo + 标题 + 引导语
- 中部：API Key / API 地址 / 模型名称 输入框
- 按钮：测试连接（次要）、一键执行配置（主按钮）
- 底部：实时执行日志 + 恢复备份 / 查看帮助

## 功能流程

### 一键执行配置前检查

点击「一键执行配置」后，会按顺序检查并弹窗确认：

1. **Node.js / npm 检查**
   - 未安装 → 弹窗提示「需要 Node.js 才能安装 Claude Code CLI，是否打开下载页面？」
   - 已安装 → 继续下一步
2. **Claude Code CLI 检查**
   - 已安装 → 弹窗提示「Claude 已安装（版本 x.x.x），是否重新安装并重新配置？」，提供「重新安装」和「取消」按钮
   - 未安装 → 直接安装
3. **环境变量检查**
   - 已配置 → 弹窗提示「检测到已存在 AIEnvKit 环境变量配置，是否重新配置？」，提供「重新配置」和「取消」按钮
   - 未配置 → 直接配置
4. 全部确认后，才执行完整配置流程。

### 完整配置流程

1. **环境检测**：检测 Node.js、npm、Claude CLI、网络
2. **安装/升级 Claude Code CLI**
3. **备份原配置**：备份 `settings.json` 和 shell/PowerShell profile
4. **写入 Claude Code 配置**：写入 `~/.claude/settings.json`（macOS）或 `%USERPROFILE%\.claude\settings.json`（Windows）
5. **设置环境变量**：写入 shell profile / PowerShell profile / Windows 用户环境变量
6. **最终验证**：测试 API 连接

### 测试连接

只发送一次 API 请求到 `/models`，不修改任何配置。

## 技术栈

| 层级 | 技术 |
|---|---|
| 桌面框架 | Tauri 2 |
| 前端 | Vue 3 + TypeScript + Vite |
| 样式 | Tailwind CSS |
| 后端 | Rust |
| 打包 | Tauri 官方 bundler |

## 目录结构

```
AIEnvKit/
├── src/                    # Vue 3 前端
│   ├── App.vue
│   ├── components/
│   │   ├── FormCard.vue
│   │   ├── LogPanel.vue
│   │   └── StatusButton.vue
│   ├── main.ts
│   ├── style.css
│   └── types.ts
├── src-tauri/              # Rust 后端
│   ├── src/main.rs
│   ├── Cargo.toml
│   ├── tauri.conf.json
│   ├── capabilities/
│   └── icons/
├── scripts/                # 跨平台配置脚本
│   ├── macos/
│   │   ├── set-env.sh
│   │   └── restore-backup.sh
│   └── windows/
│       ├── set-env.ps1
│       └── restore-backup.ps1
├── package.json
├── vite.config.ts
├── tailwind.config.js
└── README.md
```

## 开发环境要求

- [Node.js](https://nodejs.org/) 18+
- [Rust](https://www.rust-lang.org/tools/install) 1.75+
- Tauri 系统依赖（见 [Tauri 官方文档](https://v2.tauri.app/start/prerequisites/)）

## 开发命令

```bash
# 安装依赖
npm install

# 开发模式（热重载）
npm run tauri:dev

# 构建生产版（当前平台）
npm run tauri:build
```

## 分平台打包

### macOS

```bash
# Intel (x86_64)
npm run tauri:build:mac-x64

# Apple Silicon (arm64)
npm run tauri:build:mac-arm64
```

产物位置：

```
src-tauri/target/x86_64-apple-darwin/release/bundle/macos/AIEnvKit.app
src-tauri/target/aarch64-apple-darwin/release/bundle/macos/AIEnvKit.app
```

### Windows

```bash
npm run tauri:build
```

产物位置：

```
src-tauri/target/x86_64-pc-windows-msvc/release/bundle/nsis/AIEnvKit_0.1.0_x64-setup.exe
src-tauri/target/x86_64-pc-windows-msvc/release/bundle/aienvkit.exe  # 便携版
```

> Windows 首次运行若提示缺少 WebView2，应用会自动引导下载安装。

## 配置说明

一键配置会写入以下内容：

```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "你的 API Key",
    "ANTHROPIC_BASE_URL": "你的 API 地址",
    "ANTHROPIC_MODEL": "模型名称",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "模型名称",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "模型名称",
    "CLAUDE_CODE_SUBAGENT_MODEL": "模型名称"
  }
}
```

同时会在 shell profile / PowerShell profile / Windows 用户环境变量中写入同名变量。

## 恢复备份

每次执行配置前会自动备份：

- macOS：`~/.aienvkit/backups/`
- Windows：`%USERPROFILE%\.aienvkit\backups\`

点击界面底部「恢复备份」可还原最近一次的 settings.json 和 shell profile。

## 安全提示

- API Key 仅存储在本地 `~/.claude/settings.json` 和环境变量中，不会上传。
- 正式分发 macOS 版本需要 Apple 开发者账号签名，否则用户会看到安全提示。
- Windows 版本建议配合 WebView2 安装引导一起分发。

## 许可证

MIT
