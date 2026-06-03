#!/bin/bash
# 构建 MarkdownReader.app
# 用法: ./build-app.sh [-r|--release] [-s|--sign [IDENTITY]] [-d|--distribution]
#   --sign       签名 .app（非分发模式自动使用 ad-hoc 签名，可分享给他人）
#   --sign ID    分发模式下使用指定签名身份（如 "Developer ID Application: xxx"）
#   -d           分发模式：启用 hardened runtime + timestamp（需 Developer ID 证书 + 公证）

set -euo pipefail

APP_NAME="MarkdownReader"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="debug"
SIGN_IDENTITY=""
DISTRIBUTION=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--release) CONFIG="release" ;;
        -d|--distribution) DISTRIBUTION=true ;;
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

echo "🔨 构建 ${APP_NAME} (${CONFIG})..."
swift build -c "$CONFIG"

BUILD_DIR="${PROJECT_DIR}/.build/arm64-apple-macosx/${CONFIG}"
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

# 创建 Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh-Hans</string>
    <key>CFBundleExecutable</key>
    <string>MarkdownReader</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.markdownreader.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Markdown Reader</string>
    <key>CFBundleDisplayName</key>
    <string>Markdown Reader</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Markdown Document</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>net.daringfireball.markdown</string>
            </array>
        </dict>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Plain Text Markdown</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.plain-text</string>
            </array>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>md</string>
                <string>markdown</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLIST

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
