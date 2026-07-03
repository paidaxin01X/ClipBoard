import AppKit
import ClipBoardCore

final class PinWindow: NSWindow {
    private let image: NSImage
    private let originalSize: NSSize
    private var trackingArea: NSTrackingArea?

    init(image: NSImage) {
        self.image = image
        self.originalSize = image.size

        // 计算初始尺寸
        let screenSize = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1440, height: 900)
        var initialSize = image.size
        let maxW = screenSize.width * 0.8
        let maxH = screenSize.height * 0.8
        if initialSize.width > maxW || initialSize.height > maxH {
            let scale = min(maxW / initialSize.width, maxH / initialSize.height)
            initialSize = NSSize(width: initialSize.width * scale, height: initialSize.height * scale)
        }

        // 居中放置
        let origin = NSPoint(
            x: (screenSize.width - initialSize.width) / 2,
            y: (screenSize.height - initialSize.height) / 2
        )

        super.init(
            contentRect: NSRect(origin: origin, size: initialSize),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.level = .floating
        self.isMovableByWindowBackground = true
        self.acceptsMouseMovedEvents = true
        self.isReleasedWhenClosed = false

        // 内容视图
        self.contentView = PinContentView(image: image, frame: NSRect(origin: .zero, size: initialSize))

        setupTracking()
    }

    private func setupTracking() {
        if let existing = trackingArea {
            contentView?.removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: contentView?.bounds ?? .zero,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        if let area = trackingArea {
            contentView?.addTrackingArea(area)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        PinManager.shared?.focusedPin = self
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        PinManager.shared?.focusedPin = self
    }

    // 使用 Esc 关闭（由 PinApplication.sendEvent 处理）

    // 鼠标滚轮 / 触控板双指滑动 → 缩放
    override func scrollWheel(with event: NSEvent) {
        let scale: CGFloat = event.deltaY > 0 ? 1.1 : (event.deltaY < 0 ? 0.9 : 1.0)
        applyZoom(scale: scale)
    }

    // MARK: - 缩放

    private func applyZoom(scale: CGFloat) {
        var newWidth = frame.width * scale
        var newHeight = frame.height * scale

        let minSize: CGFloat = 50
        let screenSize = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1440, height: 900)
        let maxW = screenSize.width * 2
        let maxH = screenSize.height * 2
        newWidth = max(minSize, min(maxW, newWidth))
        newHeight = max(minSize, min(maxH, newHeight))

        let newFrame = NSRect(
            x: frame.origin.x - (newWidth - frame.width) / 2,
            y: frame.origin.y - (newHeight - frame.height) / 2,
            width: newWidth,
            height: newHeight
        )
        setFrame(newFrame, display: true, animate: false)
    }

    /// 按比例缩放（供快捷键调用）
    func zoomBy(scale: CGFloat) {
        applyZoom(scale: scale)
    }

    /// 恢复原始尺寸
    func resetZoom() {
        let screenSize = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1440, height: 900)
        var size = originalSize
        let maxW = screenSize.width * 0.8
        let maxH = screenSize.height * 0.8
        if size.width > maxW || size.height > maxH {
            let scale = min(maxW / size.width, maxH / size.height)
            size = NSSize(width: size.width * scale, height: size.height * scale)
        }
        let newFrame = NSRect(
            x: frame.origin.x - (size.width - frame.width) / 2,
            y: frame.origin.y - (size.height - frame.height) / 2,
            width: size.width,
            height: size.height
        )
        setFrame(newFrame, display: true, animate: false)
    }

    override var canBecomeKey: Bool { true }
}

// MARK: - 图片内容视图

class PinContentView: NSView {
    private let image: NSImage

    init(image: NSImage, frame: NSRect) {
        self.image = image
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current else { return }
        ctx.cgContext.setAllowsAntialiasing(true)

        // 圆角裁剪路径
        let clipPath = NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4)
        clipPath.addClip()

        // 绘制图片（保持宽高比，居中）
        let imageSize = image.size
        let boundsSize = bounds.size
        let scale = min(boundsSize.width / imageSize.width, boundsSize.height / imageSize.height)
        let drawSize = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let imageRect = NSRect(
            x: (boundsSize.width - drawSize.width) / 2,
            y: (boundsSize.height - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        image.draw(in: imageRect, from: .zero, operation: .copy, fraction: 1.0)
    }
}
