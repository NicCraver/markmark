#!/bin/bash
# 构建 MarkdownReader.app
# 用法: ./build-app.sh [-r|--release] [-s|--sign [IDENTITY]] [-d|--distribution]
#   --sign       签名 .app（非分发模式自动使用 ad-hoc 签名，可分享给他人）
#   --sign ID    分发模式下使用指定签名身份（如 "Developer ID Application: xxx"）
#   -d           分发模式：启用 hardened runtime + timestamp（需 Developer ID 证书 + 公证）

set -euo pipefail

APP_NAME="MarkdownReader"

# 动态读取版本号（优先级：git tag > CHANGELOG.md > 兜底）
if VERSION=$(git describe --tags --match 'v*' --abbrev=0 2>/dev/null | sed 's/^v//'); then
    echo "📌 版本号来自 git tag: $VERSION"
elif VERSION=$(grep -m1 -o '\[[0-9][0-9.]*\]' CHANGELOG.md 2>/dev/null | tr -d '[]'); then
    echo "📌 版本号来自 CHANGELOG.md: $VERSION"
else
    VERSION="0.0.0-dev"
    echo "⚠️  未找到 git tag 或 CHANGELOG.md，使用兜底版本: $VERSION"
fi
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="debug"
SIGN_IDENTITY=""
DISTRIBUTION=false
ARCH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--release) CONFIG="release" ;;
        -d|--distribution) DISTRIBUTION=true ;;
        -a|--arch)
            if [[ $# -gt 1 && ! "$2" =~ ^- ]]; then
                ARCH="$2"
                shift
            else
                ARCH="$(uname -m)"
            fi
            ;;
        -s|--sign)
            if [[ $# -gt 1 && ! "$2" =~ ^- ]]; then
                SIGN_IDENTITY="$2"
                shift
            else
                SIGN_IDENTITY="auto"
            fi
            ;;
        *) echo "未知选项: $1"; exit 1 ;;
    esac
    shift
done

# 默认使用本机架构
if [[ -z "$ARCH" ]]; then
    ARCH="$(uname -m)"
fi

echo "🔨 构建 ${APP_NAME} (${CONFIG}, ${ARCH})..."

# 交叉编译时指定目标架构
if [[ "$ARCH" == "x86_64" ]]; then
    swift build -c "$CONFIG" --arch x86_64
elif [[ "$ARCH" == "arm64" ]]; then
    swift build -c "$CONFIG" --arch arm64
else
    swift build -c "$CONFIG"
fi

BUILD_DIR="${PROJECT_DIR}/.build/${ARCH}-apple-macosx/${CONFIG}"
APP_BUNDLE="${PROJECT_DIR}/${APP_NAME}.app"

# 清理旧的
rm -rf "$APP_BUNDLE"

# 创建 .app 目录结构
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 复制可执行文件
cp "${BUILD_DIR}/${APP_NAME}" "$APP_BUNDLE/Contents/MacOS/"

# 复制资源 bundle（Swift Package Manager 编译的资源）
if [ -d "${BUILD_DIR}/${APP_NAME}_MarkdownReader.bundle" ]; then
    cp -R "${BUILD_DIR}/${APP_NAME}_MarkdownReader.bundle/" "$APP_BUNDLE/Contents/Resources/"
fi

# 使用 actool 编译 Assets.xcassets（确保图标正确显示）
# macOS 系统需要编译后的 Assets.car 来识别应用图标，SPM bundle 中的原始 PNG 不够
ASSETS_SRC="${PROJECT_DIR}/Sources/${APP_NAME}/Assets.xcassets"
if [ -d "$ASSETS_SRC" ]; then
    echo "📦 编译 Assets.xcassets..."
    actool \
        --compile "$APP_BUNDLE/Contents/Resources" \
        --platform macosx \
        --minimum-deployment-target 15.0 \
        --app-icon AppIcon \
        --output-format human-readable-text \
        --output-partial-info-plist /tmp/markdownreader_partial.plist \
        "$ASSETS_SRC" 2>/dev/null || echo "⚠️  actool 编译失败，图标可能不显示（不影响功能）"
fi

# 从模板生成 Info.plist（与 CI 流程共用同一模板）
PLIST_TEMPLATE="${PROJECT_DIR}/scripts/Info.plist"
if [ -f "$PLIST_TEMPLATE" ]; then
    sed "s/__VERSION__/$VERSION/g" "$PLIST_TEMPLATE" > "$APP_BUNDLE/Contents/Info.plist"
    echo "📝 Info.plist 从模板生成 (版本: $VERSION)"
else
    echo "❌ 未找到 Info.plist 模板: $PLIST_TEMPLATE"
    exit 1
fi

# 创建 PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# 签名
if [[ -n "$SIGN_IDENTITY" ]]; then
    if $DISTRIBUTION; then
        # 分发模式：需要真实的 Developer ID 证书
        if [[ "$SIGN_IDENTITY" == "auto" ]]; then
            # 优先查找 Developer ID Application 证书
            SIGN_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed -n 's/.*"\(.*\)"/\1/p')
            if [[ -z "$SIGN_IDENTITY" ]]; then
                echo "❌ 分发模式需要 Developer ID Application 证书，未找到"
                exit 1
            fi
            echo "🔑 自动检测到签名身份: $SIGN_IDENTITY"
        fi
    else
        # 开发/分享模式：使用 ad-hoc 签名
        # Apple Development 证书在其他 Mac 上不受信任，macOS 会硬拒绝启动 (Code=111)
        # Ad-hoc 签名 (-) 让其他 Mac 显示标准 Gatekeeper 对话框，可右键打开绕过
        SIGN_IDENTITY="-"
        echo "🔑 开发/分享模式: 使用 ad-hoc 签名"
    fi

    echo "🔏 签名 ${APP_NAME}.app..."

    if $DISTRIBUTION; then
        # 分发签名：使用 Developer ID 证书 + hardened runtime + timestamp
        # 需要配合 notarytool 公证后才能在其他 Mac 上正常启动
        codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
        echo "   模式: 分发 (hardened runtime + timestamp)"
    else
        # 开发/分享签名：使用 ad-hoc 签名
        codesign --force --deep --sign - "$APP_BUNDLE"
        echo "   模式: 开发/分享 (ad-hoc 签名)"
    fi

    echo "🔍 验证签名..."
    codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE" 2>&1

    echo ""
    echo "✅ ${APP_NAME}.app 已签名: ${APP_BUNDLE}"
    if $DISTRIBUTION; then
        echo "   签名身份: ${SIGN_IDENTITY}"
    else
        echo "   签名身份: ad-hoc (-)"
    fi
    if ! $DISTRIBUTION; then
        echo ""
        echo "   📋 分享给他人时，对方需要："
        echo "      右键点击 app → 打开 → 确认打开"
        echo "      或终端执行: xattr -cr /path/to/${APP_NAME}.app"
    fi
else
    echo ""
    echo "✅ ${APP_NAME}.app 已生成: ${APP_BUNDLE}"
    echo "   ⚠️  未签名 — 分发时接收方需右键打开绕过 Gatekeeper"
fi

echo "   运行: open ${APP_BUNDLE}"
