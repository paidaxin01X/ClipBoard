import AppKit
import ClipBoardCore
import Carbon

@MainActor
final class PinManager: NSObject, NSWindowDelegate {
    static weak var shared: PinManager?
    private var pinnedWindows: [PinWindow] = []
    /// 当前钉图窗口列表（供事件转发使用）
    var activePins: [PinWindow] { pinnedWindows }

    // MARK: - 自定义快捷键（由 AppDelegate 同步）

    var zoomInKeyCode: UInt16 = UInt16(kVK_ANSI_Equal)
    var zoomInModifiers: NSEvent.ModifierFlags = .command
    var zoomOutKeyCode: UInt16 = UInt16(kVK_ANSI_Minus)
    var zoomOutModifiers: NSEvent.ModifierFlags = .command
    var zoomResetKeyCode: UInt16 = UInt16.max  // 默认不使用，由 Carbon 热键处理
    var zoomResetModifiers: NSEvent.ModifierFlags = .command

    /// 从自定义快捷键配置同步缩放快捷键
    func applyZoomBindings(_ bindings: [String: KeyBinding]) {
        if let b = bindings["zoomIn"] {
            zoomInKeyCode = UInt16(b.keyCode)
            zoomInModifiers = carbonToAppKitModifiers(b.carbonModifiers)
        }
        if let b = bindings["zoomOut"] {
            zoomOutKeyCode = UInt16(b.keyCode)
            zoomOutModifiers = carbonToAppKitModifiers(b.carbonModifiers)
        }
        if let b = bindings["zoomReset"] {
            zoomResetKeyCode = UInt16(b.keyCode)
            zoomResetModifiers = carbonToAppKitModifiers(b.carbonModifiers)
        }
    }

    private func carbonToAppKitModifiers(_ carbon: Int) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbon & cmdKey != 0    { flags.insert(.command) }
        if carbon & shiftKey != 0  { flags.insert(.shift) }
        if carbon & optionKey != 0 { flags.insert(.option) }
        if carbon & controlKey != 0{ flags.insert(.control) }
        return flags
    }

    // ... rest stays the same

/// 钉一张图片到屏幕上
    func pin(image: NSImage) {
        let window = PinWindow(image: image)
        window.delegate = self
        window.orderFrontRegardless()
        pinnedWindows.append(window)
        focusedPin = window  // 新钉的图默认获得焦点
    }

    /// 当前获得焦点的钉图（鼠标悬停或点击过的那张）
    weak var focusedPin: PinWindow?  // 允许 PinWindow 在 mouseEntered/mouseDown 时设置

    /// 移除指定的钉图窗口
    func remove(_ window: PinWindow) {
        window.close()
        pinnedWindows.removeAll { $0 == window }
        if focusedPin == window {
            focusedPin = pinnedWindows.last
        }
    }

    /// 移除全部钉图
    func unpinAll() {
        for window in pinnedWindows {
            window.close()
        }
        pinnedWindows.removeAll()
    }

    /// 当前钉图数量
    var count: Int { pinnedWindows.count }

    // MARK: - NSWindowDelegate

    func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? PinWindow else { return }
        focusedPin = window
    }
}
