#!/usr/bin/env bash
set -e

BASE_URL="$1"
API_KEY="$2"
MODEL_NAME="$3"

if [ -z "$BASE_URL" ] || [ -z "$API_KEY" ]; then
  echo "❌ API 地址和 API Key 不能为空"
  exit 1
fi

# 去除末尾斜杠
BASE_URL="${BASE_URL%/}"

echo "🔌 正在测试连接: $BASE_URL"

# 优先尝试 OpenAI 兼容的 /models 接口
HTTP_STATUS=$(curl -s -o /tmp/aienvkit_test.json -w "%{http_code}" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  --max-time 15 \
  "${BASE_URL}/models" 2>/dev/null || true)

if [ "$HTTP_STATUS" = "200" ]; then
  MODELS_COUNT=$(grep -o '"id"' /tmp/aienvkit_test.json 2>/dev/null | wc -l | tr -d ' ')
  echo "✅ 连接成功 (HTTP 200)，可用模型数量约: $MODELS_COUNT"
  echo "💡 当前配置模型: $MODEL_NAME"
  exit 0
fi

# 如果 /models 失败，尝试一次 chat completions 简单请求
HTTP_STATUS=$(curl -s -o /tmp/aienvkit_chat.json -w "%{http_code}" \
  -X POST \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"$MODEL_NAME\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":5}" \
  --max-time 15 \
  "${BASE_URL}/chat/completions" 2>/dev/null || true)

if [ "$HTTP_STATUS" = "200" ]; then
  echo "✅ 连接成功 (HTTP 200)，/chat/completions 可正常访问"
  exit 0
fi

if [ -z "$HTTP_STATUS" ] || [ "$HTTP_STATUS" = "000" ]; then
  echo "❌ 无法连接到 $BASE_URL，请检查网络或代理地址"
  exit 1
fi

echo "❌ 连接测试失败 (HTTP $HTTP_STATUS)"
if [ -f /tmp/aienvkit_chat.json ]; then
  echo "响应内容:"
  cat /tmp/aienvkit_chat.json
fi
exit 1
