#!/usr/bin/env bash
set -e

API_KEY="$1"
BASE_URL="$2"
MODEL_NAME="$3"

if [ -z "$API_KEY" ] || [ -z "$BASE_URL" ] || [ -z "$MODEL_NAME" ]; then
  echo "❌ API Key、API 地址和模型名称不能为空"
  exit 1
fi

echo "🚀 AIEnvKit 开始配置 Claude 环境..."

DEFAULT_SONNET_MODEL="${MODEL_NAME}"
DEFAULT_HAIKU_MODEL="${MODEL_NAME}"
SUBAGENT_MODEL="${MODEL_NAME}"

# 1. 检测 node 和 npm
if ! command -v node &>/dev/null || ! command -v npm &>/dev/null; then
  echo "❌ 未检测到 Node.js 或 npm，请先安装 Node.js"
  exit 1
fi

echo "✔ Node.js 已安装: $(node --version)"
echo "✔ npm 已安装: $(npm --version)"

# 2. 安装/升级 Claude Code CLI
echo "📦 正在安装/升级 Claude Code CLI..."
npm install -g @anthropic-ai/claude-code
echo "✔ Claude Code CLI 已就绪"

# 2. 确定当前使用的 shell profile
SHELL_PROFILE=""
if [ -n "$SHELL" ]; then
  CURRENT_SHELL=$(basename "$SHELL")
  case "$CURRENT_SHELL" in
    zsh)
      SHELL_PROFILE="$HOME/.zshrc"
      ;;
    bash)
      if [ -f "$HOME/.bash_profile" ]; then
        SHELL_PROFILE="$HOME/.bash_profile"
      else
        SHELL_PROFILE="$HOME/.bashrc"
      fi
      ;;
    *)
      SHELL_PROFILE="$HOME/.profile"
      ;;
  esac
else
  SHELL_PROFILE="$HOME/.zshrc"
fi

# 3. 创建配置备份
BACKUP_DIR="$HOME/.aienvkit/backups"
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/shell_profile_$(date +%Y%m%d_%H%M%S).bak"
if [ -f "$SHELL_PROFILE" ]; then
  cp "$SHELL_PROFILE" "$BACKUP_FILE"
  echo "✔ 已备份 shell 配置: $BACKUP_FILE"
fi

# 4. 在 shell profile 中写入环境变量
MARKER="# AIEnvKit auto-generated config"
END_MARKER="# AIEnvKit config end"

if [ -f "$SHELL_PROFILE" ] && grep -q "$MARKER" "$SHELL_PROFILE"; then
  awk -v start="$MARKER" -v end="$END_MARKER" '
    {copy=$0}
    $0 ~ start {skip=1; next}
    $0 ~ end {skip=0; next}
    !skip {print copy}
  ' "$SHELL_PROFILE" > "$SHELL_PROFILE.tmp"
  mv "$SHELL_PROFILE.tmp" "$SHELL_PROFILE"
fi

{
  echo ""
  echo "$MARKER"
  echo "export ANTHROPIC_AUTH_TOKEN=\"$API_KEY\""
  echo "export ANTHROPIC_BASE_URL=\"$BASE_URL\""
  echo "export ANTHROPIC_MODEL=\"$MODEL_NAME\""
  echo "export ANTHROPIC_DEFAULT_SONNET_MODEL=\"$DEFAULT_SONNET_MODEL\""
  echo "export ANTHROPIC_DEFAULT_HAIKU_MODEL=\"$DEFAULT_HAIKU_MODEL\""
  echo "export CLAUDE_CODE_SUBAGENT_MODEL=\"$SUBAGENT_MODEL\""
  echo "$END_MARKER"
} >> "$SHELL_PROFILE"

echo "✔ 环境变量已写入 $SHELL_PROFILE"

# 5. 写入 Claude Code settings.json
CLAUDE_SETTINGS_DIR="$HOME/.claude"
CLAUDE_SETTINGS="$CLAUDE_SETTINGS_DIR/settings.json"
mkdir -p "$CLAUDE_SETTINGS_DIR"

if [ -f "$CLAUDE_SETTINGS" ]; then
  cp "$CLAUDE_SETTINGS" "$BACKUP_DIR/settings_$(date +%Y%m%d_%H%M%S).json"
fi

cat > "$CLAUDE_SETTINGS" <<EOF
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "$API_KEY",
    "ANTHROPIC_BASE_URL": "$BASE_URL",
    "ANTHROPIC_MODEL": "$MODEL_NAME",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "$DEFAULT_SONNET_MODEL",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "$DEFAULT_HAIKU_MODEL",
    "CLAUDE_CODE_SUBAGENT_MODEL": "$SUBAGENT_MODEL"
  }
}
EOF

echo "✔ Claude Code 配置已写入 $CLAUDE_SETTINGS"

# 6. 导出到当前 shell
export ANTHROPIC_AUTH_TOKEN="$API_KEY"
export ANTHROPIC_BASE_URL="$BASE_URL"
export ANTHROPIC_MODEL="$MODEL_NAME"
export ANTHROPIC_DEFAULT_SONNET_MODEL="$DEFAULT_SONNET_MODEL"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="$DEFAULT_HAIKU_MODEL"
export CLAUDE_CODE_SUBAGENT_MODEL="$SUBAGENT_MODEL"

echo "✅ macOS 环境配置完成！"
echo "💡 提示：请重新打开终端，或运行 source $SHELL_PROFILE 使环境变量生效。"
