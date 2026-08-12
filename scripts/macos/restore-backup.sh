#!/usr/bin/env bash
set -e

BACKUP_DIR="$HOME/.aienvkit/backups"

if [ ! -d "$BACKUP_DIR" ]; then
  echo "❌ 没有找到备份目录"
  exit 1
fi

# 找到最新的 settings.json 备份
LATEST_SETTINGS=$(find "$BACKUP_DIR" -name 'settings_*.json' -type f -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -n 1)
LATEST_SHELL=$(find "$BACKUP_DIR" -name 'shell_profile_*.bak' -type f -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -n 1)

RESTORED=false

if [ -n "$LATEST_SETTINGS" ]; then
  mkdir -p "$HOME/.claude"
  cp "$LATEST_SETTINGS" "$HOME/.claude/settings.json"
  echo "✔ 已恢复 Claude Code 配置: $LATEST_SETTINGS"
  RESTORED=true
fi

if [ -n "$LATEST_SHELL" ]; then
  SHELL_PROFILE=""
  if [ -n "$SHELL" ]; then
    CURRENT_SHELL=$(basename "$SHELL")
    case "$CURRENT_SHELL" in
      zsh) SHELL_PROFILE="$HOME/.zshrc" ;;
      bash) SHELL_PROFILE="$HOME/.bash_profile" ;;
      *) SHELL_PROFILE="$HOME/.profile" ;;
    esac
  fi

  if [ -n "$SHELL_PROFILE" ]; then
    cp "$LATEST_SHELL" "$SHELL_PROFILE"
    echo "✔ 已恢复 shell 配置: $LATEST_SHELL -> $SHELL_PROFILE"
    RESTORED=true
  fi
fi

if [ "$RESTORED" = false ]; then
  echo "❌ 没有找到可恢复的备份"
  exit 1
fi

echo "✅ 配置已恢复到最近一次的备份状态"
echo "💡 请重新打开终端使环境变量生效"
