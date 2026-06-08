#!/bin/bash
# 一键构建 + 打包 MarkdownReader.dmg
# 用法: ./package.sh [--arch arm64|x86_64] [-d|--distribution]
#   不指定 --arch 时同时构建两个架构
#   --distribution  启用分发模式签名（需 Developer ID 证书 + 公证）
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="MarkdownReader"
DISTRIBUTION=false

build_dmg() {
    local ARCH="$1"
    local DMG_NAME="MarkdownReader-${ARCH}.dmg"

    echo ""
    echo "=========================================="
    echo "  构建 ${ARCH} 版本"
    echo "=========================================="

    # 1. 构建并签名
    local BUILD_ARGS=(--release --sign --arch "$ARCH")
    if $DISTRIBUTION; then
        BUILD_ARGS+=(--distribution)
    fi
    ./build-app.sh "${BUILD_ARGS[@]}"

    # 2. 提取 App 图标作为 DMG 卷图标
    VOLICON="${APP_NAME}.app/Contents/Resources/AppIcon.icns"
    if [ ! -f "$VOLICON" ]; then
        echo "⚠️  未找到 AppIcon.icns，DMG 将使用默认图标"
        VOLICON=""
    fi

    # 3. 打包 DMG
    # 删除已存在的旧 DMG（create-dmg/hdiutil 不会自动覆盖）
    rm -f "$DMG_NAME"

    # 优先使用 create-dmg（支持设置卷图标、窗口布局等）
    if command -v create-dmg &>/dev/null; then
        echo "📦 使用 create-dmg 打包 DMG..."
        CREATE_DMG_ARGS=(
            --volname "Markdown Reader"
            --window-pos 200 120
            --window-size 600 400
            --icon-size 100
            --icon "${APP_NAME}.app" 175 190
            --app-drop-link 425 190
        )
        if [ -n "$VOLICON" ]; then
            CREATE_DMG_ARGS+=(--volicon "${VOLICON}")
        fi
        create-dmg "${CREATE_DMG_ARGS[@]}" "$DMG_NAME" "${APP_NAME}.app"
    else
        echo "📦 create-dmg 未安装，使用 hdiutil 打包（DMG 将无自定义图标和布局）..."
        echo "   💡 提示：运行 brew install create-dmg 可获得更好的 DMG 打包效果"
        STAGING=$(mktemp -d)
        trap "rm -rf '$STAGING'" EXIT
        cp -R "${APP_NAME}.app" "$STAGING/"
        ln -s /Applications "$STAGING/Applications"
        hdiutil create -volname "Markdown Reader" -srcfolder "$STAGING" -ov -format UDZO "$DMG_NAME"
        rm -rf "$STAGING"
        trap - EXIT
    fi

    # 4. 移除 quarantine 属性（必须在 seticon 之前，否则会清除资源叉和 FinderInfo）
    xattr -cr "$DMG_NAME" 2>/dev/null || true

    # 5. 设置 DMG 文件本身的自定义图标（必须在 xattr -cr 之后）
    # create-dmg --volicon 只设置挂载卷的图标，不会设置 DMG 文件本身的图标
    if [ -n "$VOLICON" ] && [ -f "$DMG_NAME" ]; then
        SETICON_BIN="$(dirname "$0")/scripts/.seticon-bin"
        if [ ! -f "$SETICON_BIN" ]; then
            echo "🔧 编译 seticon 工具..."
            swiftc "$(dirname "$0")/scripts/seticon.swift" -o "$SETICON_BIN"
        fi
        echo "🎨 设置 DMG 文件自定义图标..."
        "$SETICON_BIN" "$VOLICON" "$DMG_NAME"
    fi

    # 6. 验证
    echo "🔍 验证构建结果..."
    file "${APP_NAME}.app/Contents/MacOS/${APP_NAME}"
    codesign --verify --deep --strict "${APP_NAME}.app" 2>&1 || true

    echo ""
    echo "✅ ${DMG_NAME} 已生成"
    if [ -n "$VOLICON" ]; then
        echo "🎨 DMG 卷图标 + 文件图标均已设置为 AppIcon.icns"
    fi
}

# 解析参数
TARGET_ARCH=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --arch)
            TARGET_ARCH="$2"
            shift
            ;;
        -d|--distribution) DISTRIBUTION=true ;;
        *) echo "未知选项: $1"; exit 1 ;;
    esac
    shift
done

if [[ -n "$TARGET_ARCH" ]]; then
    # 只构建指定架构
    build_dmg "$TARGET_ARCH"
else
    # 同时构建两个架构
    build_dmg "arm64"
    build_dmg "x86_64"
fi

echo ""
echo "🎉 所有 DMG 打包完成！"
ls -lh MarkdownReader-*.dmg 2>/dev/null
