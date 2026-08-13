#!/usr/bin/env bash
set -euo pipefail

# publish-release.sh
# 一键打包并发布 GitHub Release
# 用法：
#   ./scripts/publish-release.sh 0.1.0
#   ./scripts/publish-release.sh 0.1.0 --skip-build
#
# 要求：
#   - 已安装 gh CLI 并执行 gh auth login 登录
#   - 已安装 rust + cargo + npm
#   - macOS 上交叉编译 Windows 需要安装 mingw-w64 和 makensis（brew install mingw-w64 nsis）

VERSION="${1:-}"
SKIP_BUILD=false

if [[ -z "$VERSION" ]]; then
  echo "用法：$0 <版本号> [--skip-build]"
  echo "示例：$0 0.1.0"
  exit 1
fi

# 解析可选参数
for arg in "${@:2}"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=true ;;
    *) echo "未知参数：$arg"; exit 1 ;;
  esac
done

# 版本号前缀处理
TAG="v${VERSION#v}"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_DIR="$PROJECT_ROOT/release"
ASSET_PREFIX="AIEnvKit_${VERSION}"

cd "$PROJECT_ROOT"

# 检查 gh 是否已登录
if ! command -v gh >/dev/null 2>&1; then
  echo "错误：未安装 gh CLI，请先执行 brew install gh"
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "错误：gh CLI 未登录，请先执行："
  echo "  gh auth login"
  exit 1
fi

# 检查 release 目录
mkdir -p "$RELEASE_DIR"

if [[ "$SKIP_BUILD" == true ]]; then
  echo "[跳过构建] 使用已存在的产物..."
else
  echo "[构建] 开始构建所有平台..."
  # macOS Apple Silicon
  npm run tauri:build:mac-arm64
  # macOS Intel
  npm run tauri:build:mac-x64
  # Windows x64（GNU 交叉编译）
  CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER=x86_64-w64-mingw32-gcc \
    npm run tauri -- build --target x86_64-pc-windows-gnu
fi

# 打包 macOS .app 为 zip
echo "[打包] 准备 Release 文件..."

MAC_ARM_APP="$PROJECT_ROOT/src-tauri/target/aarch64-apple-darwin/release/bundle/macos/AIEnvKit.app"
MAC_INTEL_APP="$PROJECT_ROOT/src-tauri/target/x86_64-apple-darwin/release/bundle/macos/AIEnvKit.app"
WIN_EXE="$PROJECT_ROOT/src-tauri/target/x86_64-pc-windows-gnu/release/bundle/nsis/AIEnvKit_${VERSION}_x64-setup.exe"

# 如果 Windows 产物路径不存在，尝试 MSVC 路径
if [[ ! -f "$WIN_EXE" ]]; then
  WIN_EXE="$PROJECT_ROOT/src-tauri/target/x86_64-pc-windows-msvc/release/bundle/nsis/AIEnvKit_${VERSION}_x64-setup.exe"
fi

ASSET_ARM="$RELEASE_DIR/${ASSET_PREFIX}_macOS_Apple_Silicon.zip"
ASSET_INTEL="$RELEASE_DIR/${ASSET_PREFIX}_macOS_Intel.zip"
ASSET_WIN="$RELEASE_DIR/${ASSET_PREFIX}_Windows_x64_Setup.exe"

if [[ ! -d "$MAC_ARM_APP" ]]; then
  echo "错误：找不到 macOS Apple Silicon 产物：$MAC_ARM_APP"
  exit 1
fi
if [[ ! -d "$MAC_INTEL_APP" ]]; then
  echo "错误：找不到 macOS Intel 产物：$MAC_INTEL_APP"
  exit 1
fi
if [[ ! -f "$WIN_EXE" ]]; then
  echo "错误：找不到 Windows 安装包：$WIN_EXE"
  exit 1
fi

rm -f "$ASSET_ARM" "$ASSET_INTEL" "$ASSET_WIN"
ditto -c -k --keepParent "$MAC_ARM_APP" "$ASSET_ARM"
ditto -c -k --keepParent "$MAC_INTEL_APP" "$ASSET_INTEL"
cp "$WIN_EXE" "$ASSET_WIN"

# 生成 release notes
echo "[文档] 生成 Release Notes..."
NOTES_FILE="$RELEASE_DIR/release-notes-${TAG}.md"

# 根据版本判断是 Initial Release 还是后续版本
if [[ "$VERSION" == "0.1.0" ]]; then
  cat > "$NOTES_FILE" <<EOF
## 功能介绍

AIEnvKit 是一个面向普通用户的 Claude Code 环境一键配置工具。首个版本包含以下核心功能：

### 核心功能

- **图形化配置界面**：基于 Tauri 2 + Vue 3 的跨平台桌面应用，无需命令行操作。
- **三字段快速配置**：只需填写 API Key、API 地址、模型名称，即可开始使用。
- **连接测试**：发送一次 \`/models\` 请求验证配置是否正确，不修改任何系统配置。
- **一键执行配置**：自动完成 Node.js 检测、Claude Code CLI 安装、环境变量写入等全部流程。
- **自动备份**：每次重新配置前自动备份原 Claude Code 配置和 shell profile。
- **恢复备份**：一键还原最近一次备份。
- **一键安装 Node.js**：未安装 Node.js 时，可选择从官方 / 淘宝 / 腾讯镜像一键安装。
- **npm 镜像与代理支持**：内置淘宝镜像选项，方便国内网络环境。
- **跨平台支持**：支持 macOS Apple Silicon、macOS Intel 和 Windows x64。

### 安装说明

#### macOS

- Apple Silicon 用户下载 \`AIEnvKit_${TAG}_macOS_Apple_Silicon.zip\`，解压后将 \`AIEnvKit.app\` 拖入「应用程序」文件夹。
- Intel 用户下载 \`AIEnvKit_${TAG}_macOS_Intel.zip\`，解压后将 \`AIEnvKit.app\` 拖入「应用程序」文件夹。
- 首次打开若提示安全警告，请前往「系统设置 → 隐私与安全性」点击「仍要打开」。

#### Windows

- 下载 \`AIEnvKit_${TAG}_Windows_x64_Setup.exe\`，双击运行安装向导。
- 首次运行若提示「Windows 已保护你的电脑」，请点击「更多信息」→「仍要运行」。

### 快速配置示例（DeepSeek）

- **API 地址**：\`https://api.deepseek.com\`
- **模型名称**：\`deepseek-v4-pro\`
- **API Key**：填写你自己的 Key

没有梯子（VPN/代理）的用户请不要填写「代理」字段，保持为空即可。

### 校验和

EOF
else
  cat > "$NOTES_FILE" <<EOF
## 更新内容

### 新增功能
-

### 改进优化
-

### Bug 修复
-

### 验证测试
-

## 安装说明

#### macOS

- Apple Silicon 用户下载 \`AIEnvKit_${TAG}_macOS_Apple_Silicon.zip\`，解压后将 \`AIEnvKit.app\` 拖入「应用程序」文件夹。
- Intel 用户下载 \`AIEnvKit_${TAG}_macOS_Intel.zip\`，解压后将 \`AIEnvKit.app\` 拖入「应用程序」文件夹。

#### Windows

- 下载 \`AIEnvKit_${TAG}_Windows_x64_Setup.exe\`，双击运行安装向导。

### 校验和

EOF
fi

# 计算并追加校验和
cd "$RELEASE_DIR"
sha256sum "${ASSET_PREFIX}"_* >> "$NOTES_FILE"
cd "$PROJECT_ROOT"

echo ""
echo "Release Notes 已生成：$NOTES_FILE"
echo ""

# 创建 GitHub Release
if gh release view "$TAG" >/dev/null 2>&1; then
  echo "警告：Release $TAG 已存在，跳过创建，仅上传资源..."
  gh release upload "$TAG" "$ASSET_ARM" "$ASSET_INTEL" "$ASSET_WIN" --clobber
else
  echo "[发布] 创建 GitHub Release $TAG ..."
  gh release create "$TAG" \
    --title "AIEnvKit ${TAG}" \
    --notes-file "$NOTES_FILE" \
    "$ASSET_ARM" \
    "$ASSET_INTEL" \
    "$ASSET_WIN"
fi

echo ""
echo "✅ Release $TAG 发布完成！"
echo "访问地址：https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/releases/tag/$TAG"
