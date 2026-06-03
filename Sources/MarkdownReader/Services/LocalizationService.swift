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

        // 设置 - 默认打开程序
        case settingsGeneralDefaultOpenerTitle
        case settingsGeneralDefaultOpenerDesc
        case settingsGeneralSetAsDefault
        case settingsGeneralIsDefault
        case settingsGeneralSetDefaultFailed

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
        case save
        case reset
        case confirm

        // 菜单
        case menuNewFile

        // 未保存更改提醒
        case unsavedChangesTitle
        case unsavedChangesMessage
        case unsavedSave
        case unsavedDontSave
        case unsavedCancel

        // 文件外部删除提醒
        case fileDeletedTitle
        case fileDeletedMessage
        case fileDeletedSaveAs
        case fileDeletedDiscard

        // 打开最近
        case openRecent
        case openRecentEmpty
        case openRecentFiles
        case openRecentFolders
        case clearRecentItems

        // 标题栏
        case titleBarToggleSidebar
        case titleBarDisplayMode
        case titleBarOpen
        case titleBarNewFile
        case titleBarSave
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
        case selectFileHint

        // 右键菜单
        case contextMenuNewFile
        case contextMenuNewSubdirectory
        case contextMenuRename
        case contextMenuMoveTo
        case contextMenuDelete

        // 右键菜单 - 对话框
        case renameTitle
        case renameMessage
        case renameEmptyName
        case renameNameExists
        case deleteTitle
        case deleteMessage
        case deleteDirectoryMessage
        case moveSelectFolder
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
        .settingsGeneralDefaultOpenerTitle: "Default Markdown Opener",
        .settingsGeneralDefaultOpenerDesc: "Set Markdown Reader as the default application for opening .md files.",
        .settingsGeneralSetAsDefault: "Set as Default",
        .settingsGeneralIsDefault: "Markdown Reader is the default Markdown opener",
        .settingsGeneralSetDefaultFailed: "Failed to set as default opener. Please try again.",
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
        .save: "Save",
        .reset: "Reset",
        .confirm: "OK",
        .menuNewFile: "New File",
        .unsavedChangesTitle: "Unsaved Changes",
        .unsavedChangesMessage: "Your changes will be lost if you don't save them. Do you want to save before closing?",
        .unsavedSave: "Save",
        .unsavedDontSave: "Don't Save",
        .unsavedCancel: "Cancel",
        .fileDeletedTitle: "File Deleted",
        .fileDeletedMessage: "The file \"{name}\" was deleted externally. You have unsaved changes.",
        .fileDeletedSaveAs: "Save As\u{2026}",
        .fileDeletedDiscard: "Discard Changes",
        .openRecent: "Open Recent",
        .openRecentEmpty: "No Recent Items",
        .openRecentFiles: "Files",
        .openRecentFolders: "Folders",
        .clearRecentItems: "Clear Menu",
        .titleBarToggleSidebar: "Toggle Sidebar (⌘\\)",
        .titleBarDisplayMode: "Display Mode",
        .titleBarOpen: "Open (⌘O)",
        .titleBarNewFile: "New File",
        .titleBarSave: "Save (⌘S)",
        .titleBarToggleOutline: "Toggle Outline",
        .outlineTitle: "Outline",
        .outlineEmpty: "No headings",
        .loading: "Loading...",
        .emptyDirectoryMessage: "No Markdown files in this directory",
        .sidebarSettings: "Settings (⌘,)",
        .sidebarSettingsButton: "Settings",
        .welcomeOpenFolder: "Open a folder to get started",
        .welcomePressCmdO: "Press Cmd+O or click Open in toolbar",
        .selectFileHint: "Select a file to preview",
        .contextMenuNewFile: "New File",
        .contextMenuNewSubdirectory: "New Subdirectory",
        .contextMenuRename: "Rename",
        .contextMenuMoveTo: "Move to\u{2026}",
        .contextMenuDelete: "Move to Trash",
        .renameTitle: "Rename",
        .renameMessage: "Enter a new name for \"{name}\":",
        .renameEmptyName: "Name cannot be empty.",
        .renameNameExists: "An item with this name already exists.",
        .deleteTitle: "Move to Trash",
        .deleteMessage: "Are you sure you want to move \"{name}\" to the Trash?",
        .deleteDirectoryMessage: "Are you sure you want to move \"{name}\" and all its contents to the Trash?",
        .moveSelectFolder: "Select Destination Folder",
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
        .settingsGeneralDefaultOpenerTitle: "默认 Markdown 打开程序",
        .settingsGeneralDefaultOpenerDesc: "将 Markdown Reader 设置为 .md 文件的默认打开程序。",
        .settingsGeneralSetAsDefault: "设为默认",
        .settingsGeneralIsDefault: "Markdown Reader 已是默认 Markdown 打开程序",
        .settingsGeneralSetDefaultFailed: "设置默认打开程序失败，请重试。",
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
        .displayModeRaw: "编辑",
        .open: "打开",
        .save: "保存",
        .reset: "重置",
        .confirm: "确认",
        .menuNewFile: "新建文件",
        .unsavedChangesTitle: "未保存的更改",
        .unsavedChangesMessage: "如果不保存，您的更改将会丢失。关闭前是否保存？",
        .unsavedSave: "保存",
        .unsavedDontSave: "不保存",
        .unsavedCancel: "取消",
        .fileDeletedTitle: "文件已被删除",
        .fileDeletedMessage: "文件「{name}」已被外部删除，您有未保存的更改。",
        .fileDeletedSaveAs: "另存为\u{2026}",
        .fileDeletedDiscard: "放弃更改",
        .openRecent: "打开最近使用",
        .openRecentEmpty: "无最近打开的项",
        .openRecentFiles: "文件",
        .openRecentFolders: "文件夹",
        .clearRecentItems: "清除菜单",
        .titleBarToggleSidebar: "切换侧边栏 (⌘\\)",
        .titleBarDisplayMode: "显示模式",
        .titleBarOpen: "打开 (⌘O)",
        .titleBarNewFile: "新建文件",
        .titleBarSave: "保存 (⌘S)",
        .titleBarToggleOutline: "切换大纲",
        .outlineTitle: "大纲",
        .outlineEmpty: "暂无标题",
        .loading: "加载中...",
        .emptyDirectoryMessage: "该目录下无 Markdown 文件",
        .sidebarSettings: "设置 (⌘,)",
        .sidebarSettingsButton: "设置",
        .welcomeOpenFolder: "打开文件夹开始阅读",
        .welcomePressCmdO: "按 Cmd+O 或点击工具栏中的打开按钮",
        .selectFileHint: "选择文件以预览",
        .contextMenuNewFile: "新建文档",
        .contextMenuNewSubdirectory: "新建子目录",
        .contextMenuRename: "重命名",
        .contextMenuMoveTo: "移动到\u{2026}",
        .contextMenuDelete: "移到废纸篓",
        .renameTitle: "重命名",
        .renameMessage: "输入「{name}」的新名称：",
        .renameEmptyName: "名称不能为空。",
        .renameNameExists: "已存在同名项目。",
        .deleteTitle: "移到废纸篓",
        .deleteMessage: "确定要将「{name}」移到废纸篓吗？",
        .deleteDirectoryMessage: "确定要将「{name}」及其所有内容移到废纸篓吗？",
        .moveSelectFolder: "选择目标文件夹",
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
        .settingsGeneralDefaultOpenerTitle: "預設 Markdown 開啟程式",
        .settingsGeneralDefaultOpenerDesc: "將 Markdown Reader 設為 .md 檔案的預設開啟程式。",
        .settingsGeneralSetAsDefault: "設為預設",
        .settingsGeneralIsDefault: "Markdown Reader 已是預設 Markdown 開啟程式",
        .settingsGeneralSetDefaultFailed: "設定預設開啟程式失敗，請重試。",
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
        .displayModeRaw: "編輯",
        .open: "開啟",
        .save: "儲存",
        .reset: "重設",
        .confirm: "確認",
        .menuNewFile: "新增檔案",
        .unsavedChangesTitle: "未儲存的變更",
        .unsavedChangesMessage: "如果不儲存，您的變更將會遺失。關閉前是否儲存？",
        .unsavedSave: "儲存",
        .unsavedDontSave: "不儲存",
        .unsavedCancel: "取消",
        .fileDeletedTitle: "檔案已被刪除",
        .fileDeletedMessage: "檔案「{name}」已被外部刪除，您有未儲存的變更。",
        .fileDeletedSaveAs: "另存為\u{2026}",
        .fileDeletedDiscard: "放棄變更",
        .openRecent: "開啟最近使用",
        .openRecentEmpty: "無最近開啟的項目",
        .openRecentFiles: "檔案",
        .openRecentFolders: "資料夾",
        .clearRecentItems: "清除選單",
        .titleBarToggleSidebar: "切換側邊欄 (⌘\\)",
        .titleBarDisplayMode: "顯示模式",
        .titleBarOpen: "開啟 (⌘O)",
        .titleBarNewFile: "新增檔案",
        .titleBarSave: "儲存 (⌘S)",
        .titleBarToggleOutline: "切換大綱",
        .outlineTitle: "大綱",
        .outlineEmpty: "暫無標題",
        .loading: "載入中...",
        .emptyDirectoryMessage: "此目錄下無 Markdown 檔案",
        .sidebarSettings: "設定 (⌘,)",
        .sidebarSettingsButton: "設定",
        .welcomeOpenFolder: "開啟資料夾開始閱讀",
        .welcomePressCmdO: "按 Cmd+O 或點擊工具列中的開啟按鈕",
        .selectFileHint: "選擇檔案以預覽",
        .contextMenuNewFile: "新增檔案",
        .contextMenuNewSubdirectory: "新增子目錄",
        .contextMenuRename: "重新命名",
        .contextMenuMoveTo: "移動到\u{2026}",
        .contextMenuDelete: "移到垃圾桶",
        .renameTitle: "重新命名",
        .renameMessage: "輸入「{name}」的新名稱：",
        .renameEmptyName: "名稱不能為空。",
        .renameNameExists: "已存在同名項目。",
        .deleteTitle: "移到垃圾桶",
        .deleteMessage: "確定要將「{name}」移到垃圾桶嗎？",
        .deleteDirectoryMessage: "確定要將「{name}」及其所有內容移到垃圾桶嗎？",
        .moveSelectFolder: "選擇目標資料夾",
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
