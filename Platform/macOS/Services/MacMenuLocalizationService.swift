#if os(macOS)
import AppKit

@MainActor
enum MacMenuLocalizationService {
    static func apply() {
        guard let mainMenu = NSApp.mainMenu else { return }
        let loc = LocalizationManager.shared
        localizeTopLevelMenus(mainMenu, loc: loc)
        localizeItems(in: mainMenu, loc: loc)
    }

    private static func localizeTopLevelMenus(_ menu: NSMenu, loc: LocalizationManager) {
        for item in menu.items {
            if let key = canonicalTopLevelKey(for: item.title) {
                item.title = loc.localized(key)
            }
        }
    }

    private static func localizeItems(in menu: NSMenu, loc: LocalizationManager) {
        for item in menu.items {
            if let key = canonicalItemKey(for: item.title) {
                item.title = loc.localized(key).replacingOccurrences(of: "%@", with: "Ruffnova")
            }
            if let submenu = item.submenu {
                localizeItems(in: submenu, loc: loc)
            }
        }
    }

    private static func canonicalTopLevelKey(for title: String) -> String? {
        switch normalized(title) {
        case "File", "文件": return "systemMenu.file"
        case "Edit", "编辑": return "systemMenu.edit"
        case "View", "显示", "视图": return "systemMenu.view"
        case "Control", "控制": return "menu.control"
        case "Window", "窗口": return "systemMenu.window"
        case "Help", "帮助": return "systemMenu.help"
        default: return nil
        }
    }

    private static func canonicalItemKey(for title: String) -> String? {
        switch normalized(title) {
        case "About Ruffnova", "关于 Ruffnova": return "systemMenu.aboutApp"
        case "Settings...", "Preferences...", "偏好设置...", "设置...": return "menu.preferences"
        case "Services", "服务": return "systemMenu.services"
        case "Hide Ruffnova", "隐藏 Ruffnova": return "systemMenu.hideApp"
        case "Hide Others", "隐藏其他": return "systemMenu.hideOthers"
        case "Show All", "全部显示": return "systemMenu.showAll"
        case "Quit Ruffnova", "退出 Ruffnova": return "systemMenu.quitApp"
        case "Undo", "撤销": return "systemMenu.undo"
        case "Redo", "重做": return "systemMenu.redo"
        case "Cut", "剪切": return "systemMenu.cut"
        case "Copy", "拷贝", "复制": return "systemMenu.copy"
        case "Paste", "粘贴": return "systemMenu.paste"
        case "Paste and Match Style", "粘贴并匹配样式": return "systemMenu.pasteAndMatchStyle"
        case "Delete", "删除": return "systemMenu.delete"
        case "Select All", "全选": return "systemMenu.selectAll"
        case "Find", "查找": return "systemMenu.find"
        case "Find...", "查找...": return "systemMenu.findItem"
        case "Find and Replace...", "查找和替换...": return "systemMenu.findAndReplace"
        case "Find Next", "查找下一个": return "systemMenu.findNext"
        case "Find Previous", "查找上一个": return "systemMenu.findPrevious"
        case "Use Selection for Find", "使用所选内容查找": return "systemMenu.useSelectionForFind"
        case "Jump to Selection", "跳到所选内容": return "systemMenu.jumpToSelection"
        case "Spelling and Grammar", "拼写和语法": return "systemMenu.spellingAndGrammar"
        case "Show Spelling and Grammar", "显示拼写和语法": return "systemMenu.showSpellingAndGrammar"
        case "Check Document Now", "立即检查文稿": return "systemMenu.checkDocumentNow"
        case "Check Spelling While Typing", "键入时检查拼写": return "systemMenu.checkSpellingWhileTyping"
        case "Check Grammar With Spelling", "随拼写检查语法": return "systemMenu.checkGrammarWithSpelling"
        case "Correct Spelling Automatically", "自动纠正拼写": return "systemMenu.correctSpellingAutomatically"
        case "Substitutions", "替换": return "systemMenu.substitutions"
        case "Show Substitutions", "显示替换": return "systemMenu.showSubstitutions"
        case "Smart Copy/Paste", "智能拷贝/粘贴": return "systemMenu.smartCopyPaste"
        case "Smart Quotes", "智能引号": return "systemMenu.smartQuotes"
        case "Smart Dashes", "智能破折号": return "systemMenu.smartDashes"
        case "Smart Links", "智能链接": return "systemMenu.smartLinks"
        case "Data Detectors", "数据检测器": return "systemMenu.dataDetectors"
        case "Text Replacement", "文本替换": return "systemMenu.textReplacement"
        case "Transformations", "转换": return "systemMenu.transformations"
        case "Make Upper Case", "改为大写": return "systemMenu.makeUpperCase"
        case "Make Lower Case", "改为小写": return "systemMenu.makeLowerCase"
        case "Capitalize", "首字母大写": return "systemMenu.capitalize"
        case "Speech", "语音": return "systemMenu.speech"
        case "Start Speaking", "开始朗读": return "systemMenu.startSpeaking"
        case "Stop Speaking", "停止朗读": return "systemMenu.stopSpeaking"
        case "Show Toolbar", "显示工具栏": return "systemMenu.showToolbar"
        case "Hide Toolbar", "隐藏工具栏": return "systemMenu.hideToolbar"
        case "Customize Toolbar...", "自定工具栏...": return "systemMenu.customizeToolbar"
        case "Minimize", "最小化": return "systemMenu.minimize"
        case "Zoom", "缩放": return "systemMenu.zoom"
        case "Bring All to Front", "全部移到前面": return "systemMenu.bringAllToFront"
        default: return nil
        }
    }

    private static func normalized(_ title: String) -> String {
        title.replacingOccurrences(of: "\u{2026}", with: "...")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
#endif
