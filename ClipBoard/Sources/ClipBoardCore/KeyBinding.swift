import Carbon
import Foundation

/// 单个快捷键绑定
public struct KeyBinding: Identifiable, Codable, Sendable {
    public let id: String
    public let label: String
    public var keyCode: Int
    public var carbonModifiers: Int  // Carbon 格式的修饰键（cmdKey/shiftKey/optionKey/controlKey）

    public init(id: String, label: String, keyCode: Int, carbonModifiers: Int) {
        self.id = id
        self.label = label
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    /// 可读的快捷键字符串（如 ⌘⇧V）
    public var displayString: String {
        var parts: [String] = []
        if carbonModifiers & cmdKey != 0 { parts.append("⌘") }
        if carbonModifiers & shiftKey != 0 { parts.append("⇧") }
        if carbonModifiers & optionKey != 0 { parts.append("⌥") }
        if carbonModifiers & controlKey != 0 { parts.append("⌃") }
        parts.append(keyName)
        return parts.joined()
    }

    private var keyName: String {
        switch keyCode {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Grave: return "`"
        case kVK_Space: return "空格"
        case kVK_Return: return "回车"
        case kVK_Escape: return "Esc"
        case kVK_Delete: return "退格"
        case kVK_Tab: return "Tab"
        default: return "键\(keyCode)"
        }
    }
}

/// 全部快捷键配置
public struct KeyBindingConfig: Codable, Sendable {
    public var bindings: [String: KeyBinding]

    public init(bindings: [String: KeyBinding]) {
        self.bindings = bindings
    }

    /// 获取某个操作的快捷键
    public func binding(for id: String) -> KeyBinding? {
        bindings[id]
    }

    /// 默认配置
    public static let `default` = KeyBindingConfig(bindings: [
        "togglePanel": KeyBinding(id: "togglePanel", label: "打开/关闭面板",
                                   keyCode: kVK_ANSI_V, carbonModifiers: cmdKey | shiftKey),
        "pinImage": KeyBinding(id: "pinImage", label: "钉图（最近图片）",
                                keyCode: kVK_ANSI_P, carbonModifiers: cmdKey | shiftKey),
        "zoomIn": KeyBinding(id: "zoomIn", label: "钉图放大",
                              keyCode: kVK_ANSI_Equal, carbonModifiers: cmdKey),
        "zoomOut": KeyBinding(id: "zoomOut", label: "钉图缩小",
                               keyCode: kVK_ANSI_Minus, carbonModifiers: cmdKey),
        "zoomReset": KeyBinding(id: "zoomReset", label: "钉图复原",
                                 keyCode: kVK_ANSI_R, carbonModifiers: cmdKey),
    ])
}

// MARK: - 持久化

public final class KeyBindingStore {
    private let defaultsKey = "customKeyBindings"

    public private(set) var config: KeyBindingConfig

    public init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(KeyBindingConfig.self, from: data) {
            config = decoded
        } else {
            config = .default
        }
    }

    /// 更新某个快捷键并持久化
    public func updateBinding(_ binding: KeyBinding) {
        config.bindings[binding.id] = binding
        save()
    }

    /// 恢复默认
    public func resetToDefaults() {
        config = .default
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
