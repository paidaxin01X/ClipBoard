import Carbon
import AppKit

public final class HotkeyManager: @unchecked Sendable {
    private var hotkeyRefs: [EventHotKeyRef] = []
    private var toggleAction: (() -> Void)?
    private var pasteActions: [Int: () -> Void] = [:]
    private var pinAction: (() -> Void)?
    private var pinHotkeyID: Int = -1
    private var handlerInstalled = false

    public init() {}

    deinit {
        unregisterAll()
    }

    // MARK: - 注册

    public func registerToggleHotkey(action: @escaping () -> Void) {
        toggleAction = action
        registerHotkey(
            keyCode: UInt32(kVK_ANSI_V),   // V 键
            modifiers: UInt32(cmdKey | shiftKey),
            action: action
        )
    }

    public func registerPasteHotkey(index: Int, action: @escaping () -> Void) {
        guard (1...9).contains(index) else { return }
        pasteActions[index] = action
        // Alt+1 的 keyCode = kVK_ANSI_1 (18), Alt+2 = kVK_ANSI_2 (19), ..., Alt+9 = kVK_ANSI_9 (25)
        let keyCodes: [Int: UInt32] = [
            1: UInt32(kVK_ANSI_1), 2: UInt32(kVK_ANSI_2), 3: UInt32(kVK_ANSI_3),
            4: UInt32(kVK_ANSI_4), 5: UInt32(kVK_ANSI_5), 6: UInt32(kVK_ANSI_6),
            7: UInt32(kVK_ANSI_7), 8: UInt32(kVK_ANSI_8), 9: UInt32(kVK_ANSI_9),
        ]
        guard let keyCode = keyCodes[index] else { return }

        registerHotkey(
            keyCode: keyCode,
            modifiers: UInt32(optionKey),
            action: action
        )
    }

    public func registerPinHotkey(action: @escaping () -> Void) {
        pinAction = action
        pinHotkeyID = hotkeyRefs.count
        registerHotkey(
            keyCode: UInt32(kVK_ANSI_P),
            modifiers: UInt32(cmdKey | shiftKey),
            action: action
        )
    }

    // MARK: - 自定义快捷键（重新注册）

    /// 根据自定义配置重新注册所有热键
    public func applyBindings(_ bindings: [String: KeyBinding]) {
        // 卸载所有旧热键
        for ref in hotkeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotkeyRefs.removeAll()
        handlerInstalled = false

        // 重新注册开关面板
        if let b = bindings["togglePanel"], let action = toggleAction {
            registerHotkey(keyCode: UInt32(b.keyCode), modifiers: UInt32(b.carbonModifiers), action: action)
        }

        // 重新注册粘贴 1~9（暂不开放自定义，固定 Alt+数字）
        let pasteKeyCodes: [Int: UInt32] = [
            1: UInt32(kVK_ANSI_1), 2: UInt32(kVK_ANSI_2), 3: UInt32(kVK_ANSI_3),
            4: UInt32(kVK_ANSI_4), 5: UInt32(kVK_ANSI_5), 6: UInt32(kVK_ANSI_6),
            7: UInt32(kVK_ANSI_7), 8: UInt32(kVK_ANSI_8), 9: UInt32(kVK_ANSI_9),
        ]
        for (index, action) in pasteActions {
            if let keyCode = pasteKeyCodes[index] {
                registerHotkey(keyCode: keyCode, modifiers: UInt32(optionKey), action: action)
            }
        }

        // 重新注册钉图
        if let b = bindings["pinImage"], let action = pinAction {
            pinHotkeyID = hotkeyRefs.count
            registerHotkey(keyCode: UInt32(b.keyCode), modifiers: UInt32(b.carbonModifiers), action: action)
        }
    }

    func unregisterAll() {
        for ref in hotkeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotkeyRefs.removeAll()
        pasteActions.removeAll()
    }

    // MARK: - 底层 Carbon API

    private func registerHotkey(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        var hotkeyRef: EventHotKeyRef?
        let hotkeyID = EventHotKeyID(signature: OSType(0x434C4942), id: UInt32(hotkeyRefs.count)) // "CLIB"

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetEventDispatcherTarget(),
            0,
            &hotkeyRef
        )

        guard status == noErr, let ref = hotkeyRef else { return }
        hotkeyRefs.append(ref)

        // 安装事件处理器（仅首次）
        if !handlerInstalled {
            handlerInstalled = true
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(
                GetEventDispatcherTarget(),
                { _, event, _ -> OSStatus in
                    var hotkeyID = EventHotKeyID()
                    let status = GetEventParameter(
                        event,
                        EventParamName(kEventParamDirectObject),
                        EventParamType(typeEventHotKeyID),
                        nil,
                        MemoryLayout<EventHotKeyID>.size,
                        nil,
                        &hotkeyID
                    )
                    guard status == noErr else { return noErr }

                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: .hotkeyPressed,
                            object: nil,
                            userInfo: ["id": Int(hotkeyID.id)]
                        )
                    }
                    return noErr
                },
                1,
                &eventType,
                nil,
                nil
            )

            // 监听通知以分发回调
            NotificationCenter.default.addObserver(
                forName: .hotkeyPressed,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self = self,
                      let id = notification.userInfo?["id"] as? Int else { return }
                if id == 0 {
                    self.toggleAction?()
                } else if id == self.pinHotkeyID {
                    self.pinAction?()
                } else if let action = self.pasteActions[id] {
                    action()
                }
            }
        }
    }
}

extension Notification.Name {
    static let hotkeyPressed = Notification.Name("HotkeyPressed")
}
