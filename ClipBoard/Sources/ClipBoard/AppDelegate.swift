import SwiftUI
import AppKit
import ClipBoardCore
import ServiceManagement
import Carbon

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var clipboardManager: ClipboardManager!
    private var hotkeyManager: HotkeyManager!
    var pinManager: PinManager!
    private var eventMonitor: Any?
    let keyBindingStore = KeyBindingStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        clipboardManager = ClipboardManager()
        hotkeyManager = HotkeyManager()
        pinManager = PinManager()
        PinManager.shared = pinManager

        // 创建状态栏按钮
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "clipboard",
                accessibilityDescription: "ClipBoard"
            )
            button.action = #selector(togglePopover)
            button.target = self
            // 支持右键
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // 创建 Popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 480)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: ClipboardListView()
                .environmentObject(clipboardManager)
        )

        // 注册全局热键
        hotkeyManager.registerToggleHotkey { [weak self] in
            self?.togglePopover()
        }

        for i in 1...9 {
            hotkeyManager.registerPasteHotkey(index: i) { [weak self] in
                self?.pasteItem(at: i - 1)
            }
        }

        hotkeyManager.registerPinHotkey { [weak self] in
            self?.pinLatestImage()
        }

        // 开始监听剪贴板
        clipboardManager.startMonitoring()

        // 监听触控板捏合事件（转发到焦点钉图窗口）
        NSEvent.addLocalMonitorForEvents(matching: .magnify) { event in
            guard let pinMgr = PinManager.shared else { return event }
            guard let target = pinMgr.focusedPin ?? pinMgr.activePins.last else { return event }
            let scale = 1.0 + event.magnification
            target.zoomBy(scale: scale)
            return nil
        }

        // 监听钉图缩放快捷键 Cmd+= / Cmd+- / Cmd+R（只作用在焦点窗口）
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let pinMgr = PinManager.shared else { return event }
            guard let target = pinMgr.focusedPin ?? pinMgr.activePins.last else { return event }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            if event.keyCode == pinMgr.zoomInKeyCode && mods == pinMgr.zoomInModifiers {
                target.zoomBy(scale: 1.15)
                return nil
            }
            if event.keyCode == pinMgr.zoomOutKeyCode && mods == pinMgr.zoomOutModifiers {
                target.zoomBy(scale: 0.85)
                return nil
            }
            if pinMgr.zoomResetKeyCode != UInt16.max,
               event.keyCode == pinMgr.zoomResetKeyCode && mods == pinMgr.zoomResetModifiers {
                target.resetZoom()
                return nil
            }

            return event
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button, let event = NSApp.currentEvent else { return }

        // 右键 → 显示菜单
        if event.type == .rightMouseUp {
            let menu = NSMenu()

            // 开机启动开关
            let launchItem = NSMenuItem(
                title: "开机启动",
                action: #selector(toggleLaunchAtLogin),
                keyEquivalent: ""
            )
            if #available(macOS 13.0, *) {
                launchItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
            }
            menu.addItem(launchItem)

            menu.addItem(NSMenuItem(
                title: "偏好设置...",
                action: #selector(showPreferences),
                keyEquivalent: ","
            ))

            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(
                title: "退出 ClipBoard",
                action: #selector(quitApp),
                keyEquivalent: "q"
            ))
            menu.popUp(positioning: nil, at: button.bounds.origin, in: button)
            return
        }

        // 左键 → 开关面板
        if popover.isShown {
            popover.performClose(nil)
            removeEventMonitor()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            installEventMonitor()
        }
    }

    @objc private func toggleLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    print("已取消开机自启")
                } else {
                    try SMAppService.mainApp.register()
                    print("已开启开机自启")
                }
            } catch {
                print("⚠️ 开机启动设置失败: \(error)")
            }
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - 偏好设置

    @objc private func showPreferences() {
        let view = ShortcutSettingsView(store: keyBindingStore) { [weak self] binding in
            self?.onShortcutChanged(binding)
        }
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = "偏好设置"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 420, height: 420))
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func onShortcutChanged(_ binding: KeyBinding) {
        // 更新 HotkeyManager 的 Carbon 热键（开关面板、钉图）
        hotkeyManager.applyBindings(keyBindingStore.config.bindings)
        // 更新 PinManager 的缩放快捷键
        pinManager.applyZoomBindings(keyBindingStore.config.bindings)
    }

    // MARK: - 键盘事件监听（Popover 内方向键 + Enter + Esc）

    private func installEventMonitor() {
        // 移除旧的监听器（防止重复安装）
        removeEventMonitor()

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            // 确认事件发生在我们的 popover 窗口中
            guard let popoverWindow = self.popover.contentViewController?.view.window,
                  event.window == popoverWindow else {
                return event
            }

            switch event.keyCode {
            case 126: // 上箭头
                let count = self.clipboardManager.items.count
                if count > 0 {
                    self.clipboardManager.keyboardSelectedIndex = max(0, self.clipboardManager.keyboardSelectedIndex - 1)
                }
                return nil // 拦截事件

            case 125: // 下箭头
                let count = self.clipboardManager.items.count
                if count > 0 {
                    self.clipboardManager.keyboardSelectedIndex = min(count - 1, self.clipboardManager.keyboardSelectedIndex + 1)
                }
                return nil

                case 36: // Enter/Return
                    let index = self.clipboardManager.keyboardSelectedIndex
                    if index < self.clipboardManager.items.count {
                        let item = self.clipboardManager.items[index]
                        self.clipboardManager.writeToPasteboard(item)
                        self.showCopiedToast()
                    }
                    return nil

            case 53: // Escape
                self.popover.performClose(nil)
                self.removeEventMonitor()
                NSApp.hide(nil)
                return nil

            default:
                return event // 不拦截其他按键
            }
        }
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    // MARK: - 复制成功提示

    /// 关闭弹出面板
    func closePopover() {
        popover.performClose(nil)
        removeEventMonitor()
    }

    /// 在屏幕中央显示"已复制"浮层提示
    func showCopiedToast() {
        let width: CGFloat = 140
        let height: CGFloat = 44

        let toastWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        toastWindow.isOpaque = false
        toastWindow.backgroundColor = .clear
        toastWindow.level = .floating
        toastWindow.ignoresMouseEvents = true
        toastWindow.isReleasedWhenClosed = false

        // 使用 SwiftUI 视图，确保内容和背景完美居中
        let toastView = NSHostingView(rootView: CopiedToastView())
        toastView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        toastWindow.contentView = toastView

        // 定位到屏幕正中央
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            toastWindow.setFrameOrigin(NSPoint(
                x: screenFrame.midX - width / 2,
                y: screenFrame.midY - height / 2
            ))
        }

        toastWindow.orderFrontRegardless()

        // 0.8s 后淡出消失
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                toastWindow.animator().alphaValue = 0
            } completionHandler: {
                Task { @MainActor in
                    toastWindow.close()
                }
            }
        }
    }

    private func pasteItem(at index: Int) {
        guard index < clipboardManager.items.count else { return }
        let item = clipboardManager.items[index]
        clipboardManager.writeToPasteboard(item)
        showCopiedToast()
    }

    private func pinLatestImage() {
        guard let image = clipboardManager.latestImage else { return }
        pinManager.pin(image: image)
    }
}

// MARK: - 复制成功提示浮层

private struct CopiedToastView: View {
    var body: some View {
        Text("已复制 ✓")
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.primary)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
    }
}
