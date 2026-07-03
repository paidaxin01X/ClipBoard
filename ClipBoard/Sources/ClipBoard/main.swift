import Cocoa
import SwiftUI
import Carbon

/// 自定义 NSApplication 子类，拦截触控板捏合和键盘事件
final class PinApplication: NSApplication {
    override func sendEvent(_ event: NSEvent) {
        // 触控板捏合缩放 → 转发到焦点钉图窗口
        if event.type == .magnify {
            if let mgr = PinManager.shared {
                let scale = 1.0 + event.magnification
                mgr.focusedPin?.zoomBy(scale: scale)
            }
        }

        // 钉图缩放快捷键（只作用在焦点窗口，不是全部）
        if event.type == .keyDown {
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if let mgr = PinManager.shared {
                guard let target = mgr.focusedPin ?? mgr.activePins.last else {
                    super.sendEvent(event)
                    return
                }
                // Zoom In
                if event.keyCode == mgr.zoomInKeyCode && mods == mgr.zoomInModifiers {
                    target.zoomBy(scale: 1.15)
                    return
                }
                // Zoom Out
                if event.keyCode == mgr.zoomOutKeyCode && mods == mgr.zoomOutModifiers {
                    target.zoomBy(scale: 0.85)
                    return
                }
                // Zoom Reset
                if mgr.zoomResetKeyCode != UInt16.max,
                   event.keyCode == mgr.zoomResetKeyCode && mods == mgr.zoomResetModifiers {
                    target.resetZoom()
                    return
                }
            }
        }

        // Escape → 关闭钉图
        if event.type == .keyDown && event.keyCode == 53 {
            if let mgr = PinManager.shared, let window = mgr.activePins.last {
                mgr.remove(window)
                return  // 拦截事件，不继续分发
            }
        }

        // 其他事件照常分发
        super.sendEvent(event)
    }
}

// 手动启动应用
let app = PinApplication.shared
NSApp.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate
app.run()
