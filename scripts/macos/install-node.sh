#!/usr/bin/env bash
set -e

MIRROR="${1:-official}"
PROXY="${2:-}"

INSTALL_DIR="$HOME/.aienvkit/node"
NODE_VERSION="20.16.0"
ARCH=$(uname -m)

if [ "$ARCH" = "arm64" ]; then
    NODE_ARCH="darwin-arm64"
elif [ "$ARCH" = "x86_64" ]; then
    NODE_ARCH="darwin-x64"
else
    echo "❌ 不支持的架构: $ARCH"
    exit 1
fi

TARBALL="node-v${NODE_VERSION}-${NODE_ARCH}.tar.gz"

if [ "$MIRROR" = "npmmirror" ]; then
    DOWNLOAD_URL="https://cdn.npmmirror.com/binaries/node/v${NODE_VERSION}/${TARBALL}"
else
    DOWNLOAD_URL="https://nodejs.org/dist/v${NODE_VERSION}/${TARBALL}"
fi

echo "📦 正在下载 Node.js v${NODE_VERSION} (${NODE_ARCH})..."
echo "   来源: ${MIRROR} (${DOWNLOAD_URL})"

mkdir -p "$INSTALL_DIR"

curl_opts="-fsSL"
if [ -n "$PROXY" ]; then
    curl_opts="$curl_opts -x $PROXY"
fi

if ! curl $curl_opts "$DOWNLOAD_URL" -o "/tmp/${TARBALL}"; then
    echo "❌ 下载失败，请检查网络连接或代理设置"
    exit 1
fi

echo "📂 正在解压到 ${INSTALL_DIR}..."
rm -rf "$INSTALL_DIR"/*
tar -xzf "/tmp/${TARBALL}" -C "$INSTALL_DIR" --strip-components=1
rm -f "/tmp/${TARBALL}"

NODE_BIN="$INSTALL_DIR/bin/node"
NPM_BIN="$INSTALL_DIR/bin/npm"

if [ ! -f "$NODE_BIN" ]; then
    echo "❌ Node.js 安装失败，可执行文件不存在"
    exit 1
fi

echo "✔ Node.js 已安装: $(${NODE_BIN} --version)"
echo "✔ npm 已安装: $(${NPM_BIN} --version)"
echo "✅ 安装完成，路径: ${INSTALL_DIR}"
