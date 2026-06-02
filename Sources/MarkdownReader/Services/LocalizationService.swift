import SwiftUI

// MARK: - 本地化服务

/// 简易本地化服务，参照 buddy-macos 的 i18n 字典方案
/// 使用扁平 key-value 结构，支持插值 {n}
enum L10n {

    // MARK: - Key 定义

    /// 所有本地化键，与 buddy-macos 的 settings key 结构对齐
    enum Key: String, CaseIterable, Sendable {
        // 应用名称
        case appName

        // 设置 - 菜单/导航
        case settingsMenuLabel
        case settingsBackToApp

        // 设置 - 标签页
        case settingsTabGeneral
        case settingsTabAppearance

        // 设置 - 通用
        case settingsGeneralLanguageTitle
        case settingsGeneralLanguageDesc
        case settingsGeneralDisplayTitle
        case settingsGeneralDisplayMode

        // 设置 - 启动
        case settingsGeneralStartupTitle
        case settingsGeneralReopenLastLocation

        // 设置 - 文件树
        case settingsGeneralFileTreeTitle
        case settingsGeneralShowHiddenFiles
        case settingsGeneralShowNonMarkdownFiles

        // 设置 - 外观 - 主题模式
        case settingsAppearanceThemeTitle
        case settingsAppearanceThemeDesc
        case settingsAppearanceModeLight
        case settingsAppearanceModeLightDesc
        case settingsAppearanceModeDark
        case settingsAppearanceModeDarkDesc
        case settingsAppearanceModeSystem
        case settingsAppearanceModeSystemDesc

        // 设置 - 外观 - 配色方案
        case settingsAppearanceSchemeTitle
        case settingsAppearanceSchemeDesc

        // 设置 - 外观 - 自定义颜色
        case settingsAppearanceCustomTitle
        case settingsAppearanceCustomDesc
        case settingsAppearanceCustomSurface
        case settingsAppearanceCustomInk
        case settingsAppearanceCustomAccent
        case settingsAppearanceCustomSuccess
        case settingsAppearanceCustomDanger

        // 设置 - 外观 - 对比度
        case settingsAppearanceContrastTitle
        case settingsAppearanceContrastDesc
        case settingsAppearanceContrastLow
        case settingsAppearanceContrastHigh

        // 设置 - 外观 - 字体排版（保留）
        case settingsAppearanceTypographyTitle
        case settingsAppearanceSourceFontSize
        case settingsAppearanceContentPadding

        // 语言选项
        case languageAuto
        case languageZhCN
        case languageZhTW
        case languageEn

        // 显示模式
        case displayModeRendered
        case displayModeRaw

        // 通用操作
        case open
        case reset

        // 标题栏
        case titleBarToggleSidebar
        case titleBarDisplayMode
        case titleBarOpen
        case titleBarToggleOutline

        // 大纲
        case outlineTitle
        case outlineEmpty

        // 侧边栏
        case loading
        case emptyDirectoryMessage
        case sidebarSettings
        case sidebarSettingsButton

        // 欢迎页
        case welcomeOpenFolder
        case welcomePressCmdO

        // Git 状态
        case gitChangesCount
        case gitNoChanges
        case gitCommitMessage
        case gitPushing
        case gitCommitAndPush
        case gitStaged
        case gitModified
        case gitUntracked
    }

    // MARK: - 翻译字典

    private static let en: [Key: String] = [
        .appName: "Markdown Reader",
        .settingsMenuLabel: "Settings\u{2026}",
        .settingsBackToApp: "Back to App",
        .settingsTabGeneral: "General",
        .settingsTabAppearance: "Appearance",
        .settingsGeneralLanguageTitle: "Language",
        .settingsGeneralLanguageDesc: "Choose the interface language. \"Auto\" follows your system.",
        .settingsGeneralDisplayTitle: "Display",
        .settingsGeneralDisplayMode: "Default display mode",
        .settingsGeneralStartupTitle: "Startup",
        .settingsGeneralReopenLastLocation: "Reopen last location on launch",
        .settingsGeneralFileTreeTitle: "File Tree",
        .settingsGeneralShowHiddenFiles: "Show hidden files",
        .settingsGeneralShowNonMarkdownFiles: "Show non-Markdown files",
        .settingsAppearanceThemeTitle: "Theme",
        .settingsAppearanceThemeDesc: "Choose the application appearance mode.",
        .settingsAppearanceModeLight: "Light",
        .settingsAppearanceModeLightDesc: "Always use light appearance",
        .settingsAppearanceModeDark: "Dark",
        .settingsAppearanceModeDarkDesc: "Always use dark appearance",
        .settingsAppearanceModeSystem: "System",
        .settingsAppearanceModeSystemDesc: "Follow system setting",
        .settingsAppearanceSchemeTitle: "Color Scheme",
        .settingsAppearanceSchemeDesc: "Choose a preset color scheme for the current mode.",
        .settingsAppearanceCustomTitle: "Custom Colors",
        .settingsAppearanceCustomDesc: "Customize individual color tokens. Changes override the current scheme.",
        .settingsAppearanceCustomSurface: "Surface",
        .settingsAppearanceCustomInk: "Ink",
        .settingsAppearanceCustomAccent: "Accent",
        .settingsAppearanceCustomSuccess: "Success",
        .settingsAppearanceCustomDanger: "Danger",
        .settingsAppearanceContrastTitle: "Contrast",
        .settingsAppearanceContrastDesc: "Adjust the contrast between background and foreground layers.",
        .settingsAppearanceContrastLow: "Low",
        .settingsAppearanceContrastHigh: "High",
        .settingsAppearanceTypographyTitle: "Typography",
        .settingsAppearanceSourceFontSize: "Source font size",
        .settingsAppearanceContentPadding: "Content padding",
        .languageAuto: "Auto / Auto Detect",
        .languageZhCN: "Simplified Chinese",
        .languageZhTW: "Traditional Chinese",
        .languageEn: "English",
        .displayModeRendered: "Rendered",
        .displayModeRaw: "Raw",
        .open: "Open",
        .reset: "Reset",
        .titleBarToggleSidebar: "Toggle Sidebar (⌘\\)",
        .titleBarDisplayMode: "Display Mode",
        .titleBarOpen: "Open (⌘O)",
        .titleBarToggleOutline: "Toggle Outline",
        .outlineTitle: "Outline",
        .outlineEmpty: "No headings",
        .loading: "Loading...",
        .emptyDirectoryMessage: "No Markdown files in this directory",
        .sidebarSettings: "Settings (⌘,)",
        .sidebarSettingsButton: "Settings",
        .welcomeOpenFolder: "Open a folder to get started",
        .welcomePressCmdO: "Press Cmd+O or click Open in toolbar",
        .gitChangesCount: "{n} changes",
        .gitNoChanges: "No changes",
        .gitCommitMessage: "Commit message",
        .gitPushing: "Pushing...",
        .gitCommitAndPush: "Commit & Push",
        .gitStaged: "Staged",
        .gitModified: "Modified",
        .gitUntracked: "Untracked",
    ]

    private static let zhCN: [Key: String] = [
        .appName: "Markdown Reader",
        .settingsMenuLabel: "设置\u{2026}",
        .settingsBackToApp: "返回应用",
        .settingsTabGeneral: "通用",
        .settingsTabAppearance: "外观",
        .settingsGeneralLanguageTitle: "界面语言",
        .settingsGeneralLanguageDesc: "选择应用界面的语言。「自动检测」会跟随系统。",
        .settingsGeneralDisplayTitle: "显示",
        .settingsGeneralDisplayMode: "默认显示模式",
        .settingsGeneralStartupTitle: "启动",
        .settingsGeneralReopenLastLocation: "启动时重新打开上次位置",
        .settingsGeneralFileTreeTitle: "文件树",
        .settingsGeneralShowHiddenFiles: "显示隐藏文件",
        .settingsGeneralShowNonMarkdownFiles: "显示非 Markdown 文件",
        .settingsAppearanceThemeTitle: "主题",
        .settingsAppearanceThemeDesc: "选择应用的外观模式。",
        .settingsAppearanceModeLight: "浅色",
        .settingsAppearanceModeLightDesc: "始终使用浅色外观",
        .settingsAppearanceModeDark: "深色",
        .settingsAppearanceModeDarkDesc: "始终使用深色外观",
        .settingsAppearanceModeSystem: "跟随系统",
        .settingsAppearanceModeSystemDesc: "跟随系统设置",
        .settingsAppearanceSchemeTitle: "配色方案",
        .settingsAppearanceSchemeDesc: "为当前模式选择预设配色方案。",
        .settingsAppearanceCustomTitle: "自定义颜色",
        .settingsAppearanceCustomDesc: "自定义各颜色令牌。修改将覆盖当前方案的对应颜色。",
        .settingsAppearanceCustomSurface: "背景色",
        .settingsAppearanceCustomInk: "文字色",
        .settingsAppearanceCustomAccent: "强调色",
        .settingsAppearanceCustomSuccess: "成功色",
        .settingsAppearanceCustomDanger: "危险色",
        .settingsAppearanceContrastTitle: "对比度",
        .settingsAppearanceContrastDesc: "调整背景与前景层之间的对比度。",
        .settingsAppearanceContrastLow: "低",
        .settingsAppearanceContrastHigh: "高",
        .settingsAppearanceTypographyTitle: "字体与排版",
        .settingsAppearanceSourceFontSize: "源码字号",
        .settingsAppearanceContentPadding: "内容边距",
        .languageAuto: "自动检测",
        .languageZhCN: "简体中文",
        .languageZhTW: "繁體中文",
        .languageEn: "English",
        .displayModeRendered: "渲染",
        .displayModeRaw: "原始",
        .open: "打开",
        .reset: "重置",
        .titleBarToggleSidebar: "切换侧边栏 (⌘\\)",
        .titleBarDisplayMode: "显示模式",
        .titleBarOpen: "打开 (⌘O)",
        .titleBarToggleOutline: "切换大纲",
        .outlineTitle: "大纲",
        .outlineEmpty: "暂无标题",
        .loading: "加载中...",
        .emptyDirectoryMessage: "该目录下无 Markdown 文件",
        .sidebarSettings: "设置 (⌘,)",
        .sidebarSettingsButton: "设置",
        .welcomeOpenFolder: "打开文件夹开始阅读",
        .welcomePressCmdO: "按 Cmd+O 或点击工具栏中的打开按钮",
        .gitChangesCount: "{n} 个变更",
        .gitNoChanges: "无变更",
        .gitCommitMessage: "提交消息",
        .gitPushing: "推送中",
        .gitCommitAndPush: "提交并推送",
        .gitStaged: "已暂存",
        .gitModified: "已修改",
        .gitUntracked: "未跟踪",
    ]

    private static let zhTW: [Key: String] = [
        .appName: "Markdown Reader",
        .settingsMenuLabel: "設定\u{2026}",
        .settingsBackToApp: "返回應用",
        .settingsTabGeneral: "一般",
        .settingsTabAppearance: "外觀",
        .settingsGeneralLanguageTitle: "介面語言",
        .settingsGeneralLanguageDesc: "選擇應用介面的語言。「自動偵測」會跟隨系統。",
        .settingsGeneralDisplayTitle: "顯示",
        .settingsGeneralDisplayMode: "預設顯示模式",
        .settingsGeneralStartupTitle: "啟動",
        .settingsGeneralReopenLastLocation: "啟動時重新開啟上次位置",
        .settingsGeneralFileTreeTitle: "檔案樹",
        .settingsGeneralShowHiddenFiles: "顯示隱藏檔案",
        .settingsGeneralShowNonMarkdownFiles: "顯示非 Markdown 檔案",
        .settingsAppearanceThemeTitle: "主題",
        .settingsAppearanceThemeDesc: "選擇應用的外觀模式。",
        .settingsAppearanceModeLight: "淺色",
        .settingsAppearanceModeLightDesc: "始終使用淺色外觀",
        .settingsAppearanceModeDark: "深色",
        .settingsAppearanceModeDarkDesc: "始終使用深色外觀",
        .settingsAppearanceModeSystem: "跟隨系統",
        .settingsAppearanceModeSystemDesc: "跟隨系統設定",
        .settingsAppearanceSchemeTitle: "配色方案",
        .settingsAppearanceSchemeDesc: "為目前模式選擇預設配色方案。",
        .settingsAppearanceCustomTitle: "自訂顏色",
        .settingsAppearanceCustomDesc: "自訂各顏色令牌。修改將覆蓋目前方案的對應顏色。",
        .settingsAppearanceCustomSurface: "背景色",
        .settingsAppearanceCustomInk: "文字色",
        .settingsAppearanceCustomAccent: "強調色",
        .settingsAppearanceCustomSuccess: "成功色",
        .settingsAppearanceCustomDanger: "危險色",
        .settingsAppearanceContrastTitle: "對比度",
        .settingsAppearanceContrastDesc: "調整背景與前景層之間的對比度。",
        .settingsAppearanceContrastLow: "低",
        .settingsAppearanceContrastHigh: "高",
        .settingsAppearanceTypographyTitle: "字體與排版",
        .settingsAppearanceSourceFontSize: "原始碼字號",
        .settingsAppearanceContentPadding: "內容邊距",
        .languageAuto: "自動偵測",
        .languageZhCN: "简体中文",
        .languageZhTW: "繁體中文",
        .languageEn: "English",
        .displayModeRendered: "渲染",
        .displayModeRaw: "原始",
        .open: "開啟",
        .reset: "重設",
        .titleBarToggleSidebar: "切換側邊欄 (⌘\\)",
        .titleBarDisplayMode: "顯示模式",
        .titleBarOpen: "開啟 (⌘O)",
        .titleBarToggleOutline: "切換大綱",
        .outlineTitle: "大綱",
        .outlineEmpty: "暫無標題",
        .loading: "載入中...",
        .emptyDirectoryMessage: "此目錄下無 Markdown 檔案",
        .sidebarSettings: "設定 (⌘,)",
        .sidebarSettingsButton: "設定",
        .welcomeOpenFolder: "開啟資料夾開始閱讀",
        .welcomePressCmdO: "按 Cmd+O 或點擊工具列中的開啟按鈕",
        .gitChangesCount: "{n} 個變更",
        .gitNoChanges: "無變更",
        .gitCommitMessage: "提交訊息",
        .gitPushing: "推送中",
        .gitCommitAndPush: "提交並推送",
        .gitStaged: "已暫存",
        .gitModified: "已修改",
        .gitUntracked: "未追蹤",
    ]

    // MARK: - 查找

    private static func dictionary(for language: Language) -> [Key: String] {
        switch language {
        case .zhCN: zhCN
        case .zhTW: zhTW
        case .en: en
        }
    }

    static func tr(_ key: Key, language: Language) -> String {
        dictionary(for: language)[key] ?? key.rawValue
    }

    static func tr(_ key: Key, language: Language, args: [String: String]) -> String {
        var result = tr(key, language: language)
        for (k, v) in args {
            result = result.replacingOccurrences(of: "{\(k)}", with: v)
        }
        return result
    }
}

// MARK: - SwiftUI Environment 支持

private struct LanguageEnvironmentKey: EnvironmentKey {
    static let defaultValue: Language = .en
}

extension EnvironmentValues {
    var language: Language {
        get { self[LanguageEnvironmentKey.self] }
        set { self[LanguageEnvironmentKey.self] = newValue }
    }
}

extension View {
    func withLanguage(_ language: Language) -> some View {
        environment(\.language, language)
    }
}
